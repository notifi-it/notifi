---
name: notification-mockup
description: Draw a macOS notification banner for notifi in Apple's own Figma UI kit and export it as a PNG. Use when a banner image is needed for the website, the README or a store listing.
---

# A macOS notification banner, from Apple's kit

This produces a picture of a banner, not a banner. For proof that a real push
renders correctly, send one and screenshot the machine — see
[docs/VERIFYING.md](../../../docs/VERIFYING.md). Use this when the target is a
published image, where a real capture would carry a real desktop behind it.

## The kit is Apple's, and it is already in the account

Do not trace a screenshot into CSS and do not install a community "macOS UI"
package; both drift from whatever Apple last shipped. The source is:

1. <https://developer.apple.com/design/resources/> → macOS → the Figma link.
2. **Open in Figma** offers *Use UI Kit in a new file* or *Make a copy*. Take
   the first: it enables the library and leaves the kit's own multi-screen file
   out of the account.
3. Page **Notifications**. `Dark Example` and `Light Example` hold banners on a
   wallpaper; the 850x450 section above them is the component definition. Edit
   an example, never the definition — the definition feeds every instance.

The kit tracks a named release (macOS 27 at the time of writing) and is marked
Beta before that release ships. Check which, and say so wherever the image
lands, because the styling still moves.

## Copy comes from packages/copy, never from imagination

The banner a reader meets first is the one the empty state tells them to send,
so it is `empty.sampleTitle` and `empty.sampleMessage` — the same two strings
`EmptyStateView` prints in its curl snippet. A banner captioned with anything
else shows a product the reader cannot reproduce.

Title and message are exposed as component properties on the `Notification`
instance, so set them in the right-hand panel rather than by typing on canvas.
Editing text the first time prompts for Apple's SF Pro licence, which is a
person's decision to accept, not an agent's.

## The app icon has two traps

`icon-1024.png` is the unmasked square artwork — macOS applies the squircle
itself, so pasting it gives a hard-cornered tile. `mac-*.png` are masked but
carry the transparent margin macOS composites them with, so pasting one leaves
the artwork at 86% of the slot and it reads as small next to Apple's own icons.

Neither is right as-is. Crop the masked one to its own alpha bounds:

```bash
python3 -c "
from PIL import Image
im = Image.open('apps/app/Shared/Assets.xcassets/AppIcon.appiconset/mac-1024.png').convert('RGBA')
im.crop(im.getchannel('A').getbbox()).save('/tmp/notifi-icon.png')"
```

Figma's *Upload from computer* opens a native file dialog, which an agent
cannot drive. Go through the clipboard instead:

```bash
osascript -e 'set the clipboard to (read (POSIX file "/tmp/notifi-icon.png") as «class PNGf»)'
```

Then in Figma: select the `App Icon` node, **detach it** (`⌥⌘B`) — paste cannot
replace a component instance — right-click → **Paste to replace**, and set the
node back to 32x32, which the paste resets to the source image's size. Use the
menu item, not `⇧⌘R`: Chrome takes that as a hard reload before Figma sees it.

## Export

Select the `Notification` node itself, not the stack. 3x PNG; the export
carries the drop shadow and a transparent ground, so it composites onto any
background. 344x56 at 3x is 1320x456 including that shadow's bleed.

## Export it over a neutral ground, not the kit's wallpaper

The banner material is translucent, so the export bakes in whatever is behind
it. Over the kit's purple wallpaper the result measures (48,48,61) -- blue 13
above red -- and against notifi's neutral popover it reads as a navy card.

Before exporting, in `Dark Example`:

1. Select the `Frame` under it and give it a solid Fill of the colour the
   banner will sit on (`242424` for the popover).
2. Hide the `Desktop Template` layer, which is the wallpaper.

Then export. The same banner comes out neutral. Check it rather than trusting
it -- sample the banner's interior and the surface it will sit on, and compare
blue minus red.

## Putting it in the Mac App Store frames

`appstore-frames-mac.py` puts it on the first frame only, at
`Scripts/assets/notification-banner.png`. It stands above the menu bar rather
than over the popover: laid on the app's own screen it reads as part of the
app's interface, and a notification is the system's.

The script crops the PNG to its opaque core and casts the shadow itself, the
way it already does for the popover. That is not tidiness. At desk width the
export's baked shadow wants 73px above the artwork -- even cropped to where it
is invisible -- and the bar leaves about 150px for the whole banner, so a
banner wide enough to span the desk cannot carry its exported shadow without a
grey band running off the top of the frame. The core is measured rather than
written down, so re-exporting at a different scale changes nothing.

**A new export will not reach the frames on its own.** `publish_image.py` only
rewrites a frame when enough pixels differ by more than `EPS = 48`, and a
colour correction is far below that -- the run says `0.000% differs` and keeps
the old frame, which is the failure this gate is documented to have. Force it:

```bash
PUBLISH_ALL=1 python3 apps/app/Scripts/appstore-frames-mac.py
```

The other frames re-render byte-identical, so `git status` still shows only
what really moved and `sync_screenshots` still uploads only that.
