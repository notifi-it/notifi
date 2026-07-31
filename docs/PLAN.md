# notifi — Apple-only rebuild: implementation plan

This is the implementation-ready version of the notifi rebuild plan. It settles every
micro-decision so the implementer never has to guess. If something is not specified
here, prefer the simplest option that keeps the invariants in "Hard rules" below.

**Appendices A–F at the bottom are normative.** They contain the protocol constants,
reference implementations for every cryptographic component, fixture formats, and a
trap list. When prose and appendix code disagree, the appendix wins. Implement the
crypto spine (Appendix order) before any route or view.

**This plan builds a NEW standalone repo (`notifi/`), not a service in this monorepo.**
Nothing in `apps/` here should be touched.

---

## 0. Corrections to the original plan

These are real problems found in review. They are already folded into the spec below —
listed here so nobody "fixes" them back.

1. **`messages.id` needs `AUTOINCREMENT`.** A plain `INTEGER PRIMARY KEY` is the rowid,
   and SQLite reuses the max rowid after the newest row is deleted (e.g. a device
   cascade-delete). The `since=` bookmark requires ids that only ever go up, so
   `messages` uses `INTEGER PRIMARY KEY AUTOINCREMENT`. The other two tables keep plain
   rowids.
2. **Secure Enclave is not on every supported Mac — those Macs are simply not
   supported.** macOS 14 runs on a handful of Intel Macs without a T2 chip; rather
   than carry a software-key fallback, the app requires the Secure Enclave and shows
   an "unsupported Mac" screen (`ContentUnavailableView`) when
   `SecureEnclave.isAvailable` is false — it must say *which* Macs work ("Requires a
   Mac with Apple silicon or a T2 chip") and include a Quit button, since a menu-bar
   app has no Dock icon to quit from; put the same requirement line in the Mac App
   Store description, because the store can't gate on Secure Enclave presence.
   Every iPhone on iOS 17 has one, so iOS is unaffected. The single exception is the iOS **Simulator**, which has no Secure
   Enclave: a software signing key exists behind `#if targetEnvironment(simulator)`
   only, so it cannot ship in any device build.
3. **The APNs JWT is not "hourly".** Apple requires refresh between 20 and 60 minutes;
   refreshing more often than every 20 minutes gets `TooManyProviderTokenUpdates`.
   Cache the JWT in isolate memory for 50 minutes.
4. **One UPDATE, not three.** The send path folds `sent_count`, `last_used_at`, and the
   rate-limit window into a single UPDATE on `keys`, keeping a send at exactly 2 row
   writes (key update + message insert) — the free-tier math in the original plan
   depends on this.
5. **Registering for a device token does not need notification permission.** Register
   for remote notifications on every launch unconditionally; ask for *notification
   permission* contextually (first key created / "Enable notifications" button), never
   at first launch. The permission dialog shows once, ever.
6. **`410 Unregistered` pruning needs the timestamp check.** Only delete the device if
   APNs' `timestamp` in the 410 body is newer than the device row's `last_seen_at` —
   otherwise a stale 410 can delete a device that just re-registered a fresh token.
7. **Simulator note for dev loop.** iOS Simulator on Apple silicon (Xcode 14+, macOS 13+)
   can receive real APNs pushes, and `xcrun simctl push` injects payloads locally —
   use simctl for NSE/UI iteration, real hardware for the Phase 0 end-to-end proof.

### Scope upgrades added during review

8. **Client-only decryption (sealed content).** Message content and key names are no
   longer encrypted with a server-held symmetric key. The device registers a second
   public key (an encryption key, next to the signing key), the Worker **seals content
   to it at ingest** (HPKE) and discards the plaintext. After the ingest instant, the
   server cannot read any message, ever — a full database dump plus every Workers
   secret reveals nothing. Honest caveat, documented in the README: the sender talks
   plain HTTPS (`curl` is the product), so the Worker does see plaintext in memory for
   the milliseconds of the request. Full sender-side E2E would require senders to
   fetch the device public key and run HPKE client-side, which kills the one-line
   `curl`. Consequences: APNs payloads carry ciphertext, so the Notification Service
   Extension decrypts before display and is **mandatory from Phase 1** (with a generic
   "New notification" fallback), and the app+NSE share a Keychain access group.
   Spec in §6, §8, §9.
9. **Rate limiting is three layers, not one.** Per-IP at the zone edge (WAF rule,
   Terraform), per-IP inside the Worker (rate-limiting binding — this also protects
   the dev `workers.dev` URL, which the zone WAF never sees), and the authoritative
   per-key window in D1. Spec in §7.

## Hard rules (do not violate, do not "improve")

- Exactly **six routes**. No `/v1/` prefix. No `unregister`, `recover`, `transfer`,
  `claim`, or any route that lets one keypair touch another device's data.
- No accounts, no sign-in, no device linking, no migration, no websockets, no Firebase.
- `/send` answers an unknown or revoked key with **`401`**, never `200`.
- User content (message content, key names) is **sealed to the device's encryption
  public key** — the server cannot decrypt it after ingest (spec §6). Operational
  columns the server must read (`apns_token`, `platform`, `app_version`) are
  AES-GCM-encrypted with a Workers secret. `secret_hash`, the two public keys, ids,
  and timestamps are the only plaintext.
- The server keeps a message until the device has synced it (ack-based retention),
  with a 90-day backstop only to reclaim space from devices that vanish. It is a
  relay, not a mailbox — retention is driven by received-or-not, not by a clock.
- The private key never leaves the device. There is no second credential.
- Server responses never contain a full send key except the one time `POST /keys`
  returns it.

---

## 1. Repo scaffold

```
notifi/
├── apps/
│   ├── app/                      # Xcode project — see §9
│   └── api/                      # Cloudflare Worker (TypeScript)
│       ├── src/
│       │   ├── index.ts          # Hono app, route wiring, error handler
│       │   ├── routes/
│       │   │   ├── devices.ts    # POST /devices
│       │   │   ├── keys.ts       # GET/POST /keys, DELETE /keys/:id
│       │   │   ├── send.ts       # GET|POST /send
│       │   │   └── history.ts    # GET /history
│       │   ├── lib/
│       │   │   ├── signature.ts  # device-signature auth middleware
│       │   │   ├── sendkey.ts    # key generation, hashing, prefix
│       │   │   ├── seal.ts       # HPKE seal to device key (no open exists here)
│       │   │   ├── fieldcrypto.ts# AES-GCM for operational columns
│       │   │   ├── apns.ts       # JWT cache + push + 410 handling
│       │   │   └── time.ts       # now(), window math
│       │   ├── scripts/
│       │   │   └── phase0-push.ts# throwaway: JWT + raw push to hardcoded token
│       │   ├── migrations/
│       │   │   └── 0001_init.sql
│       │   ├── wrangler.toml
│       │   ├── package.json
│       │   └── tsconfig.json
├── packages/
│   └── contract/
│       ├── src/index.ts          # Zod schemas, the single source of truth
│       ├── scripts/gen-vectors.ts# one-off crypto vector generator (Appendix E)
│       ├── fixtures/             # two committed vector files
│       └── package.json
├── infra/                        # Terraform — DNS zone settings + edge rate limit
├── .github/workflows/
│   ├── api.yml
│   ├── app.yml
│   └── infra.yml
├── Makefile
├── package.json                  # pnpm workspace root
├── pnpm-workspace.yaml
└── README.md
```

Toolchain: pnpm workspaces, TypeScript strict, wrangler v4. No ORM — D1's prepared
statements directly; the schema is three tables. **No automated tests and no code
comments anywhere in this project** — verification is manual (§14), and any
constraint a comment would carry belongs in this document instead.

Makefile targets (root):

```make
dev:        cd apps/api && wrangler dev            # local worker + local D1
deploy:     cd apps/api && wrangler deploy --env production
migrate:    cd apps/api && wrangler d1 migrations apply notifi-dev --local
```

---

## 2. Environments

Two wrangler environments, two D1 databases, two APNs hosts. This split is the single
most common way APNs silently breaks — treat it as load-bearing.

| | dev (default env) | production (`--env production`) |
|---|---|---|
| Worker name | `notifi-api-dev` | `notifi-api` |
| D1 database | `notifi-dev` | `notifi-prod` |
| Route | `workers.dev` subdomain | custom domain `notifi.it` |
| `APNS_HOST` var | `api.sandbox.push.apple.com` | `api.push.apple.com` |
| App build that talks to it | Xcode debug builds (Debug config `API_BASE_URL`) | TestFlight + App Store builds |

**Gotcha to encode in the README:** a TestFlight build gets a *production* APNs token.
TestFlight builds must point at the production Worker. Only local Xcode debug builds use
dev/sandbox.

Secrets (`wrangler secret put`, per env): `APNS_TEAM_ID`, `APNS_KEY_ID`,
`APNS_PRIVATE_KEY` (the `.p8` PEM contents), `ENCRYPTION_KEY` (64 hex chars = 32
bytes). Vars (in `wrangler.toml`): `APNS_HOST`, `APNS_TOPIC` (the app bundle id — one
bundle id shared by the iOS and macOS targets, e.g. `it.notifi.app`).

`wrangler.toml` sketch:

```toml
name = "notifi-api-dev"
main = "src/index.ts"
compatibility_date = "2026-07-01"

[[d1_databases]]
binding = "DB"
database_name = "notifi-dev"
database_id = "<filled by wrangler d1 create>"

[vars]
APNS_HOST = "https://api.sandbox.push.apple.com"
APNS_TOPIC = "it.notifi.app"

[triggers]
crons = ["0 3 * * *"]           # nightly expiry sweep

[env.production]
name = "notifi-api"
routes = [{ pattern = "notifi.it", custom_domain = true }]
[env.production.vars]
APNS_HOST = "https://api.push.apple.com"
APNS_TOPIC = "it.notifi.app"
[[env.production.d1_databases]]
binding = "DB"
database_name = "notifi-prod"
database_id = "<filled by wrangler d1 create>"
```

The cron handler sweeps in three chunked passes (`LIMIT 1000` loops to stay under D1
limits): first the acknowledged messages `DELETE FROM messages WHERE id IN (SELECT
m.id FROM messages m JOIN devices d ON d.id = m.device_id WHERE m.id <= d.acked_id …)`
— the primary rule; then the 90-day backstop `DELETE FROM messages WHERE expires_at <
?now` for messages on devices that never came back; then registration flood residue
`DELETE FROM devices WHERE last_seen_at < ?now - 2592000 AND id NOT IN (SELECT DISTINCT
device_id FROM keys)`.

---

## 3. Database schema

`apps/api/migrations/0001_init.sql`, applied with `wrangler d1 migrations apply`.
Two ciphertext kinds, both TEXT: **sealed** = HPKE to the device's encryption public
key, server cannot decrypt (§6a); **encrypted** = AES-GCM with the Workers secret,
server can decrypt (§6b). All timestamps are unix **seconds**, INTEGER.

```sql
CREATE TABLE devices (
  id                     INTEGER PRIMARY KEY,
  public_key             TEXT NOT NULL UNIQUE,
  encryption_public_key  TEXT NOT NULL,
  apns_token             TEXT NOT NULL,
  apns_token_hmac        TEXT NOT NULL UNIQUE,
  platform               TEXT NOT NULL,
  app_version            TEXT NOT NULL,
  created_at             INTEGER NOT NULL,
  last_seen_at           INTEGER NOT NULL,
  acked_id               INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE keys (
  id               INTEGER PRIMARY KEY,
  device_id        INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  meta_sealed      TEXT NOT NULL,
  secret_hash      TEXT NOT NULL UNIQUE,
  sent_count       INTEGER NOT NULL DEFAULT 0,
  rl_window_start  INTEGER NOT NULL DEFAULT 0,
  rl_window_count  INTEGER NOT NULL DEFAULT 0,
  created_at       INTEGER NOT NULL,
  last_used_at     INTEGER,
  revoked_at       INTEGER
);

CREATE TABLE messages (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  device_id       INTEGER NOT NULL REFERENCES devices(id) ON DELETE CASCADE,
  key_id          INTEGER REFERENCES keys(id) ON DELETE SET NULL,
  content_sealed  TEXT NOT NULL,
  created_at      INTEGER NOT NULL,
  expires_at      INTEGER NOT NULL
);

CREATE INDEX idx_messages_device ON messages(device_id, id);
CREATE INDEX idx_messages_expiry ON messages(expires_at);
```

Column notes: `public_key` is the signing key, `encryption_public_key` the sealing
target (both base64 X9.63); `apns_token`, `platform` and `app_version` are
operational-encrypted (§6b); `apns_token_hmac` is a deterministic HMAC-SHA-256 of the
raw token hex, keyed with `ENCRYPTION_KEY` — its UNIQUE constraint guarantees one
push token maps to one device row, so a stolen token cannot be registered under a
second keypair alongside the victim's (§7 `/devices` handles the eviction).
`devices.acked_id` is the retention watermark (§ Delivery): the highest message id the
device has provably synced, advanced by `/history`. `messages.id` uses AUTOINCREMENT
per §0.1; `expires_at = created_at + 7776000` (a 90-day **backstop**, not the delivery
guarantee — see Delivery).

Sealed blobs are one per row, not one per column. `messages.content_sealed` opens to
the validated send content **plus the row's own identity** —
`{title, message?, link?, image?, key_id, created_at}` — and `keys.meta_sealed` opens
to `{id, name, prefix}`. The app cross-checks the sealed `key_id`/`created_at`/`id`
against the row's plaintext metadata after opening; a mismatch means someone with
database write access swapped blobs between rows, and the blob is discarded as
tampered. Nullability of `link`/`image` lives inside the blob.

Notes for the implementer:
- `keys.secret_hash UNIQUE` doubles as the send-path lookup index. Three explicit
  indexes total, as designed.
- Revoking a key sets `revoked_at`; the row is never deleted through any route. The
  `ON DELETE SET NULL` on `messages.key_id` exists for defensive integrity only.
- D1 enforces foreign keys by default; the cascades are the account-deletion story.

---

## 4. The contract package

`packages/contract` is plain Zod, no codegen. It exports:

- `sendParams` — `{ key: string, title: string, message?: string, link?: string,
  image?: string }` with limits: `title` 1–200 chars; `message` ≤ 2000; `link` and
  `image` valid absolute URLs ≤ 2048 chars; `image` must be `https:`.
- `messageContent` — `sendParams` minus `key`, plus `key_id` and `created_at`; the
  plaintext inside every sealed message blob (§3 cross-check).
- `keyMeta` — `{ id, name, prefix }`; the plaintext inside every sealed key blob.
- `registerDeviceBody` (`{ public_key, encryption_public_key, apns_token, platform,
  app_version }`), `registerDeviceResponse` (`{ device_id: number }`)
- `keySummary` (`{ id, meta_sealed, created_at, last_used_at, sent_count,
  revoked_at }`), `listKeysResponse` (`{ keys: keySummary[] }`)
- `createKeyBody` (`{ name: string }` 1–64 chars),
  `createKeyResponse` (`{ id, name, key }` — `name` is the plaintext echo; `key` is
  the one-time full key)
- `historyQuery` (`{ since?: number, limit?: number }` — `limit` default 50, max 200),
  `historyMessage` (`{ id, content_sealed, key_id, created_at }`),
  `historyResponse` (`{ messages: historyMessage[], latest_id: number | null }`)
- `sendResponse` (`{ id: number }`)
- `apiError` (`{ error: { code: string, message: string } }`)

Error codes (closed set): `bad_signature`, `stale_timestamp`, `unknown_device`,
`unknown_key`, `rate_limited`, `invalid_request`, `not_found`.

The Swift `ContractModels` structs mirror these schemas by hand (~10 structs with
explicit `CodingKeys`). There is no codegen and no golden-fixture test suite — when a
schema changes, change the Swift mirror in the same commit; the monorepo is what makes
that a one-commit operation. The only files in `fixtures/` are the two crypto vectors
from Appendix E.

---

## 5. Authentication

### 5a. Device signature auth (`POST /devices`, `GET/POST /keys`, `DELETE /keys/:id`, `GET /history`)

Headers on every signed request:

```
X-Notifi-Public-Key: <base64 of X9.63 uncompressed P-256 public key, 65 bytes>
X-Notifi-Timestamp:  <unix seconds, as decimal string>
X-Notifi-Signature:  <base64 of raw 64-byte P-256 ECDSA signature (r ‖ s)>
```

Canonical string to sign (UTF-8, joined with `\n`):

```
METHOD \n host \n path-with-query \n timestamp \n hex(sha256(raw body bytes))
```

- `host` must match the server's `new URL(req.url).host`, which **includes a
  non-default port**. Production (`notifi.it` on 443) has no explicit port, so both
  sides read `notifi.it`; but local dev on `http://localhost:8790` must sign
  `localhost:8790`, not `localhost`. The Swift side appends `components.port` when
  present. (Found the hard way: a port-less host signs fine against prod and 401s
  against any local Worker on a custom port.)
  Binding it means a request captured against the dev Worker can never replay
  against production, and vice versa — the same phone identity talks to both.

- `path-with-query` is exactly what's sent on the wire: `/history?since=41&limit=50`.
  Including the query prevents replaying a signature against different params.
- Empty body (GET, DELETE) hashes the empty byte string
  (`e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`).
- Reject if `|server_now − timestamp| > 60` seconds → `401 stale_timestamp`.
- Verify with WebCrypto: `importKey("raw", …, { name: "ECDSA", namedCurve: "P-256" })`
  then `verify({ name: "ECDSA", hash: "SHA-256" }, key, signature, canonicalBytes)`.
  WebCrypto expects the raw `r‖s` signature format — which is exactly CryptoKit's
  `rawRepresentation`. Do not use DER anywhere.
- `POST /devices` is the only signed route that doesn't require the device row to
  already exist (it upserts it). Every other signed route resolves
  `public_key → devices.id`; no row → `401 unknown_device`. On success, bump
  `last_seen_at` (fold into whatever UPDATE the route already does; for pure reads
  update it only if it's stale by > 1 hour, to keep reads cheap).

The Swift side mirrors this exactly (§9c). Both implementations are checked once,
manually, against the committed vector in
`packages/contract/fixtures/signature-vector.json` (Appendix E) before any route is
built on top of them.

### 5b. Send keys (`/send` only)

- Format: `nk_` + 43 chars of base64url (32 random bytes, no padding). Generated
  server-side with `crypto.getRandomValues`.
- `prefix` = `nk_` + first 4 chars of the random part (matches the `nk_7f3a` the UI
  shows). Stored sealed to the device (§6a) — in the clear it would hand a database
  dump the first characters of every key.
- `secret_hash` = lowercase hex SHA-256 of the **entire** key string including `nk_`.
- Lookup is exact-match on `secret_hash`. Unknown hash OR `revoked_at IS NOT NULL`
  → `401 unknown_key` (same code for both — don't leak that a key existed).

---

## 6. Encryption at rest

Two mechanisms, two threat models. Get the classification right and the rest is
mechanical.

### 6a. Sealed content — only the client can decrypt

For everything that is *user content*: `messages.content_sealed` and
`keys.meta_sealed`.

- **HPKE** (RFC 9180), ciphersuite `DHKEM(P-256, HKDF-SHA256)` + `HKDF-SHA256` +
  `AES-256-GCM` — the one suite CryptoKit and the Worker both speak.
  - Worker: `@hpke/core` (a real dependency is fine on the API side; the *app* is the
    zero-dependency target). Seal-only — the Worker never holds an opening key.
  - Device: CryptoKit `HPKE.Recipient` (iOS 17+/macOS 14+) with the device's
    P-256 key-agreement private key.
- Stored value: `base64(enc ‖ ct)` where `enc` is the 65-byte encapsulated key and
  `ct` the HPKE ciphertext. HPKE `info` parameter = the blob kind (`"content"`,
  `"key_meta"`) so a blob can't be replayed into a different column; the device must
  pass the same `info` when opening. Row identity travels *inside* the sealed JSON
  (§3) — the app rejects a blob whose sealed ids don't match the row it came on, so
  a database-level attacker can't shuffle history or key names around either.
- `seal(recipientPublicKey, info, plaintext) → string` in `lib/seal.ts`. There is
  deliberately no `open` on the server — the function does not exist in Worker code.
- The Worker seals at ingest (`/send` seals the validated `messageContent`;
  `POST /keys` seals the `keyMeta`) and drops the plaintext. From that
  point the content is unreadable to the server, to Cloudflare, and to anyone holding
  every secret in the account. What the server still sees: sizes, timestamps, ids,
  which key sent what — metadata, stated plainly in the README.
- Losing the phone loses the history: already the product's stated deal. Losing
  `ENCRYPTION_KEY` (§6b) now costs *nothing* user-visible except re-registration.

### 6b. Operational encryption — server-readable, secret-holder-only

For the columns the Worker must read to do its job: `devices.apns_token`,
`devices.platform`, `devices.app_version`.

- AES-256-GCM via WebCrypto. Key = `ENCRYPTION_KEY` secret (32 bytes hex), imported
  once per isolate. Fresh random 12-byte IV per value; stored as
  `base64(iv ‖ ciphertext‖tag)`. `lib/fieldcrypto.ts`:
  `encryptField(plaintext) → string`, `decryptField(stored) → string`. No key
  rotation support.
- GCM hides content, not length — `"ios"` vs `"macos"` is readable from the blob
  size alone. Right-pad `platform` and `app_version` with spaces to 16 chars before
  encrypting and trim after decrypting.

Verification of both mechanisms is the manual vector check in Appendix E — done once
when the crypto spine lands, before any route uses it.

---

## 7. Route specifications

All responses are JSON. Errors use the `apiError` shape with the codes from §4.
Add `Access-Control-Allow-Origin: *` on `/send` responses only (people will call it
from browser scripts; the signed routes are app-only and get no CORS).

### `POST /devices` — signature auth

Body: `registerDeviceBody`. `public_key` must equal the `X-Notifi-Public-Key` header
(reject `invalid_request` if not — prevents signing for one key and registering
another). `encryption_public_key` must parse as a valid P-256 point.

Compute `apns_token_hmac` (HMAC-SHA-256 of the token hex, keyed with
`ENCRYPTION_KEY`). First delete any row holding the same `apns_token_hmac` under a
**different** `public_key` — one physical device is one row, and a re-registration
evicts whoever held the token before (a stolen-token squatter, or this device's own
pre-reinstall row). Then upsert on `public_key`: insert new row, or update
`encryption_public_key`, `apns_token`, `apns_token_hmac`, `platform`, `app_version`,
`last_seen_at` on conflict. Response `200 { device_id }` both ways. The app calls
this on **every launch** after the token callback — it self-heals token rotation,
restores, OS updates, and any eviction that hit it.

### `GET /keys` — signature auth

Rows for this device, newest first, returning `meta_sealed` verbatim — the device
opens them for display. Never returns `secret_hash`, never a full key. Includes
revoked keys (`revoked_at` set) so the UI can grey them out.

### `POST /keys` — signature auth

Body `{ name }`. Generates the key (§5b), inserts the row with a placeholder
`meta_sealed` using `RETURNING id`, seals the `keyMeta` `{id, name, prefix}`, and
updates the row with it (two writes — fine, this is a management route, not the hot
path). Returns `200 { id, name, key }` — the only time the full key ever appears in
a response. Cap: 50 active keys per device → `invalid_request` beyond that.

### `DELETE /keys/:id` — signature auth

Sets `revoked_at = now` where `id = :id AND device_id = <this device>` and not already
revoked. Missing/foreign id → `404 not_found`. Success → `204`. Effective on the next
`/send` because the send-path lookup filters on `revoked_at IS NULL` — nothing cached,
nothing to propagate.

### `GET|POST /send` — send-key auth, the only public route

Input: query params on GET; JSON body or form-encoded on POST (accept both; query
params win if duplicated). The key may also arrive as `Authorization: Bearer nk_…` —
the **preferred** form, and the one the docs lead with for anything that isn't a
one-off curl: keys in query strings end up in shell history, proxies, and edge
firewall logs (§11). Validate with `sendParams` → `400 invalid_request`. All `/send`
responses set `Cache-Control: no-store`.

Rate limiting is layered — IP first (cheap, pre-database), key second
(authoritative):

| Layer | Where | Limit | Purpose |
|---|---|---|---|
| Edge WAF rule | zone, Terraform (§11) | 300 req/min/IP on `/send`, block 60 s | pre-Worker flood backstop on `notifi.it` (free plan includes exactly one rule) |
| Worker IP limiter | rate-limiting binding | 100 req/min/IP → `429` | caps key-guessing and 401-probe DB reads; also covers the dev `workers.dev` URL the zone WAF can't see |
| Per-key window | D1, in the send UPDATE | 120/hour/key → `429` | the product-level limit; exact, survives colo distribution |

The Worker IP limiter is **not** `/send`-only: the same binding check runs first on
all six routes. Signed routes are otherwise free to flood — a script can mint
throwaway keypairs and hammer `POST /devices` (an ECDSA verify + a D1 write each)
with no send key at all. Two more guards on that route specifically: the
`apns_token_hmac` UNIQUE constraint (§3) bounds rows per real device, and the nightly
cron also prunes device rows that have zero keys and a `last_seen_at` older than 30
days — abandoned registrations and flood residue age out on their own.

The Worker binding in `wrangler.toml` (per-colo and approximate by design — that's
fine, it's a shield, not the product limit; syntax may drift while the binding is in
beta, check current wrangler docs):

```toml
[[unsafe.bindings]]
name = "SEND_IP_LIMIT"
type = "ratelimit"
namespace_id = "1001"
simple = { limit = 100, period = 60 }
```

Flow (exactly this order):
0. `SEND_IP_LIMIT.limit({ key: request.headers.get("CF-Connecting-IP") })` — not ok
   → `429 rate_limited` before touching the database.
1. `secret_hash` lookup joined to `devices` → key row + device `apns_token`
   (decrypted) + `encryption_public_key`, else `401 unknown_key`.
2. Rate limit + usage bump in **one** UPDATE (fixed 1-hour window, limit 120/hour):

   ```sql
   UPDATE keys SET
     rl_window_count = CASE WHEN rl_window_start = ?w THEN rl_window_count + 1 ELSE 1 END,
     rl_window_start = ?w,
     sent_count      = sent_count + 1,
     last_used_at    = ?now
   WHERE id = ?key_id AND revoked_at IS NULL
     AND (rl_window_start != ?w OR rl_window_count < 120)
   RETURNING id
   ```

   `?w` = `floor(now/3600)*3600`. No row returned → `429 rate_limited` with
   `Retry-After: <seconds to window end>`.
3. Seal the validated `messageContent` — including `key_id` and `created_at` — to
   the device's `encryption_public_key` (§6a); INSERT the message (`content_sealed`,
   `expires_at = now + 7776000`, the 90-day backstop) `RETURNING id`. Plaintext is not
   referenced after this step.
4. Push to APNs (§8). APNs failures do **not** fail the request — history is the
   delivery guarantee; the push is a hint. `410` prunes the device (§8).
5. `202 { id }`.

That's 2 row writes per send, 1 read. Do not add more.

### `GET /history` — signature auth

Query: `since` (exclusive message id, default 0), `limit` (default 50, max 200).
`SELECT … WHERE device_id = ? AND id > ? ORDER BY id ASC LIMIT ?` on the
`(device_id, id)` index, return `content_sealed` verbatim (the server couldn't open
it if it wanted to), `{ messages, latest_id }` where `latest_id` = last id in this
page (or null if empty). Include rows even if their key was since revoked.

`since` is also the **acknowledgement**: the device only advances its bookmark after
durably storing a page, so a request for `since=B` proves it holds everything ≤ B.
The handler therefore advances the retention watermark in the same call —
`UPDATE devices SET acked_id = MAX(acked_id, ?since), last_seen_at = ?now` — which is
what lets the sweep drop acknowledged messages. Monotonic `MAX`, so it only moves
forward, and a bogus-high `since` only sacrifices the caller's own data. This makes
`/history` a tiny writer rather than a pure read, but it stays idempotent and safe to
repeat.

**Why the id cursor is safe** (the three failure modes and why they don't bite):
- *Out-of-order commit gaps* — the classic "id 43 visible before 42 commits, bookmark
  skips 42" bug is real on multi-writer stores (Postgres) but not on D1: SQLite is
  single-writer, so ids commit in order. Do not move this onto a multi-writer store
  without a fix.
- *Id reuse after delete* — prevented by `messages.id AUTOINCREMENT` (§0.1); a plain
  rowid would be reused after deleting the newest row and a device that already acked
  it would skip the replacement. Load-bearing, not decoration.
- *Client ordering* — the bookmark must advance only **after** the page is durably
  saved on-device (§9d). Save-then-advance; a crash mid-sync just re-fetches. Reorder
  it and, under ack-based retention, you get permanent loss.
- D1 read replicas, if ever enabled, are safe here: a lagging replica only delays a
  message to the next sync, never skips it.

---

## 8. APNs from the Worker (`lib/apns.ts`)

**JWT:** ES256-signed provider token. Header `{ alg: "ES256", kid: APNS_KEY_ID }`,
claims `{ iss: APNS_TEAM_ID, iat: now }`. Sign with WebCrypto (`importKey("pkcs8", …)`
from the `.p8` PEM). Cache `{ jwt, mintedAt }` in a module-level variable; reuse while
younger than 50 minutes. Never mint per-request.

**Request:**

```
POST {APNS_HOST}/3/device/{apns_token_hex}
authorization: bearer <jwt>
apns-topic: {APNS_TOPIC}
apns-push-type: alert
apns-priority: 10
apns-expiration: <message expires_at>
```

Payload — the server holds no plaintext by the time it pushes, so the alert is a
placeholder and the real content rides sealed. The NSE decrypts and rewrites it
before the banner renders (§9f):

```json
{
  "aps": {
    "alert": { "title": "notifi" },
    "sound": "default",
    "mutable-content": 1,
    "thread-id": "key-<key_id>"
  },
  "notifi": { "id": <message id>, "sealed": "<base64 enc‖ct>" }
}
```

`mutable-content: 1` always — the NSE is mandatory, not decoration: without it every
banner would read "notifi". `thread-id` groups the inbox by sending key for free.

**4 KB budget:** the worst-case `messageContent` (200 + 2000 + 2048 + 2048 chars)
does not fit a push after sealing + base64. The push carries a **preview seal**: the
same JSON with `message` truncated to 1000 characters and `link` dropped; the full
seal goes to the `messages` row and arrives via `/history` sync (which the app runs
on every notification anyway). Two `seal()` calls per send when the content is big;
skip the second seal when the full content already fits.

**Response handling:**
- `200` → done.
- `410` with reason `Unregistered` → parse the `timestamp` (ms) in the body; if it is
  newer than the device's `last_seen_at`, `DELETE FROM devices WHERE id = ?` and let
  the cascades erase the account. Otherwise ignore (stale 410).
- `403 ExpiredProviderToken` → drop the cached JWT, mint once, retry once.
- Anything else (429/5xx) → log via `console.error`, move on. No retry queue; the
  history endpoint is the guarantee.

**Never log the payload, the token, or full request URLs** — `/send` carries secrets
in the query string by design, so Workers logging must stay off for this route's
inputs.

---

## 9. The app (`apps/app`)

One Xcode project, Swift 6 strict concurrency, SwiftUI lifecycle. **Four targets:**

| Target | Platform | Notes |
|---|---|---|
| `notifi` (iOS) | iOS 17+ | bundle id `it.notifi.app` |
| `notifi` (macOS) | macOS 14+ | **same** bundle id `it.notifi.app` (legal across platforms; keeps one APNs topic) |
| `NotificationService` (iOS) | NSE | `it.notifi.app.nse` |
| `NotificationService` (macOS) | NSE | same source file, mac extension target |

Capabilities: Push Notifications on both app targets (`aps-environment` on iOS,
`com.apple.developer.aps-environment` on macOS — Xcode's capability sets the right
one), and **Keychain Sharing** on all four targets with one access group
(`$(AppIdentifierPrefix)it.notifi.shared`) — the NSE must read the encryption private
key to decrypt push content. The **macOS app and macOS NSE additionally need App
Sandbox (`com.apple.security.app-sandbox`) and outgoing network
(`com.apple.security.network.client`)** — mandatory for Mac App Store/TestFlight,
and without the network entitlement `URLSession` fails silently in sandboxed release
builds while debug builds work; add both in Phase 0, not at submission. No App
Groups needed (the NSE never touches the database — see 9f). Add Time Sensitive
Notifications later (Phase 3); apply for Critical Alerts entitlement during Phase 1
(lead time), wire it in Phase 3.

Shared source layout (folder `Shared/`, membership in both app targets):

```
Shared/
├── NotifiApp.swift            # @main, scenes per platform via #if os(...)
├── AppModel.swift             # @Observable root: identity, api, sync, permission state
├── Identity/
│   └── DeviceIdentity.swift   # §9b
├── API/
│   ├── APIClient.swift        # §9c
│   └── ContractModels.swift   # Codable mirrors of §4 (hand-written, ~10 structs)
├── Store/
│   ├── Message.swift          # SwiftData @Model
│   └── SyncEngine.swift       # §9d
├── Push/
│   ├── PushRegistrar.swift    # register + token → POST /devices
│   └── NotificationDelegate.swift  # §9e
└── Views/
    ├── InboxView.swift  MessageDetailView.swift
    ├── KeysView.swift   KeyDetailView.swift  CreateKeyView.swift
    ├── SettingsView.swift
    └── EmptyStateView.swift
```

### 9a. Scenes

```swift
@main struct NotifiApp: App {
  #if os(iOS)
  @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
  #else
  @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
  #endif

  var body: some Scene {
    #if os(iOS)
    WindowGroup { InboxRootView() }        // NavigationStack inside
    #else
    MenuBarExtra("notifi", systemImage: "bell.badge") {
      InboxRootView()                       // popover inbox
    }
    .menuBarExtraStyle(.window)
    Settings { SettingsTabsView() }         // Keys + Settings as toolbar tabs
    Window("Inbox", id: "inbox") { InboxRootView() }  // optional full window
    #endif
  }
}
```

The iOS `AppDelegate` exists for exactly two callbacks: the APNs token
(`didRegisterForRemoteNotificationsWithDeviceToken`) and setting
`UNUserNotificationCenter.current().delegate` at launch (before launch finishes —
delivers taps that launched the app). The macOS one carries a little more:
notification-tap navigation can't reach `openWindow` from a delegate, and a
`MenuBarExtra` window can't be opened programmatically on macOS 14 — so a tap writes
the target `serverID` into `AppModel`, activates the app, and the auxiliary
`Window("Inbox")` scene opens via an `openWindow` action captured from a live view.
Decide the activation policy up front: this app wants `LSUIElement` (`.accessory`) —
menu-bar-only, no Dock icon — which also means Settings opens from the popover, not
a menu bar.

### 9b. `DeviceIdentity` — two keypairs

```swift
protocol SigningIdentity {
  var publicKeyX963: Data { get }                 // 65 bytes
  func sign(_ digestInput: Data) throws -> Data   // raw 64-byte r‖s
}
protocol SealedBoxOpener {
  var encryptionPublicKeyX963: Data { get }
  func open(sealedB64: String, info: String) throws -> Data
}
```

**Signing key** (authenticates management calls):
- `SecureEnclave.P256.Signing.PrivateKey`, required. Persist its
  `dataRepresentation` in the Keychain (`kSecClassGenericPassword`, service
  `"it.notifi.identity"`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`).
- No Secure Enclave (a few Intel Macs) → the app shows an unsupported-device
  `ContentUnavailableView` at launch and does nothing else. No software fallback
  ships on any real device.
- Simulator only: a plain `P256.Signing.PrivateKey` behind
  `#if targetEnvironment(simulator)`, same Keychain rules,
  **`kSecAttrSynchronizable` absent/false** — dev convenience, unreachable in
  device builds.
- Signatures: `privateKey.signature(for: canonicalData).rawRepresentation` — matches
  the Worker's WebCrypto verify (§5a).

**Encryption key** (the sealing target for §6a):
- A software `P256.KeyAgreement.PrivateKey` — *not* Secure Enclave, for two reasons:
  CryptoKit's HPKE recipient doesn't take SE keys, and the NSE needs to use it.
  Stored in the **shared access group** (`…it.notifi.shared`), service
  `"it.notifi.encryption"`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`
  (pushes must decrypt while locked, after first unlock), `synchronizable = false` —
  same rule: iCloud Keychain sync would clone the account.
- `open` = CryptoKit `HPKE.Recipient` with ciphersuite
  `P256_SHA256_AES_GCM_256`, splitting the stored blob into `enc` (first 65 bytes
  after base64 decode) and ciphertext.

Both keypairs: `loadOrCreate()` on first access; created exactly once for the life of
the install. No export, no backup, no display of either private key anywhere.

### 9c. `APIClient`

Plain `URLSession`, async/await, no dependencies. One method per route, typed with
`ContractModels`. Signing interceptor builds the §5a canonical string (method,
path+query, unix-seconds timestamp, body SHA-256 hex) and sets the three headers.
`API_BASE_URL` comes from build settings: Debug → the dev workers.dev URL, Release →
`https://notifi.it`. Non-2xx decodes `apiError` and throws a typed `APIError` enum the
views can switch on.

### 9d. Store + sync

SwiftData model:

```swift
@Model final class Message {
  @Attribute(.unique) var serverID: Int
  var title: String
  var body: String?
  var link: URL?
  var imageURL: URL?
  var keyID: Int?
  var createdAt: Date
  var isRead: Bool = false
}
```

The on-device store is the permanent archive; nothing here expires. `SyncEngine`:

- Bookmark = `@AppStorage("lastSyncedMessageID")` (Int, default 0).
- `sync()`: loop `GET /history?since=bookmark&limit=200`; for each row, open
  `content_sealed` via `DeviceIdentity` (info `"content"`), decode `messageContent`,
  and **cross-check** the sealed `key_id`/`created_at` against the row's plaintext
  metadata — a mismatch means a swapped blob (§3); discard it. Upsert by `serverID`
  (insert-if-absent; existing rows keep their `isRead`). **Save the context, then
  advance the bookmark to `latest_id`** — save-before-advance is not optional: under
  ack-based retention the server deletes what the bookmark has passed, so advancing
  before a durable save is permanent data loss (a `save()` throw aborts the page and
  the bookmark stays put, so the page re-fetches next sync). Stop when a page comes
  back short. A blob that fails to open (key mismatch after a reinstall race) is
  skipped with a log, never fatal. Plaintext lives only on-device, in SwiftData — the
  archive the server never had. Safe to call from anywhere, reentrancy-guarded with a
  simple `isSyncing` flag.
- Read semantics, settled: opening the detail view marks a message read; tapping its
  notification marks it read; "Mark All as Read" lives in the inbox toolbar menu.
  The badge is the live count of `isRead == false`, recomputed on every sync and
  `scenePhase` change (`setBadgeCount`).
- Key list cache: the last successfully opened `keyMeta` list persists on device (a
  small Codable blob in Application Support — plaintext-on-device is already the
  trust model). The Keys page and the inbox filter render from the cache instantly,
  refresh on appear and pull-to-refresh, and show a quiet "couldn't refresh" note
  when offline instead of an error takeover.
- Triggers: app becomes active (`scenePhase`), pull-to-refresh, notification tap,
  and notification received in foreground. **That set is the entire offline story.**

### 9e. Notification handling (app process)

- `PushRegistrar`: on every launch call `registerForRemoteNotifications()`
  (no permission needed for the token); on the token callback, hex-encode and
  `POST /devices`. On `didFailToRegister…` just log — Simulator without APNs support
  lands here.
- Permission: requested from the Empty state's "Enable notifications" button, and
  automatically **on dismissal of the first key's reveal sheet** — not on creation,
  or the system dialog lands on top of the one screen where the user must not be
  distracted. Never at launch. Handle `.denied` with a jump to system settings
  (`UIApplication.openNotificationSettingsURLString`; on macOS the
  `x-apple.systempreferences:` Notifications-pane anchor — verify the anchor string
  at implementation, it drifts between releases).
- Restore detection: SwiftData messages survive a backup restore, but both Keychain
  items are `ThisDeviceOnly` and don't. "Messages exist but no identity" is
  therefore an unambiguous restored-phone state — before creating the fresh
  identity, show a one-time full-screen explainer: this is a new device, the old
  keys died with the old one, anything still sending to them now gets `401`. This
  is the one moment the no-migration rule can be explained when it actually
  matters.
- Delegate `willPresent` → `[.banner, .sound, .badge]` and kick `sync()` (without this
  method, foreground pushes are silently dropped).
- Delegate `didReceive` (tap) → `sync()`, then navigate to the message whose
  `serverID == userInfo["notifi"]["id"]` via a `NavigationPath` owned by `AppModel`.

### 9f. Notification Service Extension — decrypt, then decorate

One `NotificationService.swift` shared by both NSE targets. Scope: **decrypt the
sealed content and attach the image** — it reads the encryption key from the shared
Keychain group but does not touch SwiftData or the API (no App Group; cross-process
SwiftData is a tar pit this product doesn't need).

- `didReceive`: copy to `bestAttemptContent`; base64-decode `notifi.sealed`, open via
  the shared-group encryption key (info `"content"`), decode `messageContent`, set
  `title`/`body` from it. If it decodes an `image`: download (https only, 15 s
  `URLSession` timeout), move to a tmp file **with a file extension matching the
  content type**, attach via `UNNotificationAttachment`. Deliver.
- Decryption failure (no key yet, tampered blob) → deliver with the generic title
  "notifi" and body "Open notifi to view" — never crash, never drop, and the
  fallback names the recovery action (tapping syncs and resolves the content).
- `serviceExtensionTimeWillExpire`: deliver `bestAttemptContent` as-is (decrypt is
  microseconds, so in practice this only fires mid-image-download — text will already
  be rewritten). If neither handler fires, the notification vanishes entirely — this
  override is not optional.
- Test loop: `xcrun simctl push booted it.notifi.app payload.json` with a payload
  matching §8, sealed with the committed test recipient key — **iOS only**; there is
  no simctl equivalent for macOS, and the mac NSE only runs for properly
  signed/provisioned builds. Verify the mac NSE with a real sandbox push (extend the
  Phase 0 script) on hardware during Phase 1.

### 9g. Views (system components only — the point of the rewrite)

- **Inbox**: `NavigationStack` + `List`, large title. `.swipeActions` (leading: mark
  read/unread; trailing: delete, destructive). `.contextMenu`: Copy Title, Copy
  Message, Open Link (if any), Delete. `.searchable` over title+body, with a
  filter-by-key menu in the toolbar (keys fetched via `GET /keys`, matched on
  `keyID`). `.refreshable { await sync() }`. Rows: title, 2-line `lineLimit` body,
  relative timestamp, unread dot. Detail view: full text selectable, `AsyncImage`
  full-width for `imageURL`, `Link` button for `link`, `ShareLink` in the toolbar.
- **Empty state**: `ContentUnavailableView` with the app icon, one-line pitch, and the
  two onboarding actions: Create First Key, Enable Notifications. Shown when the
  message store is empty.
- **Keys**: grouped `List` of `keySummary` rows (from the cache, §9d) — name, masked
  value (`nk_7f3a…`, from the opened `keyMeta` prefix), live `sent_count`,
  greyed-out section for revoked keys. Detail: full metadata, Copy (of the
  prefix-masked identity only — the full key does not exist client-side after
  creation), `last_used_at`, destructive Revoke in its own section with a
  confirmation dialog. **Create flow**: name field → calls `POST /keys` → one-time
  reveal screen: key large and `.monospaced`, Copy button, `ShareLink`, and the
  mandatory caption verbatim: *"This key lives and dies with this device. If you
  lose the device, the key stops working and cannot be recovered."*
- **The reveal screen is guarded.** `.interactiveDismissDisabled()` — a stray swipe
  must not be the last time the key is visible. The Done button, if Copy/ShareLink
  was never tapped, raises a `confirmationDialog`: "Haven't copied it? This key will
  never be shown again." with **Copy and Close** and **Close and Revoke** (the
  second prevents a zombie row that can never be used). After dismissal the app does
  not hold the key.
- **On macOS the reveal never lives in the popover.** `MenuBarExtra(.window)`
  closes on focus loss, and the canonical next action is clicking Terminal to
  paste — which would destroy the key mid-journey. "Create Key" in the popover
  opens the flow in the real `Window` scene via `openWindow`; the reveal survives
  focus changes there.
- **Settings**: plain `Form`. Notification permission status row (live, with jump to
  system settings when off), **Send Test Notification** button — settled: it
  composes three existing routes client-side, `POST /keys` (name `Test —
  <date>`) → `/send` with the returned key while still in memory → `DELETE
  /keys/:id`. That exercises the entire real pipe (send auth, sealing, APNs, NSE
  decrypt) and leaves no residue; never a seventh route. Badge toggle
  (`setBadgeCount` from unread), About (version, link to notifi.it).
- Accessibility, the three things stock components don't fix: the unread dot gets
  folded into the row's `accessibilityLabel` ("Unread, Deploy finished, …") — never
  a color-only signal; the reveal screen exposes the key as one element whose
  primary accessible action is Copy (a 46-char string read glyph-by-glyph is where
  VoiceOver users would fail the core journey); masked key rows read as "Key,
  Grafana, ends 7f3a" rather than raw glyph soup.
- Semantic colors and system fonts only. No custom palette, no third-party
  dependencies in the app. Zero SPM packages is a feature; hold that line.

### 9h. Contract mirroring rules (Swift)

`ContractModels` structs use explicit `CodingKeys` matching the contract's snake_case
field names exactly (no `.convertFromSnakeCase` — implicit conversion hides drift).
When a schema in `packages/contract` changes, the Swift mirror changes in the same
commit.

---

## 10. CI (`.github/workflows/`)

Path-filtered from the first commit:

- `api.yml` — triggers on `apps/api/**` and `packages/contract/**`. Ubuntu runner:
  pnpm install, typecheck, then on `main` push: `wrangler deploy` (dev env)
  and `wrangler deploy --env production` behind a manual `workflow_dispatch` or a
  `production` GitHub environment approval. Secrets: `CLOUDFLARE_API_TOKEN`.
- `app.yml` — triggers on `apps/app/**` and `packages/contract/**`. macOS runner:
  `xcodebuild build -scheme notifi-iOS -destination 'platform=iOS Simulator,...'`
  and the macOS scheme (`CODE_SIGNING_ALLOWED=NO` for PR builds). TestFlight upload
  runs only on tags, not every push — macOS minutes are the expensive resource; PRs
  get a build only. Upload via `xcodebuild -exportArchive` with an upload-destination
  export-options plist and an App Store Connect API key, or fastlane `pilot` —
  **not `altool`, which Apple discontinued in 2023**. Required repo secrets for the
  tag lane: distribution cert, provisioning profiles (or cloud signing), ASC API
  key.
- `infra.yml` — `infra/**`: `terraform plan` on PR, `apply` on merge to main.
  Secrets: `CLOUDFLARE_API_TOKEN`, `TF_STATE` backend config (Terraform Cloud free or
  an R2 backend — pick R2, it's already in the account).

The contract package triggering **both** pipelines is the drift guard. Don't weaken
those path filters.

---

## 11. Terraform (`infra/`)

Only what wrangler can't express:

- Cloudflare zone settings for `notifi.it` (SSL mode full-strict, always-HTTPS).
- One edge rate-limit rule: per-IP, `/send`, 300 requests/min → block 60 s — the
  outermost of the three layers in §7 (the free plan includes exactly one rate-limit
  rule; spend it here). **Known cost, accepted with eyes open:** Cloudflare's
  security-event log records the full matched URI, so a blocked `/send?key=nk_…`
  deposits a live key in the dashboard/Logpush. That's one more reason the
  `Authorization: Bearer` form is the documented default (§7); note it in the
  `infra/` README next to the rule.
- API token definitions if managing tokens as code; nothing else. DNS for the Worker
  custom domain is handled by wrangler's `custom_domain = true` — do not duplicate it
  in Terraform.

---

## 12. Build order

### Phase 0 — prove the pipe (~1 week; do nothing else first)

- [ ] Apple Developer portal: create App ID `it.notifi.app` with Push Notifications;
      create an APNs auth key (`.p8`), note key id + team id.
- [ ] Minimal Xcode project, both app targets, push capability, `AppDelegate` that
      registers and prints the hex token for each platform.
- [ ] `apps/api/src/scripts/phase0-push.ts`: standalone script (runs under
      `wrangler dev` or plain node with WebCrypto) that mints the ES256 JWT and POSTs a
      hardcoded payload to a hardcoded token against the **sandbox** host.
- [ ] Run it against a real iPhone token and a real Mac token — first from the
      laptop, then **from a deployed dev Worker**. APNs is HTTP/2-only and node's
      `fetch` succeeding proves nothing about workerd's outbound `fetch`; this is
      the one external bet under the whole backend, so settle it before writing a
      single route.

**Done when** a push lands on both physical devices *from the deployed dev Worker*.
Commit the script; it becomes the debugging tool every APNs regression reaches for
later.

### Phase 1 — thin line end to end (2–3 weeks)

Order matters; the first item is a day now or a week later:

- [ ] Scaffold the monorepo exactly as §1; both wrangler envs; both D1 databases;
      migration 0001; all three CI workflows with path filters; Makefile.
- [ ] `packages/contract` schemas, plus `gen-vectors.ts` run once and its two vector
      files committed (Appendix E).
- [ ] Crypto spine, in appendix order, before any route: seal (C1) → signature
      verify (C2) → APNs (C3) on the Worker; DeviceIdentity (D1) → request signing
      (D2) in Swift — each checked manually against the committed vectors as it
      lands (Appendix E).
- [ ] Worker: fieldcrypto + seal, sendkey, signature middleware, then routes in this
      order: `POST /devices` → `POST /keys` → `GET|POST /send` (with both rate-limit
      layers + APNs) → `GET /history` → `GET /keys` → `DELETE /keys/:id`. Verify
      each with the curl walkthrough in §14 as it lands.
- [ ] Cron sweep handler.
- [ ] App: `DeviceIdentity` (both keypairs), `APIClient` + `ContractModels`,
      `PushRegistrar`, `Message` + `SyncEngine`, `NotificationDelegate`.
- [ ] **Minimal NSE on both platforms** — decrypt-and-rewrite only (§9f). Sealed
      content makes this Phase 1, not Phase 2: without it every banner says "notifi".
      Image attachment still waits for Phase 2. Verify on a real iPhone **and a real
      Mac** (keychain sharing and the mac NSE both lie in the Simulator — traps 10
      and 15).
- [ ] Ugly-but-working UI: Inbox list, one-shot key creation with reveal screen,
      pull-to-refresh. No images, no settings, no macOS chrome polish.
- [ ] **Apply for the Critical Alerts entitlement now** (weeks of Apple lead time).
- [ ] TestFlight build pointed at production env (see §2 gotcha).

**Done when** it's on TestFlight and routing your own real alerts.

### Phase 2 — make it good (3–4 weeks)

- [ ] Keys page complete: list, detail, revoke with confirmation, revoked section.
- [ ] NSE image enrichment + `simctl push` test payloads committed.
- [ ] Notification actions: category `MESSAGE` with Open Link / Mark Read; register at
      launch; handle in `didReceive`.
- [ ] Inbox polish: search, filter-by-key, context menus, detail view, unread/badge.
- [ ] Empty state onboarding; Settings page incl. Send Test Notification and the
      permission health check row.
- [ ] macOS `MenuBarExtra` + Settings scene + optional window; unread count tints the
      menu bar icon.
- [ ] Edge rate limit (Terraform) live; per-key 429s verified under a scripted loop.
- [ ] App Store submission for both platforms (budget real time for the first macOS
      App Review pass — and note "notarisation" is Developer ID distribution, not
      App Store; the store's own processing is what costs the time here).

**Done when** you'd let a stranger use it.

### Phase 3 — make it Apple (ongoing)

- [ ] App Intents: `GetLatestMessageIntent`, `SendNotificationIntent` (takes a stored
      key name), donated shortcuts; a Focus filter is a candidate too.
- [ ] WidgetKit: recent-alerts widget reading from the shared store — **this** is the
      point where an App Group + moving SwiftData into it becomes necessary; do the
      container migration then, not before.
- [ ] Critical Alerts wiring behind the granted entitlement: per-key opt-in flag,
      `sound.critical` payload path.
- [ ] Live Activities for message bursts (same `thread-id` within N minutes).

---

## 13. Decisions settled — implementer must not relitigate

| Question | Answer |
|---|---|
| One D1 vs Durable Object per device | Single D1 database. Revisit only if a single device gets hot. |
| Router framework | Hono. |
| ids | Integers everywhere; `messages` uses AUTOINCREMENT. |
| Timestamps | Unix seconds, INTEGER, everywhere including headers. |
| User-content storage | Sealed: HPKE `DHKEM(P-256,HKDF-SHA256)/HKDF-SHA256/AES-256-GCM`, `base64(enc‖ct)`, `info` = blob kind, row identity sealed inside the JSON. Server seals, only the device opens. |
| Operational-column storage | TEXT, `base64(iv‖ct‖tag)`, AES-256-GCM with `ENCRYPTION_KEY` (apns_token/platform/app_version only). |
| Message sealing granularity | One blob per message (`messageContent` JSON), not per column. |
| Signature format | Raw 64-byte P-256 `r‖s`, base64. Never DER. |
| Public key formats | Both keys X9.63 uncompressed (65 bytes), base64. Signing key Secure Enclave required (no-SE Macs unsupported; simulator-only software fallback); encryption key software, shared Keychain group. |
| Send key format | `nk_` + 43 base64url chars; prefix = `nk_` + 4 chars; SHA-256 hex hash. |
| Rate limiting | Three layers: edge WAF 300/min/IP, Worker binding 100/min/IP, D1 key window 120/hour. Key window is authoritative. |
| Replay window | ±60 s. |
| History paging | `since` exclusive, limit 50 default / 200 max. |
| Bundle id | One (`it.notifi.app`) for both platforms; NSEs append `.nse`. Consequence: a single App Store Connect record with universal purchase — shared name, pricing, and ratings, effectively irreversible. Accepted. |
| Rate limiting scope | The Worker IP binding runs on all six routes; `/send` additionally gets the edge rule and the per-key window. |
| App dependencies | None. Zero SPM packages. (The Worker may use `@hpke/core`.) |
| NSE scope | Decrypt + rewrite (Phase 1), image attachment (Phase 2); no DB, no App Group (until the Phase 3 widget). |
| Sent-count freshness | Bumped in the send UPDATE; Keys page reads it live. Do not add a counter cache. |
| Unknown key on /send | `401`, identical body for unknown and revoked. |

## 14. Manual verification (no automated tests in this project)

There is no test suite, by decision. Each piece is verified by hand when it lands,
with the checks below. Run them against `wrangler dev` with the dev database.

**Crypto spine (once, before building routes):**
1. Signature: sign the Appendix B canonical string from a scratch Swift executable
   using the committed vector's private key; verify the committed `signature_b64`
   opens with the committed public key on the Worker side. A request from the real
   app to a stub signed route returning 200 closes the loop.
2. Sealing: run `gen-vectors.ts`, then open the committed `sealed_b64` from Swift
   with the vector's private key — the exact plaintext must come back, and a
   wrong-`info` open must throw. This is the cross-implementation proof.

**Route walkthrough (curl, after each route lands):**
1. Register the device from the app; row appears in `wrangler d1 execute` output.
2. Create a key in the app; copy it once.
3. `curl "…/send?key=nk_…&title=hello&message=world"` → `202 {id}`, phone buzzes.
4. Same curl with one character of the key changed → `401`.
5. Revoke the key in the app; original curl → `401`.
6. Loop the send 121× with a fresh key → last one `429` with `Retry-After`.
7. `/history` from the app shows the message; force-quit, resend, reopen → backfill.
8. `simctl push` a §8-shaped payload → banner shows decrypted title, not "notifi".
9. Delete the app, send again → within a day the device row is gone (410 prune).

Anything that can't be curl-verified (NSE on hardware, Keychain sharing, sandbox vs
prod) is on the trap list (Appendix F) — check those on a physical device.

## 15. Support playbook seeds (write into the repo README)

- "Works in debug, not TestFlight" → sandbox token sent to production host or vice
  versa. Check §2 table first, always.
- "Notifications stopped" → Focus mode or permission; the Settings health check and
  Send Test button exist precisely for this mail.
- "I got a new phone and my scripts return 401" → by design; the key died with the
  device. The 401 (not a polite 200) is what tells their monitoring loudly. The app
  also detects the restored-phone state and explains this on first launch (§9e).

Also write these three honesty lines into the public README: image URLs in messages
are fetched by the recipient's device (a sender can learn the device's IP and
online state from their own image server); message ids are a global counter, so a
`202 {id}` reveals system-wide send volume; and a send key embedded in a public web
page is public — anyone can use or exhaust it, so treat it accordingly and revoke
freely.

---

# Appendices (normative)

## Appendix A — Protocol constants, one table

Every magic value in the system. If a value appears in code but not here, it's wrong.

| Constant | Value |
|---|---|
| Signed-auth headers | `X-Notifi-Public-Key`, `X-Notifi-Timestamp`, `X-Notifi-Signature` |
| Canonical string | `METHOD + "\n" + host + "\n" + pathWithQuery + "\n" + timestamp + "\n" + bodySha256Hex` |
| Empty-body SHA-256 hex | `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855` |
| Replay window | ±60 seconds |
| Timestamps | Unix **seconds**, integers, everywhere (one exception: Appendix F trap 3) |
| Public keys (both) | P-256, X9.63 uncompressed, exactly 65 bytes, **standard base64 with padding** |
| Device signatures | ECDSA P-256 over SHA-256, **raw `r‖s`, exactly 64 bytes**, standard base64 |
| Send key | `nk_` + 43 chars **base64url, no padding** (32 random bytes) |
| Send key prefix | `nk_` + first 4 chars of the random part |
| `secret_hash` | Lowercase hex SHA-256 of the full key string including `nk_` |
| HPKE ciphersuite | DHKEM(P-256, HKDF-SHA256) + HKDF-SHA256 + AES-256-GCM |
| HPKE `info` strings | `content`, `key_meta` (exact, lowercase, no prefix/suffix) |
| Sealed blob layout | standard base64 of `enc(65 bytes) ‖ hpke ciphertext` |
| Operational blob layout | standard base64 of `iv(12 bytes) ‖ ciphertext‖tag` (AES-256-GCM) |
| APNs JWT | header `{alg:"ES256", kid}`, claims `{iss: teamId, iat}`, cache 50 min |
| Per-key rate window | 3600 s fixed, bucket `floor(now/3600)*3600`, limit 120 |
| Message retention | ack-based: kept until `messages.id <= devices.acked_id`; 90-day backstop (`expires_at`, 7776000 s) only for devices that never sync back |
| `apns_token_hmac` | Lowercase hex HMAC-SHA-256 of the token hex string, keyed with `ENCRYPTION_KEY` |
| Push preview truncation | `message` cut to 1000 chars, `link` dropped |
| Base64 rule of thumb | base64url = send keys and JWT segments only; standard base64 = everything else |

## Appendix B — Worked signature example

Both implementations must reproduce this end to end (the concrete bytes live in the
committed vector, Appendix E):

```
Request:   GET https://notifi.it/history?since=41&limit=50   (no body)
Timestamp: 1753833600

Canonical string (5 lines joined with \n, no trailing newline):
GET
notifi.it
/history?since=41&limit=50
1753833600
e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
```

Rules that make the two sides agree:
- `pathWithQuery` = URL path + `?` + query **exactly as sent on the wire**. The app
  must build the URL once with `URLComponents` and derive the signed string from that
  same object — never rebuild or re-encode it. Signed-route query values are digits
  only (`since`, `limit`), so percent-encoding can never diverge. Do not add string
  query parameters to signed routes.
- For bodies: serialize the JSON **once**, hash those exact bytes, send those exact
  bytes. Never re-encode (key order changes, signature dies).

## Appendix C — Worker reference implementations

Library APIs drift; the protocol constants above are the contract. Adjust call names
to the installed version, never the byte formats.

### C1. `lib/seal.ts`

```ts
import { CipherSuite, DhkemP256HkdfSha256, HkdfSha256, Aes256Gcm } from "@hpke/core";

const suite = new CipherSuite({
  kem: new DhkemP256HkdfSha256(),
  kdf: new HkdfSha256(),
  aead: new Aes256Gcm(),
});

export async function seal(
  recipientPublicKeyB64: string,
  info: "content" | "key_meta",
  plaintext: string,
): Promise<string> {
  const pk = await suite.kem.deserializePublicKey(fromB64(recipientPublicKeyB64).buffer);
  const ctx = await suite.createSenderContext({
    recipientPublicKey: pk,
    info: new TextEncoder().encode(info),
  });
  const ct = new Uint8Array(await ctx.seal(new TextEncoder().encode(plaintext)));
  const enc = new Uint8Array(ctx.enc);
  const out = new Uint8Array(enc.length + ct.length);
  out.set(enc, 0);
  out.set(ct, enc.length);
  return toB64(out);
}
```

This module is seal-only — an open/decrypt function must never exist anywhere in
Worker code.

### C2. `lib/signature.ts`

```ts
const REPLAY_WINDOW_S = 60;

export async function verifyDeviceSignature(
  req: Request,
  rawBody: ArrayBuffer,
  nowS: number,
): Promise<{ ok: true; publicKey: string } | { ok: false; code: "bad_signature" | "stale_timestamp" }> {
  const pk = req.headers.get("X-Notifi-Public-Key");
  const ts = req.headers.get("X-Notifi-Timestamp");
  const sig = req.headers.get("X-Notifi-Signature");
  if (!pk || !ts || !sig || !/^\d{1,12}$/.test(ts)) return { ok: false, code: "bad_signature" };
  if (Math.abs(nowS - Number(ts)) > REPLAY_WINDOW_S) return { ok: false, code: "stale_timestamp" };

  const url = new URL(req.url);
  const pathWithQuery = url.pathname + url.search;
  const bodyHashHex = toHex(await crypto.subtle.digest("SHA-256", rawBody));
  const canonical = [req.method, url.host.toLowerCase(), pathWithQuery, ts, bodyHashHex].join("\n");

  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "raw", fromB64(pk), { name: "ECDSA", namedCurve: "P-256" }, false, ["verify"]);
  } catch { return { ok: false, code: "bad_signature" }; }

  const ok = await crypto.subtle.verify(
    { name: "ECDSA", hash: "SHA-256" }, key,
    fromB64(sig),
    new TextEncoder().encode(canonical));
  return ok ? { ok: true, publicKey: pk } : { ok: false, code: "bad_signature" };
}
```

`rawBody` is the exact received bytes (an empty `ArrayBuffer` for GET/DELETE);
`url.search` already includes the leading `?` or is empty, matching Appendix B.

### C3. `lib/apns.ts` — JWT mint + push

```ts
let cachedJwt: { jwt: string; mintedAt: number } | null = null;

async function providerJwt(env: Env, nowS: number): Promise<string> {
  if (cachedJwt && nowS - cachedJwt.mintedAt < 50 * 60) return cachedJwt.jwt;
  const header = b64url(JSON.stringify({ alg: "ES256", kid: env.APNS_KEY_ID }));
  const claims = b64url(JSON.stringify({ iss: env.APNS_TEAM_ID, iat: nowS }));
  const input = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8", pemToDer(env.APNS_PRIVATE_KEY),
    { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
  const sig = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" }, key, new TextEncoder().encode(input));
  cachedJwt = { jwt: `${input}.${b64urlBytes(new Uint8Array(sig))}`, mintedAt: nowS };
  return cachedJwt.jwt;
}

export async function push(env: Env, db: D1Database, device: DeviceRow, payload: object, expiresAt: number, nowS: number): Promise<void> {
  const doSend = async () => fetch(`${env.APNS_HOST}/3/device/${decryptField(device.apns_token)}`, {
    method: "POST",
    headers: {
      authorization: `bearer ${await providerJwt(env, nowS)}`,
      "apns-topic": env.APNS_TOPIC,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "apns-expiration": String(expiresAt),
    },
    body: JSON.stringify(payload),
  });

  let res = await doSend();
  if (res.status === 403) {
    const body = await res.json().catch(() => null) as { reason?: string } | null;
    if (body?.reason === "ExpiredProviderToken") { cachedJwt = null; res = await doSend(); }
  }
  if (res.status === 410) {
    const body = await res.json().catch(() => null) as { timestamp?: number } | null;
    if (body?.timestamp) {
      await db.prepare("DELETE FROM devices WHERE id = ? AND last_seen_at < ?")
        .bind(device.id, Math.floor(body.timestamp / 1000)).run();
    }
  }
}
```

The JWT cache is module-level and per-isolate by design. `pemToDer` strips the
BEGIN/END lines and base64-decodes the rest. The 410 delete puts the staleness check
**in the SQL**, not in JS — the in-memory `device.last_seen_at` was read before the
push, and the device may have re-registered in between; comparing against the live
row is what stops a stale 410 from cascade-deleting a live account. For any status
other than 200/403/410 (429, 5xx): `console.error` the status only and return —
history is the delivery guarantee, so a failed push never fails the request.
APNs speaks HTTP/2 only; whether the deployed Worker's outbound `fetch` negotiates
it acceptably is the single external bet in this design — Phase 0 settles it (§12).

## Appendix D — Swift reference implementations

### D1. `DeviceIdentity` (both keypairs)

```swift
import CryptoKit
import Foundation

enum IdentityConstants {
  static let service = "it.notifi.identity"
  static let encryptionService = "it.notifi.encryption"
  static let accessGroup = "\(teamIdPrefix)it.notifi.shared"
}

enum SigningKeyBox {
  case secureEnclave(SecureEnclave.P256.Signing.PrivateKey)
  #if targetEnvironment(simulator)
  case simulatorSoftware(P256.Signing.PrivateKey)
  #endif

  var publicKeyX963: Data { ... }
  func sign(_ canonical: Data) throws -> Data { ... }
}

struct DeviceIdentity {
  let signing: SigningKeyBox
  let encryption: P256.KeyAgreement.PrivateKey

  static func loadOrCreate() throws -> DeviceIdentity
  static func load() throws -> DeviceIdentity
  static func loadOpener() throws -> SealedBoxOpener

  func open(sealedB64: String, info: String) throws -> Data {
    guard let blob = Data(base64Encoded: sealedB64), blob.count > 65 else { throw NotifiError.badSealedBlob }
    var recipient = try HPKE.Recipient(
      privateKey: encryption,
      ciphersuite: .P256_SHA256_AES_GCM_256,
      info: Data(info.utf8),
      encapsulatedKey: blob.prefix(65))
    return try recipient.open(blob.dropFirst(65))
  }
}
```

Rules the code above must follow:

- `sign` receives the raw canonical `Data` — CryptoKit hashes with SHA-256
  internally. Never pre-hash (trap 6).
- `loadOpener()` reads **only** the shared-group encryption key and is the only
  entry point the NSE may use. `load()`/`loadOrCreate()` read the signing key too,
  which lives outside the shared group — inside the extension they will always
  throw, and on the Simulator they would appear to work (trap 10). This exact
  mistake ships as "every banner says notifi, only on real devices."
- Keychain storage, both keys: `kSecClassGenericPassword`,
  `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`, `kSecAttrSynchronizable`
  absent, and `kSecUseDataProtectionKeychain: true` on **every** SecItem call —
  harmless on iOS, mandatory on macOS, where its absence routes writes to the
  legacy login keychain and silently voids the access-group and accessibility
  semantics this design depends on. Signing key under `service`, **not** in the
  shared group, storing `dataRepresentation` (SE) or `rawRepresentation`
  (software); create the SE key with an explicit after-first-unlock access control
  rather than the default. Encryption key under `encryptionService` **with**
  `kSecAttrAccessGroup = accessGroup` so the NSE can read it, storing
  `rawRepresentation` (32 bytes).
- `loadOrCreate`: read both from the Keychain; if present, done. Otherwise create —
  an SE signing key, or throw `NotifiError.unsupportedDevice` when
  `SecureEnclave.isAvailable` is false (the app shows the unsupported screen and
  stops; simulator builds create the `simulatorSoftware` key instead); the
  encryption key is always a software `P256.KeyAgreement` key — write both, re-read.
  Never regenerate over an existing item: an existing key IS the account.

### D2. Request signing (in `APIClient`)

```swift
func signedRequest(method: String, components: URLComponents, body: Data?) throws -> URLRequest {
  let pathWithQuery = components.percentEncodedPath
    + (components.percentEncodedQuery.map { "?\($0)" } ?? "")
  let host = components.port.map { "\(components.host!):\($0)" }?.lowercased() ?? components.host!.lowercased()
  let timestamp = Int(Date().timeIntervalSince1970)
  let bodyHash = SHA256.hash(data: body ?? Data()).map { String(format: "%02x", $0) }.joined()
  let canonical = Data("\(method)\n\(host)\n\(pathWithQuery)\n\(timestamp)\n\(bodyHash)".utf8)

  var req = URLRequest(url: components.url!)
  req.httpMethod = method
  req.httpBody = body
  req.setValue(identity.signing.publicKeyX963.base64EncodedString(), forHTTPHeaderField: "X-Notifi-Public-Key")
  req.setValue(String(timestamp), forHTTPHeaderField: "X-Notifi-Timestamp")
  req.setValue(try identity.signing.sign(canonical).base64EncodedString(), forHTTPHeaderField: "X-Notifi-Signature")
  if body != nil { req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
  return req
}
```

`components` is THE URL: the same object produces both the request URL and the signed
path. Never rebuild the query string separately (trap 4).

### D3. Notification Service Extension

```swift
final class NotificationService: UNNotificationServiceExtension {
  private var contentHandler: ((UNNotificationContent) -> Void)?
  private var best: UNMutableNotificationContent?

  override func didReceive(_ request: UNNotificationRequest,
                           withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
    self.contentHandler = contentHandler
    best = request.content.mutableCopy() as? UNMutableNotificationContent
    guard let best else { contentHandler(request.content); return }
    best.title = "notifi"
    best.body = "Open notifi to view"

    guard let notifi = request.content.userInfo["notifi"] as? [String: Any],
          let sealed = notifi["sealed"] as? String,
          let opener = try? DeviceIdentity.loadOpener(),
          let plaintext = try? opener.open(sealedB64: sealed, info: "content"),
          let content = try? JSONDecoder().decode(MessageContent.self, from: plaintext)
    else { contentHandler(best); return }

    best.title = content.title
    if let message = content.message { best.body = message }

    guard let image = content.image, let url = URL(string: image), url.scheme == "https" else {
      contentHandler(best); return
    }
    let task = URLSession.shared.downloadTask(with: url) { [weak self] tmp, response, _ in
      defer { contentHandler(self?.best ?? best) }
      guard let tmp else { return }
      let ext = (response?.mimeType == "image/png") ? "png" : "jpg"
      let dest = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
      try? FileManager.default.moveItem(at: tmp, to: dest)
      if let attachment = try? UNNotificationAttachment(identifier: "image", url: dest) {
        self?.best?.attachments = [attachment]
      }
    }
    task.resume()
  }

  override func serviceExtensionTimeWillExpire() {
    if let contentHandler, let best { contentHandler(best) }
  }
}
```

The generic title/body set up front is the fallback for every failure below it — and
the body says "Open notifi to view" because tapping triggers a sync that resolves the
content, so even the failure state has a next step. The NSE calls `loadOpener()`,
never `load()` or `loadOrCreate()` — the full identity includes the signing key,
which is outside the shared group and unreadable from the extension, and key creation
belongs to the app process only. Every exit path calls `contentHandler` (trap 9).
Image downloads: reject anything over 5 MB (check `expectedContentLength`, count
bytes) and any content type outside `image/png`, `image/jpeg`, `image/gif`; stay
streamed-to-disk — the NSE memory ceiling is ~24 MB, so never `Data(contentsOf:)`.

## Appendix E — Committed fixtures and how they're made

`packages/contract/scripts/gen-vectors.ts` generates these **once**; they are
committed and never regenerated (HPKE and ECDSA are randomized — regeneration changes
the bytes and proves nothing). They exist for the manual crypto-spine check in §14.
These keys are throwaway and must never be used by a real device.

`fixtures/signature-vector.json`:

```json
{
  "private_key_raw_b64": "…32-byte P-256 scalar, for CryptoKit…",
  "private_key_pkcs8_b64": "…same key, PKCS#8 DER, for WebCrypto…",
  "public_key_x963_b64": "…65 bytes…",
  "method": "GET",
  "host": "notifi.it",
  "path_with_query": "/history?since=41&limit=50",
  "timestamp": 1753833600,
  "body_b64": "",
  "canonical_string": "GET\nnotifi.it\n/history?since=41&limit=50\n1753833600\ne3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  "signature_b64": "…64 bytes r‖s…"
}
```

Manual check on both sides (§14): rebuild `canonical_string` from the parts and
compare; verify `signature_b64` with the public key; sign fresh with the private key
and verify your own output. Never byte-compare fresh signatures — ECDSA is
randomized, only verification is meaningful.

`fixtures/sealed-vector.json`:

```json
{
  "recipient_private_key_raw_b64": "…32 bytes, for CryptoKit…",
  "recipient_private_key_pkcs8_b64": "…for the Worker-side open in tests only…",
  "recipient_public_key_x963_b64": "…65 bytes…",
  "info": "content",
  "plaintext": "{\"title\":\"Deploy finished\",\"message\":\"main → prod\"}",
  "sealed_b64": "…enc‖ct, sealed by gen-vectors.ts…"
}
```

Manual check (§14): Swift opens the **committed** `sealed_b64` with the raw private
key and gets back the exact plaintext — that is the cross-implementation proof. A
wrong-`info` open must throw. Remember `lib/seal.ts` has no open; the only opener in
the system is the device.

## Appendix F — Traps. Read twice before writing any crypto code.

1. **Two base64 alphabets.** Send keys and JWT segments are base64url without
   padding; every other blob is standard base64 with padding. Mixing them produces
   errors only on inputs containing `+`, `/`, `-` or `_` — i.e. intermittently.
2. **Raw vs DER signatures.** Everything here is raw 64-byte `r‖s`. If a signature is
   70–72 bytes, something emitted DER — wrong. (WebCrypto and CryptoKit
   `rawRepresentation` are both already raw; there is no conversion step anywhere.)
3. **Seconds vs milliseconds.** The whole system is unix seconds. The one exception:
   the APNs `410` body timestamp is **milliseconds** — divide by 1000. And in JS,
   `Date.now()` is milliseconds: `Math.floor(Date.now() / 1000)` everywhere.
4. **Path signing must not re-encode.** Derive `pathWithQuery` from the same
   `URLComponents`/`URL` object the request is actually sent with (D2). Signed routes
   keep query values numeric so percent-encoding can never diverge.
5. **Hash the bytes you send.** Serialize the body once; hash and transmit the same
   buffer. JSON re-serialization reorders keys and breaks the signature.
6. **Don't pre-hash before CryptoKit signing.** `signature(for: Data)` hashes
   internally. Signing a digest of a digest verifies nowhere.
7. **Sealed blob splits at byte 65** after base64 decoding — never at a character
   offset in the base64 string.
8. **`info` strings are load-bearing.** `content` / `key_meta`,
   exactly. A mismatch fails only at open time, on the phone, days later.
9. **Every NSE code path calls `contentHandler`.** A missed early return doesn't
   error — the notification silently ceases to exist.
10. **Keychain sharing fails only on device.** The Simulator ignores access groups; a
    missing `keychain-access-groups` entitlement on the NSE target works in the sim
    and returns `errSecItemNotFound` on hardware. Test D3 on a real phone early.
11. **Sandbox/production is per-build, not per-app.** Debug → sandbox host; TestFlight
    and App Store → production host. A token from one is `400 BadDeviceToken` on the
    other. This is 95% of "pushes stopped working."
12. **The dev loop needs `wrangler dev --remote` awareness.** Local `wrangler dev`
    can't reach APNs sandbox with the real `.p8` unless secrets are in
    `.dev.vars` — put dev copies there, gitignored.
13. **Zod strictness.** Signed-route bodies use `.strict()` (unknown fields are a bug
    in our own client). `/send` params stay non-strict — strangers' scripts send
    extra query params and must not 400.
14. **`ctx.waitUntil` for the APNs call is tempting — don't.** Await the push inline;
    a dropped-on-shutdown push with no error is undebuggable. The request budget
    comfortably covers one APNs round trip.
15. **macOS keychain is a different beast without one flag.** Every SecItem call
    sets `kSecUseDataProtectionKeychain: true` — harmless on iOS, mandatory on
    macOS, where omitting it writes to the legacy login keychain and silently voids
    access groups and accessibility classes. And the mac NSE only runs for properly
    signed builds, with no simctl equivalent — mac notification decryption can only
    be proven with a real sandbox push on hardware.
16. **The NSE can only load the opener.** `DeviceIdentity.load()` touches the
    signing key, which is outside the shared access group — inside the extension it
    always fails, and the Simulator hides it (trap 10). The extension uses
    `loadOpener()` exclusively. Verify the exact CryptoKit `HPKE.Recipient.open`
    overload compiles as written at implementation, and keep `Recipient` a `var` —
    `open` is mutating.
