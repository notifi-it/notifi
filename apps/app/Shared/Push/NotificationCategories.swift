import Foundation
import UserNotifications

/// The buttons a delivered notification carries, and the identifiers both sides
/// of the delivery agree on.
///
/// Categories are registered by the app and only *named* by the notification
/// service extension, so this file is compiled into both. The extension picks the
/// link variant only when the message carries an https link: it cannot read the
/// per-key allow-list `LinkPolicy` keeps in the app's UserDefaults — no app group
/// — so the strictest rule, the one that holds for a key nobody has opted in, is
/// the only one it can honour. A link that rule rejects is still openable from the
/// message screen, where the key and its allowance are both known.
enum NotificationCategories {
    static let message = "notifi.message"
    static let messageWithLink = "notifi.message.link"

    enum Action {
        static let openLink = "notifi.action.open-link"
        static let markRead = "notifi.action.mark-read"
    }

    /// A key the app can name in a stacked notification's summary.
    struct SummaryKey {
        let id: Int
        let name: String
    }

    /// The server already stacks pushes per key with `thread-id`, so a quiet key
    /// collapses into "3 more notifications" — true, and useless on a lock screen
    /// carrying four keys. The count reads "3 more from Deploy" instead.
    ///
    /// It has to be a category per key, because the name is only knowable here: the
    /// extension has `key_id` and nothing else, and the name it would need is sealed
    /// in the key meta the server cannot open either. Registering a category per key
    /// puts the name in the format string at registration time, where it is known.
    private static func summaryCategories(for key: SummaryKey) -> [UNNotificationCategory] {
        // The name goes into a format string, and key names are user-chosen: an
        // unescaped "%" in "50% off" would consume the count as its own argument.
        let name = key.name.replacingOccurrences(of: "%", with: "%%")
        return [
            UNNotificationCategory(
                identifier: categoryID(keyID: key.id, hasLink: false),
                actions: [markReadAction],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: nil,
                categorySummaryFormat: "%u more from \(name)",
                options: []
            ),
            UNNotificationCategory(
                identifier: categoryID(keyID: key.id, hasLink: true),
                actions: [openLinkAction, markReadAction],
                intentIdentifiers: [],
                hiddenPreviewsBodyPlaceholder: nil,
                categorySummaryFormat: "%u more from \(name)",
                options: []
            ),
        ]
    }

    /// Which category a push should carry. The extension asks this; the app answers
    /// it by having registered the matching category first.
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

        // The set replaces the previous one wholesale, so a key that has gone away
        // takes its categories with it — and the record below is rewritten to match
        // in the same breath, which is what keeps the extension from naming one of
        // them afterwards.
        var all: Set<UNNotificationCategory> = [plain, withLink]
        for key in keys { all.formUnion(summaryCategories(for: key)) }
        center.setNotificationCategories(all)
        KnownKeys.ids = Set(keys.map(\.id))
    }

    private static var openLinkAction: UNNotificationAction {
        UNNotificationAction(
            identifier: Action.openLink,
            title: "Open link",
            // Foreground because handing a URL to the OS is the app's job, and a
            // process launched only to service a background action is not reliably
            // allowed to do it. A tap that does not reach the browser has failed.
            options: [.foreground]
        )
    }

    private static var markReadAction: UNNotificationAction {
        UNNotificationAction(identifier: Action.markRead, title: "Mark as read", options: [])
    }
}

/// The keys the app has registered a per-key category for.
///
/// The extension can only *name* a category. Naming one the app never registered
/// costs the notification its buttons entirely, so the extension has to be able to
/// tell — and it cannot see the key cache, which lives in the app's Application
/// Support directory. The ids go in the shared keychain group for the same reason
/// `RemoteImages` puts its flag there: the two targets share a keychain group and
/// no app group.
///
/// Ids only. The names are baked into the categories at registration and never
/// need to leave the app.
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
