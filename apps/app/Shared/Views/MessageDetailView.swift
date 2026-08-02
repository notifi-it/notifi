import OSLog
import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct MessageDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query private var messages: [Message]
    private let log = Logger(subsystem: "it.notifi.app", category: "store")

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
        #if os(iOS)
        .toolbar {
            if let imageURL = message?.imageURL {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        downloadImage(imageURL)
                    } label: {
                        Image("akar-download")
                    }
                    .accessibilityLabel("Download image")
                }
            }
        }
        #else
        .safeAreaInset(edge: .top) { macNavBar }
        #endif
        .onAppear { markRead() }
    }

    #if os(macOS)
    private var macNavBar: some View {
        MacNavBar(backTitle: "Inbox") {
            if let imageURL = message?.imageURL {
                Button {
                    downloadImage(imageURL)
                } label: {
                    Image("akar-download")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Download image")
            }
        }
    }
    #endif

    private func downloadImage(_ url: URL) {
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            #if os(iOS)
            if let image = UIImage(data: data) {
                UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            }
            #else
            let panel = NSSavePanel()
            panel.nameFieldStringValue = url.lastPathComponent.isEmpty ? "image.jpg" : url.lastPathComponent
            if panel.runModal() == .OK, let dest = panel.url {
                try? data.write(to: dest)
            }
            #endif
        }
    }

    private func content(for message: Message) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(message.title)
                    .font(.inco(.title2, weight: .bold))
                    .textSelection(.enabled)

                Text(message.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.inco(.caption))
                    .foregroundStyle(.secondary)

                if let imageURL = remoteImageURL(message.imageURL) {
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
                        .font(.karla(.body))
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
            .textSelection(.enabled)
            .padding()
        }
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func markRead() {
        guard let message, !message.isRead else { return }
        message.isRead = true
        do {
            try context.save()
        } catch {
            log.error("save failed: \(String(describing: error), privacy: .public)")
        }
        model.sync?.updateBadge()
    }
}
