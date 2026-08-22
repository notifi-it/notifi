import Foundation

struct CachedKey: Codable, Identifiable, Hashable, Sendable {
    var id: Int
    var name: String
    var prefix: String
    var sentCount: Int
    var createdAt: Int
    var lastUsedAt: Int?
    var revokedAt: Int?
    var isCriticalFlag: Bool?

    var isRevoked: Bool { revokedAt != nil }

    var isCritical: Bool { isCriticalFlag == true }

    var isDefault: Bool { name.lowercased() == "default" }

    var maskedValue: String { Copy.Keys.maskedValue(prefix) }

    var createdDate: Date { Date(timeIntervalSince1970: TimeInterval(createdAt)) }

    var lastUsedDate: Date? {
        lastUsedAt.map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}

extension Array where Element == CachedKey {
    var mergedByName: [CachedKey] {
        var seen = Set<String>()
        return (filter { !$0.isRevoked } + filter(\.isRevoked))
            .filter { seen.insert($0.name.lowercased()).inserted }
            .map(carryingHistoryOfItsName)
    }

    private func carryingHistoryOfItsName(_ representative: CachedKey) -> CachedKey {
        let sameName = filter { $0.name.lowercased() == representative.name.lowercased() }
        guard sameName.count > 1 else { return representative }
        var merged = representative
        merged.sentCount = sameName.reduce(0) { $0 + $1.sentCount }
        merged.lastUsedAt = sameName.compactMap(\.lastUsedAt).max()
        return merged
    }

    func idsSharingName(with id: Int) -> Set<Int> {
        guard let name = first(where: { $0.id == id })?.name.lowercased() else { return [id] }
        return Set(filter { $0.name.lowercased() == name }.map(\.id))
    }

    var revokedUnderUnusedNames: [CachedKey] {
        var seen = Set(filter { !$0.isRevoked }.map { $0.name.lowercased() })
        return filter { $0.isRevoked && seen.insert($0.name.lowercased()).inserted }
            .map(carryingHistoryOfItsName)
    }
}

enum KeyCacheStore {
    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("notifi-keys.json")
    }

    static func load() -> [CachedKey] {
        guard !LocalDev.isActive,
              let data = try? Data(contentsOf: fileURL),
              let keys = try? JSONDecoder().decode([CachedKey].self, from: data) else {
            return []
        }
        return keys
    }

    static func save(_ keys: [CachedKey]) {
        guard !LocalDev.isActive else { return }
        guard let data = try? JSONEncoder().encode(keys) else { return }
        #if os(iOS)
        try? data.write(to: fileURL, options: [.atomic, .completeFileProtectionUnlessOpen])
        #else
        try? data.write(to: fileURL, options: .atomic)
        #endif
        OnDiskProtection.excludeFromBackup(fileURL)
    }
}
