import Combine
import OSLog
import SwiftData
import SwiftUI

struct InboxView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    @State private var now = Date()
    private static let clock = Timer
        .publish(every: 30, tolerance: 5, on: .main, in: .common)
        .autoconnect()

    @State private var searchText = ""
    @State private var filterKeyID: Int?
    @State private var showingSearch = false
    @FocusState private var searchFocused: Bool
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var keys: [CachedKey] { model.sync?.keys ?? [] }

    private var activeKeyName: String? {
        filterKeyID.flatMap { id in keys.first { $0.id == id }?.name }
    }

    private var trimmedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [Message] {
        let needle = trimmedQuery.lowercased()
        let keyIDs = filterKeyID.map { keys.idsSharingName(with: $0) }
        return messages.filter { message in
            let matchesKey = keyIDs.map { ids in
                message.keyID.map(ids.contains) ?? false
            } ?? true
            guard matchesKey else { return false }
            guard !needle.isEmpty else { return true }
            if message.title.lowercased().contains(needle) { return true }
            if let body = message.body?.lowercased(), body.contains(needle) { return true }
            if let host = message.link?.host()?.lowercased(), host.contains(needle) { return true }
            return false
        }
    }

    private var unreadCount: Int { messages.reduce(0) { $0 + ($1.isRead ? 0 : 1) } }

    private var subtitle: Text {
        let total = Copy.Inbox.count(messages.count)
        guard unreadCount > 0 else { return Text(total) }
        return Text("\(unreadCount)").foregroundColor(Theme.brandText)
            + Text(Copy.Inbox.unreadSummary(total))
    }

    @ViewBuilder
    var body: some View {
        #if os(iOS)
        if sizeClass == .regular {
            page.searchable(text: $searchText, prompt: Copy.Search.prompt)
        } else {
            page
        }
        #else
        page
        #endif
    }

    private var page: some View {
        GeistPage(scroll: .content) {
            header
        } content: {
            #if DEBUG
            Color.clear.frame(height: 0)
                .onAppear { SampleData.pushLaunchMessage(into: model) }
            #endif

            if model.isOffline {
                InlineError(message: Copy.Inbox.offline, followsAction: false)
                    .padding(.top, Theme.contentTop)
                    .geistGutter()
            }

            list
        }
    }

    @ViewBuilder
    private var list: some View {
        if messages.isEmpty {
            GeometryReader { proxy in
                ScrollView {
                    EmptyStateView()
                        .frame(minHeight: proxy.size.height)
                }
            }
        } else {
            feed
        }
    }

    private var feed: some View {
        MessageFeed(messages: filtered) {
            NoResultsView(
                query: trimmedQuery,
                scopeNote: activeKeyName.map { Copy.Inbox.filteredToKey($0) },
                onClear: clearFilters
            )
        }
        .geistTopFade()
        .geistBottomFade()
    }

    #if os(macOS)
    private var searchToggle: some View {
        IconButton(systemImage: showingSearch ? "xmark" : "magnifyingglass",
                   label: showingSearch ? Copy.Inbox.closeSearch : Copy.Common.search,
                   glass: true) {
            if showingSearch {
                closeSearch()
            } else {
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

    private var hasHeaderControls: Bool {
        #if os(macOS)
        !messages.isEmpty && (showingSearch || activeKeyName != nil)
        #else
        !messages.isEmpty && activeKeyName != nil
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            FeedHeader(subtitle: subtitle, filterKeyID: $filterKeyID) {
                #if os(macOS)
                if !messages.isEmpty { searchToggle }
                #endif
            }
            .padding(.bottom, hasHeaderControls ? 14 : 0)

            if !messages.isEmpty {
                #if os(macOS)
                if showingSearch {
                    SearchField(text: $searchText, focused: $searchFocused)
                }
                #endif

                if let activeKeyName {
                    HStack(spacing: 8) {
                        Chip(text: activeKeyName, color: Theme.fg,
                             border: Theme.muted.opacity(0.5))
                        Button(Copy.Common.clear) { filterKeyID = nil }
                            .font(Theme.label)
                            .foregroundStyle(Theme.dim)
                            .buttonStyle(.geist)
                            .geistHitArea(expandedBy: 16)
                        Spacer(minLength: 0)
                    }
                    .padding(.top, 10)
                }
            }
        }
    }

    private func clearFilters() {
        searchText = ""
        filterKeyID = nil
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Logger(subsystem: "it.notifi.app", category: "inbox")
                .error("save failed: \(String(describing: error), privacy: .public)")
        }
    }
}
