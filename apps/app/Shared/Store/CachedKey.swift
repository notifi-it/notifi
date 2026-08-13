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

/// A key's name is the only thing about it a reader can recognise — the value is
/// shown once and the prefix is four characters — so two rows saying the same
/// name are two rows they cannot tell apart. Regenerating the default mints a
/// replacement under the same name and retires the predecessor, and a revoked key
/// stays in `/keys`, so that pair is the common case rather than a corner one.
///
/// Collapsing them is only safe where the survivor still reaches everything the
/// entries it hid covered, which is why these are two helpers rather than one:
/// the Inbox filter can merge fully because `idsSharingName(with:)` widens the
/// match back out, while the Keys tab must keep every live key on screen because
/// each one is separately revocable and a hidden one could never be turned off.
extension Array where Element == CachedKey {
    /// One entry per name, preferring a key that still works.
    var mergedByName: [CachedKey] {
        var seen = Set<String>()
        // Live keys are offered the name first; within each group the server's
        // newest-first order stands, so a name with no live key left is
        // represented by the most recently retired one.
        return (filter { !$0.isRevoked } + filter(\.isRevoked))
            .filter { seen.insert($0.name.lowercased()).inserted }
            .map(carryingHistoryOfItsName)
    }

    /// The representative carrying the whole name's usage: sends summed and the
    /// most recent use taken across every key that has answered to the name.
    ///
    /// Merging the rows without this would destroy the count it hid. A
    /// regenerated key starts at zero, so a "default" that has delivered
    /// hundreds would read "0 sent, never used" the moment its predecessor
    /// stopped being listed — and the real figure would be on no screen at all.
    ///
    /// Prefix, creation date and revoked state stay the representative's own:
    /// those describe the key actually in use, which is the one a reader would
    /// go on to revoke or send with. Only the usage figures belong to the name.
    private func carryingHistoryOfItsName(_ representative: CachedKey) -> CachedKey {
        let sameName = filter { $0.name.lowercased() == representative.name.lowercased() }
        guard sameName.count > 1 else { return representative }
        var merged = representative
        merged.sentCount = sameName.reduce(0) { $0 + $1.sentCount }
        merged.lastUsedAt = sameName.compactMap(\.lastUsedAt).max()
        return merged
    }

    /// Every key id sharing this one's name. A filter chosen from `mergedByName`
    /// has to match these rather than the single id it was set from: messages
    /// delivered by the previous default key carry that key's id, and matching
    /// only the survivor would quietly drop them from a filter named after both.
    func idsSharingName(with id: Int) -> Set<Int> {
        guard let name = first(where: { $0.id == id })?.name.lowercased() else { return [id] }
        return Set(filter { $0.name.lowercased() == name }.map(\.id))
    }

    /// Revoked keys whose name is not already spoken for. Seeding the set with
    /// the live names is what makes a regenerated key hide its predecessor
    /// instead of sitting above a "revoked" row for a name that plainly works.
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
