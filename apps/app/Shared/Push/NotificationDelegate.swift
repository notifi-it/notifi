import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
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
