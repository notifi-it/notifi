#if os(iOS)
import SwiftData
import SwiftUI

/// The search tab.
///
/// Exists so the tab bar can carry `Tab(role: .search)`, which is the whole
/// point of it: tapping the tab morphs the bar itself into the search field,
/// animated by the system. Every hand-built version of that in the header
/// fought the tab bar for the bottom of the screen and lost.
///
/// iOS only. `InboxRootView` does not use `TabView` on macOS — there is no tab
/// bar there to morph — so the Mac keeps the search button in the Inbox header.
struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    @State private var query = ""

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Title, message and link host, matching what the Inbox's own field
    /// searched before this tab existed. No key filter: that lives in the
    /// Inbox's overflow menu and is a way of narrowing the feed, not a thing
    /// you would expect a search box to silently inherit.
    ///
    /// An empty query is every message, not none. Opening search is a request
    /// to look at the feed with a field in hand — blanking the screen until a
    /// character is typed throws away the thing being searched and makes the
    /// tab read as broken.
    private var results: [Message] {
        let needle = trimmed.lowercased()
        guard !needle.isEmpty else { return messages }
        return messages.filter { message in
            if message.title.lowercased().contains(needle) { return true }
            if let body = message.body?.lowercased(), body.contains(needle) { return true }
            if let host = message.link?.host()?.lowercased(), host.contains(needle) { return true }
            return false
        }
    }

    /// The count describes the results, not the mailbox, so it answers the
    /// question the query just asked. It falls back to the whole-feed wording
    /// when nothing has been typed, because then it *is* the mailbox.
    private var subtitle: Text {
        guard !trimmed.isEmpty else {
            return Text(Copy.Inbox.count(messages.count))
        }
        return Text(Copy.Search.matches(results.count))
    }

    var body: some View {
        VStack(spacing: 0) {
            FeedHeader(subtitle: subtitle, filterKeyID: .constant(nil))
                .geistPageHeader()
                .geistGutter()
                // The static runs under the header here as it does on the Inbox:
                // this screen is the same feed seen through a query, and it was
                // the one screen still standing on a flat ground.
                .background(StaticField())

            feed
        }
        .background(StaticField())
    }

    private var feed: some View {
        MessageFeed(messages: results) {
            // Only reachable with nothing to show at all: an empty query is the
            // whole feed, so this is either a typed query that matched nothing
            // or an account with no notifications yet.
            if trimmed.isEmpty {
                EmptyStateView().padding(.top, 30)
            } else {
                NoResultsView(query: trimmed, scopeNote: nil) { query = "" }
            }
        }
        // The header above this one is pinned too, so rows arrive under it the
        // same way they do on the Inbox.
        .geistTopFade()
        .searchable(text: $query, prompt: Copy.Search.prompt)
        // The tab bar is the field, so a navigation bar above it would only be
        // an empty strip — the same reason the Inbox hides its own.
        .toolbar(.hidden, for: .navigationBar)
    }
}

#endif
