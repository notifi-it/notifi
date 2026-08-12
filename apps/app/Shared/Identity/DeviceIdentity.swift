import CryptoKit
import Foundation
import Security

protocol SigningIdentity {
    var publicKeyX963: Data { get }
    func sign(_ canonical: Data) throws -> Data
}

protocol SealedBoxOpener {
    var encryptionPublicKeyX963: Data { get }
    func open(sealedB64: String, info: String) throws -> Data
}

enum IdentityConstants {
    // Debug talks to the dev worker, so it keeps its identity and default key
    // under different service names. On a Mac a Debug build runs beside the
    // installed Release app in the same keychain groups; sharing these items
    // meant the Debug run's ensureDefaultKey() replaced the Release app's
    // stored default key with one minted on the dev server.
    #if DEBUG
    private static let suffix = ".debug"
    #else
    private static let suffix = ""
    #endif

    static let service = "it.notifi.identity" + suffix
    static let encryptionService = "it.notifi.encryption" + suffix
    static let defaultKeyService = "it.notifi.defaultkey" + suffix

    static let teamIdPrefix: String = {
        (Bundle.main.object(forInfoDictionaryKey: "AppIdentifierPrefix") as? String) ?? ""
    }()

    // AppIdentifierPrefix only expands when the target has a signing team. If it is
    // empty, an explicit group would not match the entitlement and every keychain
    // write would fail with errSecMissingEntitlement; nil resolves to the app's
    // default group, which is the shared group listed first in the entitlements.

    // Shared with the Notification Service Extension. It holds the encryption key
    // and nothing else.
    static var sharedAccessGroup: String? {
        teamIdPrefix.isEmpty ? nil : "\(teamIdPrefix)it.notifi.shared"
    }

    // App only — the NSE does not list this group. The signing key and the default
    // send key live here because the NSE needs neither: it parses an attacker-chosen
    // payload and downloads an attacker-chosen image, so a foothold there should
    // reach the one key required to unseal a push and no further.
    static var appAccessGroup: String? {
        teamIdPrefix.isEmpty ? nil : "\(teamIdPrefix)it.notifi.private"
    }
}

enum SigningKeyBox {
    case secureEnclave(SecureEnclave.P256.Signing.PrivateKey)
    #if targetEnvironment(simulator)
    case simulatorSoftware(P256.Signing.PrivateKey)
    #endif

    var publicKeyX963: Data {
        switch self {
        case let .secureEnclave(key):
            return key.publicKey.x963Representation
        #if targetEnvironment(simulator)
        case let .simulatorSoftware(key):
            return key.publicKey.x963Representation
        #endif
        }
    }

    func sign(_ canonical: Data) throws -> Data {
        switch self {
        case let .secureEnclave(key):
            return try key.signature(for: canonical).rawRepresentation
        #if targetEnvironment(simulator)
        case let .simulatorSoftware(key):
            return try key.signature(for: canonical).rawRepresentation
        #endif
        }
    }
}

struct EncryptionKeyOpener: SealedBoxOpener {
    let encryption: P256.KeyAgreement.PrivateKey

    var encryptionPublicKeyX963: Data { encryption.publicKey.x963Representation }

    func open(sealedB64: String, info: String) throws -> Data {
        guard let blob = Data(base64Encoded: sealedB64), blob.count > 65 else {
            throw NotifiError.badSealedBlob
        }
        var recipient = try HPKE.Recipient(
            privateKey: encryption,
            ciphersuite: .P256_SHA256_AES_GCM_256,
            info: Data(info.utf8),
            encapsulatedKey: blob.prefix(65)
        )
        return try recipient.open(blob.dropFirst(65))
    }
}

struct DeviceIdentity: SigningIdentity, SealedBoxOpener {
    let signing: SigningKeyBox
    let encryption: P256.KeyAgreement.PrivateKey

    var publicKeyX963: Data { signing.publicKeyX963 }
    var encryptionPublicKeyX963: Data { encryption.publicKey.x963Representation }

    func sign(_ canonical: Data) throws -> Data {
        try signing.sign(canonical)
    }

    func open(sealedB64: String, info: String) throws -> Data {
        try EncryptionKeyOpener(encryption: encryption).open(sealedB64: sealedB64, info: info)
    }

    static func loadOrCreate() throws -> DeviceIdentity {
        if let existing = try load(returnNilIfMissing: true) {
            return existing
        }

        let signing = try createSigningKey()
        let encryption = P256.KeyAgreement.PrivateKey()
        try storeEncryptionKey(encryption)
        return DeviceIdentity(signing: signing, encryption: encryption)
    }

    static func load() throws -> DeviceIdentity {
        guard let identity = try load(returnNilIfMissing: true) else {
            throw NotifiError.identityMissing
        }
        return identity
    }

    static func loadOpener() throws -> SealedBoxOpener {
        guard let data = try keychainGet(service: encryptionService, accessGroup: sharedGroup) else {
            throw NotifiError.identityMissing
        }
        let encryption = try P256.KeyAgreement.PrivateKey(rawRepresentation: data)
        return EncryptionKeyOpener(encryption: encryption)
    }

    private static var service: String { IdentityConstants.service }
    private static var encryptionService: String { IdentityConstants.encryptionService }
    private static var sharedGroup: String? { IdentityConstants.sharedAccessGroup }
    private static var appGroup: String? { IdentityConstants.appAccessGroup }

    private static func load(returnNilIfMissing: Bool) throws -> DeviceIdentity? {
        guard let signingData = try loadMigrating(service: service) else {
            return nil
        }
        guard let encryptionData = try keychainGet(service: encryptionService, accessGroup: sharedGroup) else {
            return nil
        }

        let encryption = try P256.KeyAgreement.PrivateKey(rawRepresentation: encryptionData)

        #if targetEnvironment(simulator)
        let signing: SigningKeyBox
        if let seKey = try? SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: signingData) {
            signing = .secureEnclave(seKey)
        } else {
            let softwareKey = try P256.Signing.PrivateKey(rawRepresentation: signingData)
            signing = .simulatorSoftware(softwareKey)
        }
        #else
        let seKey = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: signingData)
        let signing = SigningKeyBox.secureEnclave(seKey)
        #endif

        return DeviceIdentity(signing: signing, encryption: encryption)
    }

    private static func createSigningKey() throws -> SigningKeyBox {
        #if targetEnvironment(simulator)
        if SecureEnclave.isAvailable {
            let key = try makeSecureEnclaveKey()
            try storePrivately(service: service, data: key.dataRepresentation)
            return .secureEnclave(key)
        }
        let key = P256.Signing.PrivateKey()
        try storePrivately(service: service, data: key.rawRepresentation)
        return .simulatorSoftware(key)
        #else
        guard SecureEnclave.isAvailable else {
            throw NotifiError.unsupportedDevice
        }
        let key = try makeSecureEnclaveKey()
        try storePrivately(service: service, data: key.dataRepresentation)
        return .secureEnclave(key)
        #endif
    }

    private static func makeSecureEnclaveKey() throws -> SecureEnclave.P256.Signing.PrivateKey {
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            .privateKeyUsage,
            &error
        ) else {
            throw NotifiError.keychain(errSecParam)
        }
        return try SecureEnclave.P256.Signing.PrivateKey(accessControl: access)
    }

    private static func storeEncryptionKey(_ key: P256.KeyAgreement.PrivateKey) throws {
        try keychainSet(service: encryptionService, accessGroup: sharedGroup, data: key.rawRepresentation)
    }
}

extension DeviceIdentity {
    static func storeDefaultKey(_ value: String) {
        try? storePrivately(service: IdentityConstants.defaultKeyService, data: Data(value.utf8))
    }

    static func loadDefaultKey() -> String? {
        guard let data = (try? loadMigrating(service: IdentityConstants.defaultKeyService)) ?? nil else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

// Not private: RemoteImages stores its flag through keychainSet/keychainGet too.
extension DeviceIdentity {
    // Writes to the app-only group. A build whose provisioning profile does not
    // carry that group answers errSecMissingEntitlement; losing the isolation is
    // bad, but failing to store an identity at all is worse, so that one status
    // falls back to the shared group. Every other failure still throws.
    static func storePrivately(service: String, data: Data) throws {
        do {
            try keychainSet(service: service, accessGroup: appGroup, data: data)
        } catch NotifiError.keychain(errSecMissingEntitlement) {
            guard appGroup != sharedGroup else {
                throw NotifiError.keychain(errSecMissingEntitlement)
            }
            try keychainSet(service: service, accessGroup: sharedGroup, data: data)
        }
    }

    // Items written before the group split sit in the shared group. Move them on
    // first read, and keep using the copy that is already there if the move fails.
    //
    // The app-group read is deliberately non-throwing: a missing entitlement reads
    // as an error rather than as "not found", and that must fall through to the
    // shared group instead of failing the whole identity load. The shared-group read
    // still throws, so AppModel can keep telling a transient keychain failure apart
    // from a genuinely absent identity.
    static func loadMigrating(service: String) throws -> Data? {
        if let data = (try? keychainGet(service: service, accessGroup: appGroup)) ?? nil {
            return data
        }
        guard appGroup != sharedGroup,
              let legacy = try keychainGet(service: service, accessGroup: sharedGroup) else {
            return nil
        }
        if (try? keychainSet(service: service, accessGroup: appGroup, data: legacy)) != nil {
            keychainDelete(service: service, accessGroup: sharedGroup)
        }
        return legacy
    }

    static func keychainDelete(service: String, accessGroup: String?) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }
        _ = SecItemDelete(query as CFDictionary)
    }

    // Add first, and only update on an explicit duplicate. Deleting up front would
    // destroy a live identity whenever a read had failed for a transient reason.
    static func keychainSet(service: String, accessGroup: String?, data: Data) throws {
        var addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: data,
        ]
        if let accessGroup { addQuery[kSecAttrAccessGroup as String] = accessGroup }

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status == errSecSuccess { return }
        guard status == errSecDuplicateItem else { throw NotifiError.keychain(status) }

        var updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
        ]
        if let accessGroup { updateQuery[kSecAttrAccessGroup as String] = accessGroup }

        let updateStatus = SecItemUpdate(
            updateQuery as CFDictionary,
            [kSecValueData as String: data] as CFDictionary
        )
        guard updateStatus == errSecSuccess else { throw NotifiError.keychain(updateStatus) }
    }

    static func keychainGet(service: String, accessGroup: String?) throws -> Data? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecUseDataProtectionKeychain as String: true,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if let accessGroup { query[kSecAttrAccessGroup as String] = accessGroup }

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw NotifiError.keychain(status) }
        return result as? Data
    }
}
