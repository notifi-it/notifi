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

enum Appearance: String, CaseIterable {
    case dark
    case light

    var colorScheme: ColorScheme { self == .dark ? .dark : .light }

    var title: String { self == .dark ? Copy.Settings.themeDark : Copy.Settings.themeLight }
}

enum AppRoute: Hashable {
    case settings
}

enum AppTab: Hashable {
    case inbox
    case keys
    case settings
    case search

    static var launchOverride: AppTab? {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["NOTIFI_START_TAB"] {
        case "inbox": return .inbox
        case "keys": return .keys
        case "settings": return .settings
        case "search": return .search
        default: return nil
        }
        #else
        return nil
        #endif
    }
}

enum NotificationAction {
    case show(serverID: Int)
    case markRead(serverID: Int)
    case openLink(URL, keyID: Int?, serverID: Int)
}

@MainActor
@Observable
final class AppModel {
    static private(set) var shared: AppModel?

    private static var pendingActions: [NotificationAction] = []

    static func perform(_ action: NotificationAction) {
        if let shared {
            shared.apply(action)
        } else {
            pendingActions.append(action)
        }
    }

    var bootState: BootState = .loading
    var path = NavigationPath()
    var selectedTab: AppTab = AppTab.launchOverride ?? .inbox
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    var criticalAlertStatus: UNNotificationSetting = .notSupported
    var remoteImagesEnabled: Bool {
        didSet { RemoteImages.setEnabled(remoteImagesEnabled) }
    }
    private(set) var strictSend = false
    var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    private(set) var keysAllowingAnyLink: Set<Int>
    var presentingCreateKey = false

    private(set) var identity: DeviceIdentity?
    private(set) var api: APIClient?
    private(set) var sync: SyncEngine?

    var hasUnread: Bool { (sync?.unread ?? 0) > 0 }

    var isOffline: Bool { socket?.state == .failed }

    private(set) var pollOnlyArrivals: Int = UserDefaults.standard.integer(forKey: pollOnlyKey)
    #if DEBUG
    private static let pollOnlyKey = "notifi.pollOnlyArrivals.debug"
    #else
    private static let pollOnlyKey = "notifi.pollOnlyArrivals"
    #endif

    var pushDeliveryLooksBroken: Bool { pollOnlyArrivals >= 3 }

    private var lastPushAt: Date?
    private var hasCompletedFirstSync = false
    private var arrivalObserver: NSObjectProtocol?
    private var socket: SocketClient?
    private var wantsLiveUpdates = false

    private var context: ModelContext?
    private var pendingToken: String?
    private var registrationChain: Task<Void, Never>?
    private var lastRegisteredToken: String?
    private let log = Logger(subsystem: "it.notifi.notifi", category: "app")

    #if DEBUG
    private static let realTokenKey = "lastRealAPNSToken.debug"
    #else
    private static let realTokenKey = "lastRealAPNSToken"
    #endif
    private static let appearanceKey = "appearance"

    init() {
        remoteImagesEnabled = RemoteImages.isEnabled
        appearance = Appearance(rawValue: UserDefaults.standard.string(forKey: Self.appearanceKey) ?? "")
            ?? .dark
        keysAllowingAnyLink = LocalDev.isActive ? [] : LinkPolicy.allowedKeyIDs()
    }

    func allowsAnyLink(keyID: Int?) -> Bool {
        guard let keyID else { return false }
        return keysAllowingAnyLink.contains(keyID)
    }

    func setAllowsAnyLink(_ allow: Bool, keyID: Int) {
        if allow {
            keysAllowingAnyLink.insert(keyID)
        } else {
            keysAllowingAnyLink.remove(keyID)
        }
        if !LocalDev.isActive { LinkPolicy.store(keysAllowingAnyLink) }
    }

    var baseURL: URL {
        if let url = LocalDev.baseURL {
            return url
        }
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

        let queued = AppModel.pendingActions
        AppModel.pendingActions = []
        for action in queued { apply(action) }

        if arrivalObserver == nil {
            arrivalObserver = NotificationCenter.default.addObserver(
                forName: .notifiNewMessages,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in AppModel.shared?.noteMessagesArrived() }
            }
        }

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
        } catch {
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

        if wantsLiveUpdates { startLiveUpdates() }

        Task {
            await refreshPermission()
            if notificationStatus == .notDetermined {
                await requestNotificationPermission()
            }
        }

        Task {
            await enqueueRegistration(token: token).value
            await sync?.refreshKeys()
            await ensureDefaultKey()
            await sync?.sync()
        }
    }

    func ensureDefaultKey() async {
        guard let api, let sync else { return }
        guard !sync.keysRefreshFailed else { return }
        if sync.keys.contains(where: { $0.isDefault && !$0.isRevoked }) {
            return
        }
        do {
            let created = try await api.createKey(name: "default")
            DeviceIdentity.storeDefaultKey(created.key)
            await sync.refreshKeys()
        } catch {
            log.error("default key creation failed: \(String(describing: error), privacy: .private)")
        }
    }

    var defaultKeyValue: String? { DeviceIdentity.loadDefaultKey() }

    @discardableResult
    func setKeyCritical(id: Int, isCritical: Bool) async throws -> UNNotificationSetting {
        guard let api, let sync else { throw NotifiError.identityMissing }
        if isCritical, criticalAlertStatus != .enabled {
            await requestCriticalAlertPermission()
        }
        try await api.updateKey(id: id, isCritical: isCritical)
        await sync.refreshKeys()
        return criticalAlertStatus
    }

    func setStrictSend(_ enabled: Bool) async throws {
        guard let api else { throw NotifiError.identityMissing }
        try await api.updateDeviceSettings(strictSend: enabled)
        strictSend = enabled
    }

    func regenerateDefaultKey() async throws {
        guard let api, let sync else { throw NotifiError.identityMissing }
        let superseded = sync.keys.filter { $0.isDefault && !$0.isRevoked }
        let created = try await api.createKey(name: "default")
        DeviceIdentity.storeDefaultKey(created.key)
        for key in superseded {
            do {
                try await api.revokeKey(id: key.id)
            } catch {
                log.error("regenerate: revoking key \(key.id) failed")
            }
        }
        await sync.refreshKeys()
    }

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
            let response = try await api.registerDevice(body)
            if let strict = response.strictSend { strictSend = strict == 1 }
            lastRegisteredToken = apnsToken
        } catch {
            log.error("device registration failed: \(String(describing: error), privacy: .private)")
        }
    }

    private static func syntheticToken(for identity: DeviceIdentity) -> String {
        SHA256.hash(data: identity.publicKeyX963).map { String(format: "%02x", $0) }.joined()
    }

    func handleForegroundPush() {
        notePushArrived()
        Task {
            await sync?.sync()
        }
    }

    func notePushArrived() {
        lastPushAt = Date()
    }

    private static let pushGrace: TimeInterval = 20

    private func noteMessagesArrived() {
        guard hasCompletedFirstSync else {
            hasCompletedFirstSync = true
            return
        }
        if let lastPushAt, Date().timeIntervalSince(lastPushAt) < Self.pushGrace {
            if pollOnlyArrivals != 0 {
                pollOnlyArrivals = 0
                UserDefaults.standard.set(0, forKey: Self.pollOnlyKey)
            }
            return
        }
        pollOnlyArrivals += 1
        UserDefaults.standard.set(pollOnlyArrivals, forKey: Self.pollOnlyKey)
    }

    func startLiveUpdates() {
        wantsLiveUpdates = true
        if socket == nil, let api {
            socket = SocketClient(api: api) { [weak self] unpushedID in
                if let unpushedID { self?.sync?.noteUnpushed(unpushedID) }
                await self?.sync?.sync()
            }
        }
        socket?.start()
    }

    func stopLiveUpdates() {
        wantsLiveUpdates = false
        socket?.stop()
    }

    private func apply(_ action: NotificationAction) {
        switch action {
        case .show(let serverID):
            handleTap(serverID: serverID)
        case .markRead(let serverID):
            markReadAfterSync(serverID: serverID)
        case .openLink(let url, let keyID, let serverID):
            openLink(url, keyID: keyID, serverID: serverID)
        }
    }

    private func openLink(_ url: URL, keyID: Int?, serverID: Int) {
        guard LinkPolicy.allows(url, anyScheme: allowsAnyLink(keyID: keyID)) else {
            handleTap(serverID: serverID)
            return
        }
        #if os(iOS)
        UIApplication.shared.open(url)
        #else
        NSWorkspace.shared.open(url)
        #endif
        markReadAfterSync(serverID: serverID)
    }

    private func markReadAfterSync(serverID: Int) {
        Task {
            await sync?.sync()
            markRead(serverID: serverID)
            sync?.reconcileNotifications()
        }
    }

    func handleTap(serverID: Int) {
        Task {
            await sync?.sync()
            markRead(serverID: serverID)
            selectedTab = .inbox
            path.append(serverID)
            sync?.reconcileNotifications()
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
                log.error("mark read failed: \(String(describing: error), privacy: .private)")
            }
        }
    }

    func refresh() async {
        await sync?.sync()
        await sync?.refreshKeys()
    }

    func refreshPermission() async {
        #if DEBUG
        if SampleData.isEnabled {
            notificationStatus = .authorized
            criticalAlertStatus = .enabled
            return
        }
        #endif
        let settings: (UNAuthorizationStatus, UNNotificationSetting) =
            await withCheckedContinuation { continuation in
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    continuation.resume(
                        returning: (settings.authorizationStatus, settings.criticalAlertSetting)
                    )
                }
            }
        notificationStatus = settings.0
        criticalAlertStatus = settings.1
    }

    func requestNotificationPermission() async {
        await requestAuthorization(options: [.alert, .sound, .badge])
    }

    func requestCriticalAlertPermission() async {
        await requestAuthorization(options: [.alert, .sound, .badge, .criticalAlert])
    }

    private func requestAuthorization(options: UNAuthorizationOptions) async {
        do {
            _ = try await UNUserNotificationCenter.current().requestAuthorization(options: options)
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
        let pane = "x-apple.systempreferences:com.apple.Notifications-Settings.extension"
        let target = Bundle.main.bundleIdentifier.map { "\(pane)?id=\($0)" } ?? pane
        if let url = URL(string: target) {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    func sendTestNotification(
        title: String = Copy.Settings.testTitle,
        message: String = Copy.Settings.testBody
    ) async throws {
        guard let api, let key = defaultKeyValue else { throw NotifiError.identityMissing }
        _ = try await api.send(key: key, title: title, message: message)
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

}
