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
        case let .http(status, code, message):
            if let message, !message.isEmpty { return message }
            if let code { return code }
            return "Request failed (\(status))."
        case .transport:
            return "Couldn't reach the server."
        case .decoding, .invalidResponse:
            return "The server returned something unexpected."
        }
    }
}
