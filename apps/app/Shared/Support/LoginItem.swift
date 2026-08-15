#if os(macOS)
import ServiceManagement
import SwiftUI

@MainActor
@Observable
final class LoginItem {
    static let shared = LoginItem()

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
        }
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}
#endif
