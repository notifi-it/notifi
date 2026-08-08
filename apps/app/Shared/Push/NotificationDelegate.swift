import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // `.list` as well as `.banner`, so a page that arrives while the app is
        // open still lands in Notification Center. Without it the banner is the
        // only copy that ever exists and it is gone in four seconds — which for
        // anything the user did not happen to be looking at is a lost alert.
        completionHandler([.banner, .list, .sound, .badge])
        Task { @MainActor in
            AppModel.shared?.handleForegroundPush()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in AppModel.shared?.notePushArrived() }

        let userInfo = response.notification.request.content.userInfo
        guard let serverID = Self.serverID(from: userInfo) else {
            completionHandler()
            return
        }

        switch response.actionIdentifier {
        case NotificationCategories.Action.markRead:
            Task { @MainActor in AppModel.perform(.markRead(serverID: serverID)) }
        case NotificationCategories.Action.openLink:
            // The link is read back out of the sealed blob rather than the row,
            // because the button has to work before the message has synced, and
            // because putting the URL in the push's userInfo would leave it sitting
            // in the notification store in the clear.
            let content = Self.content(from: userInfo)
            var link: URL?
            if let raw = content?.link { link = URL(string: raw) }
            Task { @MainActor in
                if let link {
                    AppModel.perform(.openLink(link, keyID: content?.keyID, serverID: serverID))
                } else {
                    AppModel.perform(.show(serverID: serverID))
                }
            }
        case UNNotificationDefaultActionIdentifier:
            Task { @MainActor in AppModel.perform(.show(serverID: serverID)) }
        default:
            break
        }
        completionHandler()
    }

    private static func content(from userInfo: [AnyHashable: Any]) -> MessageContent? {
        guard let notifi = userInfo["notifi"] as? [String: Any],
              let sealed = notifi["sealed"] as? String,
              let opener = try? DeviceIdentity.loadOpener(),
              let plaintext = try? opener.open(sealedB64: sealed, info: "content")
        else { return nil }
        return try? JSONDecoder().decode(MessageContent.self, from: plaintext)
    }

    private static func serverID(from userInfo: [AnyHashable: Any]) -> Int? {
        guard let notifi = userInfo["notifi"] as? [String: Any] else { return nil }
        if let id = notifi["id"] as? Int { return id }
        if let id = notifi["id"] as? NSNumber { return id.intValue }
        return nil
    }
}
