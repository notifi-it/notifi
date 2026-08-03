import Foundation

struct RegisterDeviceBody: Codable, Sendable {
    let publicKey: String
    let encryptionPublicKey: String
    let apnsToken: String
    let platform: String
    let appVersion: String

    enum CodingKeys: String, CodingKey {
        case publicKey = "public_key"
        case encryptionPublicKey = "encryption_public_key"
        case apnsToken = "apns_token"
        case platform
        case appVersion = "app_version"
    }
}

struct RegisterDeviceResponse: Codable, Sendable {
    let deviceID: Int

    enum CodingKeys: String, CodingKey {
        case deviceID = "device_id"
    }
}

struct KeySummary: Codable, Sendable {
    let id: Int
    let metaSealed: String
    let createdAt: Int
    let lastUsedAt: Int?
    let sentCount: Int
    let revokedAt: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case metaSealed = "meta_sealed"
        case createdAt = "created_at"
        case lastUsedAt = "last_used_at"
        case sentCount = "sent_count"
        case revokedAt = "revoked_at"
    }
}

struct ListKeysResponse: Codable, Sendable {
    let keys: [KeySummary]
}

struct CreateKeyBody: Codable, Sendable {
    let name: String
}

struct CreateKeyResponse: Codable, Sendable {
    let id: Int
    let name: String
    let key: String
}

struct HistoryMessage: Codable, Sendable {
    let id: Int
    let contentSealed: String
    let keyID: Int?
    let createdAt: Int
    /// Client-supplied event time in unix milliseconds. Display only.
    let occurredAt: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case contentSealed = "content_sealed"
        case keyID = "key_id"
        case createdAt = "created_at"
        case occurredAt = "occurred_at"
    }
}

struct HistoryResponse: Codable, Sendable {
    let messages: [HistoryMessage]
    let latestID: Int?

    enum CodingKeys: String, CodingKey {
        case messages
        case latestID = "latest_id"
    }
}

struct SendResponse: Codable, Sendable {
    let ok: Bool
}

struct MessageContent: Codable, Sendable {
    let title: String
    let message: String?
    let link: String?
    let image: String?
    let keyID: Int?
    let createdAt: Int
    /// Client-supplied event time in unix milliseconds, sealed alongside the rest
    /// so it can be checked against the row the same way `createdAt` is.
    let occurredAt: Int?

    enum CodingKeys: String, CodingKey {
        case title
        case message
        case link
        case image
        case keyID = "key_id"
        case createdAt = "created_at"
        case occurredAt = "occurred_at"
    }
}

struct KeyMeta: Codable, Sendable {
    let id: Int
    let name: String
    let prefix: String
}

struct APIErrorEnvelope: Codable, Sendable {
    struct Body: Codable, Sendable {
        let code: String
        let message: String
    }
    let error: Body
}
