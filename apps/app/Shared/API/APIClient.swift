import CryptoKit
import Foundation

@MainActor
final class APIClient {
    let baseURL: URL
    private let identity: DeviceIdentity
    private let session: URLSession

    private var serverOffset: TimeInterval = 0

    private static let maxClockOffset: TimeInterval = 24 * 60 * 60

    private static let httpDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss 'GMT'"
        return formatter
    }()

    init(baseURL: URL, identity: DeviceIdentity, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.identity = identity
        self.session = session
    }

    func registerDevice(_ body: RegisterDeviceBody) async throws -> RegisterDeviceResponse {
        let data = try encode(body)
        return try await performSigned {
            try self.signedRequest(method: "POST", path: "/devices", body: data)
        }
    }

    func updateDeviceSettings(strictSend: Bool) async throws {
        let data = try encode(UpdateDeviceSettingsBody(strictSend: strictSend))
        _ = try await performSignedVoid {
            try self.signedRequest(method: "PATCH", path: "/devices/settings", body: data)
        }
    }

    func listKeys() async throws -> ListKeysResponse {
        try await performSigned { try self.signedRequest(method: "GET", path: "/keys") }
    }

    func createKey(name: String) async throws -> CreateKeyResponse {
        let data = try encode(CreateKeyBody(name: name))
        return try await performSigned {
            try self.signedRequest(method: "POST", path: "/keys", body: data)
        }
    }

    func updateKey(
        id: Int,
        isCritical: Bool? = nil,
        paused: Bool? = nil,
        metaSealed: String? = nil
    ) async throws {
        let data = try encode(
            UpdateKeyBody(isCritical: isCritical, paused: paused, metaSealed: metaSealed))
        _ = try await performSignedVoid {
            try self.signedRequest(method: "PATCH", path: "/keys/\(id)", body: data)
        }
    }

    func revokeKey(id: Int) async throws {
        _ = try await performSignedVoid {
            try self.signedRequest(method: "DELETE", path: "/keys/\(id)")
        }
    }

    func history(since: Int, limit: Int) async throws -> HistoryResponse {
        let items = [
            URLQueryItem(name: "since", value: String(since)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        return try await performSigned {
            try self.signedRequest(method: "GET", path: "/history", queryItems: items)
        }
    }

    func send(
        key: String,
        title: String,
        message: String?,
        link: String? = nil,
        image: String? = nil
    ) async throws -> SendResponse {
        struct Body: Encodable {
            let title: String
            let message: String?
            let link: String?
            let image: String?
        }
        let body = try encode(Body(title: title, message: message, link: link, image: image))

        var request = URLRequest(url: baseComponents(path: "/send").url!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let data = try await performVoid(request)
        do {
            return try JSONDecoder().decode(SendResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    func socketRequest() throws -> URLRequest {
        var request = try signedRequest(method: "GET", path: "/socket")
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "http" ? "ws" : "wss"
        request.url = components.url
        return request
    }

    private func signedRequest(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil
    ) throws -> URLRequest {
        var components = baseComponents(path: path)
        if !queryItems.isEmpty { components.queryItems = queryItems }

        let pathWithQuery = components.percentEncodedPath
            + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
        let host: String = {
            if let port = components.port {
                return "\(components.host!):\(port)".lowercased()
            }
            return components.host!.lowercased()
        }()
        let timestamp = Int(Date().addingTimeInterval(serverOffset).timeIntervalSince1970)
        let bodyHash = SHA256.hash(data: body ?? Data())
            .map { String(format: "%02x", $0) }
            .joined()
        let canonical = Data("\(method)\n\(host)\n\(pathWithQuery)\n\(timestamp)\n\(bodyHash)".utf8)

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.httpBody = body
        request.setValue(identity.publicKeyX963.base64EncodedString(),
                         forHTTPHeaderField: "X-Notifi-Public-Key")
        request.setValue(String(timestamp), forHTTPHeaderField: "X-Notifi-Timestamp")
        request.setValue(try identity.sign(canonical).base64EncodedString(),
                         forHTTPHeaderField: "X-Notifi-Signature")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        request.setValue(Self.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        return request
    }

    private static let acceptLanguage: String = {
        let languages = Locale.preferredLanguages.prefix(5)
        guard !languages.isEmpty else { return "en" }
        return languages.enumerated()
            .map { index, tag in
                index == 0 ? tag : "\(tag);q=\(String(format: "%.1f", 1.0 - Double(index) * 0.1))"
            }
            .joined(separator: ", ")
    }()

    private func baseComponents(path: String) -> URLComponents {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        return components
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func performSigned<T: Decodable>(_ build: () throws -> URLRequest) async throws -> T {
        let data = try await performSignedVoid(build)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    @discardableResult
    private func performSignedVoid(_ build: () throws -> URLRequest) async throws -> Data {
        do {
            return try await performVoid(try build())
        } catch let APIError.http(status, code, message) {
            guard status == 401, code == "stale_timestamp" else {
                throw APIError.http(status: status, code: code, message: message)
            }
            return try await performVoid(try build())
        }
    }

    @discardableResult
    private func performVoid(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            let envelope = try? JSONDecoder().decode(APIErrorEnvelope.self, from: data)
            if envelope?.error.code == "stale_timestamp" { adoptServerClock(http) }
            throw APIError.http(
                status: http.statusCode,
                code: envelope?.error.code,
                message: envelope?.error.message
            )
        }
        adoptServerClock(http)
        return data
    }

    private func adoptServerClock(_ http: HTTPURLResponse) {
        guard let dateHeader = http.value(forHTTPHeaderField: "Date"),
              let serverDate = Self.httpDateFormatter.date(from: dateHeader) else { return }
        let offset = serverDate.timeIntervalSince(Date())
        guard abs(offset) <= Self.maxClockOffset else { return }
        serverOffset = offset
    }
}
