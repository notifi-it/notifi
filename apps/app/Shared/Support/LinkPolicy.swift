import Foundation

/// Whether a URL that arrived inside a message may be handed to the OS.
///
/// `link` and `image` are written by whoever holds a send key, and the server
/// accepts any scheme in `link`. That matters because `UIApplication.open` and
/// `NSWorkspace.open` will launch `shortcuts:`, `prefs:` or `file:` from a single
/// tap, and the inbox row shows only `url.host()` — so the scheme a tap is about
/// to act on is never on screen.
///
/// The allowance is per key, not per device, because that is the granularity trust
/// actually has: a key wired to your own deploy script is not the same sender as a
/// key pasted into a third-party webhook. Every key starts at https-only and is
/// opted in one at a time. A message whose key has since been revoked and swept
/// carries no key id, so it falls back to the strict rule.
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

    /// For the backstop guards, which run outside any view and so cannot read the
    /// observed copy of the allow-list.
    static func allows(_ url: URL, keyID: Int?) -> Bool {
        guard let keyID else { return allows(url, anyScheme: false) }
        return allows(url, anyScheme: allowedKeyIDs().contains(keyID))
    }
}
