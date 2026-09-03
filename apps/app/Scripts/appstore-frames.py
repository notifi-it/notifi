"""Compose the App Store screenshots from raw simulator captures.

Same type as the site — Recursive Mono for the title, Karla for the
description, one red accent — set on a soft ground with the whole device
floating on it: rounded, shadowed, a hairline ring standing in for the bezel,
and clear of every edge. Output is 1290x2796 (the 6.9" iPhone set), or
2048x2732 with IPAD=1 — both are required, because the app runs on iPad.

Normally not run by hand: `make screens` builds, captures both device
sets from the Simulator, and runs this twice (plain, then IPAD=1). To re-render
from existing captures:

    SHOTS=<dir> LOCALE=<locale> python3 apps/app/Scripts/appstore-frames.py

LOCALE names both the caption set in fastlane/screenshot-copy.json and the
output directory under fastlane/screenshots, and defaults to en-GB.

Run it from the repo root. The seeded feed points its one image at
notifi.it/demo/latency.png, so that has to be deployed for the graph to appear.
"""
import json, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from publish_image import publish

REPO = os.environ.get("REPO", os.getcwd())
SHOTS = os.environ.get("SHOTS", "shots")
LOCALE = os.environ.get("LOCALE", "en-GB")
OUT = os.environ.get("OUT", f"{REPO}/apps/app/fastlane/screenshots/{LOCALE}")
os.makedirs(OUT, exist_ok=True)

# The frame copy is not written here. Like every other user-facing string it
# lives in packages/copy/src/strings.ts, and `make gen-copy` renders this file.
with open(f"{REPO}/apps/app/fastlane/screenshot-copy.json") as fh:
    CAPTIONS = json.load(fh)[LOCALE]

# 1290x2796 is the 6.9" iPhone set. The iPad Pro 12.9"/13" set (2048x2732)
# is not optional: the app runs on iPad, and App Store Connect refuses the
# submission without it — "A screenshot with type ipadPro129 is required".
W, H = (2048, 2732) if os.environ.get("IPAD") else (1290, 2796)
# Inverted against the app on purpose: the screenshots are black, so a light
# page is what separates them from the frame. Nothing else has to. The page is
# a ramp rather than one flat white, because a black device on flat white has
# nothing to sit on — the shadow needs something to fall across.
FG, MUTED, BRAND = "#0A0A0A", "#5A5A5A", "#BC2122"
GROUND_TOP, GROUND_BOTTOM = (0xE8, 0xE8, 0xEB), (0xFC, 0xFC, 0xFD)
BRAND_RGB = (0xBC, 0x21, 0x22)

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
TOP = 220
# Fixed, not text-relative: the three frames sit side by side on the listing,
# and a device that starts at a different height on each reads as a mistake.
# The whole device is on the page now, so its height and the gap below it are
# what fix it in place — a bleed only had to name where it started.
# 920 is set by the longest caption, not by taste: the French message frame
# runs to five lines and ends at 864.
DEVICE_TOP = 910
DEVICE_BOTTOM = 76
TITLE_SIZE, DESC_SIZE = 82, 45
RADIUS_RATIO = 0.058
# Both captures carry the aspect ratio of the canvas they are framed on, so a
# caption above the device and a device at full width cannot both be had: every
# pixel the caption takes comes off the width. The phone can afford it — a tall
# slab with air down its sides still reads as a phone. The near-square iPad
# cannot, so it keeps the full width and runs off the bottom edge instead.
BLEED = bool(os.environ.get("IPAD"))
if os.environ.get("IPAD"):
    GUTTER = 120
    TITLE_SIZE, DESC_SIZE = 108, 56
    # The iPad caption wraps to five lines in German, so its device starts
    # lower than the phone's. Height is free here — the device runs off the
    # page regardless.
    TOP = 264
    DEVICE_TOP = 974
    # Only the top corners are on the page, and at 1808px wide the phone's
    # ratio rounds them far harder than the hardware does.
    RADIUS_RATIO = 0.031

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


def ground():
    """A vertical ramp with a faint brand bloom where the device meets the
    page. Drawn at full size: at 1290px a ramp built small and scaled up bands
    visibly. Soft white shapes over the top of it looked like a smudge on the
    print — the ramp alone is what gives the shadow something to fall across."""
    ramp = Image.new("RGB", (1, H))
    px = ramp.load()
    for y in range(H):
        t = y / (H - 1)
        px[0, y] = tuple(
            round(a + (b - a) * t) for a, b in zip(GROUND_TOP, GROUND_BOTTOM)
        )
    page = ramp.resize((W, H), Image.BICUBIC).convert("RGBA")

    bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(bloom).ellipse(
        [W * 0.06, DEVICE_TOP - H * 0.07, W * 0.94, DEVICE_TOP + H * 0.16],
        fill=BRAND_RGB + (26,),
    )
    page.alpha_composite(bloom.filter(ImageFilter.GaussianBlur(160)))
    return page


MARK = 110 if os.environ.get("IPAD") else 84
# The mark sits a mark's height in from the top, and the title a gap under it;
# TOP already counts both, so the caption keeps its distance from the device.
MARK_TOP = TOP - MARK - (44 if os.environ.get("IPAD") else 40)


def mark():
    """The site's bell, drawn in the brand red above the caption: bell-body.svg
    and bell-clapper.svg stacked, both cropped by the same box by
    generate-marks.sh, rasterized the way the CSS mask-image does it."""
    import subprocess
    art = Image.new("RGBA", (MARK, MARK), (0, 0, 0, 0))
    for part in ("bell-body", "bell-clapper"):
        path = f"{OUT}/.{part}.png"
        svg = open(f"{REPO}/apps/api/public/{part}.svg").read()
        subprocess.run(["rsvg-convert", "-w", str(MARK), "-o", path],
                       input=svg.encode(), check=True)
        layer = Image.open(path).convert("RGBA")
        os.remove(path)
        tint = Image.new("RGBA", layer.size, BRAND_RGB + (0,))
        tint.putalpha(layer.getchannel("A"))
        art.alpha_composite(tint, (0, (MARK - layer.height) // 2))
    return art


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
    canvas = ground()
    canvas.alpha_composite(mark(), (GUTTER, MARK_TOP))
    d = ImageDraw.Draw(canvas)

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

    y += 34

    # ── description
    df = ImageFont.truetype(SANS, DESC_SIZE)
    try:
        df.set_variation_by_name("Regular")
    except OSError:
        pass
    y += 34
    for line in wrap(d, desc, df, W - GUTTER * 2):
        d.text((GUTTER, y), line, font=df, fill=MUTED)
        y += round(DESC_SIZE * 1.48)

    # A caption that runs into the device is the one failure this layout can
    # produce silently: the device sits at a fixed height so the three frames
    # line up, and a longer translation just keeps going.
    if y > DEVICE_TOP - 40:
        print(f"WARNING {out_name}: caption ends at {y}, device starts at {DEVICE_TOP}")

    # ── the device: whole and floating on the phone, bled off the bottom on
    # the iPad
    shot = Image.open(f"{SHOTS}/{shot_name}").convert("RGB")

    # The status bar stays. Cutting it left the title flush against the top
    # edge, and filling the gap with ground read as a mistake — a frame without
    # a drawn bezel has nothing else to stand in for the device's own inset.
    # screens.sh overrides it to 09:41 first, so it is the same on every shot.
    if BLEED:
        target_w = W - GUTTER * 2
        target_h = round(shot.height * target_w / shot.width)
    else:
        target_h = H - DEVICE_TOP - DEVICE_BOTTOM
        target_w = round(shot.width * target_h / shot.height)
    shot = shot.resize((target_w, target_h), Image.LANCZOS)
    # Proportional, so a device rounds by an amount of its own width rather
    # than by the same number of pixels at either size.
    radius = round(target_w * RADIUS_RATIO)
    left = (W - target_w) // 2
    box = [left, DEVICE_TOP, left + target_w, DEVICE_TOP + target_h]

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [box[0] + 26, box[1] + 54, box[2] - 26, box[3] + 30],
        radius=radius, fill=(18, 18, 24, 96),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(46)))

    card = rounded(shot, radius)
    canvas.paste(card, (left, DEVICE_TOP), card)
    # The ring is the bezel. Without it a dark capture on a light page has no
    # edge of its own, and the corners read as torn rather than cut.
    d.rounded_rectangle(box, radius=radius, outline=(10, 10, 10, 46), width=3)
    publish(canvas.convert("RGB"), f"{OUT}/{out_name}", "PNG")


INBOX_TITLE = CAPTIONS["inboxTitleIpad"] if os.environ.get("IPAD") else CAPTIONS["inboxTitle"]
frame("inbox.png", INBOX_TITLE, CAPTIONS["inboxBody"], "01_inbox.png")
frame("detail.png", CAPTIONS["messageTitle"], CAPTIONS["messageBody"], "02_message.png")
frame("keys.png", CAPTIONS["keysTitle"], CAPTIONS["keysBody"], "03_keys.png")

for tmp in (MONO, SANS):
    os.remove(tmp)
