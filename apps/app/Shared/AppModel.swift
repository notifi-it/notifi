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

/// Which of `Theme`'s two grounds the app paints on.
///
/// The app pins a scheme rather than following the system's, and there is no
/// "match system" case. The two are the same setting for most people most of
/// the time, and the difference is a phone on automatic switching to light at
/// sunrise — which for a pager means the app changes ground on its own, at the
/// hour it is least wanted. The default is dark; light is chosen, and stays.
enum Appearance: String, CaseIterable {
    case dark
    case light

    var colorScheme: ColorScheme { self == .dark ? .dark : .light }

    var title: String { self == .dark ? Copy.Settings.groundDark : Copy.Settings.groundLight }
}

/// Pages the macOS popover pushes on top of the inbox.
enum AppRoute: Hashable {
    case settings
}

enum AppTab: Hashable {
    case inbox
    case keys
    case settings
    /// iOS only. `GeistTabBar` lists its items explicitly, so this case never
    /// reaches the Mac's bar — where it would be a tab that opens a field the
    /// Mac draws in the Inbox header instead.
    case search
}

/// What a notification asked for, in terms the model can act on once it exists.
enum NotificationAction {
    case show(serverID: Int)
    case markRead(serverID: Int)
    case openLink(URL, keyID: Int?, serverID: Int)
}

@MainActor
@Observable
final class AppModel {
    static private(set) var shared: AppModel?

    /// iOS launches the app to deliver a tap or a button press, so the response
    /// regularly arrives before any UI — and so before `bootstrap` has run and
    /// there is a model to act on it. Anything that lands early waits here and is
    /// drained by `bootstrap`, which is what makes a lock-screen button behave the
    /// same whether the app was running or not. Before this existed a tap on a
    /// notification with the app cold opened the inbox rather than the message.
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
    var selectedTab: AppTab = .inbox
    var notificationStatus: UNAuthorizationStatus = .notDetermined
    /// Whether the system will actually let a Critical Alert through. Stays
    /// `.notSupported` until Apple grants the entitlement. The key screen reads
    /// this to say how loud an urgent send will be — Time Sensitive on its own, or
    /// Time Sensitive plus audible through silent mode — not to decide whether the
    /// switch works, which it does either way.
    var criticalAlertStatus: UNNotificationSetting = .notSupported
    var remoteImagesEnabled: Bool {
        didSet { RemoteImages.setEnabled(remoteImagesEnabled) }
    }
    /// Which ground the app paints on. Written straight through on change, so
    /// the choice survives a launch that never reaches `bootstrap` — which is
    /// most of them, since a notification tap can open the app cold.
    var appearance: Appearance {
        didSet { UserDefaults.standard.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }
    private(set) var keysAllowingAnyLink: Set<Int>
    var presentingCreateKey = false

    private(set) var identity: DeviceIdentity?
    private(set) var api: APIClient?
    private(set) var sync: SyncEngine?

    var hasUnread: Bool { (sync?.unread ?? 0) > 0 }

    private var context: ModelContext?
    private var pendingToken: String?
    private var registrationChain: Task<Void, Never>?
    private var lastRegisteredToken: String?
    private let log = Logger(subsystem: "it.notifi.notifi", category: "app")

    private static let realTokenKey = "lastRealAPNSToken"
    private static let appearanceKey = "appearance"

    init() {
        remoteImagesEnabled = RemoteImages.isEnabled
        // Nothing stored is the case that matters: an unset key reads as `nil`
        // and lands on `.dark`, so a fresh install and a user who has never
        // opened this row both get the ground the app was designed on.
        appearance = Appearance(rawValue: UserDefaults.standard.string(forKey: Self.appearanceKey) ?? "")
            ?? .dark
        keysAllowingAnyLink = LinkPolicy.allowedKeyIDs()
    }

    /// Whether messages sent with this key may open links the strict rule rejects.
    /// A message with no key — its key was revoked and swept — is never trusted.
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
        LinkPolicy.store(keysAllowingAnyLink)
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

        let queued = AppModel.pendingActions
        AppModel.pendingActions = []
        for action in queued { apply(action) }

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

    /// Callable from the first-run screen as well as boot: the boot task races the
    /// empty state onto the screen, and a walkthrough that shows a placeholder key
    /// hands the user a command that 401s.
    func ensureDefaultKey() async {
        guard let api, let sync else { return }
        // Only act on an authoritative key list. If the refresh failed, sync.keys may be
        // empty simply because we could not reach the server, and creating a key here
        // would mint a duplicate "default" and orphan the previous secret.
        guard !sync.keysRefreshFailed else { return }
        if sync.keys.contains(where: { $0.isDefault && !$0.isRevoked }) {
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

    /// Allows or stops escalated alerts for one key. The server keeps the last word:
    /// a send still has to ask for `critical=1`, and a key that was never switched
    /// on here can never raise its own volume, however the key value is used.
    ///
    /// The switch is not gated on Critical Alerts, because escalation does not
    /// depend on them: until Apple grants request W8U762V6VJ the server sends these
    /// as Time Sensitive, which needs no approval and already carries the page past
    /// Focus. Critical Alerts are the ceiling this reaches once the grant lands, so
    /// the permission is still asked for and the OS's standing is still returned —
    /// the caller uses it to say how loud "on" is actually going to be, rather than
    /// to decide whether "on" is allowed at all.
    @discardableResult
    func setKeyCritical(id: Int, critical: Bool) async throws -> UNNotificationSetting {
        guard let api, let sync else { throw NotifiError.identityMissing }
        if critical, criticalAlertStatus != .enabled {
            // Re-reads the setting itself, so what the caller reports is the OS's
            // answer to this request rather than whatever was cached when the
            // screen appeared.
            await requestCriticalAlertPermission()
        }
        try await api.updateKey(id: id, critical: critical)
        await sync.refreshKeys()
        return criticalAlertStatus
    }

    /// Replaces the default key with a fresh one. The old value stops working, so
    /// anything still sending with it starts getting 401 — same as a revoke, but
    /// you are not left without a default.
    ///
    /// The replacement is minted before the old one is retired: if creation fails,
    /// the working key is still in place rather than the device having none.
    func regenerateDefaultKey() async throws {
        guard let api, let sync else { throw NotifiError.identityMissing }
        let superseded = sync.keys.filter { $0.isDefault && !$0.isRevoked }
        let created = try await api.createKey(name: "default")
        DeviceIdentity.storeDefaultKey(created.key)
        for key in superseded {
            do {
                try await api.revokeKey(id: key.id)
            } catch {
                // The new key already works. A stranded old one is worth logging
                // but not worth failing the whole regenerate over.
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

    /// The extension only offers the button for an https link, because it cannot
    /// see the per-key allow-list. This side can, so the full policy is applied
    /// here — and a link it rejects opens the message instead of nothing, which is
    /// where the user can see the URL and decide.
    private func openLink(_ url: URL, keyID: Int?, serverID: Int) {
        guard LinkPolicy.allows(url, keyID: keyID) else {
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

    /// The push can beat the message it announces into the store, so the sync has
    /// to come first — otherwise the row a button acted on does not exist yet and
    /// the message stays unread with its badge still counting it.
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
                log.error("mark read failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    func refresh() async {
        await sync?.sync()
        await sync?.refreshKeys()
    }

    func refreshPermission() async {
        // UNNotificationSettings is not Sendable, so read the statuses inside the
        // callback and let only those cross the isolation boundary.
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

    /// Asked separately, the first time a key is switched to critical, rather than
    /// bundled into the initial prompt. Critical Alerts get their own system
    /// dialog, and asking for it before the user has expressed any interest is the
    /// fastest way to have it denied for good.
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
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
        #endif
    }

    /// Sends through the device's own `default` key.
    ///
    /// Every device mints a `default` key on first boot and its value is the only
    /// one kept in the Keychain, so it is always available. This used to create a
    /// throwaway key and revoke it, which flashed a junk entry through the Keys
    /// list on every test.
    /// The title and message are overridable so the onboarding step can send the
    /// exact payload its curl snippet shows. A button that quietly sends
    /// something else teaches the wrong thing about the API.
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
