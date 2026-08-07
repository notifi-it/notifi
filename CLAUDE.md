# Working in this repo

Notes for anyone (human or agent) picking this up. The design lives in
[docs/PLAN.md](docs/PLAN.md) and the manual test script in
[docs/VERIFYING.md](docs/VERIFYING.md); this file is only for things that are
easy to get wrong and expensive to discover.

## Urgent alerts: one switch, two ceilings

There is a single per-key toggle — "Urgent alerts", backed by the `keys.critical`
column — and it means "escalate this key". What escalation buys depends on what
the App ID carries.

**Time Sensitive is the floor and is live.**
`com.apple.developer.usernotifications.time-sensitive` is in all four app
entitlements files. It needs no Apple approval, and it gets a page past Focus and
onto the lock screen. It does **not** sound through silent mode.

**Critical Alerts are the ceiling and are still pending.** Submitted 2026-08-03,
request ID **W8U762V6VJ**, against bundle ID `it.notifi.notifi`. Apple replies by
email; nothing has come back.

**Do not add `com.apple.developer.usernotifications.critical-alerts` to the
entitlements files until Apple grants it.** An entitlement the App ID does not
carry fails code signing, so adding it early breaks every signed build for a
capability that still would not work. When the grant lands, add that key to all
four files and flip `CRITICAL_ENTITLED` in `apps/api/src/routes/send.ts` in the
same change — the same toggle then reaches the higher ceiling with no other work.

That constant is why the two levels are not both wired up at once: a push that
claims an interruption level the app is not entitled to is dropped by the OS
rather than downgraded, so `critical` and `time-sensitive` are mutually exclusive
in the payload, not layered.

A push is only escalated when the key is switched on **and** the individual send
asks for it with `critical=1`. A send that asks without that standing is
delivered as an ordinary notification rather than refused, because dropping an
alert from a pager is worse than under-delivering one.

### Adding an entitlement needs a portal change first

Enabling Time Sensitive Notifications on the App ID in the Apple Developer portal
is a manual step, and until it is done every signed build fails with
"Provisioning profile ... doesn't include the Time Sensitive Notifications
capability". `xcodebuild` from the command line will not add the capability for
you; Xcode.app with automatic signing will, or you can tick it under Identifiers
→ `it.notifi.notifi`. The iOS Simulator build does not sign and so passes either
way — it is not evidence the entitlement works.

## The contract is the source of truth, and Swift does not follow automatically

`packages/contract/src/index.ts` holds the Zod schemas. The Swift mirrors in
`apps/app/Shared/API/ContractModels.swift` are hand-written. Changing one without
the other typechecks on both sides and fails at runtime. Edit them together.

## Copy is written once, in packages/copy

Every sentence the product says to a person lives in
`packages/copy/src/strings.ts`. Nothing else may hold a user-facing literal.

The app does not read that file. `make gen-copy` writes two things from it:

- `apps/app/Shared/Resources/Localizable.xcstrings`, the string catalog, keyed by
  dotted path (`inbox.deleteMessage`) rather than by English source text. Keying
  by source text is Apple's default and makes every wording fix invalidate every
  translation of it.
- `apps/app/Shared/Support/Copy.swift`, typed accessors that look up those keys.

Edit neither: they are generated, and `make check-copy` regenerates them in
memory and fails if the committed ones have drifted. CI runs it.

The server reads the TypeScript directly, but never as `copy`. It negotiates a
language from `Accept-Language` once per request and every handler reads `t(c)`,
so a response cannot answer in a language of its own choosing. The app sends its
reader's `Locale.preferredLanguages` on every signed request — outside the signed
canonical string, because it changes the wording of a reply and never what the
request does.

### Adding a language

Add the code to `LANGUAGE_CODES` in `src/languages.ts`, add
`src/translations/<code>.ts`, run `make gen-copy`. The generator refuses to write
anything if a declared language is missing a key or has lost a `{placeholder}`,
so a half-translated language fails the build rather than shipping half in
English. There is no machine-translation step, by decision.

### Two rules the generator enforces

Placeholders are `{name}` and become positional format specifiers in
first-appearance order, so a translator can reorder them.

Counted things are `plural(one, other)`, and a plural leaf may contain **nothing
but `{n}`**. That restriction is what keeps the catalog able to pluralise on the
count while a language with six plural forms gets six. Anything mixing a count
with other text composes an already-rendered count — `inbox.bandLabel` takes the
output of `inbox.count`, it does not pluralise itself.

### What is deliberately not in the app's catalog

The `api` namespace. Those are the server's responses, shown to the reader as-is
in the language the request asked for; a second translation of them inside the
app would give the reader two wordings, differing by which one answered.

The push fallback title is the one string the server sends in the source language
regardless: it is read by the recipient, and the request that produced it came
from the sender's script, whose `Accept-Language` says nothing about them.
Localising it needs the device's language recorded at registration.

The website is not in this at all. Its prose still lives in
`apps/api/public/index.html` and `privacy.html`, and several sentences there are
hand-kept duplicates of in-app copy.

## Migrations

`apps/api/migrations/NNNN_snake_case.sql`, four-digit sequence. CI applies them
on merge to main **before** deploying the Worker, to dev and then production, so
a migration and the code that needs it can land in the same PR. Additive columns
with defaults only; there is no down-migration story.

## Building the app

`xcodebuild` needs the signing team passed by hand, because `project.yml` fills
`DEVELOPMENT_TEAM` from an env var that only CI sets:

```bash
xcodebuild -project apps/app/notifi.xcodeproj -scheme notifi-iOS -configuration Debug -destination 'generic/platform=iOS Simulator' DEVELOPMENT_TEAM=Z28DW76Y3W build
```

Run `cd apps/app && xcodegen generate` first if `project.yml` changed. Schemes are
`notifi-iOS` and `notifi-macOS`. Verify on the Simulator, not a device over Wi-Fi:
installs fail silently there and cannot be screenshotted.

## Confirmations are centred alerts, never confirmationDialog

Use `.alert` with a title, a `message:`, and the action buttons. Never
`confirmationDialog`: on iOS 26 it anchors to the control that opened it as a
popover, which reads as a stray tooltip rather than a decision the app is
asking the user to make. Put the question in the title and the consequence in
the message.

## The bell is drawn once, and every other copy is generated

`apps/app/Support/Icon/notifi-logo.svg` is the mark. The tab icon, the wordmark
bell, the empty state, the menu bar glyph, the app icons, the favicon, the touch
icon and the bell the website masks are all produced from it by
`Support/Icon/generate-marks.sh` — edit the master, run that, commit what it
writes. Do not edit the generated SVGs; the header in each says so, and a change
made there survives until the next person runs the script.

Two viewBoxes are declared in that script rather than measured, because things
outside it are positioned as fractions of them: `BellMark`'s unread dot in
`Wordmark.swift`, and the badge disc in the site's CSS, which lives in both
`index.html` and `privacy.html`. The script prints those fractions on every run
and refuses to write a box the artwork no longer fits inside. If you reframe
one, re-measure all of them — a release shipped with the site's disc sitting off
the bell's shoulder because only the asset moved.

### The badge has one position, and it is in the artwork

`notifi-logo.svg` is where the unread badge sits. Never place it a second time
by hand. A hard-coded fraction is a copy of that measurement, and every copy has
drifted: the menu bar's dot was placed at fractions of its own frame, which is
trimmed and re-centred and so does not share `BellLogo`'s framing at all —
"matching" the two by giving them the same numbers moved it off the bell.

Where a badge is needed, generate it: `generate-marks.sh` bakes it into
`BellTabUnread`, and `generate-menu-icon.sh` writes `menu_dot` as a separate
layer cropped by the same box as the bell, so drawing one over the other aligns
by construction. `MacMenuBar` composites those two images and knows no
coordinates. The two exceptions are `BellMark` and the site's CSS, which overlay
a live view on a static asset and cannot bake anything in; both take their
fractions from the numbers the script prints, and both are named above.

## Layout changes apply to every screen, not one

The three tabs — Inbox, Keys, Settings — are built on different containers: the
Inbox is a `List`, the other two are `ScrollView`s. Anything that changes shared
geometry (gutters, insets, header spacing, row rhythm) has to be checked and
applied on all three, or the tabs drift apart by a few points and the app starts
feeling untidy in a way nobody can name.

The gutter is `Theme.gutter` (20pt), applied through `geistGutter()`. Use it
rather than a literal number, and never correct one screen with a compensating
offset — an inset that only exists to cancel a container quirk is a bug the next
OS version will change under you. There was a `.padding(.horizontal, -8)` on the
Inbox `List` for exactly that reason; by the time it was removed its own comment
no longer described what the screen did.

Verify on the Simulator across all three tabs before calling a layout change
done. Screenshot them and compare the left edge.

## No automated tests

By decision. `make typecheck` plus both `xcodebuild` schemes is the full
automated gate; everything else is checked by hand against
[docs/VERIFYING.md](docs/VERIFYING.md). Do not add a test framework to make a
change feel verified. Say plainly what was and was not exercised instead.

## Comments explain why, never what

The Swift and TypeScript here carry long comments justifying non-obvious
decisions, and none restating the code. Match that. A comment that describes what
the line below does should be deleted.
