#!/usr/bin/env bash
# Regenerates the macOS menu bar glyph: menu_icon.imageset/menu.png, the bell,
# and menu_dot.imageset/dot.png, its unread badge alone on the same canvas.
# Requires: rsvg-convert (librsvg), python3.
#
# Two files rather than one so nothing downstream has to know where the badge
# sits. MacMenuBar used to place it by hand as a fraction of the icon's frame,
# which is a copy of a measurement that lives in notifi-logo.svg — and because
# this glyph is trimmed and re-centred, its fraction was not the one BellMark
# uses either. Both layers are now cropped by the same box, so drawing one over
# the other puts the badge exactly where the artwork puts it.
#
# STROKE adds a stroke of the same colour to each of the bell's filled outlines,
# which grows it by STROKE/2 on both edges and thickens the line by STROKE
# overall. Values above ~0.8 start closing the gap inside the clapper.
#
# It is 0 because notifi-logo.svg now carries that weight itself, so the whole
# mark reads the same in the bar, the tab bar, the app icon and on the web.
# Thicken there, not here — anything above 0 lands on top of it.
#
# The logo also carries a wide margin inside its viewBox, which left the bell
# noticeably shorter than its neighbours in the bar. The glyph is therefore
# trimmed and re-centred on the canvas at GLYPH_PT tall — measured off the bar,
# Bluetooth and the battery run 15-16pt in the same 20pt slot.
set -euo pipefail

cd "$(dirname "$0")"
OUT="../../Shared/Assets.xcassets/menu_icon.imageset/menu.png"
OUT_DOT="../../Shared/Assets.xcassets/menu_dot.imageset/dot.png"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STROKE=0
CANVAS=102     # pixels, drawn by MacMenuBar into a 20pt square
SLOT_PT=20
GLYPH_PT=16

python3 - "$TMP/menu.svg" "$STROKE" "$TMP/dot.svg" <<'PY'
import re, sys

out_path, stroke, dot_path = sys.argv[1], float(sys.argv[2]), sys.argv[3]
src = open("notifi-logo.svg").read()
BRAND = "rgb(73.699951%, 12.89978%, 13.299561%)"

# Path 0 is the clapper, already a stroke. Path 1 is the dot, which stays the
# size it is. Paths 2 onwards are the bell's filled outlines.
parts, cursor = [], 0
for i, m in enumerate(re.finditer(r"<path[^>]*>", src)):
    tag = m.group(0)
    if i == 0:
        tag = tag.replace('stroke-width="1.3"', 'stroke-width="%.3f"' % (1.3 + stroke))
    elif i > 1 and stroke > 0:
        # Skipped at 0: the source already carries these attributes, and adding
        # a second copy is an XML parse error rather than a no-op.
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

# The badge on its own, in the same viewBox, so a crop that suits one suits the
# other. Path 1 is the badge — see the comment at the top of the master.
badge = re.findall(r"<path[^>]*>", src)[1].replace(BRAND, "rgb(0%,0%,0%)")
head = src[:src.index("<path")]
open(dot_path, "w").write(head + badge + "\n</svg>\n")
PY

GLYPH_PX=$(python3 -c "print(round($CANVAS * $GLYPH_PT / $SLOT_PT))")

# Rendered oversized so the trim lands on solid pixels rather than the SVG's
# antialiased fringe, then scaled down to the height the bar wants.
rsvg-convert -w 1024 -h 1024 "$TMP/menu.svg" -o "$TMP/raw.png"
rsvg-convert -w 1024 -h 1024 "$TMP/dot.svg" -o "$TMP/raw-dot.png"

# The crop box comes from the bell and is then applied to the badge unchanged.
# Trimming the badge to its own ink would centre it on the canvas, which is the
# one thing it must not be.
BOX="$(magick "$TMP/raw.png" -format "%@" info:)"

for pair in "raw.png:$OUT" "raw-dot.png:$OUT_DOT"; do
  # PNG32 explicitly: the badge layer is one shape on empty space, and left to
  # itself magick writes that as opaque greyscale, which draws as a filled
  # square over the bell.
  magick "$TMP/${pair%%:*}" -crop "$BOX" +repage -resize "x$GLYPH_PX" \
    -background none -gravity center -extent "${CANVAS}x${CANVAS}" \
    "PNG32:${pair#*:}"
done

mkdir -p "$(dirname "$OUT_DOT")"
echo "Wrote $(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
echo "Wrote $(cd "$(dirname "$OUT_DOT")" && pwd)/$(basename "$OUT_DOT")"
