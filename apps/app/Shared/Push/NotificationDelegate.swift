import Foundation
import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound, .badge])
        Task { @MainActor in
            AppModel.shared?.handleForegroundPush()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let serverID = Self.serverID(from: response.notification.request.content.userInfo)
        Task { @MainActor in
            if let serverID {
                AppModel.shared?.handleTap(serverID: serverID)
            }
        }
        completionHandler()
    }

    private static func serverID(from userInfo: [AnyHashable: Any]) -> Int? {
        guard let notifi = userInfo["notifi"] as? [String: Any] else { return nil }
        if let id = notifi["id"] as? Int { return id }
        if let id = notifi["id"] as? NSNumber { return id.intValue }
        return nil
    }
}
