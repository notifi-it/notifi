#!/usr/bin/env bash
# Regenerates AppIcon.appiconset from the sources in this directory.
# Requires: rsvg-convert (librsvg), magick (ImageMagick 7).
#
# The background is a dissolve: a grayscale ramp is compared pixel-by-pixel
# against seeded random noise, and red wins wherever the ramp is brighter.
# Flat areas stay clean; only the ramp's transition band speckles.
set -euo pipefail

cd "$(dirname "$0")"
OUT="../../Shared/Assets.xcassets/AppIcon.appiconset"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# --- background -------------------------------------------------------------
rsvg-convert -w 1024 -h 1024 red-gradient.svg     -o "$TMP/red.png"
rsvg-convert -w 1024 -h 1024 fade-topright.svg    -o "$TMP/r1.png"
rsvg-convert -w 1024 -h 1024 fade-bottomleft.svg  -o "$TMP/r2.png"

magick "$TMP/r1.png" "$TMP/r2.png" -compose Darken -composite -colorspace Gray "$TMP/ramp.png"
magick -size 1024x1024 -seed 42 xc: +noise Random -colorspace Gray "$TMP/noise.png"
magick "$TMP/ramp.png" "$TMP/noise.png" -compose Mathematics \
  -define compose:args="0,-1,1,0.5" -composite -threshold 50% "$TMP/mask.png"
magick -size 1024x1024 xc:"#0A0405" "$TMP/red.png" "$TMP/mask.png" -composite "$TMP/bg.png"

# --- logo -------------------------------------------------------------------
sed 's/rgb(73.699951%, 12.89978%, 13.299561%)/rgb(100%,100%,100%)/g' notifi-logo.svg > "$TMP/white.svg"
rsvg-convert -w 2400 -h 2400 "$TMP/white.svg" -o "$TMP/logo-raw.png"
magick "$TMP/logo-raw.png" -trim +repage "$TMP/logo.png"

glyph() { # $1 = height, $2 = output
  magick "$TMP/logo.png" -resize "x$1" \
    \( +clone -background black -shadow 60x22+0+0 \) +swap \
    -background none -layers merge +repage "$2"
}

# --- iOS: full bleed --------------------------------------------------------
glyph 600 "$TMP/g-ios.png"
magick "$TMP/bg.png" "$TMP/g-ios.png" -gravity center -composite "$OUT/icon-1024.png"

# --- macOS: inset squircle plate + drop shadow ------------------------------
magick -size 1024x1024 xc:none -fill white \
  -draw "roundrectangle 100,90 924,914 185,185" "$TMP/plate-mask.png"
magick "$TMP/bg.png" "$TMP/plate-mask.png" -alpha off -compose CopyOpacity -composite "$TMP/plate.png"
magick "$TMP/plate.png" \( +clone -background black -shadow 32x12+0+10 \) +swap \
  -background none -layers merge +repage -gravity center -extent 1024x1024 "$TMP/plate-sh.png"
glyph 490 "$TMP/g-mac.png"
magick "$TMP/plate-sh.png" "$TMP/g-mac.png" -gravity center -geometry +0-10 -composite "$TMP/mac.png"

for sz in 16 32 64 128 256 512 1024; do
  magick "$TMP/mac.png" -resize "${sz}x${sz}" "$OUT/mac-$sz.png"
done

echo "Wrote $(cd "$OUT" && pwd)"
