#if os(iOS)
import SwiftData
import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var model
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    @State private var query = ""

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

            feed
        }
        .background(StaticField())
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

#endif
