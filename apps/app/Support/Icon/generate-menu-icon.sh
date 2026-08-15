#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
OUT="../../Shared/Assets.xcassets/menu_icon.imageset/menu.png"
OUT_DOT="../../Shared/Assets.xcassets/menu_dot.imageset/dot.png"
OUT_CLAPPER="../../Shared/Assets.xcassets/menu_clapper.imageset/clapper.png"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

STROKE=0
CANVAS=102
SLOT_PT=20
GLYPH_PT=16

python3 - "$TMP/menu.svg" "$STROKE" "$TMP/dot.svg" "$TMP/body.svg" "$TMP/clapper.svg" <<'PY'
import re, sys

out_path, stroke, dot_path, body_path, clapper_path = \
    sys.argv[1], float(sys.argv[2]), sys.argv[3], sys.argv[4], sys.argv[5]
src = open("notifi-logo.svg").read()
BRAND = "rgb(73.699951%, 12.89978%, 13.299561%)"

parts, cursor = [], 0
for i, m in enumerate(re.finditer(r"<path[^>]*>", src)):
    tag = m.group(0)
    if i == 0:
        tag = tag.replace('stroke-width="1.3"', 'stroke-width="%.3f"' % (1.3 + stroke))
    elif i > 1 and stroke > 0:

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

badge = re.findall(r"<path[^>]*>", src)[1].replace(BRAND, "rgb(0%,0%,0%)")
head = src[:src.index("<path")]
open(dot_path, "w").write(head + badge + "\n</svg>\n")

tags = re.findall(r"<path[^>]*>", src)
ink = lambda t: t.replace(BRAND, "rgb(0%,0%,0%)")
open(body_path, "w").write(head + "\n".join(ink(t) for t in tags[2:]) + "\n</svg>\n")
open(clapper_path, "w").write(head + ink(tags[0]) + "\n</svg>\n")
PY

GLYPH_PX=$(python3 -c "print(round($CANVAS * $GLYPH_PT / $SLOT_PT))")

rsvg-convert -w 1024 -h 1024 "$TMP/menu.svg" -o "$TMP/raw.png"
rsvg-convert -w 1024 -h 1024 "$TMP/dot.svg" -o "$TMP/raw-dot.png"
rsvg-convert -w 1024 -h 1024 "$TMP/body.svg" -o "$TMP/raw-body.png"
rsvg-convert -w 1024 -h 1024 "$TMP/clapper.svg" -o "$TMP/raw-clapper.png"

BOX="$(magick "$TMP/raw.png" -format "%@" info:)"

for pair in "raw-body.png:$OUT" "raw-dot.png:$OUT_DOT" "raw-clapper.png:$OUT_CLAPPER"; do
  magick "$TMP/${pair%%:*}" -crop "$BOX" +repage -resize "x$GLYPH_PX" \
    -background none -gravity center -extent "${CANVAS}x${CANVAS}" \
    "PNG32:${pair#*:}"
done

mkdir -p "$(dirname "$OUT_DOT")" "$(dirname "$OUT_CLAPPER")"
echo "Wrote $(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"
echo "Wrote $(cd "$(dirname "$OUT_DOT")" && pwd)/$(basename "$OUT_DOT")"
echo "Wrote $(cd "$(dirname "$OUT_CLAPPER")" && pwd)/$(basename "$OUT_CLAPPER")"
