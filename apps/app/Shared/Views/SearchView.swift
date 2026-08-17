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

            if trimmed.isEmpty && !recents.isEmpty && !messages.isEmpty {
                recentRow
            }

            feed
        }
        .background(StaticField())
        .onDisappear {
            recents = RecentSearches.record(trimmed, in: recents)
        }
    }

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
