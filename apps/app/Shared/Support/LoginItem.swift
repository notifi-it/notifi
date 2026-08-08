#if os(macOS)
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class LoginItem {
    static let shared = LoginItem()

    // A pager that only runs when someone remembers to start it is not a
    // pager, so the app registers itself the first time it ever launches. The
    // flag records that the default has been applied once; after that the
    // choice belongs to the user, whether they made it here or in System
    // Settings, and relaunching must not re-apply it over them.
    private static let appliedDefaultKey = "loginItemDefaultApplied"

    private(set) var opensAtLogin: Bool

    private init() {
        if !UserDefaults.standard.bool(forKey: Self.appliedDefaultKey) {
            try? SMAppService.mainApp.register()
            UserDefaults.standard.set(true, forKey: Self.appliedDefaultKey)
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    func setOpensAtLogin(_ on: Bool) {
        do {
            if on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Fall through to re-reading the status: the toggle must show what
            // the system actually holds, not what was asked of it.
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    // System Settings can flip this behind the app's back, so the value is
    // re-read whenever the Settings tab comes on screen.
    func refresh() {
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}
#endif
