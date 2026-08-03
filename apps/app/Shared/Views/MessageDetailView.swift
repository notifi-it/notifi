import OSLog
import SwiftData
import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// A single message.
///
/// Title is the only guaranteed field, so it carries the page: 27pt Inconsolata
/// bold. Everything else appears only if it exists, in a fixed order — time,
/// title, message, image, link, actions.
struct MessageDetailView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var messages: [Message]
    private let log = Logger(subsystem: "it.notifi.app", category: "store")

    @State private var copied = false
    @State private var confirmingDelete = false

    init(serverID: Int) {
        _messages = Query(filter: #Predicate<Message> { $0.serverID == serverID })
    }

    private var message: Message? { messages.first }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d MMM yyyy, HH:mm:ss.SSS"
        return f
    }()

    var body: some View {
        ScrollView {
            if let message {
                content(for: message)
                    .geistGutter()
            } else {
                VStack(spacing: 10) {
                    Text("Message not found")
                        .font(.inco(.title3, weight: .bold))
                        .foregroundStyle(Theme.fg)
                    Text("It may have been deleted on this device.")
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity)
            }
        }
        .background(Theme.bg)
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) { backBar }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear { markRead() }
        // Delete cannot be undone — the message is gone from this device and the
        // server has already dropped it — so it always asks first.
        .alert("Delete this notification?", isPresented: $confirmingDelete) {
            Button("Delete", role: .destructive) { deleteMessage() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This cannot be undone.")
        }
    }

    private func deleteMessage() {
        guard let message else { return }
        context.delete(message)
        try? context.save()
        model.sync?.updateBadge()
        if !model.path.isEmpty { model.path.removeLast() } else { dismiss() }
    }

    private var backBar: some View {
        HStack(spacing: 7) {
            Button {
                #if os(iOS)
                if !model.path.isEmpty { model.path.removeLast() } else { dismiss() }
                #else
                if !model.path.isEmpty { model.path.removeLast() } else { dismiss() }
                #endif
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Notifications").font(Theme.body)
                }
                .foregroundStyle(Theme.muted)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Notifications")

            Spacer(minLength: 8)

            if let message {
                HStack(spacing: 8) {
                    if let url = message.imageURL {
                        IconButton(systemName: "arrow.down.to.line",
                                   label: "Download image") { downloadImage(url) }
                    }

                    if let link = message.link {
                        IconButton(systemName: "globe", label: "Open link") { open(link) }
                    }

                    // The feed already says "unread" with a filled dot, so the
                    // button borrows it: solid dot to mark unread, empty ring to
                    // mark read.
                    IconButton(
                        systemName: message.isRead ? "circle.fill" : "circle",
                        label: message.isRead ? "Mark as unread" : "Mark as read"
                    ) {
                        message.isRead.toggle()
                        try? context.save()
                        model.sync?.updateBadge()
                    }

                    IconButton(systemName: "trash.fill", label: "Delete", tint: Theme.danger) {
                        confirmingDelete = true
                    }
                }
            }
        }
        .geistGutter()
        .padding(.top, 22)
        .padding(.bottom, 30)
        .background(Theme.bg)
    }

    @ViewBuilder
    private func content(for message: Message) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Self.stamp.string(from: message.occurredAt ?? message.createdAt))
                    .font(Theme.meta)
                    .foregroundStyle(Theme.dim)
                    .monospacedDigit()

                // Two clocks only when they are genuinely different things: the
                // sender's event time, and when notifi received it.
                if message.occurredAt != nil {
                    Text("sent by client · received "
                         + Self.stamp.string(from: message.createdAt))
                        .font(Theme.metaSmall)
                        .foregroundStyle(Theme.dim)
                        .monospacedDigit()
                }
            }
            .padding(.top, 6)

            Text(message.title)
                .font(.inco(.title, weight: .bold))
                .foregroundStyle(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .padding(.top, 12)

            if let body = message.body {
                MarkdownText(source: body)
                    .padding(.top, 15)
            }

            if let url = message.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFit()
                    case .failure:
                        VStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .medium))
                            Text("Image failed to load")
                                .font(Theme.metaSmall)
                        }
                        .foregroundStyle(Theme.dim)
                        .frame(maxWidth: .infinity, minHeight: 140)
                    default:
                        Theme.surface.frame(maxWidth: .infinity, minHeight: 140)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.chip, lineWidth: 1))
                .padding(.top, 20)
            }

            if let link = message.link {
                SectionLabel(text: "Link")

                // The whole URL, wrapped. Detail is where you come to read it, so
                // truncating here would defeat the point — the row already shows
                // the short form.
                Text(link.absoluteString)
                    .font(.inco(.subheadline, weight: .regular))
                    .foregroundStyle(Theme.fg)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.chip, lineWidth: 1))

                HStack(spacing: 9) {
                    Button { open(link) } label: {
                        Text("Open ↗")
                            .font(.inco(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.fg, in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: link) {
                        Text("Share")
                            .font(.inco(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.chip, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 10)
            }

            // Read/unread and delete moved to the top bar; copying the whole
            // message is the only action left that needs a labelled control.
            OutlineButton(title: copied ? "Copied" : "Copy message") {
                Clipboard.copy(plainText(for: message))
                withAnimation(.easeOut(duration: 0.15)) { copied = true }
                Task {
                    try? await Task.sleep(for: .seconds(1.6))
                    withAnimation(.easeOut(duration: 0.2)) { copied = false }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
        }
    }

    /// A round icon button for the top bar.
    ///
    /// On OS 26 this is the system Liquid Glass style, so it picks up the real
    /// material and its touch response for free. Before 26 there is no glass to
    /// have, so it falls back to the design system's own inset circle — surface
    /// fill, hairline border — which is what the rest of the app uses.
    private struct IconButton: View {
        let systemName: String
        let label: String
        var tint: Color = Theme.fg
        let action: () -> Void

        var body: some View {
            if #available(iOS 26.0, macOS 26.0, *) {
                Button(action: action) {
                    icon.frame(width: 20, height: 20)
                }
                .buttonStyle(.glass)
                .accessibilityLabel(label)
            } else {
                Button(action: action) {
                    icon
                        .frame(width: 34, height: 34)
                        .background(Theme.surface, in: Circle())
                        .overlay(Circle().stroke(Theme.chip, lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label)
            }
        }

        private var icon: some View {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
        }
    }

    private func plainText(for message: Message) -> String {
        var parts = [message.title]
        if let body = message.body { parts.append(body) }
        if let link = message.link { parts.append(link.absoluteString) }
        return parts.joined(separator: "\n\n")
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

    private func open(_ url: URL) {
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func downloadImage(_ url: URL) {
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
            #if os(iOS)
            guard let image = UIImage(data: data) else { return }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            #else
            await MainActor.run {
                let panel = NSSavePanel()
                panel.nameFieldStringValue = url.lastPathComponent
                if panel.runModal() == .OK, let target = panel.url {
                    try? data.write(to: target)
                }
            }
            #endif
        }
    }
}
