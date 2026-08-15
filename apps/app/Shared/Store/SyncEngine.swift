import Foundation
import OSLog
import SwiftData
import SwiftUI
import UserNotifications

@MainActor
@Observable
final class SyncEngine {
    private let api: APIClient
    private let identity: DeviceIdentity
    private let context: ModelContext
    private let log = Logger(subsystem: "it.notifi.notifi", category: "sync")

    var keys: [CachedKey]
    var keysRefreshFailed = false
    private(set) var isSyncing = false
    private(set) var unread = 0

    private let bookmarkKey = "lastSyncedDeviceSeq"
    private let failureKeyPrefix = "ingestFailedAt."
    private static let unreadableGraceSeconds: TimeInterval = 14 * 24 * 60 * 60
    private static let seqMigrationKey = "didMigrateToDeviceSeq"
    private static let pageSize = 200
    private static let maxPagesPerSync = 50

    init(api: APIClient, identity: DeviceIdentity, context: ModelContext) {
        self.api = api
        self.identity = identity
        self.context = context
        self.keys = KeyCacheStore.load()
        migrateToDeviceSeqIfNeeded()
    }

    static func summaryKeys(_ keys: [CachedKey]) -> [NotificationCategories.SummaryKey] {
        keys.filter { !$0.isRevoked }
            .map { NotificationCategories.SummaryKey(id: $0.id, name: $0.name) }
    }

    private func migrateToDeviceSeqIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.seqMigrationKey) else { return }

        if let existing = try? context.fetch(FetchDescriptor<Message>()) {
            for message in existing where message.serverID > 0 {
                message.serverID = -message.serverID
            }
            do {
                try context.save()
            } catch {
                log.error("device_seq migration failed: \(String(describing: error), privacy: .public)")
                return
            }
        }

        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(failureKeyPrefix) {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: "lastSyncedMessageID")
        defaults.set(true, forKey: Self.seqMigrationKey)
    }

    private var bookmark: Int {
        get { UserDefaults.standard.integer(forKey: bookmarkKey) }
        set { UserDefaults.standard.set(newValue, forKey: bookmarkKey) }
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        var newMessages = 0
        let firstSync = bookmark == 0
        var arrivals: [Arrival] = []
        do {
            var pagesFetched = 0
            pages: while pagesFetched < Self.maxPagesPerSync {
                pagesFetched += 1
                let page = try await api.history(since: bookmark, limit: Self.pageSize)
                if page.messages.isEmpty { break }

                let insertedBefore = newMessages
                var ackable = bookmark
                var blocked = false
                for row in page.messages {
                    switch ingest(row) {
                    case .inserted(let content):
                        newMessages += 1
                        arrivals.append(Arrival(
                            serverID: row.id, sealed: row.contentSealed, content: content
                        ))
                    case .duplicate, .discarded:
                        break
                    case .unreadable:
                        blocked = true
                    }
                    if !blocked { ackable = row.id }
                }

                let arrived = newMessages > insertedBefore
                try withAnimation(arrived && !Theme.reduceMotion ? Theme.reveal : nil) {
                    try context.save()
                }

                guard ackable > bookmark else { break pages }
                bookmark = ackable
                if blocked { break pages }
                if page.messages.count < Self.pageSize { break }
            }
        } catch {
            log.error("sync failed: \(String(describing: error), privacy: .private)")
        }

        reconcileNotifications()
        if newMessages > 0 {
            NotificationCenter.default.post(name: .notifiNewMessages, object: nil)
        }
        if !firstSync { backstopBanners(arrivals) }
    }

    // Server ids the socket flagged as having no APNs push behind them. Only
    // these get a local banner: for every other arrival a push is on its way
    // (or already shown), and posting our own would duplicate it.
    private var unpushedIDs: Set<Int> = []

    func noteUnpushed(_ serverID: Int) {
        unpushedIDs.insert(serverID)
    }

    private func backstopBanners(_ arrivals: [Arrival]) {
        let wanted = arrivals.filter { unpushedIDs.contains($0.serverID) }
        unpushedIDs.subtract(arrivals.map(\.serverID))
        guard !wanted.isEmpty else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let announced = Set(await center.deliveredNotifications().compactMap {
                Self.serverID(from: $0.request.content.userInfo)
            })
            for arrival in wanted where !announced.contains(arrival.serverID) {
                let content = UNMutableNotificationContent()
                content.title = arrival.content.title
                if let message = arrival.content.message { content.body = message }
                content.sound = .default
                if arrival.content.isCritical ?? false {
                    content.interruptionLevel = .timeSensitive
                }
                if let keyID = arrival.content.keyID {
                    content.threadIdentifier = "key-\(keyID)"
                }
                content.categoryIdentifier = Self.bannerCategory(for: arrival.content)
                content.userInfo = [
                    "notifi": ["id": arrival.serverID, "sealed": arrival.sealed]
                ]
                // Same identifier the APNs push gets via apns-collapse-id, so
                // if both land, Notification Center shows one entry.
                try? await center.add(UNNotificationRequest(
                    identifier: "\(arrival.serverID)",
                    content: content,
                    trigger: nil
                ))
            }
        }
    }

    private static func bannerCategory(for content: MessageContent) -> String {
        var hasLink = false
        if let link = content.link, let url = URL(string: link) {
            hasLink = LinkPolicy.allows(url, anyScheme: false)
        }
        return NotificationCategories.categoryID(keyID: content.keyID, hasLink: hasLink)
    }

    private enum IngestResult {
        case inserted(MessageContent)
        case duplicate
        case discarded
        case unreadable
    }

    private struct Arrival {
        let serverID: Int
        let sealed: String
        let content: MessageContent
    }

    private func ingest(_ row: HistoryMessage) -> IngestResult {
        let plaintext: Data
        do {
            plaintext = try identity.open(sealedB64: row.contentSealed, info: "content")
        } catch {
            log.error("message \(row.id): open failed")
            return unreadableOrGiveUp(row.id, reason: "open failed")
        }

        guard let content = try? JSONDecoder().decode(MessageContent.self, from: plaintext) else {
            log.error("message \(row.id): decode failed")
            return unreadableOrGiveUp(row.id, reason: "decode failed")
        }

        guard content.keyID == row.keyID,
              content.createdAt == row.createdAt,
              content.occurredAt == row.occurredAt else {
            log.error("discard message \(row.id): sealed identity mismatch (tampered)")
            clearFailure(row.id)
            return .discarded
        }

        clearFailure(row.id)

        let serverID = row.id
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.serverID == serverID })
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return .duplicate
        }

        let message = Message(
            serverID: row.id,
            title: content.title,
            body: content.message,
            link: content.link.flatMap(URL.init(string:)),
            imageURL: content.image.flatMap(URL.init(string:)),
            keyID: content.keyID,
            createdAt: Date(timeIntervalSince1970: TimeInterval(row.createdAt)),
            occurredAt: content.occurredAt.map {
                Date(timeIntervalSince1970: TimeInterval($0) / 1000)
            },
            isCritical: content.isCritical ?? false
        )
        context.insert(message)
        return .inserted(content)
    }

    private func unreadableOrGiveUp(_ serverID: Int, reason: String) -> IngestResult {
        let key = "\(failureKeyPrefix)\(serverID)"
        let firstSeen = UserDefaults.standard.object(forKey: key) as? Double
        guard let firstSeen else {
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: key)
            return .unreadable
        }
        if Date().timeIntervalSince1970 - firstSeen > Self.unreadableGraceSeconds {
            log.error("giving up on message \(serverID) after grace period: \(reason, privacy: .public)")
            UserDefaults.standard.removeObject(forKey: key)
            return .discarded
        }
        return .unreadable
    }

    private func clearFailure(_ serverID: Int) {
        UserDefaults.standard.removeObject(forKey: "\(failureKeyPrefix)\(serverID)")
    }

    func refreshKeys() async {
        do {
            let response = try await api.listKeys()
            var built: [CachedKey] = []
            for summary in response.keys {
                guard let plaintext = try? identity.open(sealedB64: summary.metaSealed, info: "key_meta"),
                      let meta = try? JSONDecoder().decode(KeyMeta.self, from: plaintext),
                      meta.id == summary.id else {
                    continue
                }
                built.append(CachedKey(
                    id: summary.id,
                    name: meta.name,
                    prefix: meta.prefix,
                    sentCount: summary.sentCount,
                    createdAt: summary.createdAt,
                    lastUsedAt: summary.lastUsedAt,
                    revokedAt: summary.revokedAt,
                    isCriticalFlag: summary.isCritical == 1
                ))
            }
            keys = built
            keysRefreshFailed = false
            KeyCacheStore.save(built)
            NotificationCategories.register(keys: Self.summaryKeys(built))
        } catch {
            keysRefreshFailed = true
            log.error("key refresh failed: \(String(describing: error), privacy: .private)")
        }
    }

    func unreadCount() -> Int {
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.isRead == false })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func reconcileNotifications() {
        let raw = unreadCount()
        unread = raw
        #if os(macOS)
        NotificationCenter.default.post(name: .notifiUnreadChanged, object: nil)
        #endif

        let read = readServerIDs()
        Task {
            let center = UNUserNotificationCenter.current()
            try? await center.setBadgeCount(raw)
            let stale = await center.deliveredNotifications().filter { delivered in
                guard let id = Self.serverID(from: delivered.request.content.userInfo)
                else { return false }
                return read.contains(id)
            }
            guard !stale.isEmpty else { return }
            center.removeDeliveredNotifications(
                withIdentifiers: stale.map(\.request.identifier)
            )
        }
    }

    private func readServerIDs() -> Set<Int> {
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.isRead == true })
        let messages = (try? context.fetch(descriptor)) ?? []
        return Set(messages.map(\.serverID))
    }

    private static func serverID(from userInfo: [AnyHashable: Any]) -> Int? {
        guard let notifi = userInfo["notifi"] as? [String: Any] else { return nil }
        if let id = notifi["id"] as? Int { return id }
        if let id = notifi["id"] as? NSNumber { return id.intValue }
        return nil
    }
}
