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

    @State private var confirmingDelete = false
    // Reset on every open: revealing an image is a decision about this message on
    // this visit, not a preference that should outlive it.
    @State private var revealedImage = false
    /// The image being looked at full screen, if any. Carries the URL rather
    /// than being a flag, so the presented view never reaches back for it.
    @State private var viewingImage: ViewedImage?

    /// `URL` is not `Identifiable`, and making it so app-wide to satisfy one
    /// presentation is a conformance the whole target would then inherit.
    private struct ViewedImage: Identifiable {
        let url: URL
        var id: URL { url }
    }

    init(serverID: Int) {
        _messages = Query(filter: #Predicate<Message> { $0.serverID == serverID })
    }

    private var message: Message? { messages.first }

    /// The same wording the feed row uses, so arriving here does not restate the
    /// age in a different vocabulary.
    ///
    /// Read once, when the screen is built. The feed keeps a ticking clock
    /// because a row can sit on screen for minutes while others arrive around it;
    /// a message you have opened is a screen you are reading, and an age that
    /// counts up under your eyes is movement with nothing behind it.
    private static func age(of message: Message) -> String {
        let basis = message.occurredAt ?? message.createdAt
        let seconds = max(0, Int(Date().timeIntervalSince(basis)))
        switch seconds {
        case ..<60: return Copy.Age.now
        case ..<3_600: return Copy.Age.minutes("\(seconds / 60)")
        case ..<86_400: return Copy.Age.hours("\(seconds / 3_600)")
        case ..<604_800: return Copy.Age.days("\(seconds / 86_400)")
        default: return Copy.Age.weeks("\(seconds / 604_800)")
        }
    }

    private static let stamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = Copy.Age.absoluteFormat
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
                    Text(Copy.Message.notFound)
                        .font(.inco(.title3, weight: .bold))
                        .foregroundStyle(Theme.fg)
                    Text(Copy.Message.notFoundDetail)
                        .font(Theme.body)
                        .foregroundStyle(Theme.muted)
                }
                .padding(.vertical, 80)
                .frame(maxWidth: .infinity)
            }
        }
        // The ground is painted here rather than inherited: the TabView and
        // the List underneath both draw an opaque backdrop of their own, so a
        // background set once at the root never reaches the screen.
        .background(StaticField())
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) { backBar }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear { markRead() }
        #if os(iOS)
        .fullScreenCover(item: $viewingImage) { ImageViewer(url: $0.url) }
        #else
        .sheet(item: $viewingImage) { ImageViewer(url: $0.url) }
        #endif
        // Delete cannot be undone — the message is gone from this device and the
        // server has already dropped it — so it always asks first.
        // Named, the same way the feed's own delete alert is: an alert that could
        // have been raised by any row should say which one raised it.
        .alert(message.map { Copy.Inbox.deleteTitle($0.title) } ?? Copy.Inbox.deleteTitleFallback,
               isPresented: $confirmingDelete) {
            Button(Copy.Common.delete, role: .destructive) { deleteMessage() }
            Button(Copy.Common.cancel, role: .cancel) {}
        } message: {
            Text(Copy.Inbox.deleteMessage)
        }
    }

    private func deleteMessage() {
        guard let message else { return }
        context.delete(message)
        try? context.save()
        model.sync?.reconcileNotifications()
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
                                   label: Copy.Message.downloadImage) {
                            downloadImage(url, keyID: message.keyID)
                        }
                    }

                    if let link = message.link, LinkPolicy.allows(link, anyScheme: anyScheme) {
                        IconButton(systemName: "globe", label: Copy.Common.openLink) {
                            open(link, keyID: message.keyID)
                        }
                    }

                    // Shows the state, not the action: a filled red dot while the
                    // message is unread, matching the feed, and a hollow ring once
                    // it has been read. The label still names what tapping does.
                    IconButton(
                        systemName: message.isRead ? "circle" : "circle.fill",
                        label: message.isRead ? Copy.Common.markAsUnread : Copy.Common.markAsRead,
                        tint: message.isRead ? Theme.fg : Theme.brand
                    ) {
                        message.isRead.toggle()
                        try? context.save()
                        model.sync?.reconcileNotifications()
                    }

                    IconButton(systemName: "trash", label: Copy.Common.delete) {
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
        // Same as the inbox header: opaque, but grainy rather than flat.
        .background(StaticField())
    }

    private func goBack() {
        if !model.path.isEmpty { model.path.removeLast() } else { dismiss() }
    }

    /// Glyph only — the destination is the one screen this can pop back to, so
    /// naming it earned nothing. Same round button as the trailing actions.
    private var backButton: some View {
        IconButton(systemName: "chevron.backward",
                   label: Copy.Message.backToNotifications) { goBack() }
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
            return Copy.Message.keyFallbackName("\(id)")
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
            // Same rule as the feed row: an urgent message is set in red rather
            // than flagged, and it stays red once read.
            Text(message.title)
                .font(.inco(.title, weight: .bold))
                .foregroundStyle(message.isCritical ? Theme.brandText : Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            if let keyName = keyName(for: message) {
                HStack(spacing: 6) {
                    Image(systemName: "key")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .accessibilityHidden(true)
                    Text(keyName)
                        .font(Theme.meta)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                .padding(.top, 10)
                // One element, and it says what the glyph means. Left as two, the
                // key icon was its own stop in the rotor and the name that followed
                // it arrived with nothing to say it was a key.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Copy.Message.sentWithKey(keyName))
            }

            // Where the message points, named. The feed only marks that a link
            // exists — this is the screen where a reader decides whether to
            // follow it, and that decision is made on the host.
            if let host = message.link?.host() {
                HStack(spacing: 6) {
                    Image(systemName: "globe")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.dim)
                        .accessibilityHidden(true)
                    Text(host.uppercased())
                        .font(Theme.meta)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.top, 8)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Copy.Message.linksTo(host))
            }

            // One clock, read twice. The age is what the feed showed and what a
            // reader arriving from it is still holding — dropping it here made
            // the screen restate the moment in a format nobody scans. The exact
            // stamp follows it rather than replacing it, because detail is also
            // where you come to find out precisely when.
            //
            // The sender's own event time when it gave one, and the time it
            // arrived otherwise — the difference between the two is a detail of
            // how it was sent, not something worth a second line.
            HStack(spacing: 7) {
                Text(Self.age(of: message))
                    .foregroundStyle(Theme.muted)
                Text("·")
                    .foregroundStyle(Theme.chip)
                Text(Self.stamp.string(from: message.occurredAt ?? message.createdAt))
                    .foregroundStyle(Theme.dim)
            }
            .font(Theme.meta)
            .monospacedDigit()
            .padding(.top, 6)

            // The rule divides what notifi says about the message from what the
            // sender put in it.
            Hairline()
                .padding(.top, 16)

            // Above the body rather than under it. A sender that attaches an
            // image attaches the thing itself and writes the caption second, so
            // a page that made you read past the words to reach it was showing
            // them in the opposite order to the one they were written in.
            //
            // Two gates, and both must pass. The scheme check is about what this
            // key is trusted to point at; showsImage is about whether the host
            // gets to learn this device's IP at all.
            if let url = message.imageURL, LinkPolicy.allows(url, anyScheme: anyScheme) {
                Group {
                    if showsImage {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                // Tap to open it properly. The column-width
                                // version is the right size for reading past
                                // and the wrong size for reading.
                                Button { viewingImage = ViewedImage(url: url) } label: {
                                    // Filled and cropped to the fixed frame
                                    // below rather than fitted inside it: a
                                    // fitted image leaves bars down the sides of
                                    // anything tall, and the frame is already
                                    // drawn with a border that would then be
                                    // bounding empty space.
                                    image.resizable().scaledToFill()
                                }
                                .buttonStyle(.geist)
                                .accessibilityLabel(Copy.Message.viewImageFullScreen)
                            case .failure:
                                VStack(spacing: 6) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 15, weight: .medium))
                                    Text(Copy.Message.imageFailedToLoad)
                                        .font(Theme.metaSmall)
                                }
                                .foregroundStyle(Theme.dim)
                                .frame(maxWidth: .infinity)
                            default:
                                Theme.surface.frame(maxWidth: .infinity)
                            }
                        }
                    } else {
                        hiddenImage(host: url.host() ?? Copy.Message.imageHost)
                    }
                }
                // One frame, whatever the image turns out to be. Sized by the
                // picture, the page jumped as each one arrived and every message
                // laid its text out at a different height — and the placeholder,
                // the failure state and the loaded image were three sizes for
                // the same block. 16:9 because that is what a screenshot of a
                // window or a chart tends to be.
                .frame(maxWidth: .infinity)
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.chip, lineWidth: 1))
                .padding(.top, 16)
            }

            if let body = message.body {
                MarkdownText(source: body, allowAnyScheme: anyScheme,
                             allowsRemoteImages: showsImage)
                    .foregroundStyle(message.isCritical ? Theme.brandDim : Theme.fg)
                    .padding(.top, 16)
            }

            // The link block and the copy button are gone on purpose. Every
            // action they carried is in the top bar — the globe opens the link,
            // and the body is selectable — and the URL itself is already in the
            // message, either as the rendered link or as the row's own chip.
            // Repeating it in a boxed panel with two buttons under it made the
            // page end in furniture rather than in the message.
            //
            // What went with them: sharing the link, and copying the whole
            // message in one gesture. Neither has a replacement here.
        }
        .padding(.bottom, 40)
    }

    private var showsImage: Bool { model.remoteImagesEnabled || revealedImage }

    /// Stands in for an image that has not been fetched yet.
    ///
    /// It names the host, because that is the party who learns the device's IP
    /// address and the time of day the moment the image loads.
    private func hiddenImage(host: String) -> some View {
        VStack(spacing: 10) {
            Text(Copy.Message.imageHidden)
                .font(.inco(.subheadline, weight: .semibold))
                .foregroundStyle(Theme.fg)
            Text(Copy.Message.imageLoadWarning(host))
                .font(Theme.metaSmall)
                .foregroundStyle(Theme.dim)
                .multilineTextAlignment(.center)
            Button {
                revealedImage = true
            } label: {
                Text(Copy.Message.loadImage)
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

    private func markRead() {
        guard let message, !message.isRead else { return }
        message.isRead = true
        do {
            try context.save()
        } catch {
            log.error("save failed: \(String(describing: error), privacy: .public)")
        }
        model.sync?.reconcileNotifications()
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
