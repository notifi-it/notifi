"""Compose the App Store screenshots from raw simulator captures.

Same system as the site: pure black, Recursive Mono for the title, Karla for the
description, one red accent, and the device shot bleeding off the bottom edge.
Output is 1290x2796, the 6.9" iPhone size, which is the only set Apple now
requires — it downscales the rest itself.

The captures come from a Simulator run with sample data seeded:

    xcodebuild -project apps/app/notifi.xcodeproj -scheme notifi-iOS \\
      -configuration Debug -destination 'id=<udid>' DEVELOPMENT_TEAM=Z28DW76Y3W build
    SIMCTL_CHILD_NOTIFI_SAMPLE_DATA=1 xcrun simctl launch <udid> it.notifi.notifi
    # ••• > Seed sample data, Settings > Load images automatically on
    xcrun simctl io <udid> screenshot shots/inbox.png     # and detail, search, settings

Then:

    SHOTS=shots python3 apps/app/Scripts/appstore-frames.py

Run it from the repo root. The seeded feed points its one image at
notifi.it/demo/latency.png, so that has to be deployed for the graph to appear.
"""
import os, subprocess
from PIL import Image, ImageDraw, ImageFont

REPO = os.environ.get("REPO", os.getcwd())
SHOTS = os.environ.get("SHOTS", "shots")
OUT = os.environ.get("OUT", f"{REPO}/apps/app/fastlane/screenshots/en-GB")
os.makedirs(OUT, exist_ok=True)

# 1290x2796 is the 6.9" iPhone set. The iPad Pro 12.9"/13" set (2048x2732)
# is not optional: the app runs on iPad, and App Store Connect refuses the
# submission without it — "A screenshot with type ipadPro129 is required".
W, H = (2048, 2732) if os.environ.get("IPAD") else (1290, 2796)
# Inverted against the app on purpose: the screenshots are black, so a white
# page is what separates them from the frame. Nothing else has to.
BG, FG, MUTED, BRAND = "#FFFFFF", "#0A0A0A", "#5A5A5A", "#BC2122"

def dehinted(name):
    """Both brand fonts carry TrueType hinting that FreeType renders wrong at
    these sizes — `r`, `t`, `b` and `S` come out as broken fragments. Stripping
    the bytecode fixes it, and at 40px+ the hints buy nothing anyway."""
    from fontTools.ttLib import TTFont
    from fontTools.ttLib.tables import ttProgram

    out = f"{OUT}/.{name}.ttf"
    font = TTFont(f"{REPO}/apps/app/Shared/Fonts/{name}.ttf")
    for table in ("fpgm", "prep", "cvt ", "gasp"):
        if table in font:
            del font[table]
    glyf = font["glyf"]
    for glyph_name in glyf.keys():
        glyph = glyf[glyph_name]
        if hasattr(glyph, "program"):
            empty = ttProgram.Program()
            empty.fromBytecode(b"")
            glyph.program = empty
    font.save(out)
    return out


MONO = dehinted("RecursiveMono-SemiBold")
SANS = dehinted("Karla")

GUTTER = 96
TOP = 268
# Fixed, not text-relative: the three frames sit side by side on the listing,
# and a device that starts at a different height on each reads as a mistake.
DEVICE_TOP = 780
TITLE_SIZE, DESC_SIZE = 82, 42
if os.environ.get("IPAD"):
    # Wider canvas, same lockup scale; the device shot is near-square so it
    # starts a little higher to keep a comparable bleed.
    DEVICE_TOP = 820

# The wordmark is an SVG of outlined glyphs; rasterise it once at the size used.
# Its letterforms are #EDEDED for a black page; on this white one they have to
# be dark. The bell keeps its red tittle either way.
WORDMARK_SVG = f"{OUT}/.wordmark.svg"
with open(f"{REPO}/apps/api/public/wordmark.svg") as f:
    open(WORDMARK_SVG, "w").write(f.read().replace('fill="#EDEDED"', f'fill="{FG}"'))
WORDMARK = f"{OUT}/.wordmark.png"
subprocess.run(
    ["rsvg-convert", "-h", "140", "-b", "none", WORDMARK_SVG, "-o", WORDMARK],
    check=True,
)
# The bell is composed, not a flat asset: the site masks bell.svg in the text
# colour and puts the brand-red disc on top at fractions of the same viewBox.
# Same construction here and the same fractions — see the note beside `.bell` in
# index.html. Reframing the box in generate-marks.sh moves both.
#
# The disc is centred 14.98% down and drawn 34.19% wide, so it reaches about 2%
# of the box above its own top edge. The browser lets it overhang; drawing it
# into the rasterised bell clipped it flat, so it goes on the page instead.
BELL_BOX = 80
BELL = f"{OUT}/.bell.png"
subprocess.run(
    ["rsvg-convert", "-h", str(BELL_BOX * 4), "-b", "none",
     f"{REPO}/apps/api/public/bell.svg", "-o", BELL],
    check=True,
)


def wrap(draw, text, font, width):
    lines, line = [], ""
    for word in text.split():
        trial = f"{line} {word}".strip()
        if draw.textlength(trial, font=font) <= width or not line:
            line = trial
        else:
            lines.append(line)
            line = word
    if line:
        lines.append(line)
    return lines


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, *[v - 1 for v in img.size]],
                                           radius=radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


PREFIX = "ipad_" if os.environ.get("IPAD") else ""
SHOT_PREFIX = "ipad-" if os.environ.get("IPAD") else ""


def frame(shot_name, title, desc, out_name):
    shot_name = SHOT_PREFIX + shot_name
    out_name = PREFIX + out_name
    if not os.path.exists(f"{SHOTS}/{shot_name}"):
        print(f"skipped {out_name}: no {SHOTS}/{shot_name}")
        return
    canvas = Image.new("RGB", (W, H), BG)
    d = ImageDraw.Draw(canvas)

    # ── wordmark, bell first. Sized as a poster lockup, not a web header —
    # at the header's 44px the mark disappeared on a 1290px canvas.
    bell = Image.open(BELL).convert("RGBA")
    mark = Image.open(WORDMARK).convert("RGBA")
    bell = bell.resize(
        (round(bell.width * BELL_BOX / bell.height), BELL_BOX), Image.LANCZOS
    )
    mh = 68
    mark = mark.resize((round(mark.width * mh / mark.height), mh), Image.LANCZOS)
    top = 120
    canvas.paste(bell, (GUTTER, top), bell)
    disc = BELL_BOX * 0.3419
    cx, cy = GUTTER + BELL_BOX * 0.7006, top + BELL_BOX * 0.1498
    d.ellipse([cx - disc / 2, cy - disc / 2, cx + disc / 2, cy + disc / 2], fill=BRAND)
    canvas.paste(mark, (GUTTER + bell.width + 28, top + (BELL_BOX - mh) // 2), mark)

    # ── title
    # A variable font left at its default instance renders a broken outline in
    # PIL, so an instance is named when the file carries one. RecursiveMono
    # ships as a static SemiBold and raises here — the file already is the
    # weight the frame wants.
    tf = ImageFont.truetype(MONO, TITLE_SIZE)
    try:
        tf.set_variation_by_name("Bold")
    except OSError:
        pass
    y = TOP
    for para in title.split("\n"):
        for line in wrap(d, para, tf, W - GUTTER * 2):
            d.text((GUTTER, y), line, font=tf, fill=FG)
            y += round(TITLE_SIZE * 1.14)

    # ── description
    df = ImageFont.truetype(SANS, DESC_SIZE)
    try:
        df.set_variation_by_name("Regular")
    except OSError:
        pass
    y += 22
    for line in wrap(d, desc, df, W - GUTTER * 2):
        d.text((GUTTER, y), line, font=df, fill=MUTED)
        y += round(DESC_SIZE * 1.48)

    # ── the device, bled off the bottom
    shot = Image.open(f"{SHOTS}/{shot_name}").convert("RGB")
    target_w = W - GUTTER * 2
    shot = shot.resize(
        (target_w, round(shot.height * target_w / shot.width)), Image.LANCZOS
    )
    top = DEVICE_TOP
    canvas.paste(rounded(shot, 56), (GUTTER, top), rounded(shot, 56))
    canvas.save(f"{OUT}/{out_name}", "PNG")
    print(out_name, canvas.size)


frame("inbox.png",
      "One request.\nStraight to your pocket.",
      "One HTTP request to notifi.it and it arrives a moment later. "
      "No SDK and no dependency.",
      "01_inbox.png")

frame("detail.png",
      "Markdown, rendered.",
      "Headings, lists, quotes and code blocks. Attach an image and a link, "
      "and the whole thing arrives as one push.",
      "02_message.png")

frame("keys.png",
      "One key per source.",
      "Give the deploy bot one key and the doorbell another. Revoke one and the "
      "rest keep working. No account to make first.",
      "03_keys.png")

for tmp in (WORDMARK, WORDMARK_SVG, BELL, MONO, SANS):
    os.remove(tmp)
