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
        RelativeAge.string(since: message.occurredAt ?? message.createdAt)
    }

    /// The precise clock, to the second — the point of this line is telling two
    /// near-simultaneous alerts apart — and the date beside it.
    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private static let date: DateFormatter = {
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("d MMM y")
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
                // No download button here: it lives on the image frame itself,
                // next to the thing it downloads.
                HStack(spacing: 10) {
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

            // One metadata line: the key, the moment (three renderings of the
            // same instant — clock, date, age), and the raw epoch for whoever
            // is correlating this against a log. The host moved down to the
            // links themselves and the SOURCE footer, which is where the
            // follow-or-not decision is actually made.
            metaLine(for: message)
                .padding(.top, 11)

            // The rule divides what notifi says about the message from what the
            // sender put in it.
            Hairline()
                .padding(.top, 14)

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
                        ImageBlock(url: url,
                                   onExpand: { viewingImage = ViewedImage(url: url) },
                                   onDownload: { downloadImage(url, keyID: message.keyID) })
                    } else {
                        blockedImageChip(url: url)
                    }
                }
                .padding(.top, 16)
            }

            let annotated = message.body.map { BodyLinks.annotate($0) }

            if let annotated {
                MarkdownText(source: annotated.body, allowAnyScheme: anyScheme,
                             allowsRemoteImages: showsImage,
                             critical: message.isCritical)
                    .padding(.top, 16)
            }

            sourceFooter(for: message, bodyLinks: annotated?.links ?? [],
                         anyScheme: anyScheme)

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

    // MARK: Metadata line

    /// Key chip · clock, date and age · epoch. One line, under the title.
    @ViewBuilder
    private func metaLine(for message: Message) -> some View {
        let basis = message.occurredAt ?? message.createdAt
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            if let keyName = keyName(for: message) {
                Text(keyName)
                    .font(.inco(size: 11, weight: .semibold, relativeTo: .caption2))
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .overlay(RoundedRectangle(cornerRadius: 4)
                        .stroke(Theme.chip, lineWidth: 1))
                    .accessibilityLabel(Copy.Message.sentWithKey(keyName))
            }

            (Text(Self.clock.string(from: basis))
                .font(.inco(size: 12, weight: .semibold))
                .foregroundStyle(Theme.fg)
             + Text(" · \(Self.date.string(from: basis).uppercased())")
                .font(.inco(size: 12))
                .foregroundStyle(Theme.dim)
             + Text(" — \(Copy.Age.ago(Self.age(of: message)))")
                .font(.inco(size: 12))
                .foregroundStyle(Theme.dim))
                .monospacedDigit()
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            // The raw instant, for whoever is lining this up against a log.
            // Tapping copies it — an epoch is transcribed, never read.
            let epoch = Int((basis.timeIntervalSince1970 * 1000).rounded())
            Button { Clipboard.copy("\(epoch)") } label: {
                Text("\(epoch)")
                    .font(.inco(size: 11, relativeTo: .caption2))
                    .monospacedDigit()
                    .foregroundStyle(Theme.controlBorder)
            }
            .buttonStyle(.geist)
            .accessibilityLabel(Copy.Message.copyTimestamp)
        }
    }

    // MARK: Blocked image

    /// Stands in for an image that has not been fetched yet: one chip-height
    /// line naming the file, with the load decision at its trailing edge. The
    /// IP-disclosure explanation lives on the long-press menu rather than in
    /// the layout — it is the reason for the gate, not part of the message.
    private func blockedImageChip(url: URL) -> some View {
        Button { revealedImage = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.dim)
                    .accessibilityHidden(true)
                Text("\(ImageBlock.filename(of: url)) · \(Copy.Message.imageBlocked)")
                    .font(.inco(size: 12, relativeTo: .caption))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer(minLength: 8)
                Text(Copy.Message.load)
                    .font(.inco(size: 12, weight: .semibold, relativeTo: .caption))
                    .foregroundStyle(Theme.fg)
            }
            .padding(.vertical, 11)
            .padding(.horizontal, 13)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.chip, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.geist)
        .accessibilityLabel(Copy.Message.loadImage)
        .contextMenu {
            Button(Copy.Message.imageLoadWarning(url.host() ?? Copy.Message.imageHost)) {}
                .disabled(true)
        }
    }

    // MARK: Source footer

    /// Every URL the message carries, written out in full. The body shows a
    /// link's label; this is where the actual destination is checked before
    /// anything is followed.
    @ViewBuilder
    private func sourceFooter(for message: Message, bodyLinks: [URL],
                              anyScheme: Bool) -> some View {
        var rows: [(mark: String, url: URL, isImage: Bool)] {
            var out: [(String, URL, Bool)] = []
            for (index, url) in bodyLinks.enumerated() {
                out.append((BodyLinks.mark(index), url, false))
            }
            if let link = message.link, !bodyLinks.contains(link) {
                out.append((BodyLinks.mark(out.count), link, false))
            }
            if let image = message.imageURL {
                out.append(("img↓", image, true))
            }
            return out
        }
        let listed = rows
        if !listed.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(Copy.Message.sourceHeader.uppercased())
                        .font(.inco(size: 10, weight: .semibold, relativeTo: .caption2))
                        .tracking(1.4)
                        .foregroundStyle(Theme.dim)
                        .fixedSize()
                    Hairline()
                }
                ForEach(listed, id: \.url.absoluteString) { row in
                    Button {
                        if row.isImage {
                            revealedImage = true
                            viewingImage = ViewedImage(url: row.url)
                        } else {
                            open(row.url, keyID: message.keyID)
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text(row.mark)
                                .font(.inco(size: 11.5, relativeTo: .caption2))
                                .foregroundStyle(Theme.dim)
                                .fixedSize()
                            Text(row.url.absoluteString)
                                .font(.inco(size: 11.5, relativeTo: .caption2))
                                .foregroundStyle(Theme.muted)
                                .lineSpacing(5.5)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("↗")
                                .font(.inco(size: 11.5, weight: .semibold,
                                            relativeTo: .caption2))
                                .foregroundStyle(Theme.fg)
                                .fixedSize()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.geist)
                    .disabled(!row.isImage
                              && !LinkPolicy.allows(row.url, anyScheme: anyScheme))
                }
            }
            .padding(.top, 24)
        }
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

    fileprivate func downloadImage(_ url: URL, keyID: Int?) {
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

// MARK: - Image block

/// The message's image at its own aspect ratio, capped, with a footer bar that
/// states what the file is instead of leaving the picture to imply it.
///
/// Fetched by hand rather than through `AsyncImage`, because the footer names
/// the byte size and pixel dimensions and `AsyncImage` surrenders the data the
/// moment it has decoded it. One request either way.
private struct ImageBlock: View {
    let url: URL
    let onExpand: () -> Void
    let onDownload: () -> Void

    private struct Loaded {
        let image: Image
        let width: Int
        let height: Int
        let bytes: Int
    }

    private enum Phase {
        case loading
        case failed
        case loaded(Loaded)
    }

    @State private var phase: Phase = .loading

    static func filename(of url: URL) -> String {
        let name = url.lastPathComponent
        return name.isEmpty || name == "/" ? (url.host() ?? url.absoluteString) : name
    }

    private static let bytes: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .binary
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            switch phase {
            case .loading:
                Theme.surface
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
            case .failed:
                VStack(spacing: 6) {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                    Text(Copy.Message.imageFailedToLoad)
                        .font(Theme.metaSmall)
                }
                .foregroundStyle(Theme.dim)
                .frame(maxWidth: .infinity)
                .frame(height: 120)
            case .loaded(let loaded):
                // Its own shape, letterboxed under the cap rather than cropped:
                // a chart whose top third is missing is worse than bars.
                Button(action: onExpand) {
                    loaded.image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.geist)
                .accessibilityLabel(Copy.Message.viewImageFullScreen)

                footer(for: loaded)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.chip, lineWidth: 1))
        .task(id: url) { await load() }
    }

    private func footer(for loaded: Loaded) -> some View {
        VStack(spacing: 0) {
            Hairline()
            HStack(spacing: 14) {
                Text("\(Self.filename(of: url)) · \(loaded.width)×\(loaded.height) · \(Self.bytes.string(fromByteCount: Int64(loaded.bytes)))")
                    .foregroundStyle(Theme.dim)
                    .font(.inco(size: 10, relativeTo: .caption2))
                    .tracking(0.6)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Button(action: onDownload) {
                    Image(systemName: "arrow.down.to.line")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.fg)
                }
                .buttonStyle(.geist)
                .accessibilityLabel(Copy.Message.downloadImage)
                .geistHitArea(expandedBy: 10)

                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.dim)
                }
                .buttonStyle(.geist)
                .accessibilityLabel(Copy.Message.viewImageFullScreen)
                .geistHitArea(expandedBy: 10)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 12)
        }
    }

    private func load() async {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            phase = .failed
            return
        }
        #if os(iOS)
        guard let native = UIImage(data: data) else {
            phase = .failed
            return
        }
        let loaded = Loaded(image: Image(uiImage: native),
                            width: Int(native.size.width * native.scale),
                            height: Int(native.size.height * native.scale),
                            bytes: data.count)
        #else
        guard let native = NSImage(data: data),
              let rep = native.representations.first else {
            phase = .failed
            return
        }
        let loaded = Loaded(image: Image(nsImage: native),
                            width: rep.pixelsWide,
                            height: rep.pixelsHigh,
                            bytes: data.count)
        #endif
        phase = .loaded(loaded)
    }
}

// MARK: - Body links

/// Finds the markdown links in a body and writes each one's host and footnote
/// mark after its label, so the prose names where it points without the reader
/// leaving the line. The marks index into the SOURCE footer below the body.
enum BodyLinks {
    private static let superscripts = ["¹", "²", "³", "⁴", "⁵", "⁶", "⁷", "⁸", "⁹"]

    static func mark(_ index: Int) -> String {
        index < superscripts.count ? superscripts[index] : "⁺"
    }

    static func annotate(_ source: String) -> (body: String, links: [URL]) {
        guard let regex = try? NSRegularExpression(
            pattern: #"\[([^\]]+)\]\(([^)\s]+)\)"#) else { return (source, []) }

        var links: [URL] = []
        var out = ""
        var cursor = source.startIndex
        let ns = source as NSString
        for match in regex.matches(in: source,
                                   range: NSRange(location: 0, length: ns.length)) {
            guard let whole = Range(match.range, in: source),
                  let urlRange = Range(match.range(at: 2), in: source),
                  let url = URL(string: String(source[urlRange])) else { continue }
            out += source[cursor..<whole.upperBound]
            let host = url.host() ?? url.absoluteString
            out += " \(host) \(mark(links.count))"
            links.append(url)
            cursor = whole.upperBound
        }
        out += source[cursor...]
        return (out, links)
    }
}
