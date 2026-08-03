import Foundation

/// Protection class for the files that hold decrypted content: the SwiftData
/// message store and the key-name cache.
///
/// The default class is `completeUntilFirstUserAuthentication`, so message bodies
/// the server deliberately cannot read stay readable to anything in the container
/// from first unlock onward. `completeUnlessOpen` closes that: the app declares no
/// background modes, so nothing writes while the device is locked, and a file that
/// was already open when the screen locked stays usable rather than faulting.
///
/// No-ops on macOS, which has no per-file protection classes.
enum OnDiskProtection {
    static func protect(_ url: URL) {
        #if os(iOS)
        // A protection class set on a directory becomes the default for files
        // created inside it, which is what covers the store before it first exists.
        setClass(url.deletingLastPathComponent().path)
        // SQLite keeps its write-ahead log and shared-memory file beside the store
        // and they hold the same plaintext.
        for path in [url.path, url.path + "-wal", url.path + "-shm"] {
            setClass(path)
        }
        #endif
    }

    static func excludeFromBackup(_ url: URL) {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }

    #if os(iOS)
    private static func setClass(_ path: String) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        try? FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUnlessOpen],
            ofItemAtPath: path
        )
    }
    #endif
}
