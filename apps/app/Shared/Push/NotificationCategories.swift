import Foundation
import UserNotifications

enum NotificationCategories {
    static let message = "notifi.message"
    static let messageWithLink = "notifi.message.link"

    enum Action {
        static let openLink = "notifi.action.open-link"
        static let markRead = "notifi.action.mark-read"
    }

    struct SummaryKey {
        let id: Int
        let name: String
    }

    private static func summaryCategories(for key: SummaryKey) -> [UNNotificationCategory] {
        let name = key.name.replacingOccurrences(of: "%", with: "%%")
        return [
            UNNotificationCategory(
                identifier: categoryID(keyID: key.id, hasLink: false),
                actions: [markReadAction],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: nil,
                categorySummaryFormat: Copy.Push.summaryFormat(name),
                options: []
            ),
            UNNotificationCategory(
                identifier: categoryID(keyID: key.id, hasLink: true),
                actions: [openLinkAction, markReadAction],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: nil,
                categorySummaryFormat: Copy.Push.summaryFormat(name),
                options: []
            ),
        ]
    }

    static func categoryID(keyID: Int?, hasLink: Bool) -> String {
        guard let keyID, KnownKeys.ids.contains(keyID) else {
            return hasLink ? messageWithLink : message
        }
        return hasLink ? "notifi.message.key.\(keyID).link" : "notifi.message.key.\(keyID)"
    }

    static func register(keys: [SummaryKey] = [], on center: UNUserNotificationCenter = .current()) {
        let plain = UNNotificationCategory(
            identifier: message,
            actions: [markReadAction],
            intentIdentifiers: [],
            options: []
        )
        let withLink = UNNotificationCategory(
            identifier: messageWithLink,
            actions: [openLinkAction, markReadAction],
            intentIdentifiers: [],
            options: []
        )

        var all: Set<UNNotificationCategory> = [plain, withLink]
        for key in keys { all.formUnion(summaryCategories(for: key)) }
        center.setNotificationCategories(all)
        KnownKeys.ids = Set(keys.map(\.id))
    }

    private static var openLinkAction: UNNotificationAction {
        UNNotificationAction(
            identifier: Action.openLink,
            title: Copy.Push.actionOpenLink,
            options: [.foreground]
        )
    }

    private static var markReadAction: UNNotificationAction {
        UNNotificationAction(identifier: Action.markRead, title: Copy.Push.actionMarkAsRead, options: [])
    }
}

enum KnownKeys {
    private static let service = "it.notifi.pushcategories"

    static var ids: Set<Int> {
        get {
            let stored = try? DeviceIdentity.keychainGet(
                service: service,
                accessGroup: IdentityConstants.sharedAccessGroup
            )
            guard let data = stored ?? nil,
                  let ids = try? JSONDecoder().decode([Int].self, from: data) else {
                return []
            }
            return Set(ids)
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue.sorted()) else { return }
            try? DeviceIdentity.keychainSet(
                service: service,
                accessGroup: IdentityConstants.sharedAccessGroup,
                data: data
            )
        }
    }
}
