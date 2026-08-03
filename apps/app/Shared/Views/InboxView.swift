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
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    @State private var searchText = ""
    @State private var filterKeyID: Int?
    @State private var pendingDelete: Message?
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
                        MessageRow(
                            message: message,
                            allowAnyScheme: model.allowsAnyLink(keyID: message.keyID)
                        )
                    }
                    .buttonStyle(.plain)
                    .overlay(alignment: .bottom) { Hairline() }
                    .geistGutter()
                    .plainRow()
                    // Swiping is a touch idiom. On the Mac the same actions live in
                    // the right-click menu below, which is where a Mac user looks.
                    #if os(iOS)
                    .swipeActions(edge: .leading) {
                        Button { toggleRead(message) } label: {
                            Label(message.isRead ? "Unread" : "Read",
                                  systemImage: message.isRead
                                      ? "envelope.badge.fill" : "envelope.open.fill")
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
                            Label("Delete", systemImage: "trash.fill")
                        }
                        .tint(Theme.danger)
                    }
                    #endif
                    .contextMenu { menu(for: message) }
                }
            }
        }
        .listStyle(.plain)
        // A plain List insets its content by 8pt horizontally, on top of
        // whatever the rows ask for. Neither `contentMargins` nor zeroed
        // `listRowInsets` removes it, so it is cancelled here: measured, this
        // tab sat at 28pt while Keys and Settings — plain ScrollViews on
        // `geistGutter()` — sat at 20pt. The rows carry the gutter themselves.
        .padding(.horizontal, -8)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
        .scrollDismissesKeyboard(.immediately)
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
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                BrandMark(size: 17)
                Spacer(minLength: 8)
                overflowMenu
            }
            .frame(height: Theme.headerBarHeight)
            .padding(.bottom, Theme.headerBarGap)

            // "Notifications" is a long word; beside a count it wrapped mid-word.
            // Stacked, the title always gets its own line at any Dynamic Type size.
            VStack(alignment: .leading, spacing: 3) {
                Text("Notifications")
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

            // Nothing to search through yet, so the field would just be furniture.
            if !messages.isEmpty {
                SearchField(text: $searchText, focused: $searchFocused)

                if let activeKeyName {
                    HStack(spacing: 8) {
                        Chip(text: activeKeyName, color: Theme.fg,
                             border: Theme.muted.opacity(0.5))
                        Button("Clear") { filterKeyID = nil }
                            .font(Theme.label)
                            .foregroundStyle(Theme.dim)
                            .buttonStyle(.plain)
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
            Divider()
            Button("Seed sample data") {
                SampleData.seed(into: context, keyIDs: keys.map(\.id))
            }
            Button("Clear sample data", role: .destructive) { SampleData.clear(from: context) }
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

    private var relative: String {
        let basis = message.occurredAt ?? message.createdAt
        let seconds = max(0, Int(Date().timeIntervalSince(basis)))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(seconds / 60) min"
        case ..<86_400: return "\(seconds / 3_600) hr"
        case ..<604_800: return "\(seconds / 86_400) d"
        default: return "\(seconds / 604_800) w"
        }
    }

    /// The full date as digits only — "09:32 · 03.08.2026". Fixed rather than
    /// locale-formatted so every row lines up on the same monospaced grid.
    /// Milliseconds belong on the detail page, where precision is the point; in
    /// the feed they are noise.
    private var stamp: String {
        Self.stampFormatter.string(from: message.occurredAt ?? message.createdAt)
    }

    private static let stampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm · dd.MM.yyyy"
        return f
    }()

    var body: some View {
        HStack(alignment: .top, spacing: Theme.rowGap) {
            // The unread marker — the only colour in the system.
            Circle()
                .fill(message.isRead ? Color.clear : Theme.brand)
                .frame(width: 6, height: 6)
                .padding(.top, 8)
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
                // Relative time leads — it is what you actually read. The exact
                // stamp sits under it, one step paler, for when you need it.
                Text(relative)
                    .font(Theme.meta)
                    .foregroundStyle(Theme.muted)
                Text(stamp)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                    .lineLimit(1)
                if let url = message.imageURL,
                   LinkPolicy.allows(url, anyScheme: allowAnyScheme) {
                    Thumbnail(url: url).padding(.top, 8)
                }
            }
            .monospacedDigit()
        }
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
        .accessibilityLabel((message.isRead ? "" : "Unread, ") + message.title)
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
