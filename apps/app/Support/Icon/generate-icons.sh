#!/usr/bin/env bash
# Regenerates AppIcon.appiconset from the sources in this directory.
# Requires: rsvg-convert (librsvg), magick (ImageMagick 7), python3.
#
# Palette matches the app's design system: near-black surface (#0B0B0B),
# white glyph (#EDEDED), red accent (#DB4A4B). The background is a dark
# gradient; a faint seeded grain keeps the large sizes from banding.
set -euo pipefail

cd "$(dirname "$0")"
OUT="../../Shared/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- background -------------------------------------------------------------
rsvg-convert -w 1024 -h 1024 black-bg.svg -o "$TMP/bg-flat.png"
magick -size 1024x1024 -seed 42 xc: +noise Random -colorspace Gray -blur 0x0.4 "$TMP/grain.png"
# png:color-type=6 is required: the background is neutral, so ImageMagick would
# otherwise store it as greyscale and desaturate the red dot when compositing.
magick "$TMP/bg-flat.png" "$TMP/grain.png" -compose Blend -define compose:args=6% \
  -composite -colorspace sRGB -define png:color-type=6 "$TMP/bg.png"

# --- logo: white bell, red dot ----------------------------------------------
# Path index 1 in the source SVG is the bell's dot; everything else is the bell.
python3 - "$TMP/two-tone.svg" <<'PY'
import re, sys
src = open("notifi-logo.svg").read()
BRAND = "rgb(73.699951%, 12.89978%, 13.299561%)"
out, cursor = [], 0
for i, m in enumerate(re.finditer(r"<path[^>]*>", src)):
    colour = "rgb(85.9%, 29%, 29.4%)" if i == 1 else "rgb(92.9%, 92.9%, 92.9%)"
    out.append(src[cursor:m.start()])
    out.append(m.group(0).replace(BRAND, colour))
    cursor = m.end()
out.append(src[cursor:])
open(sys.argv[1], "w").write("".join(out))
PY

rsvg-convert -w 2400 -h 2400 "$TMP/two-tone.svg" -o "$TMP/logo-raw.png"
magick "$TMP/logo-raw.png" -trim +repage "$TMP/logo.png"

glyph() { # $1 = height, $2 = output
  magick "$TMP/logo.png" -resize "x$1" \
    \( +clone -background black -shadow 55x18+0+0 \) +swap \
    -background none -layers merge +repage "$2"
}

# --- iOS: full bleed --------------------------------------------------------
glyph 600 "$TMP/g-ios.png"
magick "$TMP/bg.png" "$TMP/g-ios.png" -gravity center -composite "$OUT/icon-1024.png"

# --- macOS: inset squircle plate + hairline + drop shadow -------------------
magick -size 1024x1024 xc:none -fill white \
  -draw "roundrectangle 100,90 924,914 185,185" "$TMP/plate-mask.png"
magick "$TMP/bg.png" "$TMP/plate-mask.png" -alpha off -compose CopyOpacity -composite "$TMP/plate.png"
magick "$TMP/plate.png" -fill none -stroke "rgba(255,255,255,0.10)" -strokewidth 3 \
  -draw "roundrectangle 101,91 923,913 184,184" "$TMP/plate-edge.png"
magick "$TMP/plate-edge.png" \( +clone -background black -shadow 32x12+0+10 \) +swap \
  -background none -layers merge +repage -gravity center -extent 1024x1024 \
  -colorspace sRGB -define png:color-type=6 "$TMP/plate-sh.png"
glyph 490 "$TMP/g-mac.png"
magick "$TMP/plate-sh.png" "$TMP/g-mac.png" -gravity center -geometry +0-10 -composite "$TMP/mac.png"

for sz in 16 32 64 128 256 512 1024; do
  magick "$TMP/mac.png" -resize "${sz}x${sz}" "$OUT/mac-$sz.png"
done

echo "Wrote $(cd "$OUT" && pwd)"
