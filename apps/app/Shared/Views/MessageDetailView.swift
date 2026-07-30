import SwiftData
import SwiftUI

struct MessageDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query private var messages: [Message]

    init(serverID: Int) {
        _messages = Query(filter: #Predicate<Message> { $0.serverID == serverID })
    }

    private var message: Message? { messages.first }

    var body: some View {
        Group {
            if let message {
                content(for: message)
            } else {
                ContentUnavailableView("Message not found", systemImage: "questionmark")
            }
        }
        .toolbar {
            if let message {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText(for: message))
                }
            }
        }
        .onAppear { markRead() }
    }

    private func content(for message: Message) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(message.title)
                    .font(.title2.bold())
                    .textSelection(.enabled)

                Text(message.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let imageURL = message.imageURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case let .success(image):
                            image.resizable().scaledToFit()
                        case .failure:
                            EmptyView()
                        default:
                            ProgressView()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                if let body = message.body {
                    Text(body)
                        .font(.body)
                        .textSelection(.enabled)
                }

                if let link = message.link {
                    Link(destination: link) {
                        Label(link.absoluteString, systemImage: "link")
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func shareText(for message: Message) -> String {
        var text = message.title
        if let body = message.body { text += "\n\n" + body }
        if let link = message.link { text += "\n\n" + link.absoluteString }
        return text
    }

    private func markRead() {
        guard let message, !message.isRead else { return }
        message.isRead = true
        try? context.save()
        model.sync?.updateBadge()
    }
}
