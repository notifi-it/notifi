import CryptoKit
import Foundation
import OSLog
import SwiftData
import SwiftUI
import UserNotifications

#if os(iOS)
import UIKit
#else
import AppKit
#endif

enum BootState {
    case loading
    case unsupported
    case unavailable
    case needsRestoreAck
    case ready
}

/// Pages the macOS popover pushes on top of the inbox.
enum AppRoute: Hashable {
    case settings
}

enum AppTab: Hashable {
    case inbox
    case keys
    case settings
}

@MainActor
@Observable
final class AppModel {
    static private(set) var shared: AppModel?

    var bootState: BootState = .loading
    var path = NavigationPath()
    var selectedTab: AppTab = .inbox
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    var badgeEnabled: Bool {
        didSet { UserDefaults.standard.set(badgeEnabled, forKey: "badgeEnabled") }
    }
    var presentingCreateKey = false

    private(set) var identity: DeviceIdentity?
    private(set) var api: APIClient?
    private(set) var sync: SyncEngine?

    var hasUnread: Bool { (sync?.unread ?? 0) > 0 }

    private var context: ModelContext?
    private var pendingToken: String?
    private var registrationChain: Task<Void, Never>?
    private var lastRegisteredToken: String?
    private let log = Logger(subsystem: "it.notifi.app", category: "app")

    private static let realTokenKey = "lastRealAPNSToken"

    init() {
        badgeEnabled = UserDefaults.standard.object(forKey: "badgeEnabled") as? Bool ?? true
    }

    var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: raw), url.host != nil {
            return url
        }
        return URL(string: "https://notifi.it")!
    }

    func bootstrap(context: ModelContext) {
        guard bootState == .loading || bootState == .unavailable else { return }
        self.context = context
        AppModel.shared = self
        bootState = .loading

        #if !targetEnvironment(simulator)
        guard SecureEnclave.isAvailable else {
            bootState = .unsupported
            return
        }
        #endif

        do {
            finishBoot(with: try DeviceIdentity.load())
            return
        } catch NotifiError.identityMissing {
            // No identity yet — fall through and create one.
        } catch {
            // A transient keychain failure (locked data protection, -34018) must not be
            // mistaken for "this device cannot run notifi", and must never fall through
            // to createIdentity(), which would overwrite a live identity.
            log.error("identity load failed: \(String(describing: error), privacy: .public)")
            bootState = .unavailable
            return
        }

        if messagesExist() {
            bootState = .needsRestoreAck
            return
        }

        createIdentity()
    }

    func retryBootstrap() {
        guard let context else { return }
        bootState = .unavailable
        bootstrap(context: context)
    }

    func acknowledgeRestore() {
        createIdentity()
    }

    private func createIdentity() {
        do {
            let identity = try DeviceIdentity.loadOrCreate()
            finishBoot(with: identity)
        } catch NotifiError.unsupportedDevice {
            bootState = .unsupported
        } catch {
            log.error("identity creation failed: \(String(describing: error), privacy: .public)")
            bootState = .unavailable
        }
    }

    private func finishBoot(with identity: DeviceIdentity) {
        guard let context else { return }
        self.identity = identity
        let api = APIClient(baseURL: baseURL, identity: identity)
        self.api = api
        self.sync = SyncEngine(api: api, identity: identity, context: context)
        bootState = .ready

        let token = pendingToken
        pendingToken = nil

        Task {
            await enqueueRegistration(token: token).value
            await refreshPermission()
            await sync?.sync()
            await sync?.refreshKeys()
            await ensureDefaultKey()
        }
    }

    private func ensureDefaultKey() async {
        guard let api, let sync else { return }
        // Only act on an authoritative key list. If the refresh failed, sync.keys may be
        // empty simply because we could not reach the server, and creating a key here
        // would mint a duplicate "default" and orphan the previous secret.
        guard !sync.keysRefreshFailed else { return }
        if sync.keys.contains(where: { $0.name.lowercased() == "default" && $0.revokedAt == nil }) {
            return
        }
        do {
            let created = try await api.createKey(name: "default")
            DeviceIdentity.storeDefaultKey(created.key)
            await sync.refreshKeys()
        } catch {
            log.error("default key creation failed: \(String(describing: error), privacy: .public)")
        }
    }

    var defaultKeyValue: String? { DeviceIdentity.loadDefaultKey() }

    private func messagesExist() -> Bool {
        guard let context else { return false }
        let count = (try? context.fetchCount(FetchDescriptor<Message>())) ?? 0
        return count > 0
    }

    func didReceiveDeviceToken(_ tokenData: Data) {
        let hex = tokenData.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: Self.realTokenKey)
        guard bootState == .ready else {
            pendingToken = hex
            return
        }
        enqueueRegistration(token: hex)
    }

    // Registrations are chained so that a placeholder registration issued at boot can
    // never land after — and overwrite — the real APNs token on the server.
    @discardableResult
    private func enqueueRegistration(token: String?) -> Task<Void, Never> {
        let previous = registrationChain
        let task = Task { @MainActor in
            await previous?.value
            await self.registerDevice(token: token)
        }
        registrationChain = task
        return task
    }

    private func registerDevice(token: String?) async {
        guard let api, let identity else { return }
        if let token { UserDefaults.standard.set(token, forKey: Self.realTokenKey) }
        let knownReal = token ?? UserDefaults.standard.string(forKey: Self.realTokenKey)
        let apnsToken = knownReal ?? Self.syntheticToken(for: identity)
        guard apnsToken != lastRegisteredToken else { return }
        let body = RegisterDeviceBody(
            publicKey: identity.publicKeyX963.base64EncodedString(),
            encryptionPublicKey: identity.encryptionPublicKeyX963.base64EncodedString(),
            apnsToken: apnsToken,
            platform: Self.platformName,
            appVersion: Self.appVersion
        )
        do {
            _ = try await api.registerDevice(body)
            lastRegisteredToken = apnsToken
        } catch {
            log.error("device registration failed: \(String(describing: error), privacy: .public)")
        }
    }

    private static func syntheticToken(for identity: DeviceIdentity) -> String {
        SHA256.hash(data: identity.publicKeyX963).map { String(format: "%02x", $0) }.joined()
    }

    func handleForegroundPush() {
        Task {
            await sync?.sync()
        }
    }

    func handleTap(serverID: Int) {
        Task {
            await sync?.sync()
            markRead(serverID: serverID)
            selectedTab = .inbox
            path.append(serverID)
            sync?.updateBadge()
            #if os(macOS)
            NotificationCenter.default.post(name: .notifiOpenPanel, object: nil)
            #endif
        }
    }

    func markRead(serverID: Int) {
        guard let context else { return }
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.serverID == serverID })
        if let message = try? context.fetch(descriptor).first, !message.isRead {
            message.isRead = true
            do {
                try context.save()
            } catch {
                log.error("mark read failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func refresh() async {
        await sync?.sync()
        await sync?.refreshKeys()
    }

    func refreshPermission() async {
        // UNNotificationSettings is not Sendable, so read the status inside the
        // callback and let only that cross the isolation boundary.
        notificationStatus = await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestNotificationPermission() async {
        do {
            _ = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            log.error("permission request failed: \(String(describing: error), privacy: .public)")
        }
        await refreshPermission()
    }

    func openSystemNotificationSettings() {
        #if os(iOS)
        if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #else
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    func sendTestNotification() async throws {
        guard let api else { return }
        let dateString = Self.testDateFormatter.string(from: Date())
        let created = try await api.createKey(name: "Test — \(dateString)")
        defer {
            // The test key's secret is never shown to the user, so it must not survive
            // this call. Retry once before giving up loudly.
            Task {
                do {
                    try await api.revokeKey(id: created.id)
                } catch {
                    try? await api.revokeKey(id: created.id)
                }
                await sync?.refreshKeys()
            }
        }
        _ = try await api.send(
            key: created.key,
            title: "Test notification",
            message: "If you can read this, notifi is working."
        )
    }

    static var platformName: String {
        #if os(iOS)
        return "ios"
        #else
        return "macos"
        #endif
    }

    static var appVersion: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    private static let testDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}
