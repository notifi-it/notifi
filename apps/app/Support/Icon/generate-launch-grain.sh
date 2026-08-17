#!/usr/bin/env bash
set -euo pipefail

# Writes the launch screen's grain, light and dark.
#
# The launch screen cannot run code, so the animated StaticField that takes over
# a moment later is impossible here — a single baked frame is the closest thing,
# and it stops the first paint of the app from being a visible change of surface.
#
# The ground and amplitude below are hand-kept copies of the ones in
# StaticField.swift (darkGround/darkAmplitude, lightGround/lightAmplitude, at
# .ground level). If those move, re-run this; a launch screen a shade off the
# view that replaces it reads as a flash.

cd "$(dirname "$0")/../.."

OUT=Shared/Assets.xcassets/LaunchGrain.imageset
mkdir -p "$OUT"

# One square tile, scaled to fill by the storyboard. Drawing it at screen size
# and showing it unscaled matches StaticField exactly, but cost 11MB of PNG for
# a screen visible for under a second; the scaling softens the speckle slightly
# and that is the trade taken here.
#
# Supplied as a 3x asset so one noise pixel starts as one device pixel — the
# size StaticField's speckle is. At 1x each speckle covers a whole point and the
# launch screen is visibly blotchier than the view that replaces it.
SIZE=1536

grain() {
  local name=$1 ground=$2 amplitude=$3
  # The Swift draws uniformly over ±amplitude, whose standard deviation is
  # amplitude/sqrt(3). ImageMagick's -attenuate is not in those units: measured
  # on this build it yields sd ~ 0.081 x attenuate, so the request is converted
  # rather than passed through. Matching the spread is the point — the mean
  # alone matched while the grain was invisible.
  local attenuate
  attenuate=$(echo "$amplitude / 1.7320508 / 0.081" | bc -l)

  #   # The palette is what makes this file small. Noise defeats PNG filtering, so a
  # truecolour tile runs to megabytes; these values sit in a narrow band around
  # one ground, so 64 levels hold them with no banding visible at this amplitude
  # and the file drops by an order of magnitude.
  # The ground is given as an 8-bit sRGB triple, not a percentage: a percentage
  # is read as a linear value and converted on the way to sRGB, which lands the
  # dark tile at 0.28 when StaticField sits at 0.11. The Swift's numbers are
  # already sRGB, so they are written straight in.
  local level
  level=$(printf '%.0f' "$(echo "$ground * 255" | bc -l)")
  magick -size ${SIZE}x${SIZE} xc:"rgb($level,$level,$level)" \
    -attenuate "$attenuate" +noise Gaussian \
    -colors 64 -depth 8 \
    -define png:compression-level=9 \
    "PNG8:$OUT/$name"
  echo "  $(du -h "$OUT/$name" | tr -s '\t' ' ' | cut -d' ' -f1)  $OUT/$name"
}

echo "launch grain:"
grain grain-light.png 0.949 0.035
grain grain-dark.png  0.11 0.055

cat > "$OUT/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "grain-light.png", "idiom" : "universal", "scale" : "3x" },
    { "filename" : "grain-dark.png", "idiom" : "universal", "scale" : "3x",
      "appearances" : [ { "appearance" : "luminosity", "value" : "dark" } ] }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
JSON
echo "  $OUT/Contents.json"
