#!/usr/bin/env bash
# Regenerates menu_icon.imageset/menu.png — the macOS menu bar glyph.
# Requires: rsvg-convert (librsvg), python3.
#
# The logo's bell is drawn as filled outlines, not strokes, so it renders far
# thinner than the system menu bar glyphs (Bluetooth, Spotlight). STROKE adds a
# stroke of the same colour to each outline, which grows it by STROKE/2 on both
# edges and thickens the line by STROKE overall. Values above ~0.8 start closing
# the gap inside the clapper.
#
# The logo also carries a wide margin inside its viewBox, which left the bell
# noticeably shorter than its neighbours in the bar. The glyph is therefore
# trimmed and re-centred on the canvas at GLYPH_PT tall — measured off the bar,
# Bluetooth and the battery run 15-16pt in the same 20pt slot.
set -euo pipefail

cd "$(dirname "$0")"
OUT="../../Shared/Assets.xcassets/menu_icon.imageset/menu.png"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STROKE=0.6
CANVAS=102     # pixels, drawn by MacMenuBar into a 20pt square
SLOT_PT=20
GLYPH_PT=16

python3 - "$TMP/menu.svg" "$STROKE" <<'PY'
import re, sys

out_path, stroke = sys.argv[1], float(sys.argv[2])
src = open("notifi-logo.svg").read()
BRAND = "rgb(73.699951%, 12.89978%, 13.299561%)"

# Path 0 is the clapper, already a stroke. Path 1 is the dot, which stays the
# size it is. Paths 2 onwards are the bell's filled outlines.
parts, cursor = [], 0
for i, m in enumerate(re.finditer(r"<path[^>]*>", src)):
    tag = m.group(0)
    if i == 0:
        tag = tag.replace('stroke-width="1.3"', 'stroke-width="%.3f"' % (1.3 + stroke))
    elif i > 1:
        tag = tag.replace(
            "<path",
            '<path stroke="%s" stroke-width="%.3f" stroke-linejoin="round" stroke-linecap="round"'
            % (BRAND, stroke),
            1,
        )
    parts.append(src[cursor:m.start()])
    parts.append(tag.replace(BRAND, "rgb(0%,0%,0%)"))
    cursor = m.end()
parts.append(src[cursor:])
open(out_path, "w").write("".join(parts))
PY

GLYPH_PX=$(python3 -c "print(round($CANVAS * $GLYPH_PT / $SLOT_PT))")

# Rendered oversized so the trim lands on solid pixels rather than the SVG's
# antialiased fringe, then scaled down to the height the bar wants.
rsvg-convert -w 1024 -h 1024 "$TMP/menu.svg" -o "$TMP/raw.png"
magick "$TMP/raw.png" -trim +repage -resize "x$GLYPH_PX" \
  -background none -gravity center -extent "${CANVAS}x${CANVAS}" "$OUT"

echo "Wrote $(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
