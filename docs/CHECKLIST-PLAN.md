# checklist.design plan for the notifi iOS app — detailed designs

Each item below says what the user sees, the exact behavior and states, which
tokens and files it touches, and what new copy it needs. New strings go in
`packages/copy/src/strings.ts` and every language in
`packages/copy/src/translations/` — a missing key fails `make gen-copy`.

Deployment floor is iOS 17 / macOS 14 (`apps/app/project.yml`), so
`.sensoryFeedback` is usable unguarded.

---

## Phase 1 — pure gaps, small changes

### 1. Haptics (tab bar, toggle, button checklists)

The app has zero haptic feedback. Design: quiet by default — feedback marks
*outcomes*, not taps. Buttons don't buzz on press; only completed actions do.

| Event | Feedback | Where |
|---|---|---|
| Tab switch | `.selection` | `sensoryFeedback(.selection, trigger: selectedTab)` on the iOS `TabView` in `NotifiApp.swift` |
| Toggle flip | `.selection` | `ToggleRow` in `GeistComponents.swift`, trigger on bound value |
| Copy (key value, curl, message title/link) | `.impact(weight: .light)` | `KeyDetailView.swift`, `MessageFeed.swift` context menu, `MessageDetailView.swift` |
| Swipe mark read/unread | `.impact(weight: .light)` | `MessageFeed.swift` swipe action |
| Key created and revealed | `.success` | `CreateKeyView.swift` on phase → `.revealed` |
| Send test succeeded / failed | `.success` / `.error` | `SettingsView.swift`, `EmptyStateView.swift` |
| Delete / revoke / regenerate completed | `.success` | after the store call returns, not when the alert appears |

Implementation: plain `.sensoryFeedback` modifiers at the call sites, wrapped
in `#if os(iOS)` where the view is shared with macOS (the API exists on macOS
but does nothing; the guard documents intent). No new component. No copy.

### 2. Launch screen (splash-screen checklist)

Today `UILaunchScreen` is an empty `<dict/>` in
`apps/app/Support/Info/App-iOS-Info.plist`, so cold launch flashes the system
background (white in system-light) before `Theme.bg` paints — and the app
defaults to dark.

Design: a solid background in `Theme.bg`'s values, with the bell mark centred.

- New color asset `LaunchBackground` in `Shared/Assets.xcassets`: light
  `0.98` grey, dark `0.11` grey (the exact `Theme.bg` pair,
  `Theme.swift:26`). The launch screen follows the *system* scheme while the
  app forces its own; when those differ there is one frame of mismatch —
  accepted, it beats a white flash.
- New imageset `LaunchBell`: the bell glyph, `Theme.mark`-grey, ~88pt. Must be
  emitted by `Support/Icon/generate-marks.sh` from `notifi-logo.svg` (the
  bell is drawn once — repo rule), light and dark variants.
- Plist: `UILaunchScreen` → `UIColorName: LaunchBackground`,
  `UIImageName: LaunchBell`. No text, no spinner, nothing interactive.

### 3. App icon dark + tinted variants (icon checklist, iOS 18+)

`AppIcon.appiconset/Contents.json` carries a single `icon-1024.png`; on
iOS 18+ home screens set to dark or tinted, the system auto-treats it instead
of using art-directed variants.

Design, derived from the existing icon (red field, white bell):

- **Dark**: transparent background, the bell on the brand-red disc/field kept —
  the system supplies the dark backplate. If the current icon is a full-bleed
  red square, the dark variant is the same art with the field darkened toward
  `Theme.bg`-dark so it doesn't glow on a dark grid.
- **Tinted**: greyscale heightmap — white bell on black, transparent corners.
  The system applies the user's tint.

Implementation: extend `Support/Icon/generate-marks.sh` to render
`icon-1024-dark.png` and `icon-1024-tinted.png` from `notifi-logo.svg`, and add
the two `appearances` entries (`luminosity: dark`, `luminosity: tinted`) to
`Contents.json`. Mac icons unchanged.

### 4. Feedback for silent actions (toast checklist — resolved without toasts)

Context-menu copy title / copy message / copy link and mark-all-read complete
with no confirmation (`MessageFeed.swift:254-259`). A toast layer is the
checklist's answer; this app's answer stays quieter:

- Copy actions: the light-impact haptic from item 1 **plus** a VoiceOver
  announcement via the existing `AccessibilityNotification.Announcement`
  pattern. New copy key `inbox.copied` ("Copied").
- Mark all read: no extra chrome — the unread styling and tab badge clearing
  *is* the confirmation. Add the `.success` haptic and announce the existing
  result state.

No new component; no toast layer enters the design system.

---

## Phase 2 — error and offline visibility

### 5. Inbox refresh failure + disconnected state (empty-state checklist: error variant)

`KeysView` shows `InlineError` when `keysRefreshFailed`; the Inbox has no
equivalent — a failed pull-to-refresh or dead socket shows nothing.

Design:

- **Refresh failure**: `InlineError` (`GeistComponents.swift:480` — danger
  text, border, VoiceOver announcement) rendered directly under `FeedHeader`,
  same placement rhythm as KeysView. Appears when a manual refresh throws;
  clears on the next successful sync. New copy key `inbox.refreshFailed`
  ("Couldn't refresh. Pull down to try again.").
- **Disconnected**: a muted `Chip` (existing component) in the header row,
  label from new key `inbox.offline` ("Offline"). Driven by `SocketClient`
  state with a ~5s grace period before showing, so reconnect blips don't
  flicker it. Disappears immediately on reconnect. Colors: `Theme.dim` text,
  `Theme.chip` fill — informational, not danger; the socket dropping is not an
  error, missing it silently is.
- State plumbing mirrors `keysRefreshFailed` in `Store/SyncEngine.swift:334`.

### 6. Decision: undo on delete — recommend **no**

The in-app-notifications checklist wants swipe-to-dismiss with undo. This app
confirms deletes with a centred alert naming the message and disables
full-swipe. For a pager, deliberate-and-confirmed beats fast-with-undo; adding
undo would also add a toast layer item 4 deliberately avoided. Keep the alert,
skip undo. (If overruled: undo means deferring the server delete ~5s, which
contradicts "trust the socket" — it's a real cost, not a UI tweak.)

---

## Phase 3 — Settings and Keys polish

### 7. Support path in Settings (settings checklist)

About section (`SettingsView.swift`) has privacy policy + website links but no
way to report a problem. Design: one `Link` row "Contact support" →
`mailto:` (or the site's support page — pick whichever exists), placed in
About above the legal links, styled like the existing privacy-policy row. New
copy key `settings.support`.

### 8. Docs link on Keys (api-keys checklist)

Key detail offers copy-curl but nothing links to the API docs. Design: the
existing footnote under the key list (`KeysView.swift`) gains a `Link` to the
site's docs, `metaSmall` in `Theme.dim`, underlined on the link text only. New
copy key `keys.docsLink`.

Also verify against the api-keys checklist: key list rows should surface
last-used — `KeyDetailView` has usage `FieldRow`s; if the list row doesn't
show last-used, add it as the row's second line in `metaSmall`/`Theme.dim`.

### 9. Create-key character counter (input-field checklist)

Validation stays submit-time (documented decision in `CreateKeyView.swift`).
Add only a counter for the 64-char limit:

- Hidden until 48 chars. Then right-aligned under the field: `{n}/64` in
  `Theme.metaSmall`, `Theme.dim`; switches to `Theme.danger` at 64.
- Input is not truncated or blocked — the counter warns, submit validates.
- New copy key `keys.charCount` with `{n}` and `{max}` placeholders (digits
  and a slash, but every user-facing literal lives in `packages/copy`).

---

## Phase 4 — search and larger screens

### 10. Search extras (mobile search checklist)

- **Recent searches** (iOS): last 5 submitted queries in `UserDefaults`,
  shown as tappable `Chip`s under the search field when the query is empty,
  with a "Clear" text button (`metaSmall`, `Theme.dim`). Tapping a chip runs
  the search. New copy keys `search.recent` ("Recent") and `search.clear`
  (reuse the existing clear string if one exists in `strings.ts`).
- **Verify, don't build**: clear-query button and keyboard focus come free
  with `.searchable` — confirm on Simulator, no code expected.
- **macOS `⌘F`**: `.keyboardShortcut("f", modifiers: .command)` toggling the
  header `SearchField` in the popover, focusing it when shown.

### 11. iPad — scope decision before any work

`TARGETED_DEVICE_FAMILY = "1,2"` but iPad renders the iPhone layout capped at
`Theme.measure` (620pt). Two honest options:

- **A (cheap)**: keep the capped single column, centred; audit it once on an
  iPad Simulator for anything broken. Ship as-is.
- **B (project)**: `NavigationSplitView` — sidebar (Inbox/Keys/Settings) +
  detail pane, Inbox selection opens message detail in the pane. Touches
  navigation on every screen; its own PR series.

Recommend A now, B only if iPad usage ever matters. Not bundled with any other
phase.

---

## Phase 5 — accessibility depth

### 12. Headings and hints

- `SectionLabel` (`GeistComponents.swift`) gains
  `.accessibilityAddTraits(.isHeader)` — VoiceOver users can then jump by
  heading through long Settings/Keys screens. One-line change, applies
  everywhere at once.
- `accessibilityHint` (used twice today) added only where the label alone
  under-explains: copy-curl ("Copies a ready-to-run curl command"), regenerate
  default key, the send-test button. Hints are copy — new keys under an
  `a11y.` namespace in `strings.ts`.

### 13. Updater state read non-reactively

`SettingsView.swift:170-180` reads `Updater.shared.canCheck` /
`automaticallyChecks` directly in `body`, so the disabled state may not refresh
when Sparkle's state changes. Fix while in the file for item 7: expose them as
observable state (`@Observable` wrapper or republished `@State` refreshed
`onAppear`). Behavior-only; no visual change.

---

## Copy summary (all phases)

New keys: `inbox.copied`, `inbox.refreshFailed`, `inbox.offline`,
`settings.support`, `keys.docsLink`, `keys.charCount`, `search.recent`,
`search.clear` (if not existing), plus `a11y.*` hints. Each lands in
`strings.ts` **and** every file in `src/translations/`, then `make gen-copy`;
`make check-copy` gates CI.

## Verification (every phase)

`make typecheck`; both schemes
(`xcodebuild … -scheme notifi-iOS` with `DEVELOPMENT_TEAM=Z28DW76Y3W`, and
`notifi-macOS`); Simulator screenshots of all three tabs (shared-geometry
rule) plus each touched screen. Haptics can't be
screenshotted — state plainly in the PR which triggers were exercised by hand
on the Simulator (impact/selection fire in the Simulator's haptics log) or
that device verification is pending.

## PR slicing

- PR 1: haptics (item 1) + silent-action feedback (4) — same call sites.
- PR 2: launch screen (2) + icon variants (3) — both are `generate-marks.sh`.
- PR 3: inbox error + offline (5).
- PR 4: settings/keys polish (7, 8, 9, 13).
- PR 5: search extras (10).
- PR 6: a11y depth (12).
- iPad (11) and undo (6) are decisions, not PRs, until answered.
