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
                // The static runs under the header too. It stays opaque — rows
                // still have to disappear behind it rather than showing through
                // — but a flat ground here left a smooth band across the top of
                // an otherwise grainy screen.
                .background(StaticField())

            list
        }
        .background(StaticField())
    }

    @ViewBuilder
    private var list: some View {
        if messages.isEmpty {
            // Not a List row: the walkthrough is the whole screen at this point,
            // and centring it means measuring the space it has, which a row inside
            // a List cannot do. It stays scrollable for the case where both steps
            // are open on a short device.
            GeometryReader { proxy in
                ScrollView {
                    EmptyStateView()
                        .frame(minHeight: proxy.size.height)
                }
            }
        } else {
            messageList
        }
    }

    private var messageList: some View {
        MessageFeed(messages: filtered) {
            NoResultsView(
                query: trimmedQuery,
                scopeNote: activeKeyName.map { "Filtered to the \u{201C}\($0)\u{201D} key." },
                onClear: clearFilters
            )
        }
        #if os(iOS)
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

    #if os(macOS)
    /// Search is a button rather than a field kept on screen, because a field
    /// parked above the feed is chrome that earns its space only when it is
    /// wanted.
    ///
    /// macOS only. On iOS search is its own tab, so the tab bar morphs into the
    /// system field and this header carries nothing for it. The Mac has no
    /// equivalent: `TabView` is not used there at all (see `GeistTabBar`), so
    /// there is no bar to morph.
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
    #endif

    /// Whether anything is drawn under the title row — the search field, the key
    /// filter chip, or both.
    private var hasHeaderControls: Bool {
        #if os(macOS)
        !messages.isEmpty && (showingSearch || activeKeyName != nil)
        #else
        !messages.isEmpty && activeKeyName != nil
        #endif
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            FeedHeader(subtitle: subtitle, filterKeyID: $filterKeyID) {
                #if os(macOS)
                if !messages.isEmpty { searchToggle }
                #endif
            }
            // Separates the title row from the search field or the filter chip,
            // and only then. `geistPageHeader()` already puts 14 under the whole
            // block, so with neither of those on screen this was a second 14
            // stacked on it and the feed started 28pt lower than Keys and
            // Settings do.
            .padding(.bottom, hasHeaderControls ? 14 : 0)

            if !messages.isEmpty {
                // Nothing to search through yet, so the field would just be
                // furniture. It appears only once the search button asks for it.
                //
                // No transition. Sliding it in animates the header's height,
                // which shoves the title up and drags the whole feed after it —
                // the field is the only thing that should be arriving.
                #if os(macOS)
                if showingSearch {
                    SearchField(text: $searchText, focused: $searchFocused)
                }
                #endif

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

    // MARK: Actions

    private func clearFilters() {
        searchText = ""
        filterKeyID = nil
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
