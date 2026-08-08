import Foundation

struct CachedKey: Codable, Identifiable, Hashable, Sendable {
    var id: Int
    var name: String
    var prefix: String
    var sentCount: Int
    var createdAt: Int
    var lastUsedAt: Int?
    var revokedAt: Int?
    /// Optional only so that a cache written before Critical Alerts existed still
    /// decodes. A missing value means the same thing as the server's default: off.
    var isCriticalFlag: Bool?

    var isRevoked: Bool { revokedAt != nil }

    var isCritical: Bool { isCriticalFlag == true }

    /// The key notifi creates for you at registration. It is the only one whose
    /// value stays on the device, so it is the only one that can be regenerated
    /// rather than revoked-and-lost. The name is reserved at creation time, which
    /// is what makes it safe to identify one by name.
    var isDefault: Bool { name.lowercased() == "default" }

    var maskedValue: String { Copy.Keys.maskedValue(prefix) }

    var createdDate: Date { Date(timeIntervalSince1970: TimeInterval(createdAt)) }

    var lastUsedDate: Date? {
        lastUsedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}

enum KeyCacheStore {
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("notifi-keys.json")
    }

    static func load() -> [CachedKey] {
        guard let data = try? Data(contentsOf: fileURL),
              let keys = try? JSONDecoder().decode([CachedKey].self, from: data) else {
            return []
        }
        return keys
    }

    // Unlike the message store this cache is rebuilt from /keys on every refresh, so
    // it is excluded from backups. It holds each key's `prefix`, which the server
    // keeps sealed precisely so a database dump does not yield the first characters
    // of every key.
    static func save(_ keys: [CachedKey]) {
        guard let data = try? JSONEncoder().encode(keys) else { return }
        #if os(iOS)
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        #else
        try? data.write(to: fileURL, options: .atomic)
        #endif
        OnDiskProtection.excludeFromBackup(fileURL)
    }
}
