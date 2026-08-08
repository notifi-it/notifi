import Foundation
import OSLog
import UserNotifications

private let delegateLog = Logger(subsystem: "it.notifi.notifi", category: "delegate")
private let notificationDelegate = NotificationDelegate()

#if os(iOS)
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        // From the cache rather than the network: the categories have to exist
        // before the first push of the session lands, and /keys has not answered
        // yet. `refreshKeys` re-registers with whatever it learns.
        NotificationCategories.register(keys: SyncEngine.summaryKeys(KeyCacheStore.load()))
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set in code as well as LSUIElement: the policy decides whether this is a
        // Dock app or a menu bar accessory, and leaving it to the plist alone left
        // the process with no owned UI at the moment macOS decides whether to keep
        // it. The status item itself is created from `NotifiApp.init()`.
        NSApp.setActivationPolicy(.accessory)

        // Touching the singleton is what applies the open-at-login default on
        // first launch; left to Settings alone it would only ever happen for
        // people who opened that tab.
        _ = LoginItem.shared

        UNUserNotificationCenter.current().delegate = notificationDelegate
        // From the cache rather than the network: the categories have to exist
        // before the first push of the session lands, and /keys has not answered
        // yet. `refreshKeys` re-registers with whatever it learns.
        NotificationCategories.register(keys: SyncEngine.summaryKeys(KeyCacheStore.load()))
        NSApplication.shared.registerForRemoteNotifications()

        macAppModel.bootstrap(context: macContainer.mainContext)
        Task {
            await macAppModel.refreshPermission()
            await macAppModel.refresh()
        }

        // The Mac process is always running, so the fallback runs for the whole
        // session rather than only while the popover is open — the menu bar dot
        // is supposed to be right whether or not anyone is looking at it.
        macAppModel.startLiveUpdates()
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
