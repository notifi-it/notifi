---
name: notification-mockup
description: Get macOS/iOS notification banner geometry out of Apple's own Figma UI kit, and change the banner the App Store frames draw from it. Use when the banner in a store screenshot needs adjusting, or when a new piece of Apple system UI has to be reproduced.
---

# The notification banner in the store frames

The banner on the first Mac and iOS store frames is **drawn** by
`apps/app/Scripts/banner.py`, not pasted from a file. Change how it looks there.
Figma is where its numbers came from, and where to go for numbers it does not
yet have.

For proof that a real push renders correctly, send one and photograph the
machine — see [docs/VERIFYING.md](../../../docs/VERIFYING.md). This is for
published pictures, where a real capture would carry a real desktop behind it.

## Why it is drawn and not exported

An export was tried first and cannot work. The material is translucent, so the
PNG bakes in whatever stood behind it in Figma: over the kit's wallpaper it
came out measurably navy — (48,48,61) against a neutral (36,36,36) popover.
Worse, the material's backdrop is a *rectangle*, so the rounded card arrives
inside a grey box that shows against any ground it is placed on.

Both are properties of exporting translucency, not mistakes to be exported
around. Drawing it instead makes the ground behind it real, and makes light and
dark one argument rather than two files.

## Getting numbers out of the kit

1. <https://developer.apple.com/design/resources/> → macOS → the Figma link.
2. **Open in Figma** → *Use UI Kit in a new file*. The kit is already available
   to the account as a library, so this enables it without copying Apple's
   multi-screen file in.
3. Page **Notifications**. The 850x450 section at the top is the component
   definition; `Dark Example` and `Light Example` below it are instances on a
   wallpaper. Read numbers off an instance.

Select a part and read the right-hand panel — that is where every figure in
`banner.py` came from:

| Panel | Value |
|---|---|
| Notification frame | W 344, H 56, padding 10 / 12 / 14 / 12, gap 8 |
| App Icon | 32 x 32 |
| Title | SF Pro Bold 13, line height 16, letter spacing -2% |
| Description | SF Pro Regular 13, line height 16, letter spacing -0.8% |

The corner radius is not in the panel for a component instance. Export once and
measure it — 18pt — rather than guessing; the rest of the geometry hangs off the
card's shape.

Editing text in the kit prompts for Apple's SF Pro licence. That is a person's
decision to accept, not an agent's.

The kit tracks a named release and is marked Beta before that release ships.
Check which, because the geometry moves between them.

## Changing the banner

Everything lives at the top of `banner.py`: the point geometry, `BLUR_PT` and
`TINT_A` for how much ground reads through the glass, and a `MODES` table
holding tint, ink, edge and shadow for light and dark. The two frame scripts
choose a mode and a width; nothing else knows how a banner is built.

Its words are not written there. They are the app's own first-run sample —
`empty.sampleTitle` and `empty.sampleMessage` — carried into
`fastlane/screenshot-copy.json` by `make gen-copy`, so the banner reads in the
reader's language and shows something they can reproduce on the first try. The
timestamp stays English, like the menu bar clock beside it: it is Apple's
chrome, not our copy.

## Two traps in the app icon

`icon-1024.png` is the **unmasked square** — macOS and iOS both apply the
squircle themselves, so pasting it gives a hard-cornered tile. The `mac-` icons
are masked but carry the transparent margin macOS composites them with, which
lands the artwork at 86% of the slot and reads as small beside Apple's own
icons. `banner.icon_art` takes the masked one and crops to its alpha, which is
the only combination that is both round and full.

## Re-rendering

```bash
PUBLISH_ALL=1 python3 apps/app/Scripts/appstore-frames-mac.py
```

`PUBLISH_ALL` matters. `publish_image.py` only rewrites a frame when pixels
differ by more than `EPS = 48`, and a colour or spacing change is far below
that: the run says `0.000% differs` and silently keeps the old frame. Frames
that really are unchanged re-render byte-identical, so `git status` still shows
only what moved and `sync_screenshots` still uploads only that.

The iOS frames are not the same: `screens.sh` recaptures the app once per
locale, so their screenshots carry that language's UI and cannot be re-rendered
from one set of captures. Changing the banner there means `make screens`, which
builds and drives the Simulator. In a fresh worktree run
`cd apps/app && xcodegen generate` first — the `.xcodeproj` is generated and not
committed, and without it the build fails with "does not exist".
