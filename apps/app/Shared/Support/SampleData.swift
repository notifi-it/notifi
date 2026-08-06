#if DEBUG
import Foundation
import SwiftData

/// Debug-only fixtures.
///
/// Wrapped in `#if DEBUG` so none of this reaches a release build. The set is
/// chosen to exercise the layout rather than to look tidy: bodies present and
/// absent, links present and absent, a title long enough to wrap and a URL long
/// enough to truncate. Exactly one row carries an image, because a feed where
/// every row has a thumbnail is not what one looks like in use.
enum SampleData {

    /// Off unless the run asks for it by name. `#if DEBUG` alone still exposed the
    /// seed and clear commands on any debug build — including one handed to
    /// someone to look at — where a menu that rewrites the feed is a trap. Set
    /// `NOTIFI_SAMPLE_DATA=1` in the scheme's environment to get them back.
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["NOTIFI_SAMPLE_DATA"] == "1"
    }

    /// Negative server IDs so seeded rows can never collide with real ones, and
    /// so `clear` can find them again.
    static let idFloor = -10_000

    @MainActor
    /// `keyIDs` should be the ids this device has actually synced. Seeding ids
    /// that do not exist makes the detail screen fall back to "Key <id>", which
    /// reads as a bug rather than as sample data.
    static func seed(into context: ModelContext, keyIDs: [Int] = []) {
        clear(from: context)

        let now = Date()
        func ago(_ minutes: Int) -> Date { now.addingTimeInterval(-Double(minutes) * 60) }

        // One image, served from the marketing site rather than a random image
        // host, so the seeded feed looks the same on every machine and the
        // screenshots on the site can be regenerated from it.
        let demo = "https://notifi.it/demo"

        // title, body, image, link, minutes ago, unread, client-supplied ms offset
        let rows: [(String, String?, String?, String?, Int, Bool)] = [
            // The rich case, and the one the marketing screenshots are taken from:
            // a body that uses most of what the renderer styles — heading, emphasis,
            // list, code span, quote, fenced block and link — next to an attached
            // image, and still short enough that the image stays above the fold.
            // The first line has to read on its own, because the inbox row flattens
            // all of this to two lines.
            ("p99 latency crossed 800 ms",
             """
             api.eu-west-2 — **782 ms**, up from 214 ms over 12 minutes.

             ## What moved

             - `checkout-api` — 782 ms *(was 214 ms)*
             - `search` — 240 ms, flat
             - `payments` — 198 ms, flat

             Connection pool saturation on the primary, not the app tier.

             > Auto-scaling is held until 08:00 while the migration drains.

             ```
             kubectl -n api top pods --sort-by=cpu | head -5
             ```

             [Open the dashboard](https://grafana.internal/d/api-latency)
             """,
             "\(demo)/latency.png",
             "https://grafana.internal/d/api-latency", 9, true),

            ("Disk 91% full",
             "vault-01 /dev/nvme0n1 — 41 GB free of 460 GB.",
             nil, nil, 6, true),

            ("Error rate spiked to 4.1%",
             nil, nil, nil, 18, true),

            ("Release v2.4.0 published",
             nil, nil, "https://github.com/notifi/notifi/releases/tag/v2.4.0", 40, false),

            ("Nightly backup complete",
             "pg → r2, 4.2 GB in 3m 11s. Retention trimmed to 30 snapshots.",
             nil, nil, 300, false),

            ("New signup",
             "hannah@shorepine.co upgraded to Pro — seat 12 of 25.",
             nil, "https://dashboard.stripe.com/customers/cus_Qk29fJ", 660, false),

            ("Certificate expires in 7 days",
             nil, nil,
             "https://vault.internal/pki/certs/star-notifi-it", 960, true),

            ("Weekly digest ready",
             "412 messages, 38 alerts, 2 incidents. Median delivery 240 ms.",
             nil,
             "https://notifi.sh/digest/2026-w31", 1_200, false),

            // Markdown: headings, emphasis, a list, a quote, a rule and a code
            // block, so the detail renderer and the flattened row preview can both
            // be eyeballed in one row.
            ("Deploy 4f2c1e9 finished",
             """
             ## Summary
             Rolled out to **eu-west-2** in *42s*. One check is still amber.

             - `queue-worker` — healthy
             - `redrive` — restarting
             - api — healthy

             > Watch the redrive loop for the next 10 minutes.

             ---

             ```
             kubectl rollout status deploy/redrive -n notifi
             ```

             Full log: [build #1284](https://ci.notifi.sh/builds/1284)
             """,
             nil, "https://ci.notifi.sh/builds/1284", 1_400, true),

            // Long title — must wrap, never truncate.
            ("Certificate for vault.internal.eu-west-2.compute.amazonaws.com expires in 7 days",
             "Renew before Friday or the workers start failing TLS handshakes.",
             nil, nil, 1_500, true),

            // Worst case: a long title AND a long message, with nothing else.
            // The title wraps as far as it needs; the message clamps to two lines.
            ("Scheduled maintenance on the eu-west-2 primary database cluster has been "
             + "extended by a further four hours following a failed failover",
             "The standby did not promote cleanly after the primary was fenced at 02:14 UTC. "
             + "Engineering has rolled back to the previous topology and is replaying the "
             + "write-ahead log from the last consistent checkpoint. Reads are served from "
             + "the replica and are up to nine minutes stale. Writes are rejected with 503. "
             + "The next update lands at 07:00 UTC or sooner if the replay finishes early.",
             nil, nil, 1_620, true),

            // Same, but with every optional field present — the tallest a row gets.
            ("Incident INC-2049 postmortem published for the multi-region outage that "
             + "affected notification delivery for approximately six hours on 29 July",
             "Root cause was a malformed retention policy applied to the delivery queue, "
             + "which silently dropped acknowledgements and caused the redrive worker to "
             + "loop. 41,208 notifications were delayed and 112 were lost outright. "
             + "Remediation, owners and dates are in the linked document.",
             nil,
             "https://notifi.sh/incidents/INC-2049/postmortem",
             1_680, false),

            // Very long URL — the row shows the host, the detail shows all of it.
            ("Build artefact published",
             "Signed and notarised. Retention on this bucket is 30 days.",
             nil,
             "https://registry.internal.acme-corp.io/artifacts/v2/builds/2026/08/02/"
             + "notifi-ios/release/arm64/notifi-ios-4f2c1e9a8b7c6d5e-signed-notarised.tar.gz"
             + "?signature=aG1hYy1zaGEyNTY9YzhkOWUwZjFhMmIzYzRkNWU2ZjcwODE5&expires=1785638400",
             2_400, false),

            ("OK",
             nil, nil, nil, 4_320, false),
        ]

        for (index, row) in rows.enumerated() {
            let (title, body, image, link, minutes, unread) = row
            context.insert(
                Message(
                    serverID: idFloor - index,
                    title: title,
                    body: body,
                    link: link.flatMap(URL.init(string:)),
                    imageURL: image.flatMap(URL.init(string:)),
                    // Cycle through the real keys so the detail screen shows real
                    // names. With no keys synced yet, leave it unattributed.
                    keyID: keyIDs.isEmpty ? nil : keyIDs[index % keyIDs.count],
                    createdAt: ago(minutes),
                    // Give every other row a client timestamp so the millisecond
                    // path is visible next to the whole-second server one.
                    occurredAt: index.isMultiple(of: 2)
                        ? ago(minutes).addingTimeInterval(-Double(index) * 0.437)
                        : nil,
                    isRead: !unread
                )
            )
        }
        try? context.save()
    }

    /// Removes only seeded rows; real messages are untouched.
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
