#if DEBUG
import Foundation
import SwiftData

enum SampleData {

    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["NOTIFI_SAMPLE_DATA"] == "1"
    }

    static let idFloor = -10_000

    static var usesSampleKeys: Bool {
        ProcessInfo.processInfo.environment["NOTIFI_SEED_SAMPLE"] == "1"
    }

    static var keys: [CachedKey] {
        let now = Int(Date().timeIntervalSince1970)
        func days(_ count: Int) -> Int { now - count * 86_400 }
        func hours(_ count: Int) -> Int { now - count * 3_600 }

        let rows: [(String, String, Int, Int, Int?, Int?, Bool)] = [
            ("Default", "nk_a4Qm", 128, days(420), hours(2), nil, false),
            ("Deploy bot", "nk_u7Pg", 1_842, days(310), hours(1), nil, false),
            ("Doorbell", "nk_k2Vd", 63, days(96), hours(9), nil, true),
            ("Backups", "nk_z9Rt", 704, days(88), days(1), nil, false),
            ("Grafana", "nk_c3Wn", 219, days(54), days(3), nil, false),
            ("Old laptop", "nk_p6Hs", 47, days(500), days(212), days(210), false),
        ]

        return rows.enumerated().map { index, row in
            let (name, prefix, sent, created, lastUsed, revoked, critical) = row
            return CachedKey(
                id: idFloor - index,
                name: name,
                prefix: prefix,
                sentCount: sent,
                createdAt: created,
                lastUsedAt: lastUsed,
                revokedAt: revoked,
                isCriticalFlag: critical
            )
        }
    }

    static var launchMessageIndex: Int? {
        ProcessInfo.processInfo.environment["NOTIFI_START_MESSAGE"].flatMap(Int.init)
    }

    static var suppressesPermissionPrompt: Bool { isEnabled || usesSampleKeys }

    static var launchKeyIndex: Int? {
        ProcessInfo.processInfo.environment["NOTIFI_START_KEY"].flatMap(Int.init)
    }

    static var launchAppearance: Appearance? {
        ProcessInfo.processInfo.environment["NOTIFI_APPEARANCE"].flatMap(Appearance.init(rawValue:))
    }

    static var opensSampleMessage: Bool {
        ProcessInfo.processInfo.environment["NOTIFI_OPEN_SAMPLE_MESSAGE"] == "1"
    }

    static let showcaseID = idFloor - 1_000

    private static var demoBase: String {
        ProcessInfo.processInfo.environment["NOTIFI_DEMO_BASE"] ?? "https://notifi.it/demo"
    }

    private static let showcaseBody = """
    ## A heading

    Plain text with **bold**, `code` and ~~strikethrough~~.

    - Lists
    - Quotes
    - Tables and rules

    > Lorem ipsum dolor sit amet, consectetur adipiscing elit.

    | Field | Holds |
    | --- | --- |
    | title | one line |
    | message | Markdown |
    | image | a URL |

    ---

    ```
    curl -X POST https://notifi.it/send \\
      -H "Authorization: Bearer $NOTIFI_KEY" \\
      -d "title=Rendered from Markdown"
    ```
    """

    @MainActor
    static func screenDidAppear() {
        guard !opensSampleMessage else { return }
        writeReadyMarker()
    }

    @MainActor
    static func imageDidSettle() {
        guard opensSampleMessage else { return }
        writeReadyMarker()
    }

    @MainActor
    private static func writeReadyMarker() {
        guard isEnabled else { return }
        let documents = FileManager.default.urls(for: .documentDirectory,
                                                 in: .userDomainMask)[0]
        try? Data().write(to: documents.appending(path: "shot-ready"))
    }

    static func serverID(at index: Int) -> Int { idFloor - index }

    @MainActor
    static func applyLaunchOverrides(context: ModelContext, model: AppModel) {
        guard isEnabled else { return }
        if let appearance = launchAppearance { model.appearance = appearance }
        model.remoteImagesEnabled = true
        seed(into: context, keyIDs: model.sync?.keys.map(\.id) ?? [])
    }

    @MainActor private static var didPushLaunchMessage = false

    @MainActor
    static func pushLaunchMessage(into model: AppModel) {
        guard isEnabled, !didPushLaunchMessage, let index = launchMessageIndex else { return }
        didPushLaunchMessage = true
        model.path.append(serverID(at: index))
    }

    @MainActor
    static func seed(into context: ModelContext, keyIDs: [Int] = []) {
        clear(from: context)

        let now = Date()
        func ago(_ minutes: Int) -> Date { now.addingTimeInterval(-Double(minutes) * 60) }

        let demo = demoBase

        #if os(macOS)
        let rows: [(String, String?, String?, String?, Int, Bool)] = [
            ("Front door motion",
             "Someone at the door. Clip saved to the hub.",
             nil, nil, 14, true),

            ("Water leak detected under the sink",
             "Moisture sensor tripped at 16:32. The shut-off valve closed.",
             nil, nil, 47, true),

            ("Deploy 9c41f2 finished",
             "api.notifi.it rolled out in 38s. All checks green.",
             nil, "https://ci.notifi.sh/builds/1291", 76, true),

            ("Autoscaler added six nodes in eu-west-2 after the morning spike",
             "Capacity holds at 84% with no dropped sends. The pool drains back to baseline once the migration completes at 08:00.",
             "\(demo)/loss-curve.png", "https://grafana.internal/d/autoscaler", 130, false),

            ("Backup to r2 finished",
             "notifi-db → r2, 4.6 GB in 2m 58s.",
             nil, nil, 210, false),

            ("SSL renewed for notifi.it",
             nil, nil, nil, 340, false),

            ("Send p95 back under 300 ms",
             "notifi.it/send recovered after the 02:10 spike. No action needed.",
             "\(demo)/latency.png", "https://grafana.internal/d/api-latency", 1_510, true),

            ("New signup",
             "hannah@shorepine.co upgraded to Pro, seat 12 of 25.",
             nil, nil, 1_640, false),

            ("Washing machine finished",
             nil, nil, nil, 1_820, false),

            ("Release v2.4.1 published",
             nil, nil,
             "https://github.com/notifi/notifi/releases/tag/v2.4.1", 2_130, false),

            ("Disk cleanup reclaimed 18 GB",
             "notifi-db-01 is back to 26% used.",
             nil, nil, 3_050, false),

            ("Certificate expires in 30 days",
             "The star.notifi.it wildcard renews on the 14th.",
             nil, nil, 3_390, false),

            ("Incident INC-2051 resolved",
             "Push delivery delays cleared after the queue redrive completed.",
             nil, nil, 4_490, false),

            ("Weekly digest ready",
             "402 messages, 31 alerts, 0 incidents. Median delivery 235 ms.",
             nil, "https://notifi.sh/digest/2026-w32", 4_720, false),

            ("Nightly backup complete",
             nil, nil, nil, 5_960, false),

            ("Welcome to notifi",
             "This is what a notification looks like. Send one with your first key.",
             nil, nil, 400 * 24 * 60, false),
        ]
        #else
        let rows: [(String, String?, String?, String?, Int, Bool)] = [
            ("Autoscaler added six nodes in eu-west-2 after the morning traffic spike pushed queue depth past the ceiling",
             """
             Queue depth peaked at **2.4x** the ceiling at 07:41. Capacity holds at 84% with no dropped sends.

             | Pool | Nodes | Queue |
             | --- | --- | --- |
             | eu-west-2a | 4 → 6 | 61% |
             | eu-west-2b | 4 → 6 | 58% |
             | eu-west-2c | 4 → 6 | 47% |

             The pool drains back to baseline once the migration completes at 08:00.

             > The alert closes itself when queue depth stays under the ceiling for thirty minutes.
             """,
             "\(demo)/loss-curve.png", "https://grafana.internal/d/autoscaler", 4, false),

            ("Send p99 latency crossed 800 ms",
             """
             notifi.it/send at **782 ms**, up from 214 ms over 12 minutes.

             | Stage | p99 | 30 min ago |
             | --- | --- | --- |
             | send-api | 782 ms | 214 ms |
             | keys | 240 ms | 236 ms |
             | delivery | 198 ms | 201 ms |
             """,
             "\(demo)/latency.png",
             "https://grafana.internal/d/api-latency", 9, false),

            ("Disk 91% full on notifi-db-01",
             "/dev/nvme0n1 has 41 GB free of 460 GB.",
             nil, nil, 6, true),

            ("Send error rate spiked to 4.1%",
             nil, nil, nil, 18, true),

            ("Release v2.4.0 published",
             nil, nil, "https://github.com/notifi/notifi/releases/tag/v2.4.0", 40, false),

            ("Nightly backup complete",
             "notifi-db → r2, 4.2 GB in 3m 11s. Retention trimmed to 30 snapshots.",
             nil, nil, 300, false),

            ("New signup",
             "hannah@shorepine.co upgraded to Pro, seat 12 of 25.",
             nil, "https://dashboard.stripe.com/customers/cus_Qk29fJ", 660, false),

            ("Certificate expires in 7 days",
             nil, nil,
             "https://vault.internal/pki/certs/star-notifi-it", 960, true),

            ("Weekly digest ready",
             "412 messages, 38 alerts, 2 incidents. Median delivery 240 ms.",
             nil,
             "https://notifi.sh/digest/2026-w31", 1_200, false),

            ("Deploy 4f2c1e9 finished",
             """
             ## Summary
             api.notifi.it rolled out to **eu-west-2** in *42s*. One check is still amber.

             - `queue-worker`: healthy
             - `redrive`: restarting
             - api: healthy

             > Watch the redrive loop for the next 10 minutes.

             ---

             ```
             kubectl rollout status deploy/redrive -n notifi
             ```

             Full log: [build #1284](https://ci.notifi.sh/builds/1284)
             """,
             nil, "https://ci.notifi.sh/builds/1284", 1_400, true),

            ("Certificate for vault.internal.eu-west-2.compute.amazonaws.com expires in 7 days",
             "Renew before Friday or the workers start failing TLS handshakes.",
             nil, nil, 1_500, true),

            ("Scheduled maintenance on the notifi eu-west-2 primary database cluster has been "
             + "extended by a further four hours following a failed failover",
             "The standby did not promote cleanly after the primary was fenced at 02:14 UTC. "
             + "Engineering has rolled back to the previous topology and is replaying the "
             + "write-ahead log from the last consistent checkpoint. Reads are served from "
             + "the replica and are up to nine minutes stale. Writes are rejected with 503. "
             + "The next update lands at 07:00 UTC or sooner if the replay finishes early.",
             nil, nil, 1_620, true),

            ("Incident INC-2049 postmortem published for the multi-region outage that "
             + "affected notification delivery for approximately six hours on 29 July",
             "Root cause was a malformed retention policy applied to the delivery queue, "
             + "which silently dropped acknowledgements and caused the redrive worker to "
             + "loop. 41,208 notifications were delayed and 112 were lost outright. "
             + "Remediation, owners and dates are in the linked document.",
             nil,
             "https://notifi.sh/incidents/INC-2049/postmortem",
             1_680, false),

            ("Build artefact published",
             "Signed and notarised. Retention on this bucket is 30 days.",
             nil,
             "https://registry.notifi.internal/artifacts/v2/builds/2026/08/02/"
             + "notifi-ios/release/arm64/notifi-ios-4f2c1e9a8b7c6d5e-signed-notarised.tar.gz"
             + "?signature=aG1hYy1zaGEyNTY9YzhkOWUwZjFhMmIzYzRkNWU2ZjcwODE5&expires=1785638400",
             2_400, false),

            ("OK",
             nil, nil, nil, 4_320, false),

            ("Certificate rotated",
             "The star.notifi.it wildcard was reissued and deployed to every edge.",
             nil, nil, 12 * 24 * 60, false),

            ("Quarterly usage summary",
             "1.2M notifications delivered, 99.98% within five seconds of send.",
             nil, "https://notifi.sh/reports/q2", 70 * 24 * 60, false),

            ("Welcome to notifi",
             "This is what a notification looks like. Send one with your first key.",
             nil, nil, 400 * 24 * 60, false),
        ]
        #endif

        for (index, row) in rows.enumerated() {
            let (title, body, image, link, minutes, unread) = row
            context.insert(
                Message(
                    serverID: idFloor - index,
                    title: title,
                    body: body,
                    link: link.flatMap(URL.init(string:)),
                    imageURL: image.flatMap(URL.init(string:)),
                    keyID: keyIDs.isEmpty ? nil : keyIDs[index % keyIDs.count],
                    createdAt: ago(minutes),
                    occurredAt: index.isMultiple(of: 2)
                        ? ago(minutes).addingTimeInterval(-Double(index) * 0.437)
                        : nil,
                    isRead: !unread,
                    isCritical: Self.criticalTitles.contains(title)
                )
            )
        }
        if opensSampleMessage {
            context.insert(
                Message(
                    serverID: showcaseID,
                    title: "Rendered from Markdown",
                    body: showcaseBody,
                    link: URL(string: "https://notifi.it/docs"),
                    imageURL: URL(string: "\(demo)/placeholder.png"),
                    keyID: keyIDs.dropFirst().first,
                    createdAt: ago(3),
                    occurredAt: nil,
                    isRead: false,
                    isCritical: false
                )
            )
        }
        try? context.save()
    }

    private static let criticalTitles: Set<String> = [
        "Water leak detected under the sink",
        "Certificate for vault.internal.eu-west-2.compute.amazonaws.com expires in 7 days",
        "Incident INC-2049 postmortem published for the multi-region outage that "
            + "affected notification delivery for approximately six hours on 29 July",
    ]

    @MainActor
    static func clear(from context: ModelContext) {
        let floor = idFloor
        let descriptor = FetchDescriptor<Message>(
            predicate: #Predicate { $0.serverID <= floor }
        )
        for message in (try? context.fetch(descriptor)) ?? [] {
            context.delete(message)
        }
        try? context.save()
    }
}
#endif
