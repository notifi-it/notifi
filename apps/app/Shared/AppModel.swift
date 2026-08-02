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
    case needsRestoreAck
    case ready
}

@MainActor
@Observable
final class AppModel {
    static private(set) weak var shared: AppModel?

    var bootState: BootState = .loading
    var path = NavigationPath()
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
    private let log = Logger(subsystem: "it.notifi.app", category: "app")

    init() {
        badgeEnabled = UserDefaults.standard.object(forKey: "badgeEnabled") as? Bool ?? true
        AppModel.shared = self
    }

    var baseURL: URL {
        if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: raw), url.host != nil {
            return url
        }
        return URL(string: "https://notifi.it")!
    }

    func bootstrap(context: ModelContext) {
        guard case .loading = bootState else { return }
        self.context = context

        #if !targetEnvironment(simulator)
        guard SecureEnclave.isAvailable else {
            bootState = .unsupported
            return
        }
        #endif

        if let identity = try? DeviceIdentity.load() {
            finishBoot(with: identity)
            return
        }

        if messagesExist() {
            bootState = .needsRestoreAck
            return
        }

        createIdentity()
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
            bootState = .unsupported
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
            await registerDevice(token: token)
            await refreshPermission()
            await sync?.sync()
            await sync?.refreshKeys()
            await ensureDefaultKey()
        }
    }

    private func ensureDefaultKey() async {
        guard let api, let sync else { return }
        if sync.keys.contains(where: { $0.name.lowercased() == "default" }) { return }
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
        guard bootState == .ready else {
            pendingToken = hex
            return
        }
        Task { await registerDevice(token: hex) }
    }

    private func registerDevice(token: String?) async {
        guard let api, let identity else { return }
        let apnsToken = token ?? Self.syntheticToken(for: identity)
        let body = RegisterDeviceBody(
            publicKey: identity.publicKeyX963.base64EncodedString(),
            encryptionPublicKey: identity.encryptionPublicKeyX963.base64EncodedString(),
            apnsToken: apnsToken,
            platform: Self.platformName,
            appVersion: Self.appVersion
        )
        do {
            _ = try await api.registerDevice(body)
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
            path.append(serverID)
            sync?.updateBadge()
        }
    }

    func markRead(serverID: Int) {
        guard let context else { return }
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.serverID == serverID })
        if let message = try? context.fetch(descriptor).first, !message.isRead {
            message.isRead = true
            try? context.save()
        }
    }

    func refresh() async {
        await sync?.sync()
        await sync?.refreshKeys()
    }

    func refreshPermission() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        notificationStatus = settings.authorizationStatus
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
        _ = try await api.send(
            key: created.key,
            title: "Test notification",
            message: "If you can read this, notifi is working."
        )
        try? await api.revokeKey(id: created.id)
        await sync?.refreshKeys()
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
