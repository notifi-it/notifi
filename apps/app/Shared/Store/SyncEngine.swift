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

    private let bookmarkKey = "lastSyncedMessageID"

    init(api: APIClient, identity: DeviceIdentity, context: ModelContext) {
        self.api = api
        self.identity = identity
        self.context = context
        self.keys = KeyCacheStore.load()
    }

    private var bookmark: Int {
        get { UserDefaults.standard.integer(forKey: bookmarkKey) }
        set { UserDefaults.standard.set(newValue, forKey: bookmarkKey) }
    }

    func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            while true {
                let page = try await api.history(since: bookmark, limit: 200)
                if page.messages.isEmpty { break }

                for row in page.messages {
                    ingest(row)
                }

                try context.save()

                if let latest = page.latestID {
                    bookmark = latest
                }
                if page.messages.count < 200 { break }
            }
        } catch {
            log.error("sync failed: \(String(describing: error), privacy: .public)")
        }

        updateBadge()
    }

    private func ingest(_ row: HistoryMessage) {
        let plaintext: Data
        do {
            plaintext = try identity.open(sealedB64: row.contentSealed, info: "content")
        } catch {
            log.error("skip message \(row.id): open failed")
            return
        }

        guard let content = try? JSONDecoder().decode(MessageContent.self, from: plaintext) else {
            log.error("skip message \(row.id): decode failed")
            return
        }

        guard content.keyID == row.keyID, content.createdAt == row.createdAt else {
            log.error("skip message \(row.id): sealed identity mismatch (tampered)")
            return
        }

        let serverID = row.id
        let descriptor = FetchDescriptor<Message>(predicate: #Predicate { $0.serverID == serverID })
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let message = Message(
            serverID: row.id,
            title: content.title,
            body: content.message,
            link: content.link.flatMap(URL.init(string:)),
            imageURL: content.image.flatMap(URL.init(string:)),
            keyID: content.keyID,
            createdAt: Date(timeIntervalSince1970: TimeInterval(row.createdAt))
        )
        context.insert(message)
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
        let count = enabled ? unreadCount() : 0
        Task {
            try? await UNUserNotificationCenter.current().setBadgeCount(count)
        }
    }
}
