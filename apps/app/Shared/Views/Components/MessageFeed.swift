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

                    ForEach(band.messages, id: \.serverID) { message in
                        row(for: message)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.bg)
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
            pendingDelete.map { "Delete \u{201C}\($0.title)\u{201D}?" } ?? "Delete this notification?",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { message in
            Button("Delete", role: .destructive) {
                delete(message)
                pendingDelete = nil
            }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("This cannot be undone.")
        }
        #if os(iOS)
        // Pull-to-refresh is a touch gesture. The Mac refreshes with ⌘R and the
        // overflow menu instead.
        .refreshable { await model.refresh() }
        #endif
    }

    @ViewBuilder
    private func row(for message: Message) -> some View {
        Button {
            model.path.append(message.serverID)
        } label: {
            // The gutter is inside the button and the shape is explicit, so the
            // whole row answers a tap. With the padding outside, the 20pt
            // margins were dead, and without the shape the gaps between title,
            // time and thumbnail were too: a stack only hit-tests where it
            // actually drew something.
            MessageRow(
                message: message,
                allowAnyScheme: model.allowsAnyLink(keyID: message.keyID),
                now: now
            )
            .geistGutter()
            .contentShape(Rectangle())
        }
        .buttonStyle(.geistRow)
        // The row's content carries the gutter, the rule does not, so the
        // message stays inside the margin while the line between messages runs
        // edge to edge.
        .overlay(alignment: .bottom) { Hairline() }
        // Unread sits one step off the ground. The dot alone made the state a
        // thing you find rather than a thing you see, which on a screen whose
        // whole job is "what have I not read" is the wrong way round.
        .plainRow(background: message.isRead ? Theme.bg : Theme.surface)
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
                        message.isRead ? "Mark as unread" : "Mark as read")
            }
            .tint(Theme.chip)
        }
        .swipeActions(edge: .trailing) {
            // The tint has to be explicit. `role: .destructive` would normally
            // colour this red, but the TabView's near-white tint cascades down
            // and wins, giving white-on-white. Asks first: a swipe is easy to
            // do by accident and the message cannot be recovered afterwards.
            Button(role: .destructive) { pendingDelete = message } label: {
                Image(systemName: "trash")
                    .accessibilityLabel("Delete")
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
        Button(message.isRead ? "Mark as unread" : "Mark as read") { toggleRead(message) }
        Divider()
        Button("Copy title") { Clipboard.copy(message.title) }
        if let body = message.body {
            Button("Copy message") { Clipboard.copy(body) }
        }
        if let link = message.link {
            Button("Copy link") { Clipboard.copy(link.absoluteString) }
            if LinkPolicy.allows(link, anyScheme: model.allowsAnyLink(keyID: message.keyID)) {
                Button("Open link") { open(link, keyID: message.keyID) }
            }
        }
        Divider()
        Button("Delete", role: .destructive) { pendingDelete = message }
    }

    // MARK: Actions

    private func toggleRead(_ message: Message) {
        message.isRead.toggle()
        save()
        model.sync?.updateBadge()
    }

    private func delete(_ message: Message) {
        context.delete(message)
        save()
        model.sync?.updateBadge()
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

extension View {
    /// Strips every default List decoration so the row is drawn entirely by us.
    ///
    /// Insets are a parameter rather than a second `.listRowInsets` call —
    /// applying that modifier twice keeps the innermost value, which silently
    /// made rows full-bleed and pushed the thumbnails off the right edge.
    func plainRow(insets: EdgeInsets = EdgeInsets(),
                  background: Color = Theme.bg) -> some View {
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
        case .today: "Today"
        case .yesterday: "Yesterday"
        case .thisWeek: "Earlier This Week"
        case .thisMonth: "Earlier This Month"
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
            Text(title.uppercased())
                .font(Theme.sectionLabel)
                .tracking(1.4)
                .foregroundStyle(Theme.dim)
                .lineLimit(1)
            Hairline()
            Text("\(count)")
                .font(Theme.metaSmall)
                .foregroundStyle(Theme.dim)
                .monospacedDigit()
        }
        .padding(.top, isFirst ? 2 : 26)
        .padding(.bottom, 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(count == 1 ? "\(title), 1 notification"
                                       : "\(title), \(count) notifications")
    }
}

// MARK: - Row

private struct MessageRow: View {
    let message: Message
    let allowAnyScheme: Bool
    /// Passed in rather than read here — see the clock on `MessageFeed`.
    let now: Date

    private var relative: String {
        let basis = message.occurredAt ?? message.createdAt
        let seconds = max(0, Int(now.timeIntervalSince(basis)))
        switch seconds {
        case ..<60: return "now"
        case ..<3_600: return "\(seconds / 60) min"
        case ..<86_400: return "\(seconds / 3_600) hr"
        case ..<604_800: return "\(seconds / 86_400) d"
        default: return "\(seconds / 604_800) w"
        }
    }

    var body: some View {
        // Unread is carried by the row's ground and the title's weight, so the
        // text starts at the gutter like every other screen rather than being
        // indented past a marker column.
        HStack(alignment: .firstTextBaseline, spacing: Theme.rowGap) {
            VStack(alignment: .leading, spacing: 5) {
                Text(message.title)
                    .font(message.isRead ? Theme.title : Theme.titleUnread)
                    .foregroundStyle(message.isRead ? Theme.read : Theme.fg)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.leading)

                if let body = message.body {
                    // The row is two lines: markers are stripped and inline styling
                    // kept, so a bulleted body previews as prose rather than dashes.
                    Text(MarkdownPreview.text(body))
                        .font(Theme.body)
                        .foregroundStyle(Theme.dim)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }

                if let link = message.link {
                    Chip(text: link.host() ?? link.absoluteString, trailingGlyph: "↗")
                        .padding(.top, 5)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 2) {
                // Relative time only. The exact stamp is a fixed 18 characters, so
                // it set the width of this column and squeezed titles into extra
                // lines to buy a precision the feed never needed. The detail page
                // carries the full date, down to the millisecond.
                // Smaller and quieter than the body it sits beside: the age is a
                // coordinate, and at `meta`/`muted` it was the brightest thing in
                // the row after the title.
                Text(relative)
                    .font(Theme.metaSmall)
                    .foregroundStyle(Theme.dim)
                if let url = message.imageURL,
                   LinkPolicy.allows(url, anyScheme: allowAnyScheme) {
                    Thumbnail(url: url).padding(.top, 8)
                }
            }
            .monospacedDigit()
        }
        .padding(.vertical, 15)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(spokenDescription)
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
        if !message.isRead { parts.append("Unread") }
        parts.append(message.title)
        if let body = message.body {
            parts.append(String(MarkdownPreview.text(body).characters))
        }
        if let link = message.link, let host = link.host() {
            parts.append("Link to \(host)")
        }
        parts.append(relative == "now" ? "just now" : "\(relative) ago")
        return parts.joined(separator: ", ")
    }
}

/// Reserves its slot while loading and marks failure rather than collapsing, so
/// the list never reflows as images arrive.
///
/// Scrolling the feed would otherwise fetch every image in it, so with automatic
/// loading off this draws a placeholder and makes no request. The image is still
/// one tap away in the detail view.
private struct Thumbnail: View {
    @Environment(AppModel.self) private var model
    let url: URL

    var body: some View {
        Group {
            if model.remoteImagesEnabled {
                remote
            } else {
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.surface)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.dim)
                    )
            }
        }
        .frame(width: Theme.thumb, height: Theme.thumb)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radius))
        .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.chip, lineWidth: 1))
        .accessibilityHidden(true)
    }

    private var remote: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFill()
            case .failure:
                RoundedRectangle(cornerRadius: Theme.radius)
                    .strokeBorder(Theme.chip, style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(Theme.dim)
                    )
            default:
                RoundedRectangle(cornerRadius: Theme.radius).fill(Theme.surface)
            }
        }
    }
}
