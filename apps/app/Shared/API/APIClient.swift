import CryptoKit
import Foundation

@MainActor
final class APIClient {
    let baseURL: URL
    private let identity: DeviceIdentity
    private let session: URLSession

    // Signed requests are rejected outside a 60s window. A device with a skewed clock
    // would fail every call forever, so track the server's own clock and sign with it.
    private var serverOffset: TimeInterval = 0

    // The offset is bounded because it ends up inside a signature. Left unbounded,
    // anything that can set the Date header could make this client mint validly
    // signed requests bearing a chosen future timestamp and harvest them. TLS
    // already fails on a clock this far out, so a larger reading is a tampered
    // header rather than a skewed device.
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

    func listKeys() async throws -> ListKeysResponse {
        try await performSigned { try self.signedRequest(method: "GET", path: "/keys") }
    }

    func createKey(name: String) async throws -> CreateKeyResponse {
        let data = try encode(CreateKeyBody(name: name))
        return try await performSigned {
            try self.signedRequest(method: "POST", path: "/keys", body: data)
        }
    }

    func updateKey(id: Int, isCritical: Bool) async throws {
        let data = try encode(UpdateKeyBody(isCritical: isCritical))
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

    func send(key: String, title: String, message: String?) async throws -> SendResponse {
        var components = baseComponents(path: "/send")
        var items = [URLQueryItem(name: "title", value: title)]
        if let message { items.append(URLQueryItem(name: "message", value: message)) }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        let data = try await performVoid(request)
        do {
            return try JSONDecoder().decode(SendResponse.self, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    /// The upgrade signs exactly like a `GET /history` — the canonical string
    /// covers method, host, path, timestamp and body hash, and none of those
    /// change with the scheme — so the wss URL carries a signature the ordinary
    /// verifier accepts.
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
        // The server has no locale of its own and answers in whatever this asks
        // for. Its `message` is shown to the reader as-is, so without this a
        // refused request is the one sentence in the app that is not in their
        // language. Deliberately outside the signed canonical string: it changes
        // the wording of a reply, never what the request does.
        request.setValue(Self.acceptLanguage, forHTTPHeaderField: "Accept-Language")
        return request
    }

    /// The reader's languages, best first, in the header's own q-value form.
    /// `Locale.preferredLanguages` is the OS-level order, which is what the app
    /// itself resolves its catalog against.
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

    // On a rejected timestamp the response's Date header has already corrected
    // serverOffset, so re-signing and retrying once recovers a skewed clock.
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
            // A rejected timestamp is the one failure that has to trust the server's
            // clock, because the retry re-signs against it. Every other error leaves
            // the offset alone.
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
