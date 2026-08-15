#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
OUT="../../Shared/Resources/dmg-background"
WORDMARK="../../../api/public/wordmark.svg"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

W=660
H=410
ICON_Y=214
APP_X=170
FOLDER_X=490

MARK_W=170
MARK_H=$(python3 -c "print(f'{$MARK_W * 1000 / 3450:.2f}')")
MARK_X=$(python3 -c "print(f'{($W - $MARK_W) / 2:.2f}')")
MARK_Y=64

TRAIL_FROM=$((APP_X + 76))
TRAIL_TO=$((FOLDER_X - 76))

python3 - "$WORDMARK" "$TMP" <<PY
import re, sys
wordmark, tmp = sys.argv[1], sys.argv[2]
body = open(wordmark).read()

inner = body.split(">", 1)[1].rsplit("</svg>", 1)[0]
inner = re.sub(r"<title>.*?</title>", "", inner, flags=re.S)
inner = re.sub(r"<!--.*?-->", "", inner, flags=re.S)

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


</svg>'''
open(f"{tmp}/bg.svg", "w").write(svg)
PY

mkdir -p "$OUT"

grain() {
  local w="$1" h="$2" out="$3"
  rsvg-convert -w "$w" -h "$h" "$TMP/bg.svg" -o "$TMP/flat.png"
  magick -size "${W}x${H}" xc:gray50 +noise Gaussian -attenuate 0.55 \
         -colorspace Gray -resize "${w}x${h}" "$TMP/noise.png"
  magick "$TMP/flat.png" "$TMP/noise.png" -compose Overlay -composite "$TMP/rough.png"
  magick "$TMP/flat.png" "$TMP/rough.png" -compose blend \
         -define compose:args=45 -composite -alpha off "$out"
}

grain "$((W * 2))"  "$((H * 2))"  "$OUT/background.png"
magick "$OUT/background.png" -density 144 -units PixelsPerInch "$OUT/background.png"

echo "wrote $OUT/background.png -- 2x pixels, 144 dpi, presents as ${W}x${H}"
echo "icon centres: app ($APP_X, $ICON_Y)  Applications ($FOLDER_X, $ICON_Y)"
echo "keep those in step with Scripts/dmg-layout.applescript"
