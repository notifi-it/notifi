import Foundation
import OSLog
import UserNotifications

private let delegateLog = Logger(subsystem: "it.notifi.app", category: "delegate")
private let notificationDelegate = NotificationDelegate()

#if os(iOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        application.registerForRemoteNotifications()
        UITabBar.appearance().unselectedItemTintColor = UIColor.secondaryLabel
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            AppModel.shared?.didReceiveDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        delegateLog.error("remote registration failed: \(String(describing: error), privacy: .public)")
    }
}

#else
import AppKit
import SwiftData

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NSApplication.shared.registerForRemoteNotifications()

        menuBar.configure(model: macAppModel, container: macContainer)
        macAppModel.bootstrap(context: macContainer.mainContext)
        Task {
            await macAppModel.refreshPermission()
            await macAppModel.refresh()
        }
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            AppModel.shared?.didReceiveDeviceToken(deviceToken)
        }
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        delegateLog.error("remote registration failed: \(String(describing: error), privacy: .public)")
    }
}
#endif
