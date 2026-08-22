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
                    .padding(.horizontal, 18)
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
        .modifier(TrackingRoll())
        .listStyle(.plain)
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        #if os(macOS)
        .contentMargins(.bottom, Theme.bottomPlate, for: .scrollContent)
        #endif
        .contentMargins(.top, Theme.contentTop, for: .scrollContent)
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
                       showsRule: showsRule)
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
        .contextMenu { menu(for: message) }
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
                ShareLink(item: link) { Label(Copy.Message.shareLink, systemImage: "square.and.arrow.up") }
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

private struct TrackingRoll: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var slip: CGFloat = 0
    @State private var flicker: Double = 0
    @State private var lastOffset: CGFloat?
    @State private var lastSample = Date()

    private let floor: CGFloat = 900
    private let span: CGFloat = 3_500

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *), !reduceMotion {
            content
                .offset(x: slip)
                .brightness(flicker)
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y } action: { _, new in
                    react(to: new)
                }
        } else {
            content
        }
    }

    private func react(to offset: CGFloat) {
        let now = Date()
        let elapsed = max(now.timeIntervalSince(lastSample), 1.0 / 120.0)
        lastSample = now

        let previous = lastOffset ?? offset
        lastOffset = offset
        let velocity = abs(offset - previous) / elapsed

        let strength = min(max((velocity - floor) / span, 0), 1)
        guard strength > 0 else {
            guard slip != 0 || flicker != 0 else { return }
            withAnimation(.easeOut(duration: 0.2)) {
                slip = 0
                flicker = 0
            }
            return
        }

        slip = .random(in: -2.5...2.5) * strength
        flicker = .random(in: -0.02...0.04) * strength
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
        .padding(.top, isFirst ? 0 : 26)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Inbox.bandLabel(title, Copy.Inbox.count(count)))
    }
}

private struct MessageRow: View {
    let message: Message
    let now: Date
    let showsRule: Bool

    @State private var isHovered = false
    @State private var hoverTask: Task<Void, Never>?

    static let drawsRules = false

    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var basis: Date { message.occurredAt ?? message.createdAt }

    private var isEscalated: Bool { !message.isRead || message.isCritical }

    var body: some View {
        VStack(spacing: 0) {
            content
            if showsRule && Self.drawsRules { rule }
        }
        #if os(macOS)
        .grainReveal(trigger: message.id, duration: 0.5, once: true, strength: 1.2)
        #endif
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenDescription)
    }

    private var content: some View {
        HStack(spacing: 12) {
            Text(Self.clock.string(from: basis))
                .font(.inco(size: 12, weight: isEscalated ? .semibold : .regular))
                .monospacedDigit()
                .foregroundStyle(isEscalated ? Theme.brandText
                                 : isHovered ? Theme.muted : Theme.dim)
                .lineLimit(1)
                .fixedSize()

            Text(message.title)
                .font(.inco(size: 13.5, weight: isEscalated ? .bold : .regular,
                            relativeTo: .footnote))
                .foregroundStyle(message.isCritical ? Theme.brandText
                                 : message.isRead && !isHovered ? Theme.read : Theme.fg)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            slot(present: message.link != nil, systemName: "globe")
            slot(present: message.imageURL != nil, systemName: "photo")
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        #if os(macOS)
        .background {
            if isHovered {
                StaticField(level: .hover, fillsScreen: false)
            }
        }
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { hovering in
            hoverTask?.cancel()
            guard hovering else {
                isHovered = false
                return
            }
            hoverTask = Task {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                isHovered = true
            }
        }
        #endif
    }

    private func slot(present: Bool, systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.dim)
            .opacity(present ? 1 : 0)
            .frame(width: 12)
            .accessibilityHidden(true)
    }

    private var rule: some View {
        Hairline()
    }

    private var spokenDescription: String {
        var parts: [String] = []
        if !message.isRead { parts.append(Copy.Inbox.unread) }
        if message.isCritical { parts.append(Copy.Inbox.critical) }
        parts.append(message.title)
        if let link = message.link, let host = link.host() {
            parts.append(Copy.Inbox.linkTo(host))
        }
        if message.imageURL != nil { parts.append("Has an image") }
        parts.append(Self.clock.string(from: basis))
        return parts.joined(separator: ", ")
    }
}
