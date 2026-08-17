# Feed redesign — plan (native-first, minimum code, minimum opinion)

## The lens

Three constraints, and they all pull the same direction:

1. **Native iOS design system**
2. **Least code — reuse as much as humanly possible**
3. **Least opinionated design**

Every custom flourish fails all three at once: it is more code to write, more opinion
to defend, and less like the platform. So the rule for this plan is blunt — **if iOS
ships a component that does the job, we use it and write nothing.**

## Headline finding

The running app already implements this design with stock components. The personality in
the HTML mockup (`docs/feed-design-glass.html`) lived entirely in CSS; ported literally
to SwiftUI it would *add* a bundled font, a custom scrolling bar, hand-drawn glass, and a
custom empty state — the exact opposite of the three constraints. **The net work here is
small, and most of it is deletion.**

What already exists, verbatim, in the code:

| Piece | Where | Status |
|---|---|---|
| Inbox = `List` of `NavigationLink` rows | `InboxView.swift:58` | ✅ stock |
| Swipe: mark-read (leading) + delete (trailing) | `InboxView.swift:63,71` | ✅ stock |
| `.searchable` | `InboxView.swift:46` | ✅ stock |
| Filter by key | `InboxView.swift:16,101` (toolbar `Picker`) | ✅ stock, see change #1 |
| `.navigationTitle("notifi")` | `InboxView.swift:45` | ✅ stock |
| Detail: `AsyncImage` + `Link` + `ShareLink` in toolbar | `MessageDetailView.swift` | ✅ stock |
| Empty state = `ContentUnavailableView` | `EmptyStateView.swift:12` | ✅ stock |
| Three pages = `TabView` | `InboxRootView.swift:10` | ✅ stock |
| Unread dot = `Color.accentColor` | `InboxView.swift:138` | ✅ stock |

That is the whole design. The redesign is not a rebuild; it is **one real change plus a
compile flag, and a list of things we deliberately will not add.**

---

## Critical analysis — mockup decision vs the iOS design system

Each row: what the mockup did → the HIG/native verdict → the minimum-code native answer.

### 1. Bricolage Grotesque as the app font — ✗ drop it
- **Verdict:** The most opinionated and most expensive choice in the mockup. A bundled
  font does not get SF Pro's optical sizing or tracking, and it only respects Dynamic
  Type if every call site uses `.font(.custom(_:relativeTo:))` — code on every label, and
  an accessibility regression the moment one is missed.
- **Native / minimum:** The **system font**. Zero code, Dynamic Type for free, adapts to
  every accessibility setting. If a whisper of character is wanted later, `.fontDesign(.rounded)`
  is one modifier at the root and still fully system. **Recommendation: plain SF Pro, no
  modifier** — the least-opinion option is literally the default.
- **Outcome:** not followed. The shipped app bundles Inconsolata and Karla. The
  Dynamic Type cost above is therefore live: every call site uses
  `.font(.custom(_:relativeTo:))`, and must keep doing so.

### 2. The key-filter bar — ✗ not a stock component as drawn
- **What the mockup drew:** an always-visible, horizontally-scrolling row of glass pills.
- **Verdict:** **iOS has no stock always-visible scrolling filter bar.** Building it means
  a custom `ScrollView` of custom buttons with custom selection state — custom code and
  custom opinion, and it does not scale (a device can hold up to 50 keys). It also stacks
  glass on glass (§4), which the platform tells you not to do.
- **Native / minimum — three stock ways to express "filter by key", pick one:**
  - **a. `Picker(.segmented)`** placed under the title — an always-visible native bar,
    zero custom drawing. This is the closest stock match to the sketch. Caps at ~4–5
    items before it cramps.
  - **b. `.searchScopes`** — a stock segmented bar tied to the search field. Most minimal
    and most native (filtering *is* a facet of search), but it appears only while the
    search field is active, so it is not always-visible.
  - **c. Toolbar `Menu`** *(what the code already has)* — a filter control that scales to
    all 50 keys. Always reachable, but a menu, not a bar.
- **Recommendation:** **Segmented `Picker` when the device holds ≤4 keys, the existing
  toolbar `Menu` beyond that.** That gives the always-visible bar you asked for in the
  common case, stays 100% stock, and degrades gracefully instead of shipping a custom
  component you have to own forever. This is the one place the design and "least code"
  genuinely trade against each other, so it is the first open decision below.

### 3. Custom "notifi" wordmark + avatar button — ✗ drop it
- **Verdict:** A custom title view forfeits the automatic large-title→inline collapse on
  scroll, and adds layout code.
- **Native / minimum:** `.navigationTitle("notifi")` with the large display mode — already
  in place. The collapse animation is free. Delete the mockup's styled wordmark idea.

### 4. Liquid Glass — ✗ never hand-draw it
- **Verdict:** The mockup hand-built translucent bars, glass pills, and glass circle
  buttons. In SwiftUI that is wrong on two counts: it is code, and manually applying
  `.glassEffect` to content that sits inside the already-glass nav/tab bar is the
  **glass-on-glass** anti-pattern.
- **Native / minimum:** **Do nothing.** `NavigationStack`, `TabView`, `.searchable`,
  `.toolbar`, and `.swipeActions` adopt Liquid Glass automatically when the app is built
  against the iOS 26 SDK. The entire glass story is a compile target, not a line of code.
  The task is the reverse of the mockup: ensure there is **no** manual `.blur`,
  `.ultraThinMaterial`, or `.glassEffect` anywhere.

### 5. Unread indicator with a glow ring — ✗ flatten
- **Verdict:** The glow is decorative and non-native.
- **Native / minimum:** A plain filled `Circle` tinted `Color.accentColor` — already what
  the code does (`InboxView.swift:138`). Keep it flat.

### 6. Decorative wallpaper behind the glass — ✗ mockup-only
- The gradient existed so CSS glass had something to refract. The real surface is
  `.systemGroupedBackground`; glass refracts the actual scrolling content. Nothing to build.

### 7. Detail page: glass circle buttons + prominent red link — ~ use stock slots
- **Verdict:** Share/more as hand-drawn glass circles is code; a red-tinted prominent
  button raises the destructive-colour problem (§8).
- **Native / minimum:** `ShareLink` and a `Menu` as `ToolbarItem`s (auto-glass),
  `AsyncImage` for the image, `Link` for the URL — **all already in `MessageDetailView`.**
  Reuse as-is. If the link should be prominent, `.buttonStyle(.borderedProminent)` is one
  modifier; leave it plain for least opinion.

### 8. Red as the app tint — ⚠ real HIG cost, your call
- **Verdict:** iOS reserves **red for destructive actions**. Make red the global tint and
  the primary "Open link" button and the delete-swipe now share one colour — the accent
  stops meaning "do this" and starts blurring into "danger". This is a genuine design-system
  conflict, not a nitpick.
- **Options:**
  - **System default (blue)** — least opinion, zero code, what the app does today.
  - **Brand red** — one `.tint()` at the root; buys identity, accepts the collision.
- Second open decision below. If red wins, keep destructive actions on the *system* red
  role (don't recolour them) so at least the platform's own delete styling stays intact.

### 9. Empty state: the Flutter sad-bell vs `ContentUnavailableView` — keep the native one
- **Verdict:** You called the running empty state "awful," and earlier we admired the old
  Flutter sad-bell. But under *these three constraints* the sad-bell is a custom view, a
  bundled asset, and pure opinion. `ContentUnavailableView` is the native, one-view,
  Dynamic-Type-and-VoiceOver-handled answer.
- **Native / minimum:** **Keep `ContentUnavailableView`**, fix what actually made it feel
  cheap — the *copy* and the actions, not the component. Give it a real title, a one-line
  pitch, and the Create-Key / Enable-Notifications buttons (already there). One optional
  sliver of identity that stays free: pass a custom SF Symbol or the app's bell as the
  icon. Third open decision.

### 10. Swipe-to-delete, no alert — ✓ already correct
- The mockup and the code agree and both match the platform: leading swipe marks read,
  trailing swipe deletes with `role: .destructive`, full-swipe deletes immediately, **no
  `confirmationDialog`.** This is exactly `.swipeActions`, already in `InboxView`. Keep,
  and just confirm `allowsFullSwipe` is on and no confirmation is wired.

---

## The actual change list

Small on purpose. In priority order:

1. **Filter → always-visible native bar (pending decision #1).** Replace the hidden
   toolbar `Picker` with a segmented `Picker` under the title when `keys.count <= 4`, and
   keep the toolbar `Menu` when there are more. Gate the whole thing on `keys.count > 1`
   (one key → no filter, as agreed). Net code roughly flat — a `Picker` swapped for a
   `Picker`.
2. **Glass = compile on iOS 26.** Confirm the build targets the iOS 26 SDK so stock
   chrome turns to glass automatically, and grep the app for any manual `.blur` /
   `.material` / `.glassEffect` and remove it. Zero UI code added.
3. **Tint (pending decision #2).** Either leave the system default or add one `.tint()` at
   the root. One line, or none.
4. **Empty-state copy (pending decision #3).** Tighten the `ContentUnavailableView` text;
   optionally swap the icon. Copy only.
5. **Nothing else.** No font, no custom bar, no glass code, no custom empty state, no
   wordmark, no wallpaper, no glow.

## Explicitly NOT building (rejected on all three axes)

Bricolage Grotesque · the custom scrolling pill bar · hand-rolled Liquid Glass · the
styled wordmark · the sad-bell empty state · the decorative wallpaper · the glow ring.
Each one is more code, more opinion, and less native.

## Open decisions (need you)

1. **The filter bar.** Accept the stock realization — segmented `Picker` for a few keys,
   toolbar `Menu` beyond — or insist on the always-visible scrolling pill bar as drawn
   (custom component, against the three constraints)?
2. **Tint.** System blue (least opinion) or brand red (identity, with the destructive-red
   caveat)?
3. **Empty state.** Keep `ContentUnavailableView` with better copy (recommended), or spend
   code on the custom sad-bell?

Answer those three and the build is an afternoon, most of it deleting things.
