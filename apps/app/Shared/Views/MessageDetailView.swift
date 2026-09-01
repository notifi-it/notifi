import OSLog
#if os(iOS)
import Photos
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
    #if os(iOS)
    @Environment(\.requestReview) private var requestReview
    #endif
    @Query private var messages: [Message]
    private let log = Logger(subsystem: "it.notifi.app", category: "store")

    @ScaledMetric(relativeTo: .caption2) private var stampSize: CGFloat = 11
    @ScaledMetric(relativeTo: .caption) private var chipIconSize: CGFloat = 11

    @State private var confirmingDelete = false
    @State private var revealedImage = false
    @State private var viewingImage: ViewedImage?
    @State private var imageSave: ImageSaveState = .idle

    private struct ViewedImage: Identifiable {
        let url: URL
        var id: URL { url }
    }

    init(serverID: Int) {
        _messages = Query(filter: #Predicate<Message> { $0.serverID == serverID })
    }

    private var message: Message? { messages.first }

    private static func age(of message: Message) -> String {
        RelativeAge.agoString(since: message.occurredAt ?? message.createdAt)
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
        VStack(spacing: 0) {
            backBar
            scroll
        }
        .background(StaticField())
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

    private var scroll: some View {
        ScrollView {
            if let message {
                content(for: message)
                    .geistGutter()
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
        .scrollContentBackground(.hidden)
        .contentMargins(.top, Theme.contentTop, for: .scrollContent)
        #if os(macOS)
        .contentMargins(.bottom, Theme.bottomPlate, for: .scrollContent)
        #endif
        .geistTopFade()
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
                HStack(spacing: Theme.headerActionSpacing) {
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
        .geistPageHeader()
        .background(StaticField())
    }

    private func goBack() {
        if !model.path.isEmpty { model.path.removeLast() } else { dismiss() }
    }

    private var backButton: some View {
        IconButton(systemName: "chevron.backward",
                   label: Copy.Components.backTo(Copy.Inbox.title)) { goBack() }
    }

    private func keyName(for message: Message) -> String? {
        guard let id = message.keyID else { return nil }
        guard let key = model.sync?.keys.first(where: { $0.id == id }) else {
            return Copy.Message.keyFallbackName("\(id)")
        }
        return key.isDefault ? nil : key.name
    }

    private func key(for message: Message) -> CachedKey? {
        guard let id = message.keyID else { return nil }
        guard let key = model.sync?.keys.first(where: { $0.id == id }) else { return nil }
        return key.isDefault ? nil : key
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
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            metaLine(for: message)
                .padding(.top, 9)
                .frame(maxWidth: .infinity)

            if let url = message.imageURL, LinkPolicy.allows(url, anyScheme: anyScheme) {
                Group {
                    if showsImage {
                        ImageBlock(url: url,
                                   saveState: imageSave,
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
                             allowsRemoteImages: showsImage)
                    .padding(.top, 16)
            }
        }
        .padding(.bottom, 40)
    }

    private var showsImage: Bool { model.remoteImagesEnabled || revealedImage }

    private func keyGlyph(_ size: CGFloat, _ tint: Color) -> some View {
        Image("akar-key")
            .renderingMode(.template)
            .resizable()
            .frame(width: size, height: size)
            .foregroundStyle(tint)
            .accessibilityHidden(true)
    }

    private func quietLine(_ name: String?, age: String, stamp: String) -> some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                if let name {
                    keyGlyph(11, Theme.dim)
                    Text(name)
                        .font(.karla(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    Text("·").foregroundStyle(Theme.chip)
                }
                Text(age)
                    .font(.karla(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            Text(stamp)
                .font(.system(size: stampSize, weight: .regular, design: .monospaced))
                .tracking(1.4)
                .foregroundStyle(Theme.dim)
        }
        .lineLimit(1)
        .monospacedDigit()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func metaLine(for message: Message) -> some View {
        let basis = message.occurredAt ?? message.createdAt
        let stamp = "\(Self.clock.string(from: basis)) "
            + Self.date.string(from: basis).uppercased()
        tappableKey(message) {
            quietLine(keyName(for: message),
                      age: Self.age(of: message),
                      stamp: stamp)
        }
    }

    @ViewBuilder
    private func tappableKey<Label: View>(_ message: Message,
                                          @ViewBuilder label: () -> Label) -> some View {
        if let key = key(for: message), let name = keyName(for: message) {
            Button { model.path.append(key) } label: { label() }
                .buttonStyle(.geist)
                .accessibilityLabel(Copy.Message.openKey(name))
        } else {
            label()
                .accessibilityLabel(keyName(for: message)
                    .map { Copy.Message.sentWithKey($0) } ?? "")
        }
    }

    private func blockedImageChip(url: URL) -> some View {
        Button { revealedImage = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: chipIconSize, weight: .medium))
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
        guard LinkPolicy.allows(url, anyScheme: model.allowsAnyLink(keyID: keyID)) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    @MainActor
    fileprivate func downloadImage(_ url: URL, keyID: Int?) {
        guard LinkPolicy.allows(url, anyScheme: model.allowsAnyLink(keyID: keyID)) else { return }
        guard imageSave != .saving else { return }
        imageSave = .saving
        Task {
            guard let (data, _) = try? await URLSession.shared.data(from: url) else {
                settle(.failed(Copy.Message.imageSaveFailed))
                return
            }
            #if os(iOS)
            await saveToPhotos(data)
            #else
            await saveToFile(data, named: url.lastPathComponent)
            #endif
        }
    }

    @MainActor
    private func settle(_ state: ImageSaveState) {
        imageSave = state
        switch state {
        case .saved(let text):
            Haptics.success()
            AccessibilityNotification.Announcement(text).post()
        case .failed(let text):
            Haptics.error()
            AccessibilityNotification.Announcement(text).post()
        case .idle, .saving:
            break
        }
        guard state != .idle else { return }
        Task {
            try? await Task.sleep(for: .seconds(3))
            if imageSave == state { imageSave = .idle }
        }
    }

    #if os(iOS)
    @MainActor
    private func saveToPhotos(_ data: Data) async {
        var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        if status == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        }
        guard status == .authorized || status == .limited else {
            settle(.failed(Copy.Message.imageSaveDenied))
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetCreationRequest.forAsset().addResource(with: .photo, data: data, options: nil)
            }
            settle(.saved(Copy.Message.imageSaved))
        } catch {
            log.error("image save failed: \(String(describing: error), privacy: .public)")
            settle(.failed(Copy.Message.imageSaveFailed))
        }
    }
    #else
    @MainActor
    private func saveToFile(_ data: Data, named name: String) async {
        NSApp.activate(ignoringOtherApps: true)

        let panel = NSSavePanel()
        panel.nameFieldStringValue = name
        panel.directoryURL = try? FileManager.default.url(
            for: .downloadsDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false)
        panel.level = .modalPanel

        macMenuBar.holdOpen()
        panel.begin { response in
            if response == .OK, let target = panel.url {
                do {
                    try data.write(to: target)
                    NSWorkspace.shared.activateFileViewerSelecting([target])
                    settle(.saved(Copy.Message.imageSavedToFile))
                } catch {
                    log.error("image save failed: \(String(describing: error), privacy: .public)")
                    settle(.failed(Copy.Message.imageSaveFailed))
                }
            } else {
                imageSave = .idle
            }
            macMenuBar.releaseHold()
        }
    }
    #endif
}

enum ImageSaveState: Equatable {
    case idle
    case saving
    case saved(String)
    case failed(String)
}

private struct ImageBlock: View {
    let url: URL
    let saveState: ImageSaveState
    let onExpand: () -> Void
    let onDownload: () -> Void

    @ScaledMetric(relativeTo: .subheadline) private var failedIconSize: CGFloat = 15
    @ScaledMetric(relativeTo: .footnote) private var downloadIconSize: CGFloat = 13
    @ScaledMetric(relativeTo: .caption) private var expandIconSize: CGFloat = 12

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
                        .font(.system(size: failedIconSize, weight: .medium))
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
                Group {
                    if let status = saveStatus {
                        Text(status.text)
                            .foregroundStyle(status.tint)
                    } else {
                        Text("\(Self.filename(of: url)) · \(loaded.width)×\(loaded.height) · \(Self.bytes.string(fromByteCount: Int64(loaded.bytes)))")
                            .foregroundStyle(Theme.dim)
                    }
                }
                .font(.inco(size: 10, relativeTo: .caption2))
                .tracking(0.6)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(Theme.state, value: saveState)

                Button(action: onDownload) {
                    downloadGlyph
                        .frame(width: downloadIconSize + 5, height: downloadIconSize + 5)
                }
                .buttonStyle(.geist)
                .disabled(saveState == .saving)
                .accessibilityLabel(saveStatus?.text ?? Copy.Message.downloadImage)
                .geistHitArea(expandedBy: 10)

                Button(action: onExpand) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: expandIconSize, weight: .medium))
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

    private var saveStatus: (text: String, tint: Color)? {
        switch saveState {
        case .idle: return nil
        case .saving: return (Copy.Message.savingImage, Theme.dim)
        case .saved(let text): return (text, Theme.fg)
        case .failed(let text): return (text, Theme.danger)
        }
    }

    @ViewBuilder
    private var downloadGlyph: some View {
        switch saveState {
        case .saving:
            ProgressView()
                .controlSize(.mini)
                .tint(Theme.dim)
        case .saved:
            Image(systemName: "checkmark")
                .font(.system(size: downloadIconSize, weight: .semibold))
                .foregroundStyle(Theme.fg)
                .transition(.opacity)
        case .failed:
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: downloadIconSize, weight: .medium))
                .foregroundStyle(Theme.danger)
        case .idle:
            Image(systemName: "arrow.down.to.line")
                .font(.system(size: downloadIconSize, weight: .medium))
                .foregroundStyle(Theme.fg)
        }
    }

    private func load() async {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else {
            phase = .failed
            #if DEBUG
            SampleData.imageDidSettle()
            #endif
            return
        }
        #if os(iOS)
        guard let native = UIImage(data: data) else {
            phase = .failed
            #if DEBUG
            SampleData.imageDidSettle()
            #endif
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
            #if DEBUG
            SampleData.imageDidSettle()
            #endif
            return
        }
        let loaded = Loaded(image: Image(nsImage: native),
                            width: rep.pixelsWide,
                            height: rep.pixelsHigh,
                            bytes: data.count)
        #endif
        phase = .loaded(loaded)
        #if DEBUG
        SampleData.imageDidSettle()
        #endif
    }
}

enum BodyLinks {
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
            out += " \(host)"
            links.append(url)
            cursor = whole.upperBound
        }
        out += source[cursor...]
        return (out, links)
    }
}
