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

    var body: some View {
        List {
            if messages.isEmpty {
                empty().plainRow()
            } else {
                // Bound once: it is a computed property, and reading it inside the
                // loop as well would band the whole feed again on every row.
                let banded = bands
                ForEach(banded) { band in
                    BandHeader(title: band.band.title(now: now),
                               count: band.messages.count,
                               isFirst: band.id == banded.first?.id)
                        .geistGutter()
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

    /// The feed, cut into time bands in the order they are shown.
    ///
    /// Banded on `occurredAt ?? createdAt` — what the row's own age is measured
    /// from — rather than on the sort key. A sender that backdates an event would
    /// otherwise land a row reading "3 d" under a heading saying Today. The two
    /// differ rarely enough that a band's members stay in the query's order, so
    /// nothing is re-sorted inside a band.
    private var bands: [BandedMessages] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let week = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? today
        let month = calendar.dateInterval(of: .month, for: now)?.start ?? today

        var order: [TimeBand] = []
        var bucketed: [TimeBand: [Message]] = [:]
        for message in messages {
            let basis = message.occurredAt ?? message.createdAt
            let band: TimeBand
            // `>= today` rather than `isDateInToday`, so an event stamped a little
            // ahead of the clock — the send API allows some skew — files under
            // Today instead of dropping into whichever band happens to catch it.
            if basis >= today {
                band = .today
            } else if basis >= yesterday {
                band = .yesterday
            } else if basis >= week {
                band = .thisWeek
            } else if basis >= month {
                band = .thisMonth
            } else {
                band = .month(calendar.dateInterval(of: .month, for: basis)?.start ?? basis)
            }
            if bucketed[band] == nil { order.append(band) }
            bucketed[band, default: []].append(message)
        }
        return order
            .sorted(by: TimeBand.precedes)
            .map { BandedMessages(band: $0, messages: bucketed[$0] ?? []) }
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
    let band: TimeBand
    let messages: [Message]
    var id: TimeBand { band }
}

/// Where a message sits in the feed's time structure.
///
/// Ranked rather than ordered by date. A week that began in the previous month
/// starts before that month does, so sorting the bands by their own start would
/// file "Earlier This Week" underneath "Earlier This Month" on the first days of
/// a month — which is where a reader is most likely to be looking.
private enum TimeBand: Hashable {
    case today
    case yesterday
    case thisWeek
    case thisMonth
    /// Anything older, one band per calendar month, carrying that month's start.
    case month(Date)

    private var rank: Int {
        switch self {
        case .today: 0
        case .yesterday: 1
        case .thisWeek: 2
        case .thisMonth: 3
        case .month: 4
        }
    }

    static func precedes(_ a: TimeBand, _ b: TimeBand) -> Bool {
        guard a.rank == b.rank else { return a.rank < b.rank }
        if case .month(let x) = a, case .month(let y) = b { return x > y }
        return false
    }

    /// "Earlier This Week" rather than "This Week": Today and Yesterday are their
    /// own bands above it, so a heading claiming the whole week would be lying
    /// about what is under it.
    func title(now: Date) -> String {
        switch self {
        case .today: Copy.Inbox.bandToday
        case .yesterday: Copy.Inbox.bandYesterday
        case .thisWeek: Copy.Inbox.bandEarlierThisWeek
        case .thisMonth: Copy.Inbox.bandEarlierThisMonth
        case .month(let start):
            Calendar.current.isDate(start, equalTo: now, toGranularity: .year)
                ? Self.monthName.string(from: start)
                : Self.monthAndYear.string(from: start)
        }
    }

    /// Built from templates rather than literal patterns, so a locale that writes
    /// the year first, or names its months differently, is respected.
    private static let monthName = formatter(template: "MMMM")
    private static let monthAndYear = formatter(template: "MMMM y")

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

/// The widest the stamp column can get, drawn hidden to reserve that width.
///
/// Reserving the width rather than measuring the string that happens to be
/// there is what keeps the column still while an age ticks from "now" to
/// "22 min".
private struct StampTemplate: View {
    var body: some View {
        Text("00 min")
            .font(Theme.metaUnread)
            .monospacedDigit()
            .accessibilityHidden(true)
    }
}

private struct MessageRow: View {
    let message: Message
    /// Passed in rather than read here — see the clock on `InboxView`.
    let now: Date
    /// False before a day marker and at the foot of the feed — see the caller.
    let showsRule: Bool

    @State private var isHovered = false

    /// Drops the stamp column so its capitals start level with the title's.
    ///
    /// `.top` lines the two frames up, not the two rows of type. A frame carries
    /// the gap between the font's ascent and its capitals, and that gap grows
    /// with point size: measured off Inconsolata it is 4.01pt at the title's 17
    /// and 2.83pt at the stamp's 12, so the smaller text starts 1.18pt high.
    /// Scaled rather than fixed, because both sizes move under Dynamic Type and
    /// the difference between them moves with them.
    @ScaledMetric(relativeTo: .headline) private var capHeightOffset: CGFloat = 1.18

    /// Trial switch while the feed is being tuned — see the rule below.
    static let drawsRules = false

    private var basis: Date { message.occurredAt ?? message.createdAt }

    private var relative: String {
        let seconds = max(0, Int(now.timeIntervalSince(basis)))
        switch seconds {
        case ..<60: return Copy.Age.now
        case ..<3_600: return Copy.Age.minutes("\(seconds / 60)")
        case ..<86_400: return Copy.Age.hours("\(seconds / 3_600)")
        case ..<604_800: return Copy.Age.days("\(seconds / 86_400)")
        default: return Copy.Age.weeks("\(seconds / 604_800)")
        }
    }

    /// `PROD-DEPLOY · ↗ GITHUB.COM`, or nothing.
    ///
    /// Both markers are optional and most rows carry neither, so the line is
    /// dropped rather than drawn as a stray separator — a message with no link
    /// and no image ends on its own text.
    ///
    /// The key that sent the message is not on it. A row is scanned for what
    /// happened, and the name of the key was the widest thing on the line while
    /// answering a question the reader was not asking at that point; the detail
    /// screen names it, and the Keys tab is where a key is looked up.
    private var meta: Text? {
        var line: Text?
        if message.link != nil {
            // An SF Symbol rather than U+2197. The arrow was whatever the text
            // face happened to draw at that codepoint — a different weight and
            // baseline in each of the two faces this line can be set in, and a
            // missing-glyph box in any face that has no arrow there at all. A
            // symbol is drawn from the label's own metrics, so it sits on the
            // line and takes the same colour by construction.
            //
            // The same globe the detail screen's toolbar opens a link with, so
            // the mark that says a message has somewhere to go and the button
            // that goes there are the same object seen twice.
            //
            // The host itself is not written out here. A row is scanned for
            // whether there is anywhere to go, not for where — and the domain
            // was the longest thing on the line, taking the width that the
            // message's own text wanted. The detail screen names it, which is
            // where the question is actually asked.
            let link = Text(Image(systemName: "globe")).foregroundStyle(Theme.mark)
            line = line.map { $0 + Text(" ") + link } ?? link
        }
        // A symbol rather than the picture itself. Drawing the thumbnail here
        // would fetch it from the sender's host for every row on screen, which
        // is the request the detail screen deliberately holds back until the
        // reader asks for it — the feed would be leaking the device's IP to
        // every sender at once just by being scrolled past.
        if message.imageURL != nil {
            let marker = Text(Image(systemName: "photo")).foregroundStyle(Theme.mark)
            line = line.map { $0 + Text(" ") + marker } ?? marker
        }
        return line
    }

    var body: some View {
        VStack(spacing: 0) {
            content
            if showsRule && Self.drawsRules { rule }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenDescription)
    }

    /// An urgent message is set in red rather than flagged with a mark beside it.
    /// A third glyph did not fit the clock's column without pushing that one row
    /// across, and colouring the words says the same thing without asking for any
    /// width at all.
    ///
    /// It stays red once read. Whether a page sounded through silent mode is a
    /// fact about what happened, not a state that clears when you look at it.
    private var titleColour: Color {
        if message.isCritical { return Theme.brandText }
        return message.isRead ? Theme.read : Theme.fg
    }

    private var titleText: Text {
        Text(message.title).foregroundColor(titleColour)
    }

    private var content: some View {
        HStack(alignment: .top, spacing: Theme.rowGap) {
            // The marks sit under the clock rather than under the title, in the
            // column the row is already scanned down. They say what a message
            // has rather than what it says, which is the same kind of fact as
            // its age — and it leaves the message column as nothing but words.
            VStack(alignment: .trailing, spacing: 6) {
                stamp
                marks
            }
            .alignmentGuide(.top) { $0[.top] }
            VStack(alignment: .leading, spacing: 3) {
                titleText
                    .font(message.isRead ? Theme.title : Theme.titleUnread)
                    // Capped so one long title cannot take the screen. A pager's
                    // feed is scanned, and a message whose whole point is in its
                    // title has said it by the third line; the detail screen sets
                    // it in full.
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                // Under the title rather than on its line. Sharing the line saved
                // a row of height but put two glyphs on the far side of a gap
                // from the thing they belong to, so they read as chrome pinned to
                // the edge instead of as part of the message.

                if let body = message.body {
                    // The row is two lines: markers are stripped and inline styling
                    // kept, so a bulleted body previews as prose rather than dashes.
                    // A size below the body face the detail screen sets it in.
                    // `dim` is already the most receded colour the palette has —
                    // anything further is under the contrast floor — so the
                    // preview steps back by scale rather than by going dimmer.
                    // Red too, a step below the title's. The hierarchy inside an
                    // urgent row is carried by scale, the same way it is in every
                    // other row — `dim` would have said "ordinary" underneath a
                    // title saying the opposite.
                    Text(MarkdownPreview.text(body))
                        .font(.karla(.footnote))
                        .foregroundStyle(message.isCritical ? Theme.brandDim : Theme.dim)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

            }
            Spacer(minLength: 0)
        }
        // 16 rather than 13. With a rule between rows as well, the tighter value
        // put the line close enough to the key name to read as an underline on
        // it; the extra 3pt is what tells the two apart.
        .padding(.vertical, 16)
        #if os(macOS)
        // Mac only. Each message is its own block, told apart from the screen by
        // its own grain sitting a step off the ground rather than by a border —
        // the texture is already on both sides of the edge, so a line around it
        // said a second time what the change in level already says. On iOS the
        // feed keeps its rules: a block per row on a full-height screen is a
        // stack of cards, which this is not.
        .padding(.horizontal, 14)
        .background(
            StaticField(level: isHovered ? .hover : .raised, fillsScreen: false)
                // Clipped rather than drawn into a shape: the tile is a repeating
                // image, and the corner has to cut the texture rather than the
                // texture reflow to fit the corner.
                .clipShape(RoundedRectangle(cornerRadius: Theme.blockRadius,
                                            style: .continuous))
        )
        // Only the ground moves. Nothing shifts position, because a row that
        // lifts or grows under the pointer drags the rows below it and the whole
        // feed twitches on a mouse crossing it.
        .animation(.easeOut(duration: 0.12), value: isHovered)
        .onHover { isHovered = $0 }
        #endif
        // Carried here rather than applied by the feed, so the rule below can run
        // off the trailing edge while the message stays inside the margin.
        .geistGutter()
        #if os(macOS)
        // The blocks are their own separation, so the gap between two of them is
        // the only thing saying where one ends.
        .padding(.vertical, 4)
        #endif
    }

    /// How long ago the message arrived.
    ///
    /// The wall clock underneath this was dropped: a pager is scanned for how
    /// long something has gone unanswered, and the band headers already say
    /// which day a row belongs to, so the second stamp was restating the first
    /// in a form nobody was reading it in.
    ///
    /// Ranged right, against the message rather than against the margin. "5 min"
    /// and "17 min" are different lengths, so aligning left left the column's
    /// inner edge ragged where it meets the text it belongs to.
    @ViewBuilder
    private var marks: some View {
        if meta != nil {
            // Held to the clock's own width by the same hidden template the clock
            // is sized from. Left to size themselves, three marks were wider than
            // the widest timestamp and pushed that one row's whole column across
            // — and the straight left edge the stamp exists to hold is worth more
            // than any of the marks in it.
            ZStack(alignment: .trailing) {
                StampTemplate().hidden()
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                // Outside the `Text` the rest of this line is built from, because
                // an image asset inside one draws at its own size and ignores the
                // font — the akar star arrived at 24pt on an 11pt line. Sized
                // here, and put back on the baseline by guide, since an image
                // carries no baseline of its own.
                    if let meta {
                        meta
                            .font(Theme.meta)
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
            }
        }
    }

    private var stamp: some View {
        ZStack(alignment: .topTrailing) {
            StampTemplate().hidden()
            Text(relative)
                .font(message.isRead ? Theme.meta : Theme.metaUnread)
                .foregroundStyle(message.isRead ? Theme.dim : Theme.brandText)
        }
        .monospacedDigit()
        .alignmentGuide(.top) { $0[.top] - capHeightOffset }
        .padding(.top, capHeightOffset)
    }

    /// Drawn as the last thing in the row rather than as an overlay on its edge.
    ///
    /// On the edge it landed exactly on the boundary between two cells, and the
    /// list rounded it onto one side or the other depending on where the row
    /// happened to fall — so the separators appeared under some messages and not
    /// others, with nothing about those messages in common.
    private var rule: some View {
        // Full width, under the stamp column as well as the message. Inset to
        // where the text starts it drew a second vertical edge down the feed,
        // one the column had already established and drawn better.
        Hairline()
    }

    /// Everything the row shows, in the order it is read on screen.
    ///
    /// Overriding the label at all discards what `children: .combine` gathered,
    /// so the previous one-line version silently dropped the body preview and the
    /// age — on a pager, the two things you scan the feed for. Rebuilt here
    /// rather than removing the override, because the combined default reads the
    /// title and the preview as one run-on sentence and never says "unread".
    private var spokenDescription: String {
        var parts: [String] = []
        if !message.isRead { parts.append(Copy.Inbox.unread) }
        // Spoken rather than left to the star's own image name, which VoiceOver
        // reads as the file — a description of the glyph instead of what it is
        // being used to say.
        if message.isCritical { parts.append(Copy.Inbox.critical) }
        parts.append(message.title)
        if let body = message.body {
            parts.append(MarkdownPreview.text(body))
        }
        if let link = message.link, let host = link.host() {
            parts.append("Link to \(host)")
        }
        if message.imageURL != nil { parts.append("Has an image") }
        parts.append(relative == "now" ? "just now" : "\(relative) ago")
        return parts.joined(separator: ", ")
    }
}

