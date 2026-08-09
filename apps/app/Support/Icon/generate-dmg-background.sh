#!/usr/bin/env bash
# Draws the background of the disk image the Mac app ships in.
# Requires: rsvg-convert (librsvg).
#
# The window this sits behind is 660 x 410 of content, and Finder draws the two
# icons on top of it at the positions declared below. They are repeated in
# apps/app/Scripts/dmg-layout.applescript, which is what actually places them --
# a mark drawn here at coordinates the layout script does not share puts the
# trail somewhere the eye reads as pointing at nothing. Change both together.
#
# The wordmark is pulled from apps/api/public/wordmark.svg rather than redrawn,
# for the reason Wordmark.swift gives: a second copy of the word drifts.
set -euo pipefail

cd "$(dirname "$0")"
OUT="../../Shared/Resources/dmg-background"
WORDMARK="../../../api/public/wordmark.svg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

W=660
H=410
ICON_Y=214       # centre of both Finder icons
APP_X=170
FOLDER_X=490

# The wordmark's own box, so it can be placed as a group rather than rescaled.
MARK_W=170
MARK_H=$(python3 -c "print(f'{$MARK_W * 1000 / 3450:.2f}')")
MARK_X=$(python3 -c "print(f'{($W - $MARK_W) / 2:.2f}')")
MARK_Y=64

# The span the trail occupies: everything between the two icons, clear of both.
TRAIL_FROM=$((APP_X + 76))
TRAIL_TO=$((FOLDER_X - 76))

python3 - "$WORDMARK" "$TMP" <<PY
import re, sys
wordmark, tmp = sys.argv[1], sys.argv[2]
body = open(wordmark).read()
# Strip the wrapper; the glyphs are kept as a group so the whole word can be
# translated and scaled once.
inner = body.split(">", 1)[1].rsplit("</svg>", 1)[0]
inner = re.sub(r"<title>.*?</title>", "", inner, flags=re.S)
inner = re.sub(r"<!--.*?-->", "", inner, flags=re.S)

# Nine dots spanning the gap between the icons. Radius
# and opacity both ramp, so the trail gains weight in the direction of travel
# without any one dot being large enough to read as a bullet.
first, last, n = $TRAIL_FROM, $TRAIL_TO - 2, 9
trail = "\n  ".join(
    '<circle cx="%.2f" cy="$ICON_Y" r="%.2f" fill="#C4C4C8" fill-opacity="%.3f"/>'
    % (first + (last - first) * i / (n - 1), 1.1 + 1.5 * (i / (n - 1)) ** 1.6,
       0.16 + 0.62 * (i / (n - 1)) ** 1.3)
    for i in range(n)
)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="$W" height="$H" viewBox="0 0 $W $H">
  <defs>
    <!-- Same three-layer near-black as the app icon's plate: a top-lit ramp, a
         pool of light where the content sits, corners closed off. The window
         has no titlebar chrome of its own on this ground, so the vignette is
         what gives it an edge. -->
    <linearGradient id="ramp" x1="0" y1="0" x2="0.2" y2="1">
      <stop offset="0" stop-color="#242426"/>
      <stop offset="1" stop-color="#141416"/>
    </linearGradient>
    <!-- userSpaceOnUse throughout: a bounding-box gradient on a horizontal line
         has no height to interpolate across and renders as nothing. -->
    <radialGradient id="pool" gradientUnits="userSpaceOnUse"
                    cx="{$W/2}" cy="$ICON_Y" r="{$W*0.62}"
                    gradientTransform="translate({$W/2}, $ICON_Y) scale(1, 0.55) translate({-$W/2}, {-$ICON_Y})">
      <stop offset="0" stop-color="#37373B" stop-opacity="0.7"/>
      <stop offset="0.55" stop-color="#2C2C2F" stop-opacity="0.3"/>
      <stop offset="1" stop-color="#2C2C2F" stop-opacity="0"/>
    </radialGradient>
  </defs>

  <rect width="$W" height="$H" fill="url(#ramp)"/>
  <rect width="$W" height="$H" fill="url(#pool)"/>

  <g transform="translate($MARK_X, $MARK_Y) scale({$MARK_W/3450})" fill="#EDEDED">
    {inner}
  </g>

  <!-- The drag, as a dropped trail rather than a drawn arrow: dots growing and
       brightening toward the folder. There is no head. The ramp is what carries
       the direction, and a chevron on the end turned the trail back into the
       arrow it replaced. -->
  {trail}

  <!-- Set in the system sans, not a mono. The wordmark above is mono, and the
       caption in the same voice read as a second line of the logotype rather
       than as the instruction; the two Finder labels between them are sans, so
       this sides with the window it is captioning. -->
  <text x="{$W/2}" y="350" text-anchor="middle"
        font-family="SF Pro Text, Helvetica Neue, sans-serif" font-size="14"
        font-weight="500" letter-spacing="0.1" fill="#B4B4B8">Drag notifi into Applications</text>

</svg>'''
open(f"{tmp}/bg.svg", "w").write(svg)
PY

mkdir -p "$OUT"

# Grain, laid on after rasterising rather than as an SVG filter: feTurbulence
# through librsvg came out either invisible or as bands of its own, and the
# whole point of the layer is that it is per-pixel. The ground is three
# near-blacks a few steps apart, which on an 8-bit panel rings into visible
# contours around the pool; this is here to break those up, not as texture, so
# it is monochrome and shallow enough that a screenshot of the window looks flat.
grain() {                     # grain <svg-width> <svg-height> <out>
  local w="$1" h="$2" out="$3"
  rsvg-convert -w "$w" -h "$h" "$TMP/bg.svg" -o "$TMP/flat.png"
  # Noise generated at 1x and scaled up, so the 2x asset carries the same size
  # of speck on screen as the 1x one rather than half of it.
  magick -size "${W}x${H}" xc:gray50 +noise Gaussian -attenuate 0.55 \
         -colorspace Gray -resize "${w}x${h}" "$TMP/noise.png"
  magick "$TMP/flat.png" "$TMP/noise.png" -compose Overlay -composite "$TMP/rough.png"
  # Overlay at full strength is far too much on this ground; the blend is what
  # sets the actual depth of the grain.
  magick "$TMP/flat.png" "$TMP/rough.png" -compose blend \
         -define compose:args=45 -composite -alpha off "$out"
}

# One asset, drawn at 2x and tagged 144 dpi. A .DS_Store holds a single
# background file and Finder sizes it by its stored resolution, so 144 dpi is
# how a 1320 x 820 image comes out as a 660 x 410 window that is sharp on a
# Retina display. Shipping the 1x file instead is legible but visibly soft, and
# the grain in it lands as blotches twice the size it was drawn.
grain "$((W * 2))"  "$((H * 2))"  "$OUT/background.png"
magick "$OUT/background.png" -density 144 -units PixelsPerInch "$OUT/background.png"

echo "wrote $OUT/background.png -- 2x pixels, 144 dpi, presents as ${W}x${H}"
echo "icon centres: app ($APP_X, $ICON_Y)  Applications ($FOLDER_X, $ICON_Y)"
echo "keep those in step with Scripts/dmg-layout.applescript"
