import Foundation
import OSLog

extension Logger {
    static func notifi(category: String) -> Logger {
        Logger(subsystem: Bundle.main.bundleIdentifier ?? "notifi", category: category)
    }
}
