#if os(iOS)
import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    @State private var query = ""
    @State private var recents = RecentSearches.load()

    private var trimmed: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

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
                .background(StaticField())
                .overlay(alignment: .bottom) {
                    Hairline(color: Theme.chromeRuleColor, weight: Theme.chromeRule)
                }

            // Only while nothing is typed: once a query exists the screen
            // belongs to its results, and a row of other queries above them is
            // an invitation to lose the one being read. Hidden with the feed
            // empty too — offering re-runs over no messages re-runs nothing.
            if trimmed.isEmpty && !recents.isEmpty && !messages.isEmpty {
                recentRow
            }

            feed
        }
        .background(StaticField())
        // Recorded on the way out, not on submit. `.onSubmit(of: .search)` is
        // the API for this and it does not fire here: the search-role tab's
        // field is hosted by the tab bar, outside this hierarchy, and a real
        // Return key dismisses the keyboard without the event ever arriving —
        // verified on iOS 26 with a HID-level keypress. Leaving the screen is
        // the moment that exists instead, and it also catches the search that
        // ended by opening a result, which a submit never sees.
        .onDisappear {
            recents = RecentSearches.record(trimmed, in: recents)
        }
    }

    /// The last submitted queries, newest first. Submitted, not typed: a
    /// recent search is one that was asked, not every keystroke on the way
    /// there.
    private var recentRow: some View {
        HStack(spacing: 8) {
            Text(Copy.Search.recent)
                .font(Theme.label)
                .foregroundStyle(Theme.dim)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(recents, id: \.self) { term in
                        Button { query = term } label: {
                            Chip(text: term, color: Theme.fg,
                                 border: Theme.muted.opacity(0.5))
                        }
                        .buttonStyle(.geist)
                    }
                }
            }
            Button(Copy.Common.clear) {
                recents = []
                RecentSearches.save([])
            }
            .font(Theme.label)
            .foregroundStyle(Theme.dim)
            .buttonStyle(.geist)
            // An 11pt label draws an 11pt target — same expansion as the
            // Inbox filter row's Clear, whose height this row shares.
            .geistHitArea(expandedBy: 16)
        }
        .padding(.top, 12)
        .geistGutter()
    }

    private var feed: some View {
        MessageFeed(messages: results) {
            if trimmed.isEmpty {
                EmptyStateView().padding(.top, 30)
            } else {
                NoResultsView(query: trimmed, scopeNote: nil) { query = "" }
            }
        }
        .geistTopFade()
        .searchable(text: $query, prompt: Copy.Search.prompt)
        .toolbar(.hidden, for: .navigationBar)
    }
}

/// `UserDefaults`, not the store: these are a convenience of this screen on
/// this device, and putting them next to the messages would give them a
/// lifetime and a sync story they have not earned.
private enum RecentSearches {
    private static let key = "recentSearches"
    private static let cap = 5

    static func load() -> [String] {
        UserDefaults.standard.stringArray(forKey: key) ?? []
    }

    static func save(_ terms: [String]) {
        UserDefaults.standard.set(terms, forKey: key)
    }

    static func record(_ term: String, in current: [String]) -> [String] {
        guard !term.isEmpty else { return current }
        var next = current.filter { $0.caseInsensitiveCompare(term) != .orderedSame }
        next.insert(term, at: 0)
        next = Array(next.prefix(cap))
        save(next)
        return next
    }
}

#endif
