import Foundation

enum LocalDev {
    #if DEBUG
    static let baseURL: URL? = {
        guard let raw = ProcessInfo.processInfo.environment["NOTIFI_BASE_URL"],
              let url = URL(string: raw), url.host != nil else { return nil }
        return url
    }()

    private static let suiteName = "it.notifi.localdev"

    @MainActor static let defaults: UserDefaults = {
        guard isActive, let suite = UserDefaults(suiteName: suiteName) else { return .standard }
        suite.removePersistentDomain(forName: suiteName)
        return suite
    }()
    #else
    static let baseURL: URL? = nil
    @MainActor static let defaults: UserDefaults = .standard
    #endif

    static var isActive: Bool { baseURL != nil }
}
