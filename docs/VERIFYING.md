# notifi — how to verify it works

The companion to the build plan (`2026-07-30-notifi-apple-rebuild.md`). This is the
manual acceptance run — the plan says there are no automated tests, so **this
document is the test suite**. Work top to bottom; each flow has a command, the exact
result to expect, and the screenshot to capture as evidence.

## Setup (once per session)

```bash
cd apps/api
make dev        # Worker + local D1 on localhost:8787
make migrate    # apply 0001_init.sql to the local DB
```

Boot the two clients from Xcode, both Debug config (→ `localhost:8787`):

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
# local first — proves the JWT + payload are right
pnpm --filter api phase0-push --token $TOK

# then from the DEPLOYED dev Worker — the real test
curl "https://<dev>.workers.dev/__phase0?token=$TOK"
```

- **Expect:** APNs returns `200` (empty body); the device buzzes.
- **On `400 BadDeviceToken`:** sandbox/prod mismatch — a Debug build's token must go
  to `api.sandbox.push.apple.com`.
- **Why run it twice:** node's `fetch` succeeding proves nothing about workerd's
  outbound HTTP/2 to Apple. Only the deployed-Worker run counts.
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
xcrun simctl terminate booted it.notifi.app          # 1. kill the app
curl "$NB/send?key=$KEY&title=While%20you%20were%20out" # 2. send while dead
xcrun simctl launch booted it.notifi.app             # 3. reopen → SyncEngine runs
```

- **Expect:** the missed message appears in the inbox on reopen (backfilled via
  `/history?since=`).
- **Call it again** → no duplicates; the device owns the bookmark.
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
# → 200 …(×120)… 429
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
xcrun simctl push booted it.notifi.app bad-seal.apns.json
```

(`bad-seal.apns.json` = a §8-shaped payload sealed to the wrong recipient key.)

- **Expect:** the banner degrades to **"notifi · Open notifi to view"** — never a
  crash, never a vanished push.
- **Tapping it** triggers a sync that resolves the real content.
- **Also test on real hardware** — the Simulator ignores keychain access groups, so
  the "opener loads in the NSE" path (trap 16) only truly proves out on a device.
- 📸 **Screenshot F** — the greyed, still-tappable fallback banner.

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
xcrun simctl uninstall booted it.notifi.app
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
