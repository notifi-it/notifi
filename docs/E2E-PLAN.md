# Sender-side end-to-end encryption — plan

Today the Worker seals every message to the device's key at ingest; the gap is that
the sender posts plain HTTPS, so the Worker sees the plaintext for the length of the
request. This closes it for keys that opt in: the sender seals each field itself, and
the Worker runs its normal pipeline over the ciphertexts — including its own seal on
top. The server never sees plaintext; the device unwraps both layers.

Ported from notifi-swift PR #106, re-grounded against this repo. The companion CLI
plan (notifi-swift PR #121) is out of scope and stays parked.

---

## 1. How it works

Encryption is a **per-key setting**: each key carries an `is_encrypted` toggle in
Key Detail, off by default. Flipping it on generates a **fresh P-256 keypair for
that key alone** — distinct from the device's registered `encryption_public_key`,
which keeps sealing the server's own envelope. The private half lives in the device
keychain (shared with the NSE, as the device key already is); the public half is
**never sent to the server** — it appears only in Copy for scripts. Superseded
private halves are **kept forever** — a Renew or a toggle flip mints a new keypair
but never deletes the old one, or every row sealed to it dies. Because the server never learns it, the server
cannot construct a blob that opens: sender forgery is closed, not just documented
(§7). You flip a key on, copy its public key out of the app, and paste it into that
key's script next to its send key. Every send to that key must then carry sealed
fields — same parameter names, each value now `base64(HPKE-seal(value))`:

```
POST /send                    (GET works as today; POST recommended)
  key=nk_...
  title=<base64>              required, sealed
  message=<base64>            optional, sealed
  link=<base64>               optional, sealed
  image=<base64>              optional, sealed
  is_critical=1               optional, plaintext, as today
  occurred_at=1754899200000   optional, plaintext, as today
```

There is nothing to signal on the wire and nothing is detected: the key's setting
says what the server expects. The key lookup already returns the key row; when
`is_encrypted` is set, a send whose fields are not plausible ciphertexts (valid
base64, at least the 108-char HPKE floor) is `422 invalid_content` — the key
expects encryption and fails anything else, so one forgotten cron job cannot quietly
send plaintext. Flipping the toggle on breaks whatever script still posts plaintext
to that key until the script is updated; that is the toggle doing its job, and the
app says so before the flip (§5). Other keys are untouched, so scripts migrate one
at a time. A send with sealed-looking fields to an unencrypted key is just a weird
plaintext message; nothing is guessed.

The server pipeline is otherwise **unchanged**: it builds its content JSON from the
sealed values and seals it to the device exactly as today, adding one field of its
own inside that envelope — `"e2e": 1` — recording that this message was sealed by
its sender. That stamp is what makes the double-unwrap decision **per message**
rather than per current toggle state: rows from before a key's flip render as the
plaintext they are, rows after it are double-unwrapped, and the NSE — which has no
key list to consult — learns which kind it holds from the first unwrap. The device
opens the server's envelope as it always has, and opens each sender-sealed field
inside it only when the stamp says to.

The key's public key travels out of band — copied from the app, pasted into the
script — and doubles as a secret from the server: public to senders, unknown to
notifi. It is pinned by construction: it changes only when you paste a new one (or
renew that key, §5), and a wrong paste fails closed (the field never opens) rather
than degrading to plaintext.

---

## 2. Wire format, normative

```
name        notifi-e2e-v1
mode        HPKE base mode
kem         DHKEM(P-256, HKDF-SHA256)      0x0010
kdf         HKDF-SHA256                    0x0001
aead        AES-256-GCM                    0x0002
info        empty
aad         empty
recipient   the key's own 65-byte uncompressed P-256 point from Copy for
            scripts (X9.63 / SEC1) — generated at toggle-on, never registered
plaintext   the UTF-8 value of one field, nothing else
wire        standard base64 (with padding) of  enc || ciphertext
            where enc is the 65-byte encapsulated key and ciphertext ends
            with the 16-byte GCM tag
```

Sealing a field is one function taking one value: `base64(seal(pubkey, value))`.
The Worker's own envelopes use a different keypair entirely (the registered device
key, with non-empty info strings), so the layers can never cross-decrypt. This is CryptoKit's suite,
already used by the app and the NSE, with maintained RFC 9180 libraries in every SDK
language.

The whole sender, in Python:

```python
from hpke import CipherSuite, KEM, KDF, AEAD  # pyhpke
import base64, os, requests

suite = CipherSuite.new(KEM.DHKEM_P256_HKDF_SHA256, KDF.HKDF_SHA256, AEAD.AES256_GCM)
pubkey = suite.kem.deserialize_public_key(base64.b64decode(os.environ["NOTIFI_PUBLIC_KEY"]))

def seal(value: str) -> str:
    enc, ctx = suite.create_sender_context(pubkey)
    return base64.b64encode(enc + ctx.seal(value.encode())).decode()

requests.post("https://notifi.it/send", json={
    "key": os.environ["NOTIFI_KEY"],
    "title": seal("Deploy finished"),
    "message": seal("main → prod in 41s"),
})
```

**Fingerprint:** first 8 bytes of SHA-256 of the 65-byte point (not its base64),
uppercase hex in four-character groups: `A1B2 C3D4 E5F6 0718`. Shown in Key Detail,
printed by every SDK.

**Test vector:** `e2e-vector.json` from `packages/contract/scripts/gen-vectors.ts`,
with a fixed recipient private key and a sealed value exercising non-ASCII text.
Decrypt is deterministic; encrypt is checked by decrypting your own output. That is
every SDK's conformance test.

---

## 3. Code changes

**Contract** (`packages/contract/src/index.ts` + `ContractModels.swift`, same commit):

- `SEALED_FIELD_MIN = 108`; raised per-field maxima for encrypted keys — each
  plaintext maximum grows by the base64 and HPKE overhead (×4/3 plus 108), so a
  maximum-length message still fits after sealing.
- `keySummary` and the `PATCH /keys/:id` body gain `is_encrypted` (the route
  already exists for rename), default off on create.
- `messageContent` gains the server's `"e2e": 1` stamp (§1), inside the sealed
  envelope, so the existing tamper check covers it.
- No new request params, routes, response fields or error codes. `invalid_content`
  (422) covers a non-ciphertext send to an encrypted key.

**Migration** — described in `apps/api/prisma/schema.prisma` first, then generated
with `make migration name=e2e` (next in sequence here is `0002`):

```sql
ALTER TABLE keys ADD COLUMN is_encrypted INTEGER NOT NULL DEFAULT 0;
```

This is the `NOT NULL DEFAULT` case the generator refuses, so this one ALTER is
written by hand with the reason in the commit, per the migrations rule.

**`send.ts`** — the key lookup already returns the key row; when it carries
`is_encrypted`, the send takes one check and two skips: fields must be plausible
ciphertexts (else 422); the crop and image-check blocks are skipped (nothing to
crop, no URL to probe); the raised maxima apply. The content JSON gains the `e2e`
stamp. Everything downstream — `seal()`, the `INSERT`, the socket, the push — runs
unchanged over the sealed values.

**Device** — `ingest` opens the server envelope as today; when the content carries
the `e2e` stamp it picks the private key by the envelope's `key_id` — trying that
key's older generations after a Renew — and opens each field. A field that fails
to open shows the message as a visible "couldn't decrypt" row (new copy string) —
the sender got a `202`, and the likeliest cause is a script still sealing to a
renewed or pre-reinstall key, which only the recipient can notice. The NSE does
the same two-step unwrap, keyed off the same stamp and `key_id`, and shows the
existing fallback title when it cannot.

---

## 4. The push

The re-seal ladder cannot shorten content the server cannot read, so sends to
encrypted keys get one rung: the payload rides the push if it fits
`PUSH_BUDGET_BYTES`, else the push carries the id alone and the app syncs on open.

Double encryption compounds the base64: the sender's blob grows a third, then the
server's seal and base64 grow it again — **~1,800 characters of title + message**
fit the lock screen, versus ~2,650 single-sealed. Accepted: the preview ceiling is
the price of leaving the server pipeline untouched. Over it, the notification reads
"New notification" until the app opens — a warning on the send response, or a
`422 invalid_content` when the device has `strict_send` on, since `strict_send`
means refuse-rather-than-degrade and this is the one degradation the server can
still see.

---

## 5. App, SDKs

**App** — everything lives in **Key Detail**; Settings gains nothing (the
device's registered keypair keeps sealing the server envelope and needs no UI):

- **Key Detail** gains the **Encrypted** toggle (`is_encrypted`, off by default,
  via `PATCH /keys/:id`). Flipping it on generates the key's keypair in the
  keychain first, then updates the server; a centred `.alert` (never
  `confirmationDialog`) states the consequence: the script using this key fails
  from that moment until it seals, and the server cannot check content it cannot
  read — nothing is trimmed to fit, image links are not verified, and a message
  that is too long or broken arrives as sent.
- With the toggle on, the screen shows:
  - the key's fingerprint, monospaced,
  - **Copy for scripts** — two `export` lines, `NOTIFI_KEY` and
    `NOTIFI_PUBLIC_KEY`, via `copySensitive` (it carries the send key), replacing
    **Copy curl** — plus a snippet button: a short Python snippet with both
    values inlined, since curl cannot do HPKE,
  - **Renew** — generates a fresh keypair for this key only, for recovery from a
    suspected compromise. A centred alert states the consequence: this key's
    pasted public key stops working until re-pasted, and anything sealed to the
    old keypair after this point cannot be opened. Other keys are untouched. Sync
    runs first so nothing in flight is orphaned. The fingerprint changes, which
    is the point — a changed fingerprint is verifiable evidence of the rotation,
  - a line saying every key's keypair also changes if the app is reinstalled.
- With it off, nothing about encryption appears.
- Nothing else changes: search, retention, ack, socket untouched — decrypted messages
  sit in SwiftData exactly as today.
- Copy strings in a new `encryption` namespace, every translation, `make gen-copy`,
  `make shots` for the PR.

**SDKs** — one API everywhere:

```python
notifi = Notifi(key=os.environ["NOTIFI_KEY"], public_key=os.environ["NOTIFI_PUBLIC_KEY"])
notifi.send("Deploy finished", message="main → prod in 41s", critical=True)
```

The SDK is deliberately minimal: seal, post, surface the API's response. It does no
validation of its own — sizes, warnings and refusals all come from the API, which is
the single source of truth for them. Two rules only: presence of `public_key` turns
sealing on, and a client with a `public_key` **never** falls back to plaintext on any
error path — it raises. Every SDK exposes the fingerprint, the one thing the API
cannot compute for a key it never sees.

**Layout and publishing.** Each SDK lives in `sdks/<language>/` in this repo, beside
`sdks/SPEC.md` (a copy of §2). Publishing is per-registry, tagged
`<language>/vX.Y.Z`, versioned independently — a Python fix should not bump Go:

| What | Registry | How |
|---|---|---|
| Python | PyPI, as `notifi` | `uv build` + trusted publishing from CI |
| Node/TypeScript | npm, as `notifi` | `npm publish` from CI |
| Go | none — Go modules are git tags | `go get github.com/notifi-it/notifi/sdks/go` |

A release runs `make sdk-conformance` for that language against `e2e-vector.json`
first, and does not publish on failure — an allowed, scoped exception to the no-tests
rule, written into CLAUDE.md with the runner. Nothing publishes before the Worker
accepts sealed sends in production. Order: Python, Node, Go first; more as demand
appears.

---

## 6. Website

**Phase 0 is already done in this repo**: no page, meta or structured data says
"end-to-end encrypted" (`grep -rin "end-to-end\|end to end" apps/api/public/`
matches nothing today), and CLAUDE.md's marketing rules pin the sanctioned claim
("encrypted with your public key"). One phase-0 item remains: `privacy.md` gains a
"What encryption does not prove" section — the server can forge a message to you
and always could.

**Permanent rule:** the term never returns to the hero, metas or structured data —
it is only true for keys that opt in. "notifi supports end-to-end encrypted
sending" is the only allowed form, only where the feature is described.
End-of-phase check: `grep -rin "end-to-end\|end to end" apps/api/public/` matches
only inside the feature's docs.

**With the feature:** the encryption page is a **trust ladder**, four rungs in
order, each ending where the next begins:

1. **The base layer** — every notification is sealed to your device's key before
   it is stored; neither we nor Apple can read it afterwards. This is what
   everyone gets with plain `curl`.
2. **Seal it yourself** — flip the key's Encrypted toggle and the server never
   sees the plaintext at all. A short how-to: the toggle, what to copy, and the
   worked snippet; §2 in full below it as the normative reference.
3. **Install an SDK** — the install line and minimal example for each shipped
   SDK (`pip install notifi`, `npm install notifi`, `go get ...`), added as each
   ships.
4. **Still don't trust us?** — the GitHub repo, and a note that the Worker runs
   on your own Cloudflare account: host it yourself and point the app at it.

The page is added to `PAGES` / `PAGE_MARKDOWN` in `src/routes/site.ts`,
`run_worker_first`, `sitemap.xml` and the nav. `#api` documents encrypted keys
and the push limit; "No SDK" becomes "No SDK required"; `#send` tabs gain SDK
variants as each ships, `curl` staying the default tab.

---

## 7. Limits, stated once

For the README, the first and second also on the site (§6).

- **Metadata is visible.** Which key, which device, when, how urgent, which fields
  and roughly how long each — E2E hides contents, not the pattern of paging.
- **The server cannot forge a message that opens** — it never learns the key's
  public key. It can still inject an unstamped plaintext message; the app does
  not flag those (a pre-flip row looks the same), it just renders them as the
  plaintext they claim to be.
- **Over ~1,800 characters the lock-screen preview degrades** to "New notification"
  (a warning, or a 422 under `strict_send`).
- **The server cannot inspect encrypted content** — no crops, no image check; that
  validation moves to the script.
- **Image URLs are still fetched by the device**, so the image host still learns the
  device's IP.
- **The front-page `curl` stays plaintext.** E2E is the upgrade for people already
  scripting, not the default.

---

## 8. Phases

- **0 — website corrections (§6).** Done here, except the privacy "What encryption
  does not prove" section.
- **1 — protocol, server, device.** Contract + Swift mirror, vector, migration,
  the encrypted-key check in `send.ts`, push, two-step `ingest` with the
  "couldn't decrypt" row, NSE. Verify by hand: a throwaway Node script sealing to
  a real device, and a plaintext send to a normal key round-tripping unchanged.
- **2 — app surface.** Key Detail toggle, fingerprint, Copy for scripts, Renew,
  copy strings, screenshots.
- **3 — SDKs.** Python, Node, Go, `SPEC.md`, conformance runner + CLAUDE.md
  exception, the encryption page.
- **4 — volume.** More languages; a preview field if the push limit bites.

**Open question:** sender authentication (HPKE auth mode; would end the bearer-token
send key and the one-line `curl` — not now; the spec name is versioned for a later
revision). Deliberate re-key was an open question and is now a feature: Renew in
Key Detail (§5).
