import OSLog
import SwiftData
import SwiftUI

struct FeedHeader<Trailing: View, Accessory: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.modelContext) private var context
    @Query(sort: \Message.createdAt, order: .reverse) private var messages: [Message]

    var title: String = Copy.Inbox.title
    var subtitle: Text? = nil
    @Binding var filterKeyID: Int?
    var showsAccessory: Bool = false
    @ViewBuilder var trailing: () -> Trailing
    @ViewBuilder var accessory: () -> Accessory

    private var subtitleHeight: CGFloat {
        subtitle != nil || showsAccessory ? Theme.headerSubtitleHeight : 0
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(Theme.screenTitle)
                    .tracking(Theme.screenTitleTracking)
                    .foregroundStyle(Theme.fg)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(height: Theme.headerBarHeight, alignment: .leading)
                ZStack(alignment: .leading) {
                    Color.clear.frame(width: 0, height: subtitleHeight)
                    if let subtitle {
                        subtitle
                            .font(Theme.meta)
                            .foregroundColor(Theme.muted)
                            .lineLimit(1)
                    } else {
                        accessory().fixedSize()
                    }
                }
                .frame(height: subtitleHeight, alignment: .leading)
                .clipped()
            }
            Spacer(minLength: 8)
            HStack(spacing: Theme.headerActionSpacing) {
                trailing()
                overflowMenu
            }
                .frame(height: Theme.headerBarHeight)
        }
    }
    private var overflowMenu: some View {
        Menu {
            Button(Copy.Inbox.markAllAsRead, action: markAllRead)
                .disabled(unreadCount == 0)

            if filterableKeys.count > 1 {
                Divider()
                Picker(Copy.Inbox.filterByKey, selection: $filterKeyID) {
                    Text(Copy.Inbox.allKeys).tag(Int?.none)
                    ForEach(filterableKeys) { key in
                        Text(key.name).tag(Int?.some(key.id))
                    }
                }
            }

            #if os(macOS)
            Divider()
            Button(Copy.Inbox.refresh) { Task { await model.refresh() } }
                .keyboardShortcut("r", modifiers: .command)
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

    private var filterableKeys: [CachedKey] { keys.mergedByName }

    private var unreadCount: Int { messages.reduce(0) { $0 + ($1.isRead ? 0 : 1) } }

    private func markAllRead() {
        for message in messages where !message.isRead { message.isRead = true }
        Haptics.success()
        do {
            try context.save()
        } catch {
            Logger(subsystem: "it.notifi.app", category: "feed")
                .error("save failed: \(String(describing: error), privacy: .public)")
        }
        model.sync?.reconcileNotifications()
    }
}

extension FeedHeader where Trailing == EmptyView, Accessory == EmptyView {
    init(subtitle: Text? = nil, filterKeyID: Binding<Int?>) {
        self.init(subtitle: subtitle, filterKeyID: filterKeyID, trailing: { EmptyView() }, accessory: { EmptyView() })
    }
}

extension FeedHeader where Accessory == EmptyView {
    init(title: String = Copy.Inbox.title, subtitle: Text? = nil, filterKeyID: Binding<Int?>,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.init(title: title, subtitle: subtitle, filterKeyID: filterKeyID,
                  trailing: trailing, accessory: { EmptyView() })
    }
}
