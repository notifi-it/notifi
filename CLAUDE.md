# Working in this repo

Only things that are easy to get wrong and expensive to discover.

## Contract

`packages/contract/src/index.ts` (Zod) and the hand-written Swift mirror
`apps/app/Shared/API/ContractModels.swift` must change together — a lone change
typechecks on both sides and fails at runtime.

## Copy

All user-facing strings live in `packages/copy/src/strings.ts`. Nothing else may
hold a user-facing literal. `make gen-copy` generates
`apps/app/Shared/Resources/Localizable.xcstrings` (keyed by dotted path, not
source text) and `apps/app/Shared/Support/Copy.swift`. Never edit the generated
files; `make check-copy` (CI) fails on drift.

The server reads the TypeScript directly via `t(c)`, negotiated once per request
from `Accept-Language`. The app sends `Locale.preferredLanguages` on every
signed request, outside the signed canonical string.

Adding a language: add the code to `LANGUAGE_CODES` in `src/languages.ts`, add
`src/translations/<code>.ts`, run `make gen-copy`. Missing keys or lost
`{placeholder}`s fail the build. No machine translation, by decision.

Generator rules: placeholders are `{name}` (positional, first-appearance order);
plurals are `plural(one, other)` and a plural leaf may contain **nothing but
`{n}`** — anything mixing a count with text composes an already-rendered count
(`inbox.bandLabel` takes `inbox.count`'s output).

Deliberately not in the app catalog: the `api` namespace (server responses are
shown as-is), the push fallback title (sent in the source language — the
sender's `Accept-Language` says nothing about the recipient), and the website
(`apps/api/public/index.html` / `privacy.html`, hand-kept duplicates).

## Marketing copy

In anything pitching the product (App Store listing, README opening, site meta
descriptions and captions): say "HTTP request" not "curl", and "notifi.it" not
"notifi.it/send". Exempt: code examples, UI labels like "Copy curl", and the App
Store keywords field.

Encryption claim: "encrypted with your public key", never "end-to-end
encrypted". Follow it with "neither we nor Apple can read your notifications" —
except in fastlane metadata, where we say we cannot read them without naming
Apple.

The thing the product sends is a **notification**, never a "message", in every
string a person reads: app copy, the website, the App Store listing, the README,
social bios.

Two exceptions, both load-bearing:

- `message` is a wire field of `/send`, and appears as itself in code examples,
  parameter tables and error listings. Renaming it there would be a lie about
  the API. Where prose needs a word for that field's contents, "body" is the one
  the API already uses alongside `title`.
- `settings.deliveryBrokenDetail` uses both words on purpose. A notification is
  the banner APNs delivers; the payload can arrive over the live connection
  without one, and that string exists to explain exactly that case. Collapsing
  the two words makes it say nothing.

Copy keys keep their existing names (`inbox.copyMessage`, the `message.*`
namespace). They are internal, they key the xcstrings catalogue, and renaming
them churns every Swift call site for no reader's benefit.

### Vocabulary

The product has one word for each of its nouns. If a sentence introduces a
metaphor for something the product already has a word for, use the product's
word — "each device gets its own address" shipped on the landing page and the
product has no addresses.

- **key** (or **send key**) — the thing a sender holds. Never "address",
  "token" or "credential" as the name for it. Prose may still *explain* a key
  in those terms ("a key is a credential" on the contact page is an
  explanation, not a rename), and "bearer token" stays where it names the
  `Authorization: Bearer` mechanism itself.
- **device** — the thing that receives, when generic; "iPhone, iPad or Mac"
  when listing. "Phone" is allowed where it really means the phone ("Your
  phone holds the only key", "pages your phone").
- **notification** — the thing delivered (rule above, with its two
  exceptions).
- **send** — the verb, and `/send` the endpoint. Not "dispatch", "push a
  message" or "deliver to an address".
- **alert** — only inside Apple's feature names (Critical Alerts, Time
  Sensitive) and the life-safety disclaimer ("emergency alerting system").
  Anywhere else the word is notification.
- **revoke** — the verb for ending a key, matching the app's "Revoke key"
  button. A key is revoked; a notification is deleted. Never cross the two.
- **collect** — what a device does to its stored notifications; an
  undelivered one is "uncollected". The privacy policy leans on this pair.
- **pager** and **relay** — the two sanctioned metaphors, used as-is: "a
  pager for your own systems", "a relay, not a mailbox". Don't coin others.
- **encrypted** — the copy's word. "Seal" is the code's name (`seal.ts`) and
  stays internal.

## Every page in apps/api/public is generated

**Nothing in `apps/api/public` is edited by hand.** `packages/site` assembles
all eight pages and `make gen-site` writes them; `make check-site-html` (CI)
fails on drift.

| Change | Edit |
|---|---|
| Prose on about / contact / faq / terms / privacy | `packages/site/pages/<name>.md` |
| The 404's markup, styles or glyph script | `packages/site/pages/404.{html,css,js}` |
| The /docs reference | `packages/apidoc/src` (see below) |
| The landing page's body | `apps/api/public/index.html`, between its `<!-- gen:… -->` markers |
| Header, footer, `<head>`, shared CSS or JS | `packages/site/src/` |
| A social URL, the contact address, the App Store link, the author | `packages/site/src/constants.ts` |
| The schema.org Organization node | `packages/site/src/schema.ts` |

The five prose pages are Markdown in, HTML *and* Markdown out. The dialect is
whatever `gen-site-md` emits, so the two converters are inverses and the
round-trip is the test: regenerate, run `make gen-site-md`, and the `.md` should
come back unchanged. Two rules are positional rather than syntactic — the first
`>` block after the `# ` heading is the lede and every later one is a
`<div class="card">` callout, and `_text_` alone on a line is `<p class="meta">`.
The eyebrow and all `<head>` values live in the front matter.

The header nav and the footer both drop the link to the page they are on. That
rule is in `chrome.ts`, not in seven hand-maintained copies.

`index.html` is the exception that keeps its own body, its own 522 lines of CSS
and its own scripts: it has an early `<head>` script, a canvas film and a
superset of the design tokens, and folding those in has not been done. It still
takes its footer, its schema and its whole API section from the shared source.

## The website is served twice: HTML and Markdown

Every doc-shaped page (the ones whose body is `<main class="wrap doc">`) has a
generated `.md` sibling written by `make gen-site-md`; `make check-site-md` (CI,
in the lint workflow) fails on drift. **Never edit a generated `.md` by hand.**
`index.md` is the one exception and is hand-written, because the landing page
does not survive a mechanical conversion — change `index.html` and you have to
change it too.

The converter understands only the tags those pages already use and throws on
anything else, so a new construct fails the build rather than silently vanishing
from the copy agents read.

The Worker answers `Accept: text/markdown` on the page's own URL
(acceptmarkdown.com): q-values are parsed properly, `Vary: Accept` is on every
negotiated response, HTML carries `Link: </x.md>; rel="alternate"`, and an
`Accept` we cannot satisfy gets a `406` rather than a silent fallback. That is
why those paths are listed in `run_worker_first` in `wrangler.toml` — the asset
bucket would otherwise answer before the Worker could negotiate. A page added to
the site has to be added there, to `PAGES`/`PAGE_MARKDOWN` in
`src/routes/site.ts`, and to `sitemap.xml`.

An unknown path answers `404` with the Markdown or HTML body of `404.md` /
`404.html` — a site map an agent can recover from — except under `/send`,
`/keys`, `/devices`, `/history`, `/socket`, `/reviews` and `/download`, and for
any method other than GET or HEAD, which keep the JSON `error.code` shape API
clients parse.

Those page requests are exempt from the per-IP limiter. They used to be answered
by the asset bucket without ever reaching the Worker, and a shared IP reading the
site should not spend the budget `/send` needs; unknown paths are still limited.

`make check-site` asks a running origin for all of that and fails if any of it
regressed. It runs against production after every deploy; run it against a local
`make dev` before pushing:

```bash
BASE=http://localhost:8787 make check-site
```

## API documentation is generated

`packages/apidoc/src` is the source of truth for the prose that describes
`/send`; the schemas, limits and error codes come from the Zod contract.
`openapi.ts` converts `sendFields` (the documented schema `sendParams` derives
its crop tolerance from), `sendResponse` and `publicErrorCode` with
`z.toJSONSchema`, merges apidoc's descriptions and examples on top, and refuses
to generate if the error table in `spec.ts` and `publicErrorCode` disagree.
Change a limit or an error code in `packages/contract`, or prose in
`packages/apidoc/src`, and run

```bash
make gen-api
make gen-site
make gen-site-md
```

`gen-api` writes `openapi.json`, `notifi.postman_collection.json` and
`notifi.bru`. `gen-site` renders the /docs page body and style from `html.ts`,
and splices the landing page's endpoint prose, parameter table, language tabs
and code panels between its `<!-- gen:… -->` markers — one generator per file,
so the two never fight over `index.html`. `docs.md` then comes from `docs.html`
through `gen-site-md`, as every other page's Markdown does.

`make check-api` and `make check-site-html` (CI, in the lint workflow) fail on
drift.

Each tab carries its language's own mark. `icons.ts` pulls the path out of
`simple-icons` at generation time and inlines it, so the page still makes no
third-party request; a sample names a slug (`siPython`) and an unknown one
throws rather than rendering blank. `simple-icons` is a devDependency and the
paths are baked into the committed HTML, so bumping it can show up as
`check-site-html` drift — that is the check working.

The samples in `samples.ts` are stored as plain source; the landing page's
syntax colouring is applied by `landing.ts` — strings, `NOTIFI_KEY`, and a
per-sample `keywords` list for the `.f` class. Add a sample and it appears in
the landing page tabs and in the /docs recipes together.

`llms.txt` is still hand-written. It carries prose the spec has no room for, and
duplicating the error table there would be the next thing to generate.

## Migrations

**Never type a migration by hand.** `apps/api/prisma/schema.prisma` is the
source of truth: describe the change there, then

```bash
make migration name=snake_case_name    # writes apps/api/migrations/NNNN_*.sql
make migrate                           # applies it locally
```

`make check-migrations` (CI, in the lint workflow) fails a PR that touches
`migrations/` without touching the schema, so a hand-written file is caught
before review.

The generator diffs the **committed** schema against the working copy — it
never inspects a live database. The tables predate the schema file, so Prisma's
canonical DDL differs from them cosmetically (`AUTOINCREMENT` on `keys.id`,
`NOT NULL` on a TEXT primary key); diffing against real D1 asks to rebuild every
table to close a gap that changes nothing. The cost is that the schema is only
as accurate as the last person to edit it — describe first, generate second.

Four-digit sequence, no gaps. CI applies migrations on merge before deploying
the Worker, so migration + code land in one PR. There is one environment, so a
merge is live immediately. Additive columns only; no down migrations.

Two things the generator will not do for you:

- **A `NOT NULL DEFAULT` column comes out as a table rebuild**, because Prisma's
  SQLite provider will not trust an in-place add. `make migration` refuses to
  write it, and `check-migrations` refuses to merge it. Add the column as
  nullable, or write that one `ALTER TABLE ... ADD COLUMN x INTEGER NOT NULL
  DEFAULT 0` by hand — and say why in the commit, because CI will ask.
- **Backfills and renames.** A diff cannot infer intent, so a correlated update
  or a column rename has to be written by hand — and said so in the commit.

## Running the app against a local server

`make dev` starts wrangler on a random free port so parallel worktrees never
collide; read the port off its "Ready on" line. It passes `--host` alongside
`--port` because the signed canonical string binds host **and** port — a bare
`wrangler dev --port N` leaves the Worker verifying `localhost:8787` and every
signed request 401s.

The Worker needs `apps/api/.dev.vars` (gitignored): `ENCRYPTION_KEY` as 64 hex
chars, plus `APNS_TEAM_ID`/`APNS_KEY_ID`/`APNS_PRIVATE_KEY` stubs. Run
`make migrate` once per worktree. APNs cannot deliver locally — the push
attempt fails on the stub key every time. Arrivals still reach a running app
over the socket, and the banner comes from the app's own unpushed announce.

Point a DEBUG build at it with `NOTIFI_BASE_URL=http://localhost:<port>`.
Setting it flips the app into local-dev isolation (`LocalDev.isActive`): the
message store goes in-memory, and because the sync cursor lives *inside* the
store (`SyncState`), it dies with it — the link-policy allow-list and key
cache are simply not read or persisted. Without that isolation the Debug
build shares the installed app's store, whose cursor sits at the production
sequence, so history from a fresh local D1 (seq 1..n) is permanently
invisible — sends look accepted but never appear.

Seed sendable keys with `apps/api/seed-keys.mjs` (prints the secrets, writes
`/tmp/notifi-seed.sql` to apply with `wrangler d1 execute --local`), using the
device row the app registers on first launch.

## Building the app

```bash
xcodebuild -project apps/app/notifi.xcodeproj -scheme notifi-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' DEVELOPMENT_TEAM=Z28DW76Y3W build
```

`DEVELOPMENT_TEAM` must be passed by hand (only CI sets the env var). Run
`cd apps/app && xcodegen generate` first if `project.yml` changed. Schemes:
`notifi-iOS`, `notifi-macOS`. Verify on the Simulator, not a device over Wi-Fi
(installs fail silently and can't be screenshotted).

## Verifying a visual change: `make shots`

Never hand-roll build-install-boot-tap. A run is 14-24s for all three tabs.

```
make shots                     # one screenshot per screen
TABS="inbox settings" make shots
MESSAGE_INDEX=4 make shots     # open a different seeded message
FORCE_BUILD=1 make shots       # rebuild even if nothing looks changed
```

Writes `/tmp/notifi-shots/<name>.png`: the three tabs plus `message.png` (the
detail page, reached by seeding data and pushing at launch, not tapping). The
default `MESSAGE_INDEX` carries a body, image, link and key. There is
deliberately no skip-the-build flag: a screenshot of a stale build looks exactly
like an answer.

It sets the tab with `NOTIFI_START_TAB` instead of tapping (tapping is flaky).
`NOTIFI_START_TAB`, `NOTIFI_SAMPLE_DATA`, `NOTIFI_START_MESSAGE` are DEBUG-only
and exist only for this script — nothing else may set them. The message override
waits for `bootState == .ready`; a path pushed before the stack exists is
silently dropped.

## A PR that changes the UI attaches screenshots

One per touched screen; before/after when moving something existing. `make
shots` covers the tabs; sheets and the Mac popover are captured by hand. If
filing from a CLI that can't upload images, say so and attach via the web UI.

## Confirmations are centred alerts

Use `.alert` with a title, `message:`, and action buttons — question in the
title, consequence in the message. Never `confirmationDialog`: on iOS 26 it
anchors to its control as a popover and reads as a stray tooltip.

## The bell is drawn once

`apps/app/Support/Icon/notifi-logo.svg` is the master. Every other mark (tab
icon, empty state, menu bar glyph, app icons, favicon, touch
icon, website bell) is generated by `Support/Icon/generate-marks.sh` — edit the
master, run it, commit its output. Never edit the generated SVGs.

The script declares two viewBoxes; `BellMark`'s unread dot (`BellMark.swift`)
and the site CSS badge disc (in both `index.html` and `privacy.html`) are
positioned as fractions of them. The script prints those fractions each run and
refuses a box the artwork no longer fits. Reframe one → re-measure all.

The unread badge has one position: in the artwork. Never place it by hand with
hard-coded fractions — every copy has drifted. `generate-marks.sh` bakes it into
`BellTabUnread`; `generate-menu-icon.sh` writes `menu_dot` cropped by the same
box as the bell, so `MacMenuBar` composites them with no coordinates. Only
`BellMark` and the site CSS overlay live views and must take the printed
fractions.

## The DMG's install window is two files that must agree

`Support/Icon/generate-dmg-background.sh` draws the background;
`Scripts/dmg-layout.applescript` places the icons. The coordinates live in both
(the script prints them) — change them together. The background is 2x pixels
tagged 144 dpi (1x ships visibly soft). The `dmg` lane arranges a mounted UDRW
image before converting to UDZO — arranging a compressed image silently produces
a default window.

## Layout changes go in GeistPage, not in three screens

The tabs use different containers (Inbox is a `List`, Keys/Settings are
`ScrollView`s), so all geometry — ground, reading measure, gutter, rhythm,
header rule, fades, nav bar visibility — lives in `GeistPage`. Screens pass a
header and content and choose only `scroll:` (`.content` = own container,
`.page` = given one). Never reintroduce per-screen geometry; that's what drifted
before (titles 107pt apart on iPad).

Know before changing: the nav bar is shown on all three tabs at regular width
(it carries a safe-area inset regardless; hiding it moves titles), and the
header subtitle line (`GeistHeader`/`FeedHeader`) collapses to zero height when
it has no subtitle or accessory, so screens without one sit tight.

The vertical distance from the header title to the first section label must be
**identical on all three tabs** (INBOX→first band, KEYS→ACTIVE,
SETTINGS→PERMISSIONS). Measure it on the Simulator after any header, margin or
section-label change — the three screens share `GeistPage`/`SectionLabel`
geometry precisely so this cannot drift, and a per-screen fix that breaks the
match is wrong even if that one screen looks better.

The gutter is `Theme.gutter` (20pt) via `geistGutter()` — never a literal, and
never a compensating offset to cancel a container quirk.

Verify on the Simulator across all three tabs, phone **and** iPad — the measure
only bites at regular width. Screenshot the three headers side by side.

## No automated tests

By decision. `make typecheck`, `make lint`, `make check-site-md`, plus both
`xcodebuild` schemes is the full gate — and `make check-site` against a running
origin for anything that touches the website's negotiation or its 404. Don't add
a test framework; say plainly what was and wasn't exercised.

## Releasing to the App Store

- **Tag first, submit second, metadata last.** A `v*` tag runs CI (TestFlight +
  DMG). `MARKETING_VERSION=X.Y make app-submit` (local) *creates* the App Store
  version; `make app-metadata` before that retries "Cannot find edit app store
  version" for ~20 minutes and fails — it's not hung, the version doesn't exist.
- **`make app-metadata-check` is broken upstream** (`verify_only` hashes a
  missing ipa). Skip the dry run.
- **"Not in valid state" names no field.** Causes met so far: a missing
  screenshot set, an empty `fastlane/metadata/en-GB/release_notes.txt`.
- **iPad screenshots are mandatory** (`ipadPro129`, 2048x2732) because the app
  runs on iPad. `make appstore-shots` builds and captures both sets, seeding via
  `NOTIFI_SEED_SAMPLE` / `NOTIFI_OPEN_SAMPLE_MESSAGE` (DEBUG only), no tapping.
- **Metadata and screenshots are separate targets**, because Apple gates them
  differently: `make app-metadata` writes name, subtitle, keywords and
  description, which stay editable while a version is `WAITING_FOR_REVIEW`;
  `make app-screenshots` writes screenshots, which Apple locks the moment a
  version is submitted ("Can't Delete Screenshot After Submit for review"). The
  screenshots lane checks the version state first and says so, rather than
  spending fifty retries finding out.
- **Screenshot uploads cry wolf, but only on the upload half**: "X is missing
  ... Tries remaining: N" once per run is normal — App Store Connect computes
  the checksum deliver verifies against asynchronously, so the first check
  legitimately misses. Repeated rounds are a real failure, and each retry
  deletes the screenshots still processing before re-uploading them. A
  *delete* that fails is never flake; it means the version is submitted.
- Screenshots upload with `sync_screenshots`, not `overwrite_screenshots`: it
  diffs `locale/filename/md5`, so an unchanged set costs no API calls. Keep the
  frames byte-stable (no timestamps in the PNGs) or every run re-uploads
  everything.
- **Two local traps**: `git checkout -b x origin/main` uses the last *fetched*
  origin/main — fetch first. And don't pipe important logs through `tail`.

## Never add comments

No comments in Swift or TypeScript; `make lint` (`scripts/lint-comments.mjs`,
CI) fails on any. Reasoning goes in the commit message or PR description.
