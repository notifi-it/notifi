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
        return Text("\(total) · ")
            + Text("\(unreadCount)").foregroundColor(Theme.brandText)
            + Text(" unread")
    }

    var body: some View {
        List {
// No rule under the header: the first message opens the list, and a
            // line there only boxed the search field in. Rows still carry their
            // own bottom rule, so every message is separated from the next.
            header
                .geistPageHeader()
            // Gutter inside the row, with the row inset zeroed, so this matches
            // Keys and Settings exactly. Setting it as a row inset instead let
            // the List add a few points of its own on top.
            .geistGutter()
            .listRowInsets(EdgeInsets())
            .listRowBackground(Theme.bg)
            .listRowSeparator(.hidden)

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
                    .overlay(alignment: .bottom) { Hairline().geistGutter() }
                    .plainRow()
                    // Swiping is a touch idiom. On the Mac the same actions live in
                    // the right-click menu below, which is where a Mac user looks.
                    #if os(iOS)
                    .swipeActions(edge: .leading) {
                        Button { toggleRead(message) } label: {
                            Label(message.isRead ? "Unread" : "Read",
                                  systemImage: message.isRead
                                      ? "envelope.badge" : "envelope.open")
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
                            Label("Delete", systemImage: "trash")
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar { navBarContent }
        #endif
    }

    #if os(iOS)
    /// The wordmark is a logo, not a control, so it opts out of the toolbar's
    /// shared Liquid Glass — otherwise iOS 26 draws it sitting in a tappable-
    /// looking pill. The buttons keep their glass, because they are buttons.
    @ToolbarContentBuilder
    private var navBarContent: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: .topBarLeading) { BrandMark(size: 17) }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .topBarLeading) { BrandMark(size: 17) }
        }
        if !messages.isEmpty {
            ToolbarItem(placement: .topBarTrailing) { searchToggle }
        }
        ToolbarItem(placement: .topBarTrailing) { overflowMenu }
    }
    #endif

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
            // iOS puts the wordmark and the buttons in the navigation bar. A
            // popover has no navigation bar, so the Mac carries the same row
            // here — via `GeistBrandRow`, so it cannot drift from every other
            // screen's header the way a hand-rolled copy did.
            #if os(macOS)
            GeistBrandRow {
                if !messages.isEmpty { searchToggle }
                overflowMenu
            }
            .padding(.bottom, Theme.headerBarGap)
            #endif

            // "Notifications" is a long word; beside a count it wrapped mid-word.
            // Stacked, the title always gets its own line at any Dynamic Type size.
            VStack(alignment: .leading, spacing: 3) {
                Text("Notifications".uppercased())
                    .font(Theme.screenTitle)
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                subtitle
                    .font(Theme.meta)
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, messages.isEmpty ? 0 : 14)

            if !messages.isEmpty {
                // Nothing to search through yet, so the field would just be
                // furniture. It appears only once the search button asks for it.
                if showingSearch {
                    SearchField(text: $searchText, focused: $searchFocused)
                        .transition(.move(edge: .top).combined(with: .opacity))
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
            Button("Mark All as Read", action: markAllRead)
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
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filterKeyID == nil ? Theme.fg : Theme.brand)
                .frame(width: 34, height: 34)
                .glassBackground()
                .contentShape(Circle())
        }
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel("More")
    }

    // MARK: Row menu

    @ViewBuilder
    private func menu(for message: Message) -> some View {
        Button(message.isRead ? "Mark as Unread" : "Mark as Read") { toggleRead(message) }
        Divider()
        Button("Copy Title") { Clipboard.copy(message.title) }
        if let body = message.body {
            Button("Copy Message") { Clipboard.copy(body) }
        }
        if let link = message.link {
            Button("Copy Link") { Clipboard.copy(link.absoluteString) }
            if LinkPolicy.allows(link, anyScheme: model.allowsAnyLink(keyID: message.keyID)) {
                Button("Open Link") { open(link, keyID: message.keyID) }
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
    func plainRow(insets: EdgeInsets = EdgeInsets()) -> some View {
        listRowBackground(Theme.bg)
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
        HStack(alignment: .firstTextBaseline, spacing: Theme.rowGap) {
            // The unread marker — the only colour in the system. Hung off the
            // title's own baseline rather than a fixed top inset, so it stays
            // centred on the first line as Dynamic Type resizes it.
            Circle()
                .fill(message.isRead ? Color.clear : Theme.brand)
                .frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { $0.height + 1 }
                .accessibilityHidden(true)

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
                        .foregroundStyle(Theme.muted)
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
                Text(relative)
                    .font(Theme.meta)
                    .foregroundStyle(Theme.muted)
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
