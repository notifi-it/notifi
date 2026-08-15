import OSLog
#if os(iOS)
import StoreKit
#endif
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
    @Environment(\.dismiss) private var dismiss
    // iOS only: the Mac build ships as a direct-download DMG with no App Store
    // listing, so a rating prompt there collects stars it can deliver nowhere.
    #if os(iOS)
    @Environment(\.requestReview) private var requestReview
    #endif
    @Query private var messages: [Message]
    private let log = Logger(subsystem: "it.notifi.app", category: "store")

    @State private var confirmingDelete = false
    @State private var revealedImage = false
    @State private var viewingImage: ViewedImage?

    private struct ViewedImage: Identifiable {
        let url: URL
        var id: URL { url }
    }

    init(serverID: Int) {
        _messages = Query(filter: #Predicate<Message> { $0.serverID == serverID })
    }

    private var message: Message? { messages.first }

    private static func age(of message: Message) -> String {
        RelativeAge.string(since: message.occurredAt ?? message.createdAt)
    }

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
        .background(StaticField())
        .scrollContentBackground(.hidden)
        .safeAreaInset(edge: .top) { backBar }
        #if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        #endif
        .onAppear {
            markRead()
            #if os(iOS)
            if ReviewNudge.shouldAskAfterMessageOpen() { requestReview() }
            #endif
        }
        #if os(iOS)
        .fullScreenCover(item: $viewingImage) { ImageViewer(url: $0.url) }
        #else
        .sheet(item: $viewingImage) { ImageViewer(url: $0.url) }
        #endif
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
                HStack(spacing: 10) {
                    if let link = message.link, LinkPolicy.allows(link, anyScheme: anyScheme) {
                        IconButton(systemName: "globe", label: Copy.Common.openLink) {
                            open(link, keyID: message.keyID)
                        }
                    }

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
        .padding(.bottom, 14)
        .background(StaticField())
    }

    private func goBack() {
        if !model.path.isEmpty { model.path.removeLast() } else { dismiss() }
    }

    private var backButton: some View {
        IconButton(systemName: "chevron.backward",
                   label: Copy.Message.backToNotifications) { goBack() }
    }

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
            Text(message.title)
                .font(.inco(.title, weight: .bold))
                .foregroundStyle(message.isCritical ? Theme.brandText : Theme.fg)
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)

            metaLine(for: message)
                .padding(.top, 11)

            Hairline()
                .padding(.top, 14)

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

        }
        .padding(.bottom, 40)
    }

    private var showsImage: Bool { model.remoteImagesEnabled || revealedImage }

    @ViewBuilder
    private func metaLine(for message: Message) -> some View {
        let basis = message.occurredAt ?? message.createdAt
        // Two lines, not one. The chip, the wall-clock reading and the age is
        // already a full measure on a phone; the epoch sharing their line was
        // what wrapped it to a ragged second row and squeezed the key name to
        // "Door…". The machine timestamp reads worse interleaved with prose
        // anyway — it gets the line under, where 13 digits are just 13 digits.
        VStack(alignment: .leading, spacing: 4) {
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
        }

        let epoch = Int((basis.timeIntervalSince1970 * 1000).rounded())
        Button { Clipboard.copy("\(epoch)") } label: {
            // verbatim: Text(Int) runs the value through the locale and
            // ships 1,786,564,721,411 — grouping separators on a machine
            // timestamp, which no tool that consumes one accepts.
            Text(verbatim: "\(epoch)")
                .font(.inco(size: 11, relativeTo: .caption2))
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(Theme.controlBorder)
        }
        .buttonStyle(.geist)
        .accessibilityLabel(Copy.Message.copyTimestamp)
        }
    }

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
