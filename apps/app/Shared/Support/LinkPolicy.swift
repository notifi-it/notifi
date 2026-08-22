import Foundation

enum LinkPolicy {
    static let defaultsKey = "keysAllowingAnyLink"

    static func allows(_ url: URL, anyScheme: Bool) -> Bool {
        anyScheme || url.scheme?.lowercased() == "https"
    }

    @MainActor static func allowedKeyIDs() -> Set<Int> {
        Set(LocalDev.defaults.array(forKey: defaultsKey) as? [Int] ?? [])
    }

    @MainActor static func store(_ keyIDs: Set<Int>) {
        LocalDev.defaults.set(keyIDs.sorted(), forKey: defaultsKey)
    }

    @MainActor static func allows(_ url: URL, keyID: Int?) -> Bool {
        guard let keyID else { return allows(url, anyScheme: false) }
        return allows(url, anyScheme: allowedKeyIDs().contains(keyID))
    }
}
