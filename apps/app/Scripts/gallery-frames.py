"""Compose the iPhone frames for the Product Hunt gallery, in the Mac App
Store frames' layout: the brand-red field on the left with the mark, the
Recursive Mono title and the Karla description, and the device on the light
ground on the right. Output is 2560x1600 so the two sets sit together in one
carousel. The App Store cannot take these -- iOS sets must be portrait -- so
they are written to sketches/gif/out/ beside the film stills, not to fastlane/.

The field and caption block are appstore-frames-mac.py's; the device is drawn
the way appstore-frames.py draws it, a rounded card with a hairline ring and no
bezel, because the capture is the bare screen.

Reads the three captures `make shots` leaves in /tmp/notifi-shots (inbox,
message, keys), or the directory named by RAW.

    make gallery-frames
"""
import json, os, random, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from publish_image import publish
import banner

REPO = os.environ.get("REPO", os.getcwd())
RAW = os.environ.get("RAW", "/tmp/notifi-shots")
OUT = os.environ.get("OUT", f"{REPO}/sketches/gif/out")
ASSETS = f"{REPO}/apps/app/Shared/Assets.xcassets"
SITE = f"{REPO}/apps/api/public"

with open(f"{REPO}/apps/app/fastlane/screenshot-copy.json") as fh:
    CAPTIONS = json.load(fh)["en-GB"]

W, H = 2560, 1600
SPLIT = 1200
GUTTER = 170
MARK = 150
TITLE_SIZE, DESC_SIZE = 108, 54
RED_RGB = (0xBC, 0x21, 0x22)
GROUND_TOP, GROUND_BOTTOM = (0xE8, 0xE8, 0xEB), (0xFC, 0xFC, 0xFD)
BANNER_MODE, BANNER_WHEN, BANNER_GAP = "light", "now", 72
BANNER_ICON = f"{ASSETS}/AppIcon.appiconset/mac-1024.png"
# Where the Mac set centres its popover; the phone stands on the same axis so
# the two device sets line up as the carousel moves between them.
DEVICE_CENTER_X = 1910
DEVICE_H = 1320
RADIUS_RATIO = 0.058

FRAMES = [
    ("inbox.png", "inboxTitleIpad", "inboxBody", "ios_01_inbox.png", True),
    ("message.png", "messageTitle", "messageBody", "ios_02_message.png", False),
    ("keys.png", "keysTitle", "keysBody", "ios_03_keys.png", False),
]


def dehinted(name):
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


def rasterize(svg, width, tint, name):
    import subprocess
    path = f"{OUT}/.{name}.png"
    subprocess.run(["rsvg-convert", "-w", str(width), "-o", path],
                   input=svg.encode(), check=True)
    art = Image.open(path).convert("RGBA")
    os.remove(path)
    layer = Image.new("RGBA", art.size, tint + (0,))
    layer.putalpha(art.getchannel("A"))
    return layer


def ground(box):
    ramp = Image.new("RGB", (1, H))
    px = ramp.load()
    for y in range(H):
        t = y / (H - 1)
        px[0, y] = tuple(round(a + (b - a) * t) for a, b in zip(GROUND_TOP, GROUND_BOTTOM))
    page = ramp.resize((W, H), Image.BICUBIC).convert("RGBA")
    bloom = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(bloom).ellipse(
        [box[0] - 220, box[3] - 260, box[2] + 220, box[3] + 200], fill=RED_RGB + (26,))
    page.alpha_composite(bloom.filter(ImageFilter.GaussianBlur(160)))
    return page


def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius=radius, fill=255)
    out = img.convert("RGBA")
    out.putalpha(mask)
    return out


def frame(raw, title_key, desc_key, out_name, with_banner):
    path = f"{RAW}/{raw}"
    if not os.path.exists(path):
        sys.exit(f"{path} is missing -- run `TABS=\"inbox message keys\" make shots` first")
    shot = Image.open(path).convert("RGB")
    target_w = round(shot.width * DEVICE_H / shot.height)
    shot = shot.resize((target_w, DEVICE_H), Image.LANCZOS)
    left = DEVICE_CENTER_X - target_w // 2
    top = (H - DEVICE_H) // 2
    box = [left, top, left + target_w, top + DEVICE_H]

    canvas = ground(box)
    d = ImageDraw.Draw(canvas)

    random.seed(7)
    field = Image.new("RGB", (SPLIT, H), RED_RGB)
    grain = Image.effect_noise((SPLIT // 2, H // 2), 26).point(lambda v: max(v, 128))
    grain = grain.resize((SPLIT, H), Image.NEAREST).convert("RGB")
    canvas.paste(ImageChops.overlay(field, grain), (0, 0))

    mono, sans = dehinted("RecursiveMono-SemiBold"), dehinted("Karla")
    tf = ImageFont.truetype(mono, TITLE_SIZE)
    try:
        tf.set_variation_by_name("Bold")
    except OSError:
        pass
    df = ImageFont.truetype(sans, DESC_SIZE)
    try:
        df.set_variation_by_name("Regular")
    except OSError:
        pass

    mark = Image.new("RGBA", (MARK, MARK), (0, 0, 0, 0))
    for part in ("bell-body", "bell-clapper"):
        layer = rasterize(open(f"{SITE}/{part}.svg").read(), MARK, (255, 255, 255), part)
        mark.alpha_composite(layer, (0, (MARK - layer.height) // 2))

    title_lines = []
    for para in CAPTIONS[title_key].split("\n"):
        title_lines += wrap(d, para, tf, SPLIT - GUTTER * 2)
    desc_lines = wrap(d, CAPTIONS[desc_key], df, SPLIT - GUTTER * 2)
    banner_w = SPLIT - GUTTER * 2
    block_h = (MARK + 64 + len(title_lines) * round(TITLE_SIZE * 1.14) + 56
               + len(desc_lines) * round(DESC_SIZE * 1.48))
    if with_banner:
        block_h += BANNER_GAP + banner.height_for(banner_w)
    y = (H - block_h) // 2
    canvas.alpha_composite(mark, (GUTTER, y))
    y += MARK + 64
    for line in title_lines:
        d.text((GUTTER, y), line, font=tf, fill="#FFFFFF")
        y += round(TITLE_SIZE * 1.14)
    y += 56
    for line in desc_lines:
        d.text((GUTTER, y), line, font=df, fill=(255, 222, 222))
        y += round(DESC_SIZE * 1.48)
    if with_banner:
        banner.draw(canvas, GUTTER, y + BANNER_GAP, banner_w, BANNER_MODE,
                    CAPTIONS["bannerTitle"], CAPTIONS["bannerBody"], BANNER_WHEN, BANNER_ICON)

    radius = round(target_w * RADIUS_RATIO)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [box[0] + 26, box[1] + 54, box[2] - 26, box[3] + 30], radius=radius, fill=(18, 18, 24, 96))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(46)))
    card = rounded(shot, radius)
    canvas.paste(card, (left, top), card)
    d.rounded_rectangle(box, radius=radius, outline=(10, 10, 10, 46), width=3)

    publish(canvas.convert("RGB"), f"{OUT}/{out_name}", "PNG")
    for tmp in (mono, sans):
        os.remove(tmp)
    print(f"  wrote {OUT}/{out_name}")


os.makedirs(OUT, exist_ok=True)
for args in FRAMES:
    frame(*args)
