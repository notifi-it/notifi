import Foundation

enum OnDiskProtection {
    static func protect(_ url: URL) {
        #if os(iOS)
        setClass(url.deletingLastPathComponent().path)
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
