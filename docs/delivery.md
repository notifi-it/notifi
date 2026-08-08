# Delivery

How a message gets from a sender's curl to a device's inbox, and why it
cannot be lost or reordered on the way. The code this describes:
`apps/api/src/routes/send.ts`, `apps/api/src/socket.ts`,
`apps/api/src/routes/history.ts`, `apps/app/Shared/Store/SyncEngine.swift`,
`apps/app/Shared/API/SocketClient.swift`.

## The invariant

No transport carries state the app trusts. A push, a socket frame, launch,
foregrounding and manual refresh are five ways of learning one thing —
something may have changed — and all five call the same `sync()`, which
fetches from `/history` and reconciles against the store.

Because nothing is trusted, there is no failover logic: no code checks
whether APNs is up before using it, and a dropped frame or duplicate push
costs one wasted fetch. The socket frame carries a `latest_id` for anyone
reading the wire; the client ignores it.

There is deliberately no periodic poll. It only covered the case where the
socket is blocked *and* APNs is broken at the same time, and opening the app
covers that. If that window turns out to matter, the place to add a timer
back is `AppModel.startLiveUpdates`.

## The bookmark

The server numbers each device's messages 1, 2, 3… (`device_seq`). The app
stores one number — the highest it has saved — and every sync asks for
everything above it, saves what comes back, then moves it up.

The bookmark is also the receipt: `/history` treats the `since` it is given
as an acknowledgement, and the server deletes anything at or below it. So
the bookmark must never get ahead of the store, and `SyncEngine.sync()`
moves it only after `context.save()` returns. A crash between the two
leaves the bookmark behind, which refetches and dedupes — the safe
direction.

Gaps in the numbering are normal (a failed send burns a number), so the
client never infers a missing message from a hole.

## What a send does

`POST /send` checks the key, spends the per-account rate limit, seals the
message to the device's encryption key, and shrinks the push payload until
it fits the APNs budget: full message, then a truncated preview, then title
only. The copy in D1 never shrinks.

Then one D1 batch writes the row *and* its number together — the insert
reads `seq_counter` itself. Numbering in one statement and inserting in
another opens a window where a number is taken but its row does not exist;
a read landing there moves the bookmark past the missing row and the
message is never delivered, then swept. With the batch there is no window:
a number exists only once its row does, and concurrent sends serialise.

After the write, two transports fire, in parallel, unconditionally:

- **APNs push** — carries the sealed message, because a locked phone must be
  able to show a banner with the app closed. May be all the user ever sees.
- **Socket frame** — `{"type":"message","latest_id":N}`, nothing else. It
  reaches a running app, which fetches anyway.

Neither waits for the other; a failure in either cannot fail the send. A
device holding both gets the message twice and dedupes on `device_seq`.

## The socket

One Durable Object per device (`DeviceSocket`, keyed by device row id)
holds that device's open websocket and hibernates between events. The
upgrade to `GET /socket` is signed exactly like a `GET /history`, so the
app reuses the signing it already has.

The client sends a text `ping` every 45s; the object's auto-response
answers at the edge without waking it, so keepalives cost nothing. After
100s of silence the client assumes a half-open socket (NAT timeout, Wi-Fi
handoff), tears it down, and reconnects with jittered exponential backoff.
Every reconnect syncs *before* listening, because whatever arrived while
the socket was down was never announced — on a laptop that gap is every
lid close.

## `is_critical`

Whether a send was actually delivered as an escalated alert — the sender
asked (`is_critical=1`, or the older `critical=1`, both honoured) and the
key had the standing — is resolved before sealing and written into the
sealed content on every message, false included. Absent means the message
predates the field. The sender's request is not stored; only the outcome.

## Deletion

The server is a relay, not an archive; the device's store is the only
lasting copy. A cron sweep (daily, 03:00 UTC) deletes messages at or below
each device's ack — collected, so done with. Nothing else: an uncollected message waits, encrypted, for as
long as its device takes to come back, and a device stays registered until
its owner deletes the app's data. `expires_at` is still written, but it is
only the APNs retry deadline now.

Deleting a message in the app is local: there is no server call to make,
and the row cannot come back because `/history` only returns rows above
the bookmark. An unreadable row holds the ack at the last good message so
the sweep keeps it for a retry.

## What covers what

| Condition | Covered by | Delay |
|---|---|---|
| Device asleep, app closed | APNs | instant |
| Token signed for the wrong APNs environment | socket | instant |
| APNs incident | socket | instant |
| Socket blocked by a proxy or captive portal | APNs | instant |
| Socket blocked and APNs broken at once | launch, foreground, refresh | when the app opens |
| Socket half-open after a NAT timeout | client watchdog, then socket | ≤ 100s |
| Worker evicted before the frame was sent | APNs, which fires separately | instant |
| Sent while the device was offline | sync on reconnect | on reconnect |
| Store save failed mid-sync | bookmark holds, refetched | next sync |
| A row will not decrypt | ack holds, server keeps the row | next sync |

The app counts messages that arrive with no push behind them; three in a
row shows a "Delivery — not pushing" warning in Settings, and one good
push clears it. That is how a wrong-environment APNs token surfaces
instead of failing silently.

## Why sockets and not polling

Polling costs scale with time × devices; sockets scale with messages ×
devices, and for a pager messages are far rarer than seconds. At 10,000
devices, a 30s poll costs roughly $260/month in Worker requests (about
$1,900 before the idle D1 writes were removed); the socket costs roughly
$5–10, dominated by reconnects. Published rates against an assumed traffic
model, not a bill.

## Verifying

`make typecheck` plus both `xcodebuild` schemes, then
[VERIFYING.md](VERIFYING.md) by hand. The transactional send and the
socket path can be exercised locally against `wrangler dev` (loopback is
exempt from the HTTPS redirect for exactly this): register a device, open
`/socket`, send, and the frame arrives before any fetch is due.
