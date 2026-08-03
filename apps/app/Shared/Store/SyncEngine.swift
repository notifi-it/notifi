import Foundation
import OSLog
import SwiftData
import UserNotifications

@MainActor
@Observable
final class SyncEngine {
    private let api: APIClient
    private let identity: DeviceIdentity
    private let context: ModelContext
    private let log = Logger(subsystem: "it.notifi.app", category: "sync")

    var keys: [CachedKey]
    var keysRefreshFailed = false
    private(set) var isSyncing = false
    private(set) var unread = 0

    private let bookmarkKey = "lastSyncedDeviceSeq"
    private let failureKeyPrefix = "ingestFailedAt."
    private static let unreadableGraceSeconds: TimeInterval = 14 * 24 * 60 * 60
    private static let seqMigrationKey = "didMigrateToDeviceSeq"

    init(api: APIClient, identity: DeviceIdentity, context: ModelContext) {
        self.api = api
        self.identity = identity
        self.context = context
        self.keys = KeyCacheStore.load()
        migrateToDeviceSeqIfNeeded()
    }

    /// Moves the store off the server's old global message ids.
    ///
    /// Message ids used to be global and are now per-device, so they start again
    /// from 1 and would otherwise collide with ids already held here — a new
    /// message would look like one the store had seen and be dropped. Existing
    /// rows move below zero, which cannot collide with anything the server will
    /// ever send, and keeps the history intact. Nothing sorts or displays these,
    /// so negating them is invisible.
    ///
    /// The bookmark goes with them. The old one counts in the old numbering and
    /// is far past anything the device will be offered now, so left alone it
    /// would hide every future message.
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
                // Leaving the flag unset means this runs again next launch
                // rather than the store being left half-renumbered.
                log.error("device_seq migration failed: \(String(describing: error), privacy: .public)")
                return
            }
        }

        // Failure markers are keyed by the old ids, and a new message could
        // reach the same number and inherit one.
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
        do {
            pages: while true {
                let page = try await api.history(since: bookmark, limit: 200)
                if page.messages.isEmpty { break }

                var ackable = bookmark
                var blocked = false
                for row in page.messages {
                    switch ingest(row) {
                    case .inserted:
                        newMessages += 1
                    case .duplicate, .discarded:
                        break
                    case .unreadable:
                        blocked = true
                    }
                    if blocked { break }
                    ackable = row.id
                }

                try context.save()

                if ackable > bookmark { bookmark = ackable }
                if blocked { break pages }
                if page.messages.count < 200 { break }
            }
        } catch {
            log.error("sync failed: \(String(describing: error), privacy: .public)")
        }

        updateBadge()
        if newMessages > 0 {
            NotificationCenter.default.post(name: .notifiNewMessages, object: nil)
        }
    }

    private enum IngestResult {
        case inserted
        case duplicate
        case discarded
        case unreadable
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

        // occurred_at is checked here for the same reason created_at is: it is
        // stored on the row as well as inside the sealed blob, so a server that
        // altered one copy would be caught.
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
            }
        )
        context.insert(message)
        return .inserted
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
                    revokedAt: summary.revokedAt
                ))
            }
            keys = built
            keysRefreshFailed = false
            KeyCacheStore.save(built)
        } catch {
            keysRefreshFailed = true
            log.error("key refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func unreadCount() -> Int {
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.isRead == false })
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func updateBadge() {
        let enabled = UserDefaults.standard.object(forKey: "badgeEnabled") as? Bool ?? true
        let raw = unreadCount()
        unread = raw
        #if os(macOS)
        NotificationCenter.default.post(name: .notifiUnreadChanged, object: nil)
        #endif
        let count = enabled ? raw : 0
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }
}
