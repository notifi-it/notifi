#if os(macOS)
import Sparkle
import SwiftUI

@MainActor
@Observable
final class Updater {
    static let shared = Updater()

    private let controller: SPUStandardUpdaterController
    private(set) var canCheck = false

    private(set) var automaticallyChecks = false
    private(set) var automaticallyInstalls = false

    private init() {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        if UserDefaults.standard.object(forKey: "SUAutomaticallyUpdate") == nil {
            controller.updater.automaticallyDownloadsUpdates = true
        }
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        automaticallyInstalls = controller.updater.automaticallyDownloadsUpdates
        observation = controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
            Task { @MainActor in self?.canCheck = updater.canCheckForUpdates }
        }
    }

    private var observation: NSKeyValueObservation?

    func setAutomaticallyChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        automaticallyChecks = enabled
        if !enabled {
            setAutomaticallyInstalls(false)
        }
    }

    func setAutomaticallyInstalls(_ enabled: Bool) {
        controller.updater.automaticallyDownloadsUpdates = enabled
        automaticallyInstalls = controller.updater.automaticallyDownloadsUpdates
    }

    func refresh() {
        automaticallyChecks = controller.updater.automaticallyChecksForUpdates
        automaticallyInstalls = controller.updater.automaticallyDownloadsUpdates
    }

    var lastCheck: Date? { controller.updater.lastUpdateCheckDate }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }
}
#endif
