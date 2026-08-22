#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
EMPTY="../../../api/public/bell-empty.svg"
OUT="../../../api/public/sad-logo.png"
SIZE=512
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

INNER=$(( SIZE * 76 / 100 ))
rsvg-convert -w "$INNER" -h "$INNER" "$EMPTY" -o "$TMP/ink.png"
magick "$TMP/ink.png" -background none -gravity center -extent "${SIZE}x${SIZE}" "$TMP/mark.png"

python3 - "$TMP/mark.png" "$OUT" "$SIZE" <<'PY'
import sys
from PIL import Image, ImageChops

src, out, size = sys.argv[1], sys.argv[2], int(sys.argv[3])
WARM, COOL, INK = (0xE0, 0x32, 0x34), (0x36, 0xC4, 0xD8), (0xED, 0xED, 0xED)
SHIFT = round(size * 0.009)

alpha = Image.open(src).convert('RGBA').getchannel('A')

def tinted(rgb, dx):
    layer = Image.new('RGBA', (size, size), rgb + (0,))
    layer.putalpha(ImageChops.offset(alpha, dx, 0))
    return layer

body = Image.new('RGBA', (size, size), INK + (0,))
body.putalpha(alpha)

img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
img.alpha_composite(tinted(WARM, -SHIFT))
img.alpha_composite(tinted(COOL, SHIFT))
img.alpha_composite(body)
img.save(out, optimize=True)
print('  wrote %s (%dpx, chroma split %dpx)' % (out, size, SHIFT))
PY
