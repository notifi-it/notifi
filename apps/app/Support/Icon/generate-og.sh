#!/usr/bin/env bash
#
# The link-preview banner (apps/api/public/og.png): the website hero's
# scribbled bell as a still, 1200x630, nothing else on the card.
#
# The strokes are dealt the way the hero deals them — a grid of seeds over
# the glyph's coverage, one thin hatch line per seed at a random angle,
# clipped by the silhouette so the edge stays the artwork's — but from a
# fixed-seed PRNG, so re-running this script writes the same bytes and an
# unchanged banner never shows up as a diff.
#
# The red is decided per stroke by a probability that falls off through the
# badge's edge: strokes just inside the disc can come up white and strokes
# just outside can come up red, so the two inks bleed into each other a
# little instead of meeting at a stamped boundary. The disc itself is read
# out of bell.svg's circle element, never hard-coded.
#
# Output is derived from apps/api/public/bell.svg, which generate-marks.sh
# derives from notifi-logo.svg. Edit the master, run generate-marks.sh,
# then run this.
set -euo pipefail

cd "$(dirname "$0")"
WEB="../../../api/public"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

rsvg-convert -w 512 -h 512 "$WEB/bell.svg" -o "$TMP/glyph.png"

python3 - "$WEB/bell.svg" "$TMP/glyph.png" "$TMP/og.svg" <<'PY'
import random, re, sys
from PIL import Image

bell_path, glyph_png, out_svg = sys.argv[1:4]
bell = open(bell_path).read()
vb = [float(n) for n in re.search(r'viewBox="([^"]+)"', bell).group(1).split()]
c = re.search(r'<circle cx="([\d.]+)" cy="([\d.]+)" r="([\d.]+)"', bell)
dot_u = (float(c.group(1)) - vb[0]) / vb[2]
dot_v = (float(c.group(2)) - vb[1]) / vb[3]
dot_r = float(c.group(3)) / vb[2]

W, H = 2400, 1260
SIZE = H * 0.72
GX, GY = W / 2 - SIZE / 2, H / 2 - SIZE / 2
INK, RED, BG = "#EDEDED", "#DB4A4B", "#1C1C1E"

alpha = Image.open(glyph_png).convert("RGBA").getchannel("A").load()

rng = random.Random(1)
G = 108
lines = []
for gy in range(G):
    for gx in range(G):
        u, v = (gx + .5) / G, (gy + .5) / G
        if alpha[int(u * 512), int(v * 512)] < 96:
            continue
        u += (rng.random() - .5) / G
        v += (rng.random() - .5) / G
        du, dv = u - dot_u, v - dot_v
        d = (du * du + dv * dv) ** .5 / (dot_r * 1.25)
        p = 1 - (d - 0.7) / 0.65 if d < 1 else 0.18 * (1 - (d - 1) / 0.7)
        red = rng.random() < p
        ang = rng.random() * 3.141592653589793
        half = (.02 + rng.random() * .035) * SIZE
        from math import cos, sin
        dx, dy = cos(ang) * half, sin(ang) * half
        px, py = GX + u * SIZE, GY + v * SIZE
        lines.append(
            '<line x1="%.2f" y1="%.2f" x2="%.2f" y2="%.2f" stroke="%s" '
            'stroke-opacity="%.3f" stroke-width="%.2f" stroke-linecap="round"/>'
            % (px - dx, py - dy, px + dx, py + dy, RED if red else INK,
               0.8 * (0.25 + rng.random() * 0.6),
               SIZE / 512 * (0.5 + rng.random() * 0.5)))

scale = SIZE / vb[2]
inner = re.search(r"<svg[^>]*>(.*)</svg>", bell, re.S).group(1)
mask = ('<mask id="m"><g transform="translate(%.4f %.4f) scale(%.6f) '
        'translate(%.4f %.4f)">%s</g></mask>'
        % (GX, GY, scale, -vb[0], -vb[1], inner.replace("#000", "#fff")))

open(out_svg, "w").write(
    '<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" '
    'viewBox="0 0 %d %d"><defs>%s</defs>'
    '<rect width="%d" height="%d" fill="%s"/>'
    '<g mask="url(#m)">%s</g></svg>'
    % (W, H, W, H, mask, W, H, BG, "\n".join(lines)))
PY

rsvg-convert -w 2400 -h 1260 "$TMP/og.svg" -o "$TMP/og-2x.png"

# The grain the site's surfaces carry, then the 2x render folded down to the
# shipped size so the strokes keep their antialiasing through the platforms'
# re-encodes.
python3 - "$TMP/og-2x.png" "$WEB/og.png" <<'PY'
import random, sys
from PIL import Image

src, out = sys.argv[1:3]
rng = random.Random(2)
tile = Image.frombytes("L", (300, 300),
                       bytes(118 + int(rng.random() * 36) for _ in range(300 * 300)))
img = Image.open(src).convert("RGB")
noise = Image.new("L", img.size)
for x in range(0, img.size[0], 300):
    for y in range(0, img.size[1], 300):
        noise.paste(tile, (x, y))
img = Image.blend(img, noise.convert("RGB"), 0.055)
img = img.resize((1200, 630), Image.LANCZOS)
img.save(out, optimize=True)
print("  wrote %s (1200x630)" % out)
PY
