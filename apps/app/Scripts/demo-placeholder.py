#!/usr/bin/env python3
# The image the showcase notification carries (apps/api/public/demo/
# placeholder.png), the one the website's device shot and the App Store
# message frame open. It stands in for whatever a sender attaches: the same
# ground as the other demo images, the empty-inbox bell, and a label. 2:1 so
# the card leaves room for the Markdown underneath it on a phone.
#
# Deterministic: re-running writes the same bytes.
#
#   python3 apps/app/Scripts/demo-placeholder.py
import os
import subprocess
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "..")

W, H = 1200, 600
GROUND = (11, 11, 11)
GRID = (22, 22, 22)
INK = (72, 72, 72)
LABEL = (110, 110, 110)
FONT = os.path.join(ROOT, "apps/app/Shared/Fonts/RecursiveMono-Regular.ttf")
BELL = os.path.join(ROOT, "apps/api/public/bell-empty.svg")
OUT = os.path.join(ROOT, "apps/api/public/demo/placeholder.png")

im = Image.new("RGB", (W, H), GROUND)
draw = ImageDraw.Draw(im)
for x in range(0, W, 40):
    draw.line([(x, 0), (x, H)], fill=GRID, width=1)
for y in range(0, H, 40):
    draw.line([(0, y), (W, y)], fill=GRID, width=1)

with tempfile.TemporaryDirectory() as tmp:
    glyph_png = os.path.join(tmp, "bell.png")
    subprocess.run(["rsvg-convert", "-w", "168", "-h", "168", BELL, "-o", glyph_png],
                   check=True)
    glyph = Image.open(glyph_png).convert("RGBA")
    ink = Image.new("RGBA", glyph.size, INK + (255,))
    im.paste(ink, ((W - glyph.width) // 2, 176), glyph.split()[3])

font = ImageFont.truetype(FONT, 30)
text = "your image"
box = draw.textbbox((0, 0), text, font=font)
draw.text(((W - (box[2] - box[0])) // 2 - box[0], 392), text, font=font, fill=LABEL)

im.save(OUT, "PNG", optimize=True)
print(OUT)
