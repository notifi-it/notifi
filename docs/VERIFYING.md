# notifi — how to verify it works

The companion to the build plan (`docs/PLAN.md`). This is the
manual acceptance run — the plan says there are no automated tests, so **this
document is the test suite**. Work top to bottom; each flow has a command, the exact
result to expect, and the screenshot to capture as evidence.

## Setup (once per session)

All `make` targets run from the repository root:

```bash
make migrate    # apply migrations to the local DB
make dev        # Worker + local D1 on localhost:8787
```

Boot the two clients from Xcode, both Debug config. Debug points at the **deployed dev
Worker** (`API_BASE_URL` in `apps/app/project.yml`), so to exercise the local Worker
either change that value or run the curls below against `localhost:8787` directly:

- iOS Simulator (any iPhone running iOS 17+)
- a real Mac Debug build (the Simulator lies about keychain access groups and the
  NSE — see flow 8)

Export the values the app prints on first launch so the curls can reuse them:

```bash
export NB=http://localhost:8787
export KEY=nk_…            # from the key-reveal screen (flow 2)
export MAC_KEY=nk_…        # a key created on the Mac
export TOK=<apns hex>      # printed by the app on launch, for Phase 0
```

A device is the account, so the iPhone and the Mac are **two separate accounts** with
two separate keys. That's not a bug to work around during testing — it's flow 9.

---

## Phase 0 — prove the pipe

Do this before any product code exists. It only needs the throwaway push script and
two real devices.

### 0. Raw APNs push buzzes both devices

```bash
# proves the JWT + payload are right, from node
pnpm --filter @notifi/api phase0-push --token $TOK
```

- **Expect:** APNs returns `200` (empty body); the device buzzes.
- **On `400 BadDeviceToken`:** sandbox/prod mismatch — a Debug build's token must go
  to `api.sandbox.push.apple.com`.
- **This is not sufficient on its own:** node's `fetch` succeeding proves nothing about
  workerd's outbound HTTP/2 to Apple. The deployed-Worker equivalent is flow 3 below —
  a real `/send` against the dev Worker — which is what actually has to pass.
- 📸 **Screenshot A** — lock-screen banner on the iPhone, then the same on the Mac.

> **Done when** a push from the deployed dev Worker lands on both physical devices.

---

## Phase 1 — the thin line

### 1. Register the device — `POST /devices`

The app makes the signed call on launch; you verify the row.

```bash
wrangler d1 execute notifi-dev --local \
  --command "SELECT id, substr(public_key,1,12) pk, platform, last_seen_at FROM devices"
```

- **Expect:** one row, `platform = ios`, a recent `last_seen_at`.
- **Relaunch the app** → same row, no duplicate (idempotent upsert on `public_key`).
- **Token uniqueness:** the `apns_token_hmac` UNIQUE constraint means a re-register
  under a different keypair evicts the old row rather than duplicating it.
- 📸 **Screenshot B** — the first-launch empty state (`ContentUnavailableView` with
  *Create First Key* and *Enable Notifications*).

### 2. Create a key, revealed once — `POST /keys`

Name a key in the app.

- **Expect** the response body (visible only in the reveal screen):
  `{ id, name, key: "nk_…" }` — the full key appears this one time.
- **Verify the dismissal guard:**
  - swipe-to-dismiss the reveal sheet is **blocked** (`.interactiveDismissDisabled`)
  - closing without copying raises the dialog: **Copy and Close** / **Close and
    Revoke**
- **Verify the server kept no key:**
  ```bash
  wrangler d1 execute notifi-dev --local \
    --command "SELECT secret_hash, meta_sealed FROM keys" | grep nk_
  ```
  → no match. Only the hash and the sealed metadata are stored.
- 📸 **Screenshot C** — the one-time reveal: key large and monospaced, Copy +
  ShareLink, and the "lives and dies with this device" caption.

### 3. Send a notification — `GET|POST /send`

The only public route. Copy `KEY` from flow 2 first.

```bash
# the curl one-liner (query form)
curl "$NB/send?key=$KEY&title=Deploy%20finished&message=main%20→%20prod"

# header form — preferred, keeps the key out of shell history and edge logs
curl -H "Authorization: Bearer $KEY" \
  "$NB/send?title=Deploy%20finished&message=main+→+prod"
```

- **Expect:** `202 { "id": 42 }`; the device buzzes within a second or two.
- **Exactly 2 writes** per send (message row + key counter). Confirm the counter:
  ```bash
  wrangler d1 execute notifi-dev --local --command "SELECT sent_count FROM keys WHERE id=1"
  ```
- **The banner shows the real title** ("Deploy finished"), not "notifi" — that proves
  the NSE decrypted on-device.
- 📸 **Screenshot D** — the decrypted banner.

### 4. History sync + offline backfill — `GET /history`

This is the actual delivery guarantee, not the push.

```bash
xcrun simctl terminate booted it.notifi.notifi          # 1. kill the app
curl "$NB/send?key=$KEY&title=While%20you%20were%20out" # 2. send while dead
xcrun simctl launch booted it.notifi.notifi             # 3. reopen → SyncEngine runs
```

- **Expect:** the missed message appears in the inbox on reopen (backfilled via
  `/history?since=`).
- **Call it again** → no duplicates; the device owns the bookmark.
- **Ack-based retention:** after the sync, the device's watermark advances —
  `wrangler d1 execute notifi-dev --local --command "SELECT acked_id FROM devices"`
  shows it climbing. Messages are kept until the device syncs past them (no fixed
  window), with a 90-day backstop only for devices that never come back. Sending
  while the device stays offline for weeks no longer loses the message.
- 📸 **Screenshot E** — inbox after backfill, unread dot on the offline message.

> **Done when** it's on TestFlight and routing your own real alerts.

---

## Security & abuse flows

### 5. Unknown & revoked keys → 401, never 200

The most important negative — a dead key must shout.

```bash
curl -i "$NB/send?key=nk_nope&title=x"
# → 401 { "error": { "code": "unknown_key" } }

# revoke $KEY in the app, then reuse it:
curl -i "$NB/send?key=$KEY&title=x"
# → 401, identical body (no "it existed" leak)
```

- **Expect:** both `401`; revocation is effective on the **next** request, nothing to
  propagate.

### 6. Per-key rate limit → 429 + Retry-After

```bash
for i in $(seq 1 121); do
  curl -s -o /dev/null -w "%{http_code} " "$NB/send?key=$KEY2&title=n$i"
done
# → 202 …(×120)… 429
```

- **Expect:** the 121st in the hour is `429` with a `Retry-After` header.
- **IP layer:** the Worker binding also caps 100 req/min/IP across all six routes;
  hammer any route to confirm.

### 7. Sealed at rest — the server can't read it

```bash
wrangler d1 execute notifi-dev --local \
  --command "SELECT id, substr(content_sealed,1,24) FROM messages LIMIT 3"
```

- **Expect:** opaque base64; no `title`/`message`/`link`/`image` anywhere in the
  clear.
- **Tamper test:** swap two rows' `content_sealed`, resync the app → the app
  **discards** the mismatched blob, because the row's identity (`key_id`,
  `created_at`) is sealed inside and cross-checked.

### 8. NSE fallback when it can't decrypt — `simctl push`

```bash
xcrun simctl push booted it.notifi.notifi bad-seal.apns.json
```

(`bad-seal.apns.json` = a §8-shaped payload sealed to the wrong recipient key.)

- **Expect:** the banner degrades to **"notifi · Open notifi to view"** — never a
  crash, never a vanished push.
- **Tapping it** triggers a sync that resolves the real content.
- **Also test on real hardware** — the Simulator ignores keychain access groups, so
  the "opener loads in the NSE" path (trap 16) only truly proves out on a device.
- 📸 **Screenshot F** — the greyed, still-tappable fallback banner.

### 8b. Rich notifications — image, link button, mark as read

```bash
curl "$NB/send?key=$KEY&title=Deploy%20failed" \
  --data-urlencode "message=api-worker, run #412" \
  --data-urlencode "link=https://example.com/runs/412" \
  --data-urlencode "image=https://example.com/graph.png"
```

- **Image, Settings → Load images automatically ON:** the banner carries a
  thumbnail; long-press expands it to the full picture. The extension enforces
  ≤ 5 MB and `image/png|jpeg|gif` — a 10 MB file or an `image/svg+xml` must deliver
  as a plain banner rather than nothing.
- **Image, the same setting OFF:** no attachment, by design — downloading on arrival
  would hand the sender the device's IP and the delivery time for a message the user
  never opened. This is the one case where the notification deliberately shows less
  than it could.
- **Long-press the banner:** *Open Link* and *Mark as Read*.
- **Open Link:** goes straight to the browser. Send the same message with a
  `shortcuts:` link — the button must be **absent**, because the extension cannot
  read the per-key allow-list and so applies the https-only rule. Opting that key in
  on its key screen does *not* bring the button back; the link stays openable from
  the message screen, where the URL is on show.
- **Mark as Read:** the badge drops without the app coming forward. Do it from the
  lock screen with the app force-quit — the action is queued until the model boots,
  so it must still land.
- **Tap with the app force-quit:** opens the message itself, not just the inbox.
- **Grouping summary:** send three on one key without opening any. The stack
  collapses to **"2 more from `<key name>`"**, not "2 more notifications" — the
  app registers a category per key so the name is in the format string. Rename the
  key, pull to refresh on Keys, send again: the summary follows the new name. A key
  named with a `%` in it (`50% off`) must print literally.

  A key the app has not registered yet — a push that beats the first `/keys` of a
  fresh install — falls back to the generic category: buttons intact, plain count.

### 8c. Inbox time bands

Seed the feed from the overflow menu (**Seed sample data**, DEBUG builds only) —
it spans three days, twelve days, seventy days and a year, so every kind of band
has something under it.

- **Expect, top to bottom:** `TODAY`, `YESTERDAY`, `EARLIER THIS WEEK`,
  `EARLIER THIS MONTH`, then one heading per calendar month — `JULY`, and
  `AUGUST 2025` for anything outside the current year. Bands with nothing in them
  do not appear at all, so early in a week or a month the list is shorter.
- **The count on the right of each rule** sums to the total in the header.
- **Search, and filter by key:** headings re-band to the results. A query that
  matches only old messages must not leave an empty `TODAY` at the top.
- **The age on each row agrees with the heading above it** — nothing reading
  `3 d` under `TODAY`. Send with `occurred_at` set a few days back to check the
  case directly; it bands where the age says, not where the arrival time says.
- **Across midnight:** with the app open, the top band flips from `TODAY` to
  `YESTERDAY` within 30 seconds of the hour, on the same tick that moves the ages.
- **All three tabs:** the headings sit on the same left edge as the message titles
  and as the section labels on Keys and Settings.

---

## macOS & lifecycle

### 9. macOS menu bar + unread badge — `MenuBarExtra`

```bash
# the Mac is its own account with its own key
curl "$NB/send?key=$MAC_KEY&title=Build%20green"
```

- **Expect:** `202`; the menu-bar icon tints and shows an unread badge of 1; clicking
  it drops the inbox popover (`.window` style).
- **Reveal escapes the popover:** *Create Key* opens a **real window** — the reveal
  must survive clicking away to Terminal to paste (the popover would otherwise close
  and destroy the key).
- **Unsupported Mac:** on a non-Secure-Enclave Intel Mac, the app shows the
  unsupported screen with a **Quit** button (a menu-bar app has no Dock icon to quit
  from).
- 📸 **Screenshot G** — tinted menu-bar icon with badge + open popover.

### 10. Send Test Notification (Settings)

The support-mail button. It composes three existing routes and leaves no residue:

```
POST   /keys       { name: "Test — <date>" } → key
POST   /send       key, title:"Test notification" → 202
DELETE /keys/:id   → 204
```

- **Expect:** the device buzzes; the Keys page shows nothing left behind. No seventh
  route was added.

### 11. Account death — 410 prune & restore explainer

```bash
xcrun simctl uninstall booted it.notifi.notifi
curl "$NB/send?key=$KEY&title=gone"          # APNs returns 410 Unregistered
wrangler d1 execute notifi-dev --local --command "SELECT count(*) FROM devices"
# → 0  (device + keys + messages cascade-deleted)
```

- **Expect:** the device row and everything under it are gone after the next send.
- **The delete is guarded in SQL** (`AND last_seen_at < ?apnsTs`) — a stale 410
  cannot wipe a device that just re-registered.
- **Reinstall = a brand-new account**; the old key stays `401` forever.
- **Restore-from-backup** (messages present, Keychain identity gone) → the app shows
  the one-time "your old keys died with the old device" explainer before minting the
  new identity.

> **Done when** you'd let a stranger use it. Ship to the App Store.

---

## Evidence checklist

Attach these to the phase done-criteria:

- [ ] A — Phase 0 push on iPhone + Mac
- [ ] B — first-launch empty state
- [ ] C — one-time key reveal
- [ ] D — decrypted send banner
- [ ] E — inbox after offline backfill
- [ ] F — NSE generic fallback banner
- [ ] G — macOS menu bar + popover
- [ ] All 11 flows pass on a real iPhone **and** a real Mac (not just the Simulator)
