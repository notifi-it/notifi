# Sender-side end-to-end encryption — plan

Today the Worker seals every message to the device's key at ingest; the gap is that
the sender posts plain HTTPS, so the Worker sees the plaintext for the length of the
request. This closes it for keys that opt in: the sender seals `title`, `message`
and `image` itself, and the Worker runs its normal pipeline over the ciphertexts —
including its own seal on top. The server never sees the plaintext, never learns
the feature exists, and changes by **zero lines**: encryption is an agreement
between the app and the script, carried entirely in the values.

---

## 1. How it works

Encryption is a **per-key, app-side setting**: each key gets an Encrypted toggle in
Key Detail, off by default, stored locally — the server is never told. Flipping it
on generates a **fresh P-256 keypair for that key alone** — distinct from the
device's registered `encryption_public_key`, which keeps sealing the server's own
envelope. The private half lives in the device keychain (shared with the NSE, as
the device key already is); the public half appears only in Copy for scripts and is
never sent to the server. Because the server never learns it, the server cannot
construct a blob that opens: sender forgery is closed, not just documented (§7).
Superseded private halves are **kept forever** — a Renew or a toggle flip mints a
new keypair but never deletes the old one, or every row sealed to it dies.

You flip a key on, copy its public key out of the app, and paste it into that key's
script next to its send key. The script then seals `title`, `message` and `image` —
same parameter names, each value now `base64(HPKE-seal(value))`; `link`,
`is_critical` and `occurred_at` stay plaintext:

```
POST /send                    (GET works as today; POST recommended)
  key=nk_...
  title=<base64>              required, sealed
  message=<base64>            optional, sealed
  image=<base64>              optional, sealed
  link=https://...            optional, plaintext (the server validates it as a URL)
  is_critical=1               optional, plaintext, as today
  occurred_at=1754899200000   optional, plaintext, as today
```

The server treats these as the opaque strings they already are: it builds its
content JSON from them, seals it to the device, stores and pushes exactly as today.
Nothing signals on the wire and nothing is detected server-side — the device does
the detecting, by **trial decrypt** (§3): a sealed field either opens under the
key's private key or fails the AEAD's built-in check; nothing else can open, so
guessing is safe.

Because the server still crops and validates as if the values were prose, the
**SDK owns the size limits** for sealed fields (§5) — the one place it validates,
because the server can't: a sealed title must stay under the server's 200-char
crop, which caps the plaintext title at **69 bytes**. Short titles are the price of
a server that knows nothing.

The key's public key travels out of band — copied from the app, pasted into the
script — and doubles as a secret from the server: public to senders, unknown to
notifi. It is pinned by construction: it changes only when you paste a new one (or
renew that key, §5), and a wrong paste fails closed (the field never opens) rather
than degrading to plaintext.

**Downgrade is warned client-side.** The app records when the toggle flipped. A
message on an encrypted key whose fields arrive as plaintext after the flip is
rendered as the plaintext it is, with a warning mark: either a forgotten script
still sending plain, or something injecting on the key's behalf. Rows from before
the flip render normally, unmarked.

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
key, with non-empty info strings), so the layers can never cross-decrypt. This is
CryptoKit's suite, already used by the app and the NSE, with maintained RFC 9180
libraries in every SDK language.

Size ceilings, derived from the server's plaintext limits (81 bytes of HPKE
overhead, ×4/3 base64):

| field | server limit on the wire | sealed plaintext ceiling |
|---|---|---|
| `title` | cropped at 200 chars | **69 bytes** |
| `message` | cropped at 16,000 chars | **11,919 bytes** |
| `image` | max 2,048 chars | **1,455 bytes** |

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

**Server: none.** No migration, no contract change, no new route, param, error or
warning. The Worker crops, validates, seals, stores and pushes ciphertext strings
exactly as it does prose. The one server-adjacent artifact is the test vector
generator in `packages/contract/scripts/`.

**Device** — `ingest` opens the server envelope as today, reads `key_id` from the
content, and asks: does that key have e2e keypairs and a flip time before
`created_at`? If so, it trial-decrypts each of `title`, `message`, `image` with
that key's private keys, newest generation first:

- opens → the decrypted value is the field,
- fails and the field is a plausible ciphertext (valid base64, ≥108 chars) → the
  message shows as a visible **"couldn't decrypt"** row (§5) — likeliest a script
  sealing to a renewed or pre-reinstall key, which only the recipient can notice
  (the sender got a `202`),
- fails and the field is not ciphertext-shaped → plaintext that arrived after the
  flip: rendered as-is with the **downgrade warning** mark (§1).

Rows on keys that never flipped, and rows from before the flip, skip all of this.
The NSE does the same: it shares the keychain access group and reads the per-key
flip state from shared app-group storage; when it cannot open a field it shows the
existing fallback title.

---

## 4. The push

Unchanged, and unaware. The server seals its envelope over the (already sealed)
values and the payload rides the push if it fits `PUSH_BUDGET_BYTES`, else the
push carries the id alone and the app syncs on open. The re-seal ladder still runs
— truncating ciphertext just produces a field that fails to open, which the device
already renders as "couldn't decrypt"; in practice the SDK's ceilings (§2) keep
sealed sends inside the one-rung budget. Double encryption compounds the base64:
**~1,800 characters of title + message** fit the lock screen, versus ~2,650
single-sealed.

---

## 5. App, SDKs

**App** — everything lives in **Key Detail**; Settings gains nothing (the device's
registered keypair keeps sealing the server envelope and needs no UI):

- **Key Detail** gains the **Encrypted** toggle — local state, no server call.
  Flipping it on generates the key's keypair in the keychain and records the flip
  time; a centred `.alert` (never `confirmationDialog`) states the consequence:
  the script using this key shows as unencrypted until it seals, the title ceiling
  is short (69 bytes), and the server cannot check content it cannot read — a
  message that is too long or broken arrives as sent.
- With the toggle on, the screen shows:
  - the key's fingerprint, monospaced,
  - **Copy for scripts** — two `export` lines, `NOTIFI_KEY` and
    `NOTIFI_PUBLIC_KEY`, via `copySensitive` (it carries the send key), replacing
    **Copy curl** — plus a snippet button: a short Python snippet with both values
    inlined, since curl cannot do HPKE,
  - **Renew** — generates a fresh keypair for this key only, for recovery from a
    suspected compromise. A centred alert states the consequence: this key's
    pasted public key stops working until re-pasted, and anything sealed to the
    old keypair after this point cannot be opened. Other keys are untouched. The
    fingerprint changes, which is the point — a changed fingerprint is verifiable
    evidence of the rotation,
  - a line saying every key's keypair also changes if the app is reinstalled.
- With it off, nothing about encryption appears.
- **"Couldn't decrypt"** in the UI: the lock screen shows the existing generic
  fallback; the inbox row keeps its normal shape — timestamp and key name live
  outside the blob — with the title "Couldn't decrypt" in the muted colour and no
  preview line; the detail page repeats the title and states the likely cause (a
  script still sealing to an old public key after a Renew or reinstall) and the
  fix (re-copy Copy for scripts), with a link to the key's page. The row deletes
  and ages out like any other.
- Copy strings in a new `encryption` namespace, every translation, `make
  gen-copy`, `make shots` for the PR.

**SDKs** — one API everywhere:

```python
notifi = Notifi(key=os.environ["NOTIFI_KEY"], public_key=os.environ["NOTIFI_PUBLIC_KEY"])
notifi.send("Deploy finished", message="main → prod in 41s", critical=True)
```

The SDK is deliberately minimal: seal, post, surface the API's response. The API
stays the source of truth for everything it can see — with one carved-out
exception: the API cannot see sealed sizes, so the SDK enforces the §2 ceilings
and raises before sending a value the server would mangle. Two rules besides:
presence of `public_key` turns sealing on, and a client with a `public_key`
**never** falls back to plaintext on any error path — it raises. Every SDK exposes
the fingerprint, the one thing the API cannot compute for a key it never sees.

**Layout and publishing.** Each SDK lives in `sdks/<language>/` in this repo,
beside `sdks/SPEC.md` (a copy of §2). Publishing is per-registry, tagged
`<language>/vX.Y.Z`, versioned independently — a Python fix should not bump Go:

| What | Registry | How |
|---|---|---|
| Python | PyPI, as `notifi` | `uv build` + trusted publishing from CI |
| Node/TypeScript | npm, as `notifi` | `npm publish` from CI |
| Go | none — Go modules are git tags | `go get github.com/notifi-it/notifi/sdks/go` |

A release runs `make sdk-conformance` for that language against `e2e-vector.json`
first, and does not publish on failure — an allowed, scoped exception to the
no-tests rule, written into CLAUDE.md with the runner. Order: Python, Node, Go
first; more as demand appears.

---

## 6. Website

**Phase 0 is already done in this repo**: no page, meta or structured data says
"end-to-end encrypted" (`grep -rin "end-to-end\|end to end" apps/api/public/`
matches nothing today), and CLAUDE.md's marketing rules pin the sanctioned claim
("encrypted with your public key"). One phase-0 item remains: `privacy.md` gains a
"What encryption does not prove" section — the server can inject a plaintext
message on a key's behalf, and always could.

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
   sees the plaintext at all — it does not even know you did it. A short how-to:
   the toggle, what to copy, the ceilings, and the worked snippet; §2 in full
   below it as the normative reference.
3. **Install an SDK** — the install line and minimal example for each shipped
   SDK (`pip install notifi`, `npm install notifi`, `go get ...`), added as each
   ships.
4. **Still don't trust us?** — the GitHub repo, and a note that the Worker runs
   on your own Cloudflare account: host it yourself and point the app at it.
   (Blocked on the app growing a release-build server setting; today only DEBUG
   builds honour `NOTIFI_BASE_URL`.)

The page is added to `PAGES` / `PAGE_MARKDOWN` in `src/routes/site.ts`,
`run_worker_first`, `sitemap.xml` and the nav. "No SDK" becomes "No SDK required";
`#send` tabs gain SDK variants as each ships, `curl` staying the default tab.

---

## 7. Limits, stated once

For the README, the first and second also on the site (§6).

- **Metadata is visible.** Which key, which device, when, how urgent, the link,
  and roughly how long each sealed field is — E2E hides contents, not the pattern
  of paging. The `link` field is plaintext by design (the server validates it as
  a URL), so where a notification points is never hidden.
- **The server cannot forge a message that opens** — it never learns the key's
  public key. It can still inject a plaintext message; the app marks plaintext
  arriving on an encrypted key after the flip (§1), and that mark is the extent
  of the protection.
- **Titles are short**: 69 bytes of plaintext before sealing overflows the
  server's crop. The SDK refuses longer rather than letting the server mangle it.
- **The server cannot inspect sealed content** — nothing is trimmed to fit and a
  broken value arrives as sent; that validation moves to the SDK's ceilings and
  the script.
- **Image URLs are still fetched by the device**, so the image host still learns
  the device's IP — sealing the URL hides it from notifi, not from the host.
- **The front-page `curl` stays plaintext.** E2E is the upgrade for people
  already scripting, not the default.

---

## 8. Phases

- **0 — website corrections (§6).** Done here, except the privacy "What
  encryption does not prove" section.
- **1 — protocol, device.** Vector generator, trial-decrypt `ingest` with the
  "couldn't decrypt" row and downgrade mark, NSE. No server work exists. Verify
  by hand: a throwaway Node script sealing to a real device, and a plaintext
  send to a normal key round-tripping unchanged.
- **2 — app surface.** Key Detail toggle, fingerprint, Copy for scripts, Renew,
  copy strings, screenshots.
- **3 — SDKs.** Python, Node, Go, `SPEC.md`, conformance runner + CLAUDE.md
  exception, the encryption page.
- **4 — volume.** More languages; a sealed `link` variant if hiding the
  destination ever earns its complexity.

**Open question:** sender authentication (HPKE auth mode — would prove *which*
script sealed a message, at the cost of a second secret in every script; the spec
name is versioned for a later revision). Deliberate re-key was an open question
and is now a feature: Renew in Key Detail (§5).
