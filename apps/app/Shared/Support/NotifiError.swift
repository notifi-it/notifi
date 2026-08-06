import Foundation

enum NotifiError: Error {
    case unsupportedDevice
    case identityMissing
    case badSealedBlob
    case keychain(OSStatus)
    /// The OS will not grant Critical Alerts at all — the entitlement is absent.
    /// Distinct from the user having turned them off, which is recoverable from
    /// system settings and does not stop a key's standing being recorded.
    case criticalAlertsUnavailable
}

enum APIError: Error {
    case http(status: Int, code: String?, message: String?)
    case transport(Error)
    case decoding
    case invalidResponse
}

extension APIError {
    var userMessage: String {
        switch self {
        // The server's own `message` is written for a reader and is used as-is.
        // `code` is not — it is a machine token like `key_revoked`, and printing
        // it told the reader what had gone wrong only if they already knew.
        // Everything below it says what to do next instead.
        case let .http(status, _, message):
            if let message, !message.isEmpty { return message }
            switch status {
            case 401, 403: return "This key is no longer accepted. Create a new one under Keys."
            case 404: return "That is no longer on the server. Refresh and try again."
            case 429: return "Too many requests just now. Try again in a moment."
            case 500...599: return "The server is having trouble. Try again in a moment."
            default: return "The request didn't go through. Try again."
            }
        case .transport:
            return "Couldn't reach the server. Check your connection and try again."
        case .decoding, .invalidResponse:
            return "The server returned something unexpected. Try again in a moment."
        }
    }
}
