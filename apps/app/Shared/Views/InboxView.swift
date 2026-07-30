import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct InboxView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    @State private var searchText = ""
    @State private var filterKeyID: Int?
    #if os(iOS)
    @State private var showingCreate = false
    #else
    @Environment(\.openWindow) private var openWindow
    #endif

    private var filtered: [Message] {
        messages.filter { message in
            let matchesKey = filterKeyID.map { message.keyID == $0 } ?? true
            let matchesSearch: Bool = {
                guard !searchText.isEmpty else { return true }
                let needle = searchText.lowercased()
                if message.title.lowercased().contains(needle) { return true }
                if let body = message.body?.lowercased(), body.contains(needle) { return true }
                return false
            }()
            return matchesKey && matchesSearch
        }
    }

    var body: some View {
        Group {
            if messages.isEmpty {
                EmptyStateView()
            } else {
                list
            }
        }
        .navigationTitle("notifi")
        .searchable(text: $searchText)
        .refreshable { await model.refresh() }
        .toolbar { toolbarContent }
        #if os(iOS)
        .sheet(isPresented: $showingCreate) {
            NavigationStack { CreateKeyView() }
                .environment(model)
        }
        #endif
    }

    private var list: some View {
        List {
            ForEach(filtered) { message in
                NavigationLink(value: message.serverID) {
                    MessageRow(message: message)
                }
                .swipeActions(edge: .leading) {
                    Button(message.isRead ? "Unread" : "Read") {
                        message.isRead.toggle()
                        try? context.save()
                        model.sync?.updateBadge()
                    }
                    .tint(.blue)
                }
                .swipeActions(edge: .trailing) {
                    Button("Delete", role: .destructive) {
                        delete(message)
                    }
                }
                .contextMenu {
                    Button("Copy Title") { Clipboard.copy(message.title) }
                    if let body = message.body {
                        Button("Copy Message") { Clipboard.copy(body) }
                    }
                    if let link = message.link {
                        Button("Open Link") {
                            #if os(iOS)
                            UIApplication.shared.open(link)
                            #else
                            NSWorkspace.shared.open(link)
                            #endif
                        }
                    }
                    Button("Delete", role: .destructive) { delete(message) }
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button("Mark All as Read") { markAllRead() }
                Picker("Filter by Key", selection: $filterKeyID) {
                    Text("All Keys").tag(Int?.none)
                    ForEach(model.sync?.keys ?? []) { key in
                        Text(key.name).tag(Int?.some(key.id))
                    }
                }
                #if os(macOS)
                Divider()
                Button("Create Key…") { openWindow(id: "create-key") }
                #endif
            } label: {
                Label("More", systemImage: "ellipsis.circle")
            }
        }
    }

    private func delete(_ message: Message) {
        context.delete(message)
        try? context.save()
        model.sync?.updateBadge()
    }

    private func markAllRead() {
        for message in messages where !message.isRead {
            message.isRead = true
        }
        try? context.save()
        model.sync?.updateBadge()
    }
}

private struct MessageRow: View {
    let message: Message

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(message.isRead ? Color.clear : Color.accentColor)
                .frame(width: 8, height: 8)
                .padding(.top, 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(message.title)
                    .font(.headline)
                    .lineLimit(1)
                if let body = message.body {
                    Text(body)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Text(message.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts: [String] = []
        if !message.isRead { parts.append("Unread") }
        parts.append(message.title)
        if let body = message.body { parts.append(body) }
        return parts.joined(separator: ", ")
    }
}
