import Foundation

enum LocalDev {
    #if DEBUG
    static let baseURL: URL? = {
        guard let raw = ProcessInfo.processInfo.environment["NOTIFI_BASE_URL"],
              let url = URL(string: raw), url.host != nil else { return nil }
        return url
    }()
    #else
    static let baseURL: URL? = nil
    #endif

    static var isActive: Bool { baseURL != nil }
}
