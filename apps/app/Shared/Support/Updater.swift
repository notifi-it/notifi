#if os(macOS)
import Sparkle
import SwiftUI

@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    private let controller: SPUStandardUpdaterController
    private(set) var canCheck = false

    /// Mirrors Sparkle's `automaticallyChecksForUpdates` as observed state.
    /// Read straight off the controller in `body`, the toggle held whatever
    /// value the screen was built with — and Sparkle flips the preference
    /// itself (its first-run permission prompt does), so the row could sit
    /// showing the answer the user did not give. Same shape as `LoginItem`.
    private(set) var automaticallyChecks = false

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor in self?.canCheck = updater.canCheckForUpdates }
        }
    }

    private var observation: NSKeyValueObservation?

    func setAutomaticallyChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecks = enabled
    }

    func refresh() {
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
    }

    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
#endif
