import Foundation

enum NotifiError: Error {
    case unsupportedDevice
    case identityMissing
    case badSealedBlob
    case keychain(OSStatus)
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
            case 401, 403: return Copy.ClientErrors.unauthorized
            case 404: return Copy.ClientErrors.notFound
            case 429: return Copy.ClientErrors.rateLimited
            case 500...599: return Copy.ClientErrors.server
            default: return Copy.ClientErrors.generic
            }
        case .transport:
            return Copy.ClientErrors.transport
        case .decoding, .invalidResponse:
            return Copy.ClientErrors.decoding
        }
    }
}
