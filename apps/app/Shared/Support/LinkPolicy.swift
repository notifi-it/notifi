import Foundation

enum LinkPolicy {
    static let defaultsKey = "keysAllowingAnyLink"

    static func allows(_ url: URL, anyScheme: Bool) -> Bool {
        anyScheme || url.scheme?.lowercased() == "https"
    }

    static func allowedKeyIDs() -> Set<Int> {
        Set(UserDefaults.standard.array(forKey: defaultsKey) as? [Int] ?? [])
    }

    static func store(_ keyIDs: Set<Int>) {
        UserDefaults.standard.set(keyIDs.sorted(), forKey: defaultsKey)
    }

    static func allows(_ url: URL, keyID: Int?) -> Bool {
        guard let keyID else { return allows(url, anyScheme: false) }
        return allows(url, anyScheme: allowedKeyIDs().contains(keyID))
    }
}
