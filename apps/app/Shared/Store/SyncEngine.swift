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
    // 200 rows a page, so this is 10k messages in one pass — far more than a real
    // backlog. The cap exists because the loop is otherwise driven entirely by what
    // the server returns.
    private static let maxPagesPerSync = 50

    init(api: APIClient, identity: DeviceIdentity, context: ModelContext) {
        self.api = api
        self.identity = identity
        self.context = context
        self.keys = KeyCacheStore.load()
        migrateToDeviceSeqIfNeeded()
    }

    /// A revoked key cannot send, so it needs no summary and no category.
    static func summaryKeys(_ keys: [CachedKey]) -> [NotificationCategories.SummaryKey] {
        keys.filter { !$0.isRevoked }
            .map { NotificationCategories.SummaryKey(id: $0.id, name: $0.name) }
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
        // A first sync replays the whole backlog; announcing any of it would
        // page the user about history they have already been paged about.
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
                        // Hold the ack at the last good row so the server keeps this
                        // one for a retry — but keep ingesting the rest of the page.
                        // Stopping here would hide every later message behind one bad
                        // blob until the grace period expired.
                        blocked = true
                    }
                    if !blocked { ackable = row.id }
                }

                // The save is what the feed's `@Query` sees, so it is the only
                // place the arrival of a message can be animated from — the
                // inserts above are invisible until it lands. Without this, a
                // sync that runs while the feed is on screen shoves rows in
                // under the reader's eyes with nothing bridging the jump.
                //
                // Only a page that actually inserted something animates; a
                // routine sync that finds nothing new must not make the list
                // twitch. Reduce Motion is read from the platform rather than
                // the environment because there is no view here to read.
                let arrived = newMessages > insertedBefore
                try withAnimation(arrived && !Theme.reduceMotion ? Theme.reveal : nil) {
                    try context.save()
                }

                // /history acks whatever `since` it is given, so the bookmark cannot
                // move past a held row and there is no point re-requesting the same
                // page. A bookmark that fails to advance also means the server
                // returned rows at or below it, which would otherwise spin forever.
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

    /// Posts a local banner for any message the sync brought in whose push never
    /// arrived — APNs down, or an environment that cannot receive it. The socket
    /// wake already proves delivery is possible; a pager that stores the page but
    /// stays silent has not paged anyone.
    ///
    /// Deduplication runs in both directions. Here, a message whose push already
    /// sits in Notification Center is skipped. In `NotificationDelegate`, a push
    /// that arrives after this banner removes it by its `local-` identifier, so a
    /// slow push costs a replaced banner rather than a second one.
    ///
    /// The userInfo mirrors the push's shape exactly — id plus the sealed blob —
    /// so the delegate's action handlers work identically on either copy, and the
    /// link stays sealed rather than sitting in the notification store in the
    /// clear.
    private func backstopBanners(_ arrivals: [Arrival]) {
        guard !arrivals.isEmpty else { return }
        Task {
            let center = UNUserNotificationCenter.current()
            let announced = Set(await center.deliveredNotifications().compactMap {
                Self.serverID(from: $0.request.content.userInfo)
            })
            for arrival in arrivals where !announced.contains(arrival.serverID) {
                let content = UNMutableNotificationContent()
                content.title = arrival.content.title
                if let message = arrival.content.message { content.body = message }
                content.sound = .default
                // The same ceiling the server's escalated push asks for — see
                // CRITICAL_ENTITLED in send.ts for why this is time-sensitive
                // and not critical.
                if arrival.content.isCritical ?? false {
                    content.interruptionLevel = .timeSensitive
                }
                // The same thread the server's push would have used, so the two
                // copies of a key's messages stack together whichever transport
                // announced them.
                if let keyID = arrival.content.keyID {
                    content.threadIdentifier = "key-\(keyID)"
                }
                content.categoryIdentifier = Self.bannerCategory(for: arrival.content)
                content.userInfo = [
                    "notifi": ["id": arrival.serverID, "sealed": arrival.sealed]
                ]
                try? await center.add(UNNotificationRequest(
                    identifier: "local-\(arrival.serverID)",
                    content: content,
                    trigger: nil
                ))
            }
        }
    }

    /// The same rule the service extension applies, for the same reason: a link
    /// the strictest policy rejects gets no button, and stays openable from the
    /// message screen where the key's own allowance is known.
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

    /// A message this sync brought in, held long enough to check that the push
    /// announcing it actually arrived.
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

    /// Brings everything the OS shows about unread messages back in line with the
    /// store: the badge, the menu bar dot, and the notifications still sitting in
    /// Notification Center.
    ///
    /// One entry point rather than three, because they are the same fact told in
    /// three places and every call site that changes read state has to tell all of
    /// them. Clearing the delivered notification is the half that used to be
    /// missing: a message read in the app, or marked read from the notification's
    /// own button, left its banner sitting in Notification Center still looking
    /// unread, so the pager and the list it fed disagreed for as long as the user
    /// left them alone.
    ///
    /// Marking something unread again does not bring its notification back. Nothing
    /// can — a delivered notification cannot be re-delivered — and re-posting a copy
    /// would sound an alert for a page the user has already seen.
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

    /// The same shape `NotificationDelegate` reads, and for the same reason: the
    /// id is the only part of the push that is not sealed.
    private static func serverID(from userInfo: [AnyHashable: Any]) -> Int? {
        guard let notifi = userInfo["notifi"] as? [String: Any] else { return nil }
        if let id = notifi["id"] as? Int { return id }
        if let id = notifi["id"] as? NSNumber { return id.intValue }
        return nil
    }
}
