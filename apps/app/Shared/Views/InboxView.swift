import Combine
import OSLog
import SwiftData
import SwiftUI

/// The feed.
///
/// Geist: pure black, hairline rules, no cards. Unread is a single brand-red dot —
/// the only colour on the screen. Time reads exact-above-relative in a right-hand
/// column with the thumbnail beneath it.
///
/// This stays a `List` rather than a `ScrollView` so swipe actions and
/// pull-to-refresh keep working; the system chrome is styled away instead.
struct InboxView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    /// Ages are measured against this instead of reading the clock as each row
    /// draws. A row that calls `Date()` inside its own body is only as fresh as
    /// the last redraw SwiftUI happened to do for some other reason — so with no
    /// network to deliver a change, every stamp on the feed sat frozen at the
    /// age it had when the screen appeared. Ticking a piece of state is what
    /// actually invalidates the rows.
    ///
    /// Half a minute rather than a full one because the first step is "now" to
    /// "1 min": on a 60s tick that flip can land 59 seconds late, which on a
    /// pager is the difference a reader is looking at.
    @State private var now = Date()
    private static let clock = Timer
        .publish(every: 30, tolerance: 5, on: .main, in: .common)
        .autoconnect()

    @State private var searchText = ""
    @State private var filterKeyID: Int?
    @State private var pendingDelete: Message?
    @State private var showingSearch = false
    @FocusState private var searchFocused: Bool

    private var keys: [CachedKey] { model.sync?.keys ?? [] }

    private var activeKeyName: String? {
        filterKeyID.flatMap { id in keys.first { $0.id == id }?.name }
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Search matches title, message and link host. The key filter is separate and
    /// ANDed with the query.
    private var filtered: [Message] {
        let needle = trimmedQuery.lowercased()
        return messages.filter { message in
            let matchesKey = filterKeyID.map { message.keyID == $0 } ?? true
            guard matchesKey else { return false }
            guard !needle.isEmpty else { return true }
            if message.title.lowercased().contains(needle) { return true }
            if let body = message.body?.lowercased(), body.contains(needle) { return true }
            if let host = message.link?.host()?.lowercased(), host.contains(needle) { return true }
            return false
        }
    }

    private var unreadCount: Int { messages.reduce(0) { $0 + ($1.isRead ? 0 : 1) } }

    /// Built as concatenated `Text` so the unread count alone can take the brand
    /// colour. `brandText` rather than `brand` — the flat brand red is under the
    /// contrast floor for text this small.
    private var subtitle: Text {
        let total = messages.count == 1
            ? "1 notification"
            : "\(messages.count) notifications"
        guard unreadCount > 0 else { return Text(total) }
        // Unread leads: it is the number the screen exists to answer, and the
        // total is the context for it.
        return Text("\(unreadCount)").foregroundColor(Theme.brandText)
            + Text(" unread · \(total)")
    }

    var body: some View {
        // The header sits outside the List rather than in its first row, so it
        // stays put while the feed moves under it. In the row it scrolled away,
        // which took the title, the count, the search field and the overflow
        // menu off screen together — on the Mac that left a popover with no
        // chrome at all and nothing to get back to.
        //
        // No rule under it: the first message opens the list, and a line there
        // only boxed the search field in. Rows still carry their own bottom
        // rule, so every message is separated from the next.
        VStack(spacing: 0) {
            header
                .geistPageHeader()
                .geistGutter()
                .background(Theme.bg)

            list
        }
        .background(Theme.bg)
    }

    private var list: some View {
        List {
            if messages.isEmpty {
                EmptyStateView()
                    .padding(.top, 30)
                    .plainRow()
            } else if filtered.isEmpty {
                NoResultsView(
                    query: trimmedQuery,
                    scopeNote: activeKeyName.map { "Filtered to the “\($0)” key." },
                    onClear: clearFilters
                )
                .plainRow()
            } else {
                ForEach(filtered, id: \.serverID) { message in
                    Button {
                        searchFocused = false
                        model.path.append(message.serverID)
                    } label: {
                        // The gutter is inside the button and the shape is
                        // explicit, so the whole row answers a tap. With the
                        // padding outside, the 20pt margins were dead, and
                        // without the shape the gaps between title, time and
                        // thumbnail were too: a stack only hit-tests where it
                        // actually drew something.
                        MessageRow(
                            message: message,
                            allowAnyScheme: model.allowsAnyLink(keyID: message.keyID),
                            now: now
                        )
                        .geistGutter()
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.geistRow)
                    // The row's content carries the gutter, the rule does not,
                    // so the message stays inside the margin while the line
                    // between messages runs edge to edge.
                    .overlay(alignment: .bottom) { Hairline() }
                    // Unread sits one step off the ground. The dot alone made the
                    // state a thing you find rather than a thing you see, which on
                    // a screen whose whole job is "what have I not read" is the
                    // wrong way round.
                    .plainRow(background: message.isRead ? Theme.bg : Theme.surface)
                    // Swiping is a touch idiom. On the Mac the same actions live in
                    // the right-click menu below, which is where a Mac user looks.
                    #if os(iOS)
                    .swipeActions(edge: .leading) {
                        Button { toggleRead(message) } label: {
                            // The same ring/dot the detail screen uses for this
                            // action, so the two places that toggle read state
                            // are not drawn from different icon families.
                            //
                            // An `Image` rather than a `Label`: a swipe action
                            // renders the title under the glyph, and the word was
                            // doing nothing the icon and the swipe direction did
                            // not already say. The spoken name is kept.
                            Image(systemName: message.isRead ? "circle.fill" : "circle")
                                .accessibilityLabel(
                                    message.isRead ? "Mark as unread" : "Mark as read")
                        }
                        .tint(Theme.chip)
                    }
                    .swipeActions(edge: .trailing) {
                        // The tint has to be explicit. `role: .destructive` would
                        // normally colour this red, but the TabView's near-white
                        // tint cascades down and wins, giving white-on-white.
                        // Asks first: a swipe is easy to do by accident and the
                        // message cannot be recovered afterwards.
                        Button(role: .destructive) { pendingDelete = message } label: {
                            Image(systemName: "trash")
                                .accessibilityLabel("Delete")
                        }
                        .tint(Theme.danger)
                    }
                    #endif
                    .contextMenu { menu(for: message) }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .scrollDismissesKeyboard(.immediately)
        .onReceive(Self.clock) { now = $0 }
        // Timers do not fire while the app is suspended, so coming back to the
        // foreground after a while would otherwise show the ages from whenever
        // it was last put down until the next tick caught up.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
// Pull-to-refresh is a touch gesture. The Mac refreshes with ⌘R and the
        // overflow menu instead; the iOS-only modifier is below.
        .alert(
            "Delete this notification?",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { message in
            Button("Delete", role: .destructive) {
                delete(message)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("This cannot be undone.")
        }
        #if os(iOS)
        .refreshable { await model.refresh() }
        // The screen's own header carries the title and both controls, so the
        // navigation bar would only add an empty strip above them.
        .toolbar(.hidden, for: .navigationBar)
        // Last in the chain, so the fade sits over the finished screen rather
        // than having the refresh control layered back on top of it. Applied to
        // the feed only: Keys and Settings are short enough to end on their own,
        // and a fade over content that never reaches the bottom edge is a
        // gradient with nothing to dissolve.
        .geistBottomFade()
        #endif
    }

    /// Search is a button rather than a field kept on screen. The system one
    /// could not be made to look like anything else here, and a field parked
    /// above the feed is chrome that earns its space only when it is wanted.
    private var searchToggle: some View {
        IconButton(systemImage: showingSearch ? "xmark" : "magnifyingglass",
                   label: showingSearch ? "Close search" : "Search",
                   glass: true) {
            if showingSearch {
                closeSearch()
            } else {
                // Not animated. The field lives in a List row, so sliding it in
                // animates the row's height, which drags the title and every row
                // under it down the screen with it.
                showingSearch = true
                searchFocused = true
            }
        }
    }

    private func closeSearch() {
        searchFocused = false
        searchText = ""
        showingSearch = false
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Built here rather than with `GeistHeader` because "Notifications"
            // is a long word: beside a count it wrapped mid-word, so the title
            // and its count stack while the controls sit on the title's line.
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Notifications".uppercased())
                        .font(Theme.screenTitle)
                        .foregroundStyle(Theme.fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(height: Theme.headerBarHeight, alignment: .leading)
                    subtitle
                        .font(Theme.meta)
                        .foregroundColor(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    if !messages.isEmpty { searchToggle }
                    overflowMenu
                }
                .frame(height: Theme.headerBarHeight)
            }
            .padding(.bottom, messages.isEmpty ? 0 : 14)

            if !messages.isEmpty {
                // Nothing to search through yet, so the field would just be
                // furniture. It appears only once the search button asks for it.
                //
                // No transition. Sliding it in animates the header's height,
                // which shoves the title up and drags the whole feed after it —
                // the field is the only thing that should be arriving.
                if showingSearch {
                    SearchField(text: $searchText, focused: $searchFocused)
                }

                if let activeKeyName {
                    HStack(spacing: 8) {
                        Chip(text: activeKeyName, color: Theme.fg,
                             border: Theme.muted.opacity(0.5))
                        Button("Clear") { filterKeyID = nil }
                            .font(Theme.label)
                            .foregroundStyle(Theme.dim)
                            .buttonStyle(.geist)
                            // An 11pt label draws an 11pt target. Expanded rather
                            // than padded so the filter row keeps the height of
                            // the chip beside it.
                            .geistHitArea(expandedBy: 16)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    private var overflowMenu: some View {
        Menu {
            Button("Mark all as read", action: markAllRead)
                .disabled(unreadCount == 0)

            if keys.count > 1 {
                Divider()
                Picker("Filter by key", selection: $filterKeyID) {
                    Text("All keys").tag(Int?.none)
                    ForEach(keys) { key in
                        Text(key.name).tag(Int?.some(key.id))
                    }
                }
            }

            // Keys and Settings are tabs on both platforms now, so listing them
            // here too would be a second door to the same room. What the Mac does
            // still need is a refresh: pull-to-refresh is a touch gesture and does
            // not exist here.
            #if os(macOS)
            Divider()
            Button("Refresh") { Task { await model.refresh() } }
                .keyboardShortcut("r", modifiers: .command)
            #endif

            #if DEBUG
            if SampleData.isEnabled {
                Divider()
                Button("Seed sample data") {
                    SampleData.seed(into: context, keyIDs: keys.map(\.id))
                }
                Button("Clear sample data", role: .destructive) {
                    SampleData.clear(from: context)
                }
            }
            #endif
        } label: {
            // Deliberately the same body as `IconButton(glass: true)`, which is
            // what sits next to it. A Menu draws its own pill around whatever
            // label it is given unless the style and the button style below
            // both stand down, and the two controls stopped matching.
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filterKeyID == nil ? Theme.fg : Theme.brand)
                .frame(width: 34, height: 34)
                .glassBackground(enabled: true)
                .contentShape(Circle())
                .geistHitArea(expandedBy: 5)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More")
    }

    // MARK: Row menu

    @ViewBuilder
    private func menu(for message: Message) -> some View {
        Button(message.isRead ? "Mark as unread" : "Mark as read") { toggleRead(message) }
        Divider()
        Button("Copy title") { Clipboard.copy(message.title) }
        if let body = message.body {
            Button("Copy message") { Clipboard.copy(body) }
        }
        if let link = message.link {
            Button("Copy link") { Clipboard.copy(link.absoluteString) }
            if LinkPolicy.allows(link, anyScheme: model.allowsAnyLink(keyID: message.keyID)) {
                Button("Open link") { open(link, keyID: message.keyID) }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { pendingDelete = message }
    }

    // MARK: Actions

    private func clearFilters() {
        searchText = ""
        filterKeyID = nil
    }

    private func toggleRead(_ message: Message) {
        message.isRead.toggle()
        save()
        model.sync?.updateBadge()
    }

    private func markAllRead() {
        for message in messages where !message.isRead { message.isRead = true }
        save()
        model.sync?.updateBadge()
    }

    private func delete(_ message: Message) {
        context.delete(message)
        save()
        model.sync?.updateBadge()
    }

    private func open(_ url: URL, keyID: Int?) {
        guard LinkPolicy.allows(url, keyID: keyID) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Every write goes through here so a failure is logged rather than swallowed.
    private func save() {
        do {
            try context.save()
        } catch {
            Logger(subsystem: "it.notifi.app", category: "inbox")
                .error("save failed: \(String(describing: error), privacy: .public)")
        }
    }
}

private extension View {
    /// Strips every default List decoration so the row is drawn entirely by us.
    ///
    /// Insets are a parameter rather than a second `.listRowInsets` call — applying
    /// that modifier twice keeps the innermost value, which silently made rows
    /// full-bleed and pushed the thumbnails off the right edge.
    func plainRow(insets: EdgeInsets = EdgeInsets(),
                  background: Color = Theme.bg) -> some View {
        listRowBackground(background)
            .listRowSeparator(.hidden)
            .listRowInsets(insets)
    }
}

// MARK: - Row

private struct MessageRow: View {
    let message: Message
    let allowAnyScheme: Bool
    /// Passed in rather than read here — see the clock on `InboxView`.
    let now: Date

    private var relative: String {
        let basis = message.occurredAt ?? message.createdAt
        let seconds = max(0, Int(now.timeIntervalSince(basis)))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(seconds / 60) min"
        case ..<86_400: return "\(seconds / 3_600) hr"
        case ..<604_800: return "\(seconds / 86_400) d"
        default: return "\(seconds / 604_800) w"
        }
    }

    var body: some View {
        // Unread is carried by the row's ground and the title's weight, so the
        // text starts at the gutter like every other screen rather than being
        // indented past a marker column.
        HStack(alignment: .firstTextBaseline, spacing: Theme.rowGap) {
            VStack(alignment: .leading, spacing: 5) {
                Text(message.title)
                    .font(message.isRead ? Theme.title : Theme.titleUnread)
                    .foregroundStyle(message.isRead ? Theme.read : Theme.fg)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if let body = message.body {
                    // The row is two lines: markers are stripped and inline styling
                    // kept, so a bulleted body previews as prose rather than dashes.
                    Text(MarkdownPreview.text(body))
                        .font(Theme.body)
                        .foregroundStyle(Theme.dim)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                if let link = message.link {
                    Chip(text: link.host() ?? link.absoluteString, trailingGlyph: "↗")
                        .padding(.top, 5)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                // Relative time only. The exact stamp is a fixed 18 characters, so
                // it set the width of this column and squeezed titles into extra
                // lines to buy a precision the feed never needed. The detail page
                // carries the full date, down to the millisecond.
                // Smaller and quieter than the body it sits beside: the age is a
                // coordinate, and at `meta`/`muted` it was the brightest thing in
                // the row after the title.
                Text(relative)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                if let url = message.imageURL,
                   LinkPolicy.allows(url, anyScheme: allowAnyScheme) {
                    Thumbnail(url: url).padding(.top, 8)
                }
            }
            .monospacedDigit()
        }
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenDescription)
    }

    /// Everything the row shows, in the order it is read on screen.
    ///
    /// Overriding the label at all discards what `children: .combine` gathered,
    /// so the previous one-line version silently dropped the body preview and the
    /// age — on a pager, the two things you scan the feed for. Rebuilt here
    /// rather than removing the override, because the combined default reads the
    /// title and the preview as one run-on sentence and never says "unread".
    private var spokenDescription: String {
        var parts: [String] = []
        if !message.isRead { parts.append("Unread") }
        parts.append(message.title)
        if let body = message.body {
            parts.append(String(MarkdownPreview.text(body).characters))
        }
        if let link = message.link, let host = link.host() {
            parts.append("Link to \(host)")
        }
        parts.append(relative == "now" ? "just now" : "\(relative) ago")
        return parts.joined(separator: ", ")
    }
}

/// Reserves its slot while loading and marks failure rather than collapsing, so
/// the list never reflows as images arrive.
///
/// Scrolling the feed would otherwise fetch every image in it, so with automatic
/// loading off this draws a placeholder and makes no request. The image is still
/// one tap away in the detail view.
private struct Thumbnail: View {
    @Environment(AppModel.self) private var model
    let url: URL

    var body: some View {
        Group {
            if model.remoteImagesEnabled {
                remote
            } else {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.dim)
                    )
            }
        }
        .frame(width: Theme.thumb, height: Theme.thumb)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.chip, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var remote: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(Theme.chip, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.dim)
                    )
            default:
                RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.surface)
            }
        }
    }
}
