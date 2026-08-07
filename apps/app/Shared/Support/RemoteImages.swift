import Foundation

/// Whether an image URL carried by a message may be fetched from its host.
///
/// The host is chosen by whoever sent the message, so every fetch hands that
/// sender the device's IP address and the moment the message arrived. It is on
/// until the user turns it off; the toggle in Settings says what it discloses.
///
/// The value lives in the shared keychain group rather than UserDefaults because
/// the notification extension has to read it before it downloads an attachment,
/// and the extension shares a keychain group with the app but no app group.
enum RemoteImages {
    private static let service = "it.notifi.remoteimages"

    static var isEnabled: Bool {
        let stored = try? DeviceIdentity.keychainGet(
            service: service,
            accessGroup: IdentityConstants.sharedAccessGroup
        )
        // Nothing stored means the user has never touched the toggle, which is
        // the default-on case; only an explicit "0" turns fetching off.
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
