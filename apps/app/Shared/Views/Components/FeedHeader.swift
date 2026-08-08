import OSLog
import SwiftData
import SwiftUI

/// The "NOTIFICATIONS" title block and its count line.
///
/// Extracted so the search tab wears the same one as the Inbox. Search shows
/// the same feed, so arriving at a screen that starts straight into rows read
/// as having lost the app's chrome rather than as having entered a mode.
///
/// Built here rather than with `GeistHeader` because "Notifications" is a long
/// word: beside a count it wrapped mid-word, so the title and its count stack
/// while the controls sit on the title's line.
struct FeedHeader<Trailing: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    /// Concatenated `Text` rather than a string so the unread count alone can
    /// take the brand colour.
    let subtitle: Text
    /// The key filter the overflow menu drives. Search passes a constant: the
    /// menu still offers every action the Inbox's does, because the header is
    /// the same header, but a query is not a place to be quietly narrowing the
    /// feed by key as well.
    @Binding var filterKeyID: Int?
    /// Anything that goes to the *left* of the overflow menu. Only the Mac uses
    /// it, for its search button; the menu itself is not a slot, because the
    /// point of this type is that both screens get the same one.
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(Copy.Inbox.title.uppercased())
                    .font(Theme.screenTitle)
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: Theme.headerBarHeight, alignment: .leading)
                subtitle
                    .font(Theme.meta)
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            // See `GeistHeader`: the discs draw at 34 and were clipped by a
            // hard 30 on the other two tabs as well.
            HStack(spacing: 8) {
                trailing()
                overflowMenu
            }
                .frame(minHeight: Theme.headerBarHeight)
        }
    }
    private var overflowMenu: some View {
        Menu {
            Button(Copy.Inbox.markAllAsRead, action: markAllRead)
                .disabled(unreadCount == 0)

            if keys.count > 1 {
                Divider()
                Picker(Copy.Inbox.filterByKey, selection: $filterKeyID) {
                    Text(Copy.Inbox.allKeys).tag(Int?.none)
                    ForEach(keys) { key in
                        Text(key.name).tag(Int?.some(key.id))
                    }
                }
            }

            // Keys and Settings are tabs on both platforms now, so listing them
            // here too would be a second door to the same room. What the Mac does
            // still need is a refresh: pull-to-refresh is a touch gesture and does
            // not exist here.
            #if os(macOS)
            Divider()
            Button(Copy.Inbox.refresh) { Task { await model.refresh() } }
                .keyboardShortcut("r", modifiers: .command)
            // A menu bar app has no Dock icon and no app menu, so without this
            // the only ways out are Activity Monitor or knowing ⌘Q works blind.
            Button(Copy.Common.quit) { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q", modifiers: .command)
            #endif

            #if DEBUG
            if SampleData.isEnabled {
                Divider()
                Button(Copy.Inbox.seedSampleData) {
                    SampleData.seed(into: context, keyIDs: keys.map(\.id))
                }
                Button(Copy.Inbox.clearSampleData, role: .destructive) {
                    SampleData.clear(from: context)
                }
            }
            #endif
        } label: {
            // Deliberately the same body as `IconButton(glass: true)`, which is
            // what sits next to it. A Menu draws its own pill around whatever
            // label it is given unless the style and the button style below
            // both stand down, and the two controls stopped matching.
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(filterKeyID == nil ? Theme.fg : Theme.brand)
                .frame(width: 34, height: 34)
                .glassBackground(enabled: true)
                .contentShape(Circle())
                .geistHitArea(expandedBy: 5)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .accessibilityLabel(Copy.Inbox.more)
    }

    private var keys: [CachedKey] { model.sync?.keys ?? [] }

    private var unreadCount: Int { messages.reduce(0) { $0 + ($1.isRead ? 0 : 1) } }

    private func markAllRead() {
        for message in messages where !message.isRead { message.isRead = true }
        do {
            try context.save()
        } catch {
            Logger(subsystem: "it.notifi.app", category: "feed")
                .error("save failed: \(String(describing: error), privacy: .public)")
        }
        model.sync?.reconcileNotifications()
    }
}

extension FeedHeader where Trailing == EmptyView {
    init(subtitle: Text, filterKeyID: Binding<Int?>) {
        self.init(subtitle: subtitle, filterKeyID: filterKeyID) { EmptyView() }
    }
}
