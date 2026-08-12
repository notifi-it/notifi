import Combine
import OSLog
import SwiftData
import SwiftUI

/// The list of messages, banded by time, and everything a row can do.
///
/// Extracted from `InboxView` when search became its own tab on iOS: two
/// screens now draw the same feed, and a row that swipes on one and not the
/// other — or deletes without asking on one — is the kind of drift nobody
/// notices until a user does. The caller decides *which* messages and what to
/// show when there are none; everything below that is fixed here, banding
/// included, because a feed that groups by day on one screen and not the other
/// is the same drift in a different place.

struct MessageFeed<Empty: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase

    /// Already filtered. The feed does no matching of its own — the Inbox ANDs
    /// a query with a key filter, search does not, and pushing that in here
    /// would mean two callers passing flags to switch it off.
    let messages: [Message]
    /// Shown in place of the rows when `messages` is empty. A tab that has
    /// nothing yet and a query that matched nothing are different situations
    /// and read differently.
    @ViewBuilder let empty: () -> Empty

    @State private var now = Date()
    @State private var pendingDelete: Message?

    /// A computed property rather than a `static let`: a generic type cannot
    /// hold static storage, and the publisher is cheap to make.
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
            // Bound once: it is a computed property, and reading it inside the
            // loop as well would band the whole feed again on every row.
            let banded = bands
            ForEach(banded) { band in
                BandHeader(title: DayBand.title(for: band.day, now: now),
                           count: band.messages.count,
                           isFirst: band.id == banded.first?.id)
                    // The rows below inset at 18, not the 20pt gutter — the
                    // band's rule and the clock column share a left edge.
                    .padding(.horizontal, 18)
                    .plainRow()

                ForEach(Array(band.messages.enumerated()),
                        id: \.element.serverID) { index, message in
                    // The last message in a band draws no rule of its own.
                    // The next band's rule is already the divider under it,
                    // and two lines a few points apart read as a mistake.
                    row(for: message,
                        showsRule: index < band.messages.count - 1)
                }
            }
        }
    }

    /// The same rows in two containers. iOS keeps `List`, which buys it swipe
    /// actions and pull-to-refresh. The Mac popover uses a plain `ScrollView`:
    /// the AppKit table under a Mac `List` estimates variable row heights while
    /// scrolling and corrects them as rows arrive, which read as jitter — and a
    /// few hundred lazy rows need none of the table's recycling. It also stops
    /// AppKit ringing the right-clicked row in accent blue, which no modifier
    /// could reach.
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
        // A List cell is at least 44pt tall unless told otherwise, and the band
        // header is shorter than that — so the list was padding it out to the
        // minimum and the gap under a heading had nothing to do with the
        // padding written on it. Every row here draws its own vertical space,
        // so the floor is only ever adding space nobody asked for.
        .environment(\.defaultMinListRowHeight, 0)
        .scrollContentBackground(.hidden)
        // Room under the last row for the tab bar to float over. Measured as the
        // fade rather than as the bar: the fade is what actually obscures the
        // bottom of the feed, so clearing it clears the bar inside it, and the
        // last message can be scrolled to fully lit instead of half dissolved.
        .contentMargins(.bottom, Theme.bottomFade, for: .scrollContent)
        // Room under the header for the fade that dissolves rows as they pass
        // beneath it, the same way the bottom margin clears the fade at the
        // other end. Measured rather than left to the list: a plain List opens
        // with an inset of its own, which sat on top of the header's bottom
        // padding and left the first band floating in the middle of nothing.
        .contentMargins(.top, Theme.topFade, for: .scrollContent)
        // Clear: the screen behind paints the static ground, and repainting
        // it flat here would cover the texture across the whole feed.
        .background(Color.clear)
        .scrollDismissesKeyboard(.immediately)
        .onReceive(clock) { now = $0 }
        // Timers do not fire while the app is suspended, so coming back to the
        // foreground after a while would otherwise show the ages from whenever
        // it was last put down until the next tick caught up.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
        // The title names the message. A swipe is easy to start by accident and
        // easy to land on the wrong row, and "Delete this notification?" looks
        // identical whichever row summoned it.
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
        // Pull-to-refresh is a touch gesture. The Mac refreshes with ⌘R and the
        // overflow menu instead.
        .refreshable { await model.refresh() }
        #endif
    }

    @ViewBuilder
    private func row(for message: Message, showsRule: Bool) -> some View {
        Button {
            model.path.append(message.serverID)
        } label: {
            // The gutter is inside the button and the shape is explicit, so the
            // whole row answers a tap. With the padding outside, the 20pt
            // margins were dead, and without the shape the gaps between title,
            // time and thumbnail were too: a stack only hit-tests where it
            // actually drew something.
            MessageRow(message: message, now: now,
                       showsRule: showsRule)
                .contentShape(Rectangle())
        }
        .buttonStyle(.geistRow)
        // One ground for every row. Raising the unread ones banded the feed
        // into blocks that had nothing to do with the time bands it is already
        // cut into, and on a screen this dark the step read as a rendering fault
        // before it read as a state. Unread is the red age and the heavier
        // title. The rule between messages is drawn by the row itself, so that
        // it can be left off where a band header follows.
        .plainRow()
        // Swiping is a touch idiom. On the Mac the same actions live in the
        // right-click menu below, which is where a Mac user looks.
        #if os(iOS)
        .swipeActions(edge: .leading) {
            Button { toggleRead(message) } label: {
                // The same ring/dot the detail screen uses for this action, so
                // the two places that toggle read state are not drawn from
                // different icon families.
                //
                // An `Image` rather than a `Label`: a swipe action renders the
                // title under the glyph, and the word was doing nothing the
                // icon and the swipe direction did not already say. The spoken
                // name is kept.
                Image(systemName: message.isRead ? "circle.fill" : "circle")
                    .accessibilityLabel(
                        message.isRead ? Copy.Common.markAsUnread : Copy.Common.markAsRead)
            }
            .tint(Theme.chip)
        }
        // No full swipe. Throwing the row off the edge is the gesture that means
        // "gone, now" in Mail and Notes, and it means that there because those
        // apps can put it back. This one asks a question instead, so offering
        // the gesture would promise something the next screen takes away.
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // No `role: .destructive`, and not for the colour — the tint has to
            // be explicit either way, because the TabView's near-white tint
            // cascades down and beats the role's red. The role is what made the
            // row fly out and come back: a List reads a destructive swipe action
            // as the deletion itself and plays the removal animation on tap,
            // then puts the row back when the store turns out to be unchanged.
            // Nothing here has been agreed to yet, so nothing should move.
            //
            // Asks first: a swipe is easy to do by accident and the message
            // cannot be recovered afterwards.
            Button { pendingDelete = message } label: {
                Image(systemName: "trash")
                    .accessibilityLabel(Copy.Common.delete)
            }
            .tint(Theme.danger)
        }
        #endif
        .contextMenu { menu(for: message) }
    }

    /// The feed, cut into day bands in the order they are shown.
    ///
    /// Banded on `occurredAt ?? createdAt` — what the row's own clock shows —
    /// rather than on the sort key. The rows carry a wall-clock time and nothing
    /// else, so the band above them is what says which day that time belongs to;
    /// coarser bands would leave "14:02" ambiguous.
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

    // MARK: Row menu

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
                // Sharing the URL rather than the message: what a reader wants
                // to hand on from a page like this is the thing it points at,
                // and the title and body are already one tap from being copied
                // above.
                ShareLink(item: link) { Label(Copy.Message.shareLink, systemImage: "square.and.arrow.up") }
            }
        }
        Divider()
        Button(Copy.Common.delete, role: .destructive) { pendingDelete = message }
    }

    // MARK: Actions

    private func toggleRead(_ message: Message) {
        message.isRead.toggle()
        save()
        model.sync?.reconcileNotifications()
        // The row's visible change is subtle — a weight and a colour — and on a
        // swipe the thumb is covering it.
        Haptics.tap()
    }

    private func delete(_ message: Message) {
        // Explicit, because the swipe no longer carries an animation of its own:
        // a store change that a List picks up on its next diff takes the row out
        // between one frame and the next, which reads as the feed glitching
        // rather than as the thing the reader just asked for.
        withAnimation {
            context.delete(message)
            save()
        }
        model.sync?.reconcileNotifications()
        // Fired on completion, not on the swipe: the alert between the two is
        // where the gesture stops being an accident.
        Haptics.success()
    }

    private func open(_ url: URL, keyID: Int?) {
        guard LinkPolicy.allows(url, keyID: keyID) else { return }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
    }

    /// Every write goes through here so a failure is logged rather than swallowed.
    private func save() {
        do {
            try context.save()
        } catch {
            Logger(subsystem: "it.notifi.app", category: "feed")
                .error("save failed: \(String(describing: error), privacy: .public)")
        }
    }
}

/// A CRT losing tracking when the picture moves faster than it can hold.
///
/// Driven by scroll velocity rather than by the gesture, so it answers a flick
/// and ignores a careful drag — the point is that the feed can be scrolled past
/// what the tube can keep up with, and a wobble that fired on every touch would
/// just read as a rendering fault. Below the threshold nothing happens at all.
///
/// The displacement is deliberately small. At more than a couple of points the
/// text stops being readable while it moves, and an effect that has to be
/// waited out is one the reader learns to resent.
private struct TrackingRoll: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var slip: CGFloat = 0
    @State private var flicker: Double = 0
    @State private var lastOffset: CGFloat?
    @State private var lastSample = Date()

    /// Points per second the feed has to be moving before the picture starts to
    /// slip, and the span above it over which the effect reaches full strength.
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
        // Floored: two samples in the same frame would divide by something near
        // zero and report a velocity in the millions.
        let elapsed = max(now.timeIntervalSince(lastSample), 1.0 / 120.0)
        lastSample = now

        let previous = lastOffset ?? offset
        lastOffset = offset
        let velocity = abs(offset - previous) / elapsed

        let strength = min(max((velocity - floor) / span, 0), 1)
        guard strength > 0 else {
            guard slip != 0 || flicker != 0 else { return }
            // Eased rather than snapped: the picture settling back is the half
            // of the effect that says it was a tracking problem and not a jump.
            withAnimation(.easeOut(duration: 0.2)) {
                slip = 0
                flicker = 0
            }
            return
        }

        // Re-rolled per sample rather than animated. A tracking fault is noise,
        // and anything smoothly interpolated between two values reads as a
        // deliberate slide instead.
        slip = .random(in: -2.5...2.5) * strength
        flicker = .random(in: -0.02...0.04) * strength
    }
}

extension View {
    /// Strips every default List decoration so the row is drawn entirely by us.
    ///
    /// Insets are a parameter rather than a second `.listRowInsets` call —
    /// applying that modifier twice keeps the innermost value, which silently
    /// made rows full-bleed and pushed the thumbnails off the right edge.
    func plainRow(insets: EdgeInsets = EdgeInsets(),
                  background: Color = .clear) -> some View {
        listRowBackground(background)
            .listRowSeparator(.hidden)
            .listRowInsets(insets)
    }
}

// MARK: - Time bands

/// One band and the messages under it.
///
/// A struct rather than a tuple because `ForEach` needs an identity, and a key
/// path cannot reach into a tuple.
private struct BandedMessages: Identifiable {
    /// The start of the calendar day the band covers.
    let day: Date
    let messages: [Message]
    var id: Date { day }
}

/// Names a day band: Today and Yesterday by name, anything older by date.
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

    /// Built from templates rather than literal patterns, so a locale that writes
    /// the month first is respected.
    private static let dayAndMonth = formatter(template: "d MMM")
    private static let dayMonthYear = formatter(template: "d MMM y")

    private static func formatter(template: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}

/// The rule between two time bands.
///
/// Not `SectionLabel`: that one's spacing is tuned to the 12pt rows on Keys and
/// Settings, and against the feed's taller rows its 34pt gap opened a hole big
/// enough to read as the end of the list.
private struct BandHeader: View {
    let title: String
    let count: Int
    /// The page header already leaves a gap beneath itself, so the first band
    /// only needs to clear it rather than open its own.
    let isFirst: Bool

    var body: some View {
        HStack(spacing: 10) {
            // The name of the band is what the eye is looking for when it scans
            // back through the feed; the count is a footnote on it. Giving them
            // the same value made the header read as one undifferentiated
            // string, so the label steps up and the count stays where it was.
            Text(title.uppercased())
                .font(Theme.sectionLabel)
                .tracking(1.4)
                .foregroundStyle(Theme.fg)
                .lineLimit(1)
            // Not `Hairline`: a band is a bigger break than a message, so it
            // stays a step heavier than the rule between two rows. It does not
            // need four times the weight to say so — at 4pt it was a bar with
            // labels on it rather than a rule between them.
            Rectangle()
                .fill(Theme.dim)
                .frame(height: 1.5)
                .accessibilityHidden(true)
            Text("\(count)")
                .font(Theme.metaSmall)
                .foregroundStyle(Theme.dim)
                .monospacedDigit()
        }
        .padding(.top, isFirst ? Theme.firstBandTop : 26)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Copy.Inbox.bandLabel(title, Copy.Inbox.count(count)))
    }
}

// MARK: - Row

private struct MessageRow: View {
    let message: Message
    /// Passed in rather than read here — see the clock on `InboxView`.
    let now: Date
    /// False before a day marker and at the foot of the feed — see the caller.
    let showsRule: Bool

    @State private var isHovered = false
    /// Pending hover — see the `onHover` debounce below.
    @State private var hoverTask: Task<Void, Never>?

    /// Trial switch while the feed is being tuned — see the rule below.
    static let drawsRules = false

    /// Wall clock only. The band header above the row carries the date, and the
    /// relative age this used to show restated it in a form the bands already
    /// answer.
    private static let clock: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    private var basis: Date { message.occurredAt ?? message.createdAt }

    /// Unread and paged rows carry the weight and the red; everything else recedes.
    private var isEscalated: Bool { !message.isRead || message.isCritical }

    var body: some View {
        VStack(spacing: 0) {
            content
            if showsRule && Self.drawsRules { rule }
        }
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

            // Two fixed slots, always reserved, so the glyph column aligns down
            // the whole feed. Position is the label: the globe never sits in the
            // frame's slot, and an empty slot keeps its width.
            slot(present: message.link != nil, systemName: "globe")
            slot(present: message.imageURL != nil, systemName: "photo")
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
        #if os(macOS)
        // Mac only. Hover draws nothing — the row answers the cursor in type
        // alone, the same one-step lift the tab bar uses, so the screen stays
        // identical to iOS at rest.
        .animation(.easeOut(duration: 0.12), value: isHovered)
        // Taken only after the cursor has rested on the row — see the note on
        // the previous multi-line row for why the debounce exists.
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

    /// One 12pt column, filled or held empty.
    private func slot(present: Bool, systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Theme.dim)
            .opacity(present ? 1 : 0)
            .frame(width: 12)
            .accessibilityHidden(true)
    }

    /// Drawn as the last thing in the row rather than as an overlay on its edge
    /// — see the note on the band header for why.
    private var rule: some View {
        Hairline()
    }

    /// Everything the row shows, in the order it is read on screen.
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
