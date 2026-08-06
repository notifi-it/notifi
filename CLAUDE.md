# Working in this repo

Notes for anyone (human or agent) picking this up. The design lives in
[docs/PLAN.md](docs/PLAN.md) and the manual test script in
[docs/VERIFYING.md](docs/VERIFYING.md); this file is only for things that are
easy to get wrong and expensive to discover.

## Critical Alerts: the entitlement is requested, not granted

Submitted to Apple on 2026-08-03, request ID **W8U762V6VJ**, against bundle ID
`it.notifi.notifi`. Apple replies by email. Nothing has come back yet.

**Do not add `com.apple.developer.usernotifications.critical-alerts` to
`apps/app/Support/Entitlements/notifi-iOS.entitlements` or
`notifi-macOS.entitlements` until Apple grants it.** An entitlement the App ID
does not carry fails code signing, so adding it early breaks every signed build
for a capability that still would not work.

Everything else is already merged and live: the `keys.critical` column, the
`critical=1` send parameter, `PATCH /keys/:id`, the `sound.critical` payload
path, and the per-key toggle on the key detail screen. The toggle reads
`criticalAlertSetting`, finds `.notSupported`, and says so rather than pretending
to work. When the grant arrives, adding that one key to both files is the entire
remaining change.

A push is only marked critical when the key is switched on **and** the individual
send asks for it. A send that asks without that standing is delivered as an
ordinary notification rather than refused, because dropping an alert from a pager
is worse than under-delivering one.

## The contract is the source of truth, and Swift does not follow automatically

`packages/contract/src/index.ts` holds the Zod schemas. The Swift mirrors in
`apps/app/Shared/API/ContractModels.swift` are hand-written. Changing one without
the other typechecks on both sides and fails at runtime. Edit them together.

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
