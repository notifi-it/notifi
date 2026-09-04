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

Select a part and read the right-hand panel — but **do not stop there**. The
panel describes the file, not the picture. The App Icon node reads 32x32, yet
what a reader sees is a 30pt squircle at x 15.3: the node sits at +4 inside its
frame and holds artwork inset within itself. Taking the panel at its word put
the icon 2pt too big and 3pt too far left.

So export the banner once and measure the export. Panel values are the starting
guess; the export is the answer.

| From the panel | Measured off the export |
|---|---|
| Notification 344 x 56, padding 10/12/14/12, gap 8 | card 344 x 56, corner radius 18 |
| App Icon 32 x 32 | 30pt squircle at x 15.3, y 13 |
| Title SF Pro Bold 13/16, tracking -2% | glyph ink at x 59.2, baseline 25.0 |
| Description SF Pro Regular 13/16, -0.8% | second baseline at 41.0 |
| (not in the panel) | timestamp 11pt, 15.3 in from the right |

`banner.py` places text on its baselines rather than by a line box, because a
baseline is the one horizontal in a font that does not move when the size, the
weight or the optical cut changes.

### Checking it

Export once and diff against it — it is the only way to catch the errors above,
all of which looked fine until measured. The export is deliberately not kept in
the repo: it would drift from the kit and start being trusted. Re-export when
you need to check. Render the banner at the
export's exact width on the export's own ground, then compare ink extents per
element:

```
title  ref   59.2.. 128.1 (w  68.9) | ours   59.2.. 128.8 (w  69.5) | dx +0.0 dw +0.7
body   ref   59.2.. 155.4 (w  96.1) | ours   59.2.. 157.4 (w  98.1) | dx +0.0 dw +2.0
now    ref  309.4.. 328.7 (w  19.3) | ours  308.4.. 328.0 (w  19.6) | dx -1.0 dw +0.3
```

A `dx` is a placement bug and should go to zero. The residual `dw` is the font,
not the geometry: SF Pro's Optical Size axis floors at 17 and the banner sets
copy at 13, so the closest cut the system font can give is about 1% wide on a
title and 2% on a body line. Closing that means shipping a font file, which is
not worth a font. Do not chase it with tracking — that fits one string and
breaks the next.

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
icons — and the margin is a *shadow*, so cropping to any alpha at all keeps it:
that landed the squircle at 93% of the slot, sitting high, casting a second
shadow inside a banner that already has one. `banner.icon_art` takes the masked
icon and crops to its **opaque** bounds, which is the only combination that is
round, full and unshadowed.

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
