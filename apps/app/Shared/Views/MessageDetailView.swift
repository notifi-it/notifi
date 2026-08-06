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
    // Reset on every open: revealing an image is a decision about this message on
    // this visit, not a preference that should outlive it.
    @State private var revealedImage = false

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
                    .geistMeasure()
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
            backButton

            Spacer(minLength: 8)

            if let message {
                let anyScheme = model.allowsAnyLink(keyID: message.keyID)
                // 10, not 8. The buttons draw at 34 and are tapped at 44, so the
                // gap has to be at least 10 or two neighbouring targets overlap
                // and the row starts answering taps with the wrong action.
                HStack(spacing: 10) {
                    if let url = message.imageURL, LinkPolicy.allows(url, anyScheme: anyScheme) {
                        IconButton(systemName: "arrow.down.to.line",
                                   label: "Download image") {
                            downloadImage(url, keyID: message.keyID)
                        }
                    }

                    if let link = message.link, LinkPolicy.allows(link, anyScheme: anyScheme) {
                        IconButton(systemName: "globe", label: "Open link") {
                            open(link, keyID: message.keyID)
                        }
                    }

                    // Shows the state, not the action: a filled red dot while the
                    // message is unread, matching the feed, and a hollow ring once
                    // it has been read. The label still names what tapping does.
                    IconButton(
                        systemName: message.isRead ? "circle" : "circle.fill",
                        label: message.isRead ? "Mark as unread" : "Mark as read",
                        tint: message.isRead ? Theme.fg : Theme.brand
                    ) {
                        message.isRead.toggle()
                        try? context.save()
                        model.sync?.updateBadge()
                    }

                    IconButton(systemName: "trash", label: "Delete") {
                        confirmingDelete = true
                    }
                }
            }
        }
        .geistGutter()
        .geistMeasure()
        .padding(.top, 22)
        // Matches the gap the tabs put under their own header row. At 30, plus
        // the title's own inset, the back bar looked detached from the message
        // it belongs to.
        .padding(.bottom, 14)
        .background(Theme.bg)
    }

    private func goBack() {
        if !model.path.isEmpty { model.path.removeLast() } else { dismiss() }
    }

    /// Glyph only — the destination is the one screen this can pop back to, so
    /// naming it earned nothing. Same round button as the trailing actions.
    private var backButton: some View {
        IconButton(systemName: "chevron.backward",
                   label: "Back to Notifications") { goBack() }
    }

    /// The key the notification was sent with, or nil when saying so adds nothing.
    ///
    /// The default key is the overwhelming case and naming it on every single
    /// notification would be noise, so it is left unsaid — a named key here means
    /// the send came from somewhere you set up deliberately. An id that resolves
    /// to no key still shows, as the key may since have been revoked.
    private func keyName(for message: Message) -> String? {
        guard let id = message.keyID else { return nil }
        guard let key = model.sync?.keys.first(where: { $0.id == id }) else {
            return "Key \(id)"
        }
        return key.isDefault ? nil : key.name
    }

    @ViewBuilder
    private func content(for message: Message) -> some View {
        let anyScheme = model.allowsAnyLink(keyID: message.keyID)
        VStack(alignment: .leading, spacing: 0) {
            // The title leads, then who sent it, then when. The stamps used to
            // come first, which opened every message with its least interesting
            // fact — and the second line read "sent by client", which is the
            // shape of the API rather than anything a reader can act on.
            Text(message.title)
                .font(.inco(.title, weight: .bold))
                .foregroundStyle(Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let keyName = keyName(for: message) {
                HStack(spacing: 6) {
                    Image(systemName: "key")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                    Text(keyName)
                        .font(Theme.meta)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .padding(.top, 10)
            }

            // One clock. The sender's own event time when it gave one, and the
            // time it arrived otherwise — the difference between the two is a
            // detail of how it was sent, not something worth a second line.
            Text(Self.stamp.string(from: message.occurredAt ?? message.createdAt))
                .font(Theme.meta)
                .foregroundStyle(Theme.dim)
                .monospacedDigit()
                .padding(.top, 6)

            // The rule divides what notifi says about the message from what the
            // sender put in it.
            Hairline()
                .padding(.top, 16)

            if let body = message.body {
                MarkdownText(source: body, allowAnyScheme: anyScheme,
                             allowsRemoteImages: showsImage)
                    .padding(.top, 16)
            }

            // Two gates, and both must pass. The scheme check is about what this
            // key is trusted to point at; showsImage is about whether the host
            // gets to learn this device's IP at all.
            if let url = message.imageURL, LinkPolicy.allows(url, anyScheme: anyScheme) {
                Group {
                    if showsImage {
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
                    } else {
                        hiddenImage(host: url.host() ?? "another host")
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
                    if LinkPolicy.allows(link, anyScheme: anyScheme) {
                        Button { open(link, keyID: message.keyID) } label: {
                            Text("Open link")
                                .font(.inco(.footnote, weight: .semibold))
                                .foregroundStyle(Theme.bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.fg, in: RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.geist)
                    }

                    OutlineShareButton(title: "Share", item: link)
                }
                .padding(.top, 10)

                if !LinkPolicy.allows(link, anyScheme: anyScheme) {
                    Text("Not opened: this link is not https. Turn on "
                         + "\"Open any link\" for this key to allow it.")
                        .font(Theme.metaSmall)
                        .foregroundStyle(Theme.dim)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 8)
                }
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

    private var showsImage: Bool { model.remoteImagesEnabled || revealedImage }

    /// Stands in for an image that has not been fetched yet.
    ///
    /// It names the host, because that is the party who learns the device's IP
    /// address and the time of day the moment the image loads.
    private func hiddenImage(host: String) -> some View {
        VStack(spacing: 10) {
            Text("Image hidden")
                .font(.inco(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.fg)
            Text("Loading it contacts \(host).")
                .font(Theme.metaSmall)
                .foregroundStyle(Theme.dim)
                .multilineTextAlignment(.center)
            Button {
                revealedImage = true
            } label: {
                Text("Load image")
                    .font(.inco(.footnote, weight: .semibold))
                    .foregroundStyle(Theme.fg)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: 8)
                        .stroke(Theme.controlBorder, lineWidth: 1))
            }
            .buttonStyle(.geist)
        }
        .padding(.vertical, 26)
        .frame(maxWidth: .infinity)
        .background(Theme.surface)
    }

    /// The top bar's round icon button — the one the headers use, under this
    /// screen's own argument label.
    ///
    /// It used to be a second implementation with `.buttonStyle(.glass)`. That
    /// style fills from the app's accent, which is the brand red, so on macOS
    /// the back bar came out as a row of red tiles while the identical control
    /// one screen away was a dark glass disc.
    private struct IconButton: View {
        let systemName: String
        let label: String
        var tint: Color = Theme.fg
        let action: () -> Void

        var body: some View {
            notifi.IconButton(systemImage: systemName, label: label,
                              color: tint, glass: true, action: action)
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

    // The call sites already hide the controls that reach these, so the guards are
    // a backstop: neither should ever hand the OS a URL the policy rejects.
    private func open(_ url: URL, keyID: Int?) {
        guard LinkPolicy.allows(url, keyID: keyID) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func downloadImage(_ url: URL, keyID: Int?) {
        guard LinkPolicy.allows(url, keyID: keyID) else { return }
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
