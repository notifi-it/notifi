import Foundation

enum RemoteImages {
    private static let service = "it.notifi.remoteimages"

    static var isEnabled: Bool {
        let stored = try? DeviceIdentity.keychainGet(
            service: service,
            accessGroup: IdentityConstants.sharedAccessGroup
        )
        guard let data = stored ?? nil, let value = String(data: data, encoding: .utf8) else {
            return true
        }
        return value != "0"
    }

    static func setEnabled(_ enabled: Bool) {
        try? DeviceIdentity.keychainSet(
            service: service,
            accessGroup: IdentityConstants.sharedAccessGroup,
            data: Data((enabled ? "1" : "0").utf8)
        )
    }
}
