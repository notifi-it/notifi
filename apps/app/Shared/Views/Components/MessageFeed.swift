import Combine
import OSLog
import SwiftData
import SwiftUI

struct MessageFeed<Empty: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    let messages: [Message]
    @ViewBuilder let empty: () -> Empty

    @State private var now = Date()
    @State private var pendingDelete: Message?

    private var clock: AnyPublisher<Date, Never> {
        Timer.publish(every: 30, tolerance: 5, on: .main, in: .common)
            .autoconnect()
            .eraseToAnyPublisher()
    }

    @ViewBuilder
    private var rows: some View {
        if messages.isEmpty {
            empty().plainRow()
        } else {
            let banded = bands
            ForEach(banded) { band in
                BandHeader(title: DayBand.title(for: band.day, now: now),
                           count: band.messages.count,
                           isFirst: band.id == banded.first?.id)
                    .geistGutter()
                    .plainRow()

                ForEach(Array(band.messages.enumerated()),
                        id: \.element.serverID) { index, message in
                    row(for: message,
                        showsRule: index < band.messages.count - 1)
                }
            }
        }
    }

    @ViewBuilder
    private var feed: some View {
        #if os(macOS)
        ScrollView { LazyVStack(spacing: 0) { rows } }
        #else
        List { rows }
        #endif
    }

    var body: some View {
        feed
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        #if os(macOS)
        .contentMargins(.bottom, Theme.bottomPlate, for: .scrollContent)
        #endif
        .contentMargins(.top, Theme.listContentTop, for: .scrollContent)
        .geistTopFade()
        .background(Color.clear)
        .scrollDismissesKeyboard(.immediately)
        .onReceive(clock) { now = $0 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
        .alert(
            pendingDelete.map { Copy.Inbox.deleteTitle($0.title) } ?? Copy.Inbox.deleteTitleFallback,
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { message in
            Button(Copy.Common.delete, role: .destructive) {
                delete(message)
                pendingDelete = nil
            }
            Button(Copy.Common.cancel, role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text(Copy.Inbox.deleteMessage)
        }
        #if os(iOS)
        .refreshable { await model.refresh() }
        #endif
    }

    @ViewBuilder
    private func row(for message: Message, showsRule: Bool) -> some View {
        Button {
            model.path.append(message.serverID)
        } label: {
            MessageRow(message: message, now: now,
                       showsRule: showsRule,
                       openLink: openAction(for: message))
                .contentShape(Rectangle())
        }
        .buttonStyle(.geistRow)
        .plainRow()
        #if os(iOS)
        .swipeActions(edge: .leading) {
            Button { toggleRead(message) } label: {
                Image(systemName: message.isRead ? "circle.fill" : "circle")
                    .accessibilityLabel(
                        message.isRead ? Copy.Common.markAsUnread : Copy.Common.markAsRead)
            }
            .tint(Theme.chip)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button { pendingDelete = message } label: {
                Image(systemName: "trash")
                    .accessibilityLabel(Copy.Common.delete)
            }
            .tint(Theme.danger)
        }
        #endif
        .accessibilityAction(named: message.isRead ? Copy.Common.markAsUnread : Copy.Common.markAsRead) {
            toggleRead(message)
        }
        .accessibilityAction(named: Copy.Common.delete) {
            pendingDelete = message
        }
        .contextMenu { menu(for: message) }
    }

    private func openAction(for message: Message) -> (() -> Void)? {
        guard let link = message.link,
              LinkPolicy.allows(link, anyScheme: model.allowsAnyLink(keyID: message.keyID))
        else { return nil }
        return { open(link, keyID: message.keyID) }
    }

    private var bands: [BandedMessages] {
        let calendar = Calendar.current
        var order: [Date] = []
        var bucketed: [Date: [Message]] = [:]
        for message in messages {
            let day = calendar.startOfDay(for: message.occurredAt ?? message.createdAt)
            if bucketed[day] == nil { order.append(day) }
            bucketed[day, default: []].append(message)
        }
        return order
            .sorted(by: >)
            .map { BandedMessages(day: $0, messages: bucketed[$0] ?? []) }
    }

    @ViewBuilder
    private func menu(for message: Message) -> some View {
        Button(message.isRead ? Copy.Common.markAsUnread : Copy.Common.markAsRead) { toggleRead(message) }
        Divider()
        Button(Copy.Inbox.copyTitle) { Clipboard.copy(message.title) }
        if let body = message.body {
            Button(Copy.Inbox.copyMessage) { Clipboard.copy(body) }
        }
        if let link = message.link {
            Button(Copy.Inbox.copyLink) { Clipboard.copy(link.absoluteString) }
            if LinkPolicy.allows(link, anyScheme: model.allowsAnyLink(keyID: message.keyID)) {
                Button(Copy.Common.openLink) { open(link, keyID: message.keyID) }
                #if os(iOS)
                ShareLink(item: link) { Text(Copy.Message.shareLink) }
                #endif
            }
        }
        Divider()
        Button(Copy.Common.delete, role: .destructive) { pendingDelete = message }
    }

    private func toggleRead(_ message: Message) {
        message.isRead.toggle()
        save()
        model.sync?.reconcileNotifications()
        Haptics.tap()
    }

    private func delete(_ message: Message) {
        withAnimation {
            context.delete(message)
            save()
        }
        model.sync?.reconcileNotifications()
        Haptics.success()
    }

    private func open(_ url: URL, keyID: Int?) {
        guard LinkPolicy.allows(url, anyScheme: model.allowsAnyLink(keyID: keyID)) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    private func save() {
        do {
            try context.save()
        } catch {
            Logger(subsystem: "it.notifi.app", category: "feed")
                .error("save failed: \(String(describing: error), privacy: .public)")
        }
    }
}

extension View {
    func plainRow(insets: EdgeInsets = EdgeInsets(),
                  background: Color = .clear) -> some View {
        listRowBackground(background)
            .listRowSeparator(.hidden)
            .listRowInsets(insets)
    }
}

private struct BandedMessages: Identifiable {
    let day: Date
    let messages: [Message]
    var id: Date { day }
}

private enum DayBand {
    static func title(for day: Date, now: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDate(day, inSameDayAs: now) { return Copy.Inbox.bandToday }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return Copy.Inbox.bandYesterday
        }
        return calendar.isDate(day, equalTo: now, toGranularity: .year)
            ? dayAndMonth.string(from: day)
            : dayMonthYear.string(from: day)
    }

    private static let dayAndMonth = formatter(template: "d MMM")
    private static let dayMonthYear = formatter(template: "d MMM y")

    private static func formatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

private struct BandHeader: View {
    let title: String
    let count: Int
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 10) {
            Text(title.uppercased())
                .font(Theme.sectionLabel)
                .tracking(1.4)
                .foregroundStyle(Theme.fg)
                .lineLimit(1)
            Rectangle()
                .fill(Theme.dim)
                .frame(height: 1.5)
                .accessibilityHidden(true)
            Text("\(count)")
                .font(Theme.metaSmall)
                .foregroundStyle(Theme.dim)
                .monospacedDigit()
        }
        .padding(.top, isFirst ? 0 : 16)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Inbox.bandLabel(title, Copy.Inbox.count(count)))
    }
}

private struct MonoLine: View {
    let text: String
    let font: Font

    static let ellipsis = "..."

    private static let tracking: CGFloat = -0.34
    private static let ruler = String(repeating: "0", count: 40)

    @State private var cell: CGFloat = 0
    @State private var available: CGFloat = 0

    private static var reserved: Int {
        Int((CGFloat(ellipsis.count) * (1 + tracking)).rounded(.up))
    }

    private var head: String? {
        guard cell > 0, available > 0 else { return nil }
        let cells = Int((available + cell * 0.02) / cell)
        guard cells > Self.reserved, text.count > cells else { return nil }
        let cut = text.prefix(cells - Self.reserved)
        return String(cut.reversed().drop { $0 == "." }.reversed())
    }

    private var line: Text {
        guard let head else { return Text(text) }
        return Text(head) + Text(Self.ellipsis).tracking(cell * Self.tracking)
    }

    var body: some View {
        line
            .font(font)
            .lineLimit(1)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onChange(of: proxy.size.width, initial: true) { _, width in
                            available = width
                        }
                }
            }
            .background(alignment: .leading) {
                Text(verbatim: Self.ruler)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .hidden()
                    .accessibilityHidden(true)
                    .background {
                        GeometryReader { proxy in
                            Color.clear
                                .onChange(of: proxy.size.width, initial: true) { _, width in
                                    cell = width / CGFloat(Self.ruler.count)
                                }
                        }
                    }
            }
            .accessibilityLabel(text)
    }
}

private struct MessageRow: View {
    let message: Message
    let now: Date
    let showsRule: Bool
    var openLink: (() -> Void)?

    @ScaledMetric(relativeTo: .caption2) private var slotIconSize: CGFloat = 11

    @State private var isHovered = false
    @State private var isLinkHovered = false

    static let drawsRules = false

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var basis: Date { message.occurredAt ?? message.createdAt }

    private var textWeight: Font.Weight { message.isRead ? .light : .regular }

    private var textColor: Color {
        message.isRead && !isHovered ? Theme.read : Theme.fg
    }

    private var previewColor: Color {
        message.isRead && !isHovered ? Theme.muted : Theme.read
    }

    private var isEscalated: Bool { !message.isRead }

    private var preview: String? {
        guard let body = message.body else { return nil }
        let line = MarkdownPreview.text(body).trimmingCharacters(in: .whitespaces)
        return line.isEmpty ? nil : line
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            if showsRule && Self.drawsRules { rule }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenDescription)
    }

    private var content: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(Self.clock.string(from: basis))
                .font(.inco(size: 12, weight: textWeight, relativeTo: .footnote))
                .monospacedDigit()
                .underline(message.isCritical, pattern: .solid)
                .foregroundStyle(isEscalated ? Theme.brandText
                                 : isHovered ? Theme.muted : Theme.dim)
                .lineLimit(1)
                .fixedSize()

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    MonoLine(text: message.title,
                             font: .inco(size: 13.5, weight: textWeight,
                                         relativeTo: .footnote))
                        .foregroundStyle(textColor)

                    slot(present: message.isCritical, systemName: "bolt")
                    linkSlot
                    slot(present: message.imageURL != nil, systemName: "photo")
                }

                if let preview {
                    Text(preview)
                        .font(.karla(size: 12.5, weight: textWeight, relativeTo: .footnote))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(previewColor)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .frame(minHeight: 44)
        .hoverHighlight { isHovered = $0 }
    }

    @ViewBuilder
    private var linkSlot: some View {
        #if os(macOS)
        if message.link != nil, let openLink {
            Button(action: openLink) {
                glyph("globe")
                    .foregroundStyle(isLinkHovered ? Theme.brandText : Theme.dim)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .animation(.easeOut(duration: 0.12), value: isLinkHovered)
            .onHover { isLinkHovered = $0 }
            .help(Copy.Common.openLink)
            .accessibilityLabel(Copy.Common.openLink)
        } else {
            slot(present: message.link != nil, systemName: "globe")
        }
        #else
        slot(present: message.link != nil, systemName: "globe")
        #endif
    }

    private func glyph(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: slotIconSize, weight: .medium))
            .frame(width: slotIconSize + 1)
    }

    @ViewBuilder
    private func slot(present: Bool, systemName: String) -> some View {
        if present {
            glyph(systemName)
                .foregroundStyle(Theme.dim)
                .accessibilityHidden(true)
        }
    }

    private var rule: some View {
        Hairline()
    }

    private var spokenDescription: String {
        var parts: [String] = []
        if !message.isRead { parts.append(Copy.Inbox.unread) }
        if message.isCritical { parts.append(Copy.Inbox.critical) }
        parts.append(message.title)
        if let preview { parts.append(preview) }
        if let link = message.link, let host = link.host() {
            parts.append(Copy.Inbox.linkTo(host))
        }
        if message.imageURL != nil { parts.append(Copy.Inbox.hasImage) }
        parts.append(Self.clock.string(from: basis))
        return parts.joined(separator: ", ")
    }
}
