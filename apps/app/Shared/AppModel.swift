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

    var title: String { self == .dark ? Copy.Settings.themeDark : Copy.Settings.themeLight }
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

    /// Which tab a launch opens on, when the launch asks. Only the screenshot
    /// script sets this: driving the tab bar by tapping needs the bar to be
    /// on screen and settled, which is the slow and flaky half of capturing
    /// three tabs in a row.
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
    var selectedTab: AppTab = AppTab.launchOverride ?? .inbox
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
    /// Server-held, unlike the settings around it: it decides what the API does
    /// with a send this device never sees, so the API is where it has to live.
    /// Read back on registration, which happens every launch.
    private(set) var strictSend = false
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

    /// True only once live updates have been asked for and the socket has had a
    /// chance to connect and failed — a device that never called
    /// `startLiveUpdates`, or has asked and is still waiting on the first
    /// answer, is not "offline".
    ///
    /// `SocketClient.State` is what draws that line; asking whether the socket
    /// was connected could not. On iOS the connection is torn down on
    /// background, so every foreground began with a not-yet-connected socket and
    /// reported an outage until the first sync returned.
    var isOffline: Bool { socket?.state == .failed }

    /// A push is only a hint that there is something to fetch, so a message that
    /// arrives by sync with no push behind it is the signature of a broken push
    /// path — a token registered against the wrong APNs environment, a revoked
    /// key, a device the server can no longer reach. Nothing else in the app
    /// notices: the message still arrives, just late and silently, and the user
    /// concludes notifi is unreliable rather than that their setup is wrong.
    ///
    /// Counted rather than inferred from a timestamp, because one late message
    /// is a coincidence and twenty is a diagnosis.
    private(set) var pollOnlyArrivals: Int = UserDefaults.standard.integer(forKey: pollOnlyKey)
    private static let pollOnlyKey = "notifi.pollOnlyArrivals"

    var pushDeliveryLooksBroken: Bool { pollOnlyArrivals >= 3 }

    private var lastPushAt: Date?
    /// The catch-up sync at launch pulls whatever accumulated while the app was
    /// closed, none of which was pushed to a running app. Counting those would
    /// report every cold start as a push failure.
    private var hasCompletedFirstSync = false
    private var arrivalObserver: NSObjectProtocol?
    private var socket: SocketClient?
    private var wantsLiveUpdates = false

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
        // Environment first, so a test run can point the app at another server
        // — or an unreachable one, to exercise the offline state — without
        // re-signing the bundle. Same family as NOTIFI_STICKY and
        // NOTIFI_SAMPLE_DATA — and, like NOTIFI_START_TAB, DEBUG only: in a
        // release build
        // an env var is something any local process can set, and this one
        // redirects every request, default key included.
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["NOTIFI_BASE_URL"],
           let url = URL(string: raw), url.host != nil {
            return url
        }
        #endif
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

        if wantsLiveUpdates { startLiveUpdates() }

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
            log.error("default key creation failed: \(String(describing: error), privacy: .private)")
        }
    }

    var defaultKeyValue: String? { DeviceIdentity.loadDefaultKey() }

    /// Allows or stops escalated alerts for one key. The server keeps the last word:
    /// a send still has to ask for `is_critical=1`, and a key that was never switched
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
    func setKeyCritical(id: Int, isCritical: Bool) async throws -> UNNotificationSetting {
        guard let api, let sync else { throw NotifiError.identityMissing }
        if isCritical, criticalAlertStatus != .enabled {
            // Re-reads the setting itself, so what the caller reports is the OS's
            // answer to this request rather than whatever was cached when the
            // screen appeared.
            await requestCriticalAlertPermission()
        }
        try await api.updateKey(id: id, isCritical: isCritical)
        await sync.refreshKeys()
        return criticalAlertStatus
    }

    /// Throws rather than reverting quietly, so the screen can put the switch
    /// back where it was and say why. A switch that slid back on its own would
    /// look like the app changed its mind.
    func setStrictSend(_ enabled: Bool) async throws {
        guard let api else { throw NotifiError.identityMissing }
        try await api.updateDeviceSettings(strictSend: enabled)
        strictSend = enabled
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

    /// Any callback from the notification centre means APNs reached this device,
    /// whatever the user then did with it.
    func notePushArrived() {
        lastPushAt = Date()
    }

    /// Long enough to cover the sync the push itself triggers, plus a slow
    /// network, so a sync that beats the push to the same message is not
    /// mistaken for a missing one.
    private static let pushGrace: TimeInterval = 20

    private func noteMessagesArrived() {
        guard hasCompletedFirstSync else {
            hasCompletedFirstSync = true
            return
        }
        if let lastPushAt, Date().timeIntervalSince(lastPushAt) < Self.pushGrace {
            // Push did its job. One good delivery is enough to retire the
            // warning: whatever was wrong has been fixed or was transient.
            if pollOnlyArrivals != 0 {
                pollOnlyArrivals = 0
                UserDefaults.standard.set(0, forKey: Self.pollOnlyKey)
            }
            return
        }
        pollOnlyArrivals += 1
        UserDefaults.standard.set(pollOnlyArrivals, forKey: Self.pollOnlyKey)
    }

    /// Two transports, no timer. APNs reaches a device that is asleep or
    /// closed; the socket makes an awake device instant and re-syncs on every
    /// reconnect. There is deliberately no periodic poll behind them: it bought
    /// convergence only in the window where the socket is unreachable *and*
    /// APNs is broken at once, and launch, foreground and manual refresh
    /// already re-sync. If that window turns out to matter in practice, the
    /// place to add the timer back is here.
    func startLiveUpdates() {
        // The Mac asks for this from `applicationDidFinishLaunching`, which can
        // beat the identity load that creates the client. Remembering the intent
        // rather than dropping it means `finishBoot` can honour it late.
        wantsLiveUpdates = true
        if socket == nil, let api {
            socket = SocketClient(api: api) { [weak self] in
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
                log.error("mark read failed: \(String(describing: error), privacy: .private)")
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
