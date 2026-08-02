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
    @State private var linkCopied = false

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

            if let url = message?.imageURL {
                Button { downloadImage(url) } label: {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Download image")
            }
        }
        .geistGutter()
        .padding(.vertical, 10)
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
                Text(body)
                    .font(.karla(.body))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
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

                    Button { Clipboard.copy(link.absoluteString) } label: {
                        Text(linkCopied ? "Copied" : "Copy")
                            .font(.inco(.footnote, weight: .semibold))
                            .foregroundStyle(Theme.fg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .stroke(Theme.chip, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(TapGesture().onEnded {
                        withAnimation(.easeOut(duration: 0.15)) { linkCopied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(1.6))
                            withAnimation(.easeOut(duration: 0.2)) { linkCopied = false }
                        }
                    })
                }
                .padding(.top, 10)
            }

            HStack(spacing: 9) {
                OutlineButton(title: copied ? "Copied" : "Copy") {
                    Clipboard.copy(plainText(for: message))
                    withAnimation(.easeOut(duration: 0.15)) { copied = true }
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        withAnimation(.easeOut(duration: 0.2)) { copied = false }
                    }
                }
                OutlineButton(title: message.isRead ? "Unread" : "Read") {
                    message.isRead.toggle()
                    try? context.save()
                    model.sync?.updateBadge()
                }
                OutlineButton(title: "Delete", color: Theme.danger) {
                    context.delete(message)
                    try? context.save()
                    model.sync?.updateBadge()
                    if !model.path.isEmpty { model.path.removeLast() } else { dismiss() }
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 40)
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
