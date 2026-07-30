import Foundation

#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum PushRegistrar {
    @MainActor
    static func registerForRemoteNotifications() {
        #if os(iOS)
        UIApplication.shared.registerForRemoteNotifications()
        #else
        NSApplication.shared.registerForRemoteNotifications()
        #endif
    }
}
