import CryptoKit
import Foundation

@MainActor
final class APIClient {
    let baseURL: URL
    private let identity: DeviceIdentity
    private let session: URLSession

    init(baseURL: URL, identity: DeviceIdentity, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.identity = identity
        self.session = session
    }

    func registerDevice(_ body: RegisterDeviceBody) async throws -> RegisterDeviceResponse {
        let data = try encode(body)
        let request = try signedRequest(method: "POST", path: "/devices", body: data)
        return try await perform(request)
    }

    func listKeys() async throws -> ListKeysResponse {
        let request = try signedRequest(method: "GET", path: "/keys")
        return try await perform(request)
    }

    func createKey(name: String) async throws -> CreateKeyResponse {
        let data = try encode(CreateKeyBody(name: name))
        let request = try signedRequest(method: "POST", path: "/keys", body: data)
        return try await perform(request)
    }

    func revokeKey(id: Int) async throws {
        let request = try signedRequest(method: "DELETE", path: "/keys/\(id)")
        _ = try await performVoid(request)
    }

    func history(since: Int, limit: Int) async throws -> HistoryResponse {
        let items = [
            URLQueryItem(name: "since", value: String(since)),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        let request = try signedRequest(method: "GET", path: "/history", queryItems: items)
        return try await perform(request)
    }

    func send(key: String, title: String, message: String?) async throws -> SendResponse {
        var components = baseComponents(path: "/send")
        var items = [URLQueryItem(name: "title", value: title)]
        if let message { items.append(URLQueryItem(name: "message", value: message)) }
        components.queryItems = items

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        return try await perform(request)
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
        let timestamp = Int(Date().timeIntervalSince1970)
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
        return request
    }

    private func baseComponents(path: String) -> URLComponents {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = path
        return components
    }

    private func encode<T: Encodable>(_ value: T) throws -> Data {
        try JSONEncoder().encode(value)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await performVoid(request)
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding
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
            throw APIError.http(
                status: http.statusCode,
                code: envelope?.error.code,
                message: envelope?.error.message
            )
        }
        return data
    }
}
