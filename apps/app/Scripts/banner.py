"""Draw a notification banner onto a frame, over whatever is already there.

The banner used to be a PNG exported from Apple's macOS UI kit. Its material is
translucent, so the export baked in whatever stood behind it in Figma: over the
kit's wallpaper it came out navy, and the material's backdrop is a rectangle, so
the rounded card arrived sitting inside a grey box. Neither survives being moved
to another background, which is the only thing a mockup is for.

So it is drawn here instead, the way the menu bar beside it already is: the
ground behind the banner is blurred and tinted, which is what the glass does,
and the appearance is an argument rather than a second file.

Geometry is Apple's, read off the kit: 344x56pt, corner radius 18, a 32pt icon
inset 12 from the left and 10 from the top, 8 to the text, and SF Pro at 13pt on
16pt lines. Everything scales from the width the caller asks for, so the same
call serves a 2560px Mac frame and a 1290px iPhone one.
"""
from PIL import Image, ImageDraw, ImageFilter, ImageFont

SYSTEM_FONT = "/System/Library/Fonts/SFNS.ttf"

# Measured off Apple's export rather than read off the panel: the App Icon node
# is 32pt but sits at +4 inside its frame and holds artwork inset within itself,
# so what a reader sees is a 30pt squircle at 15.3, not a 32pt one at 12. The
# text is placed on its baselines, which is the one horizontal line in a font
# that does not move when the size or the cut changes.
W_PT, H_PT, RADIUS_PT = 344, 56, 18
ICON_PT, ICON_X_PT, ICON_Y_PT = 30, 15.3, 13
TEXT_X_PT, TITLE_BASE_PT, LINE_PT = 58.2, 25.0, 16
TEXT_PT = 13
# The timestamp is smaller than the copy and sits the icon's own inset in from
# the right, so the card is padded alike on both sides.
WHEN_PT, RIGHT_PT = 11, 15.3

# The glass: how far it blurs what is behind it, and how much of its own tint it
# lays over that. Tuned so the ground still reads through as a wash rather than
# a colour -- at full opacity it stops being glass and the point of drawing it
# here is lost.
BLUR_PT, TINT_A = 11, 0.80

# Light and dark are the same drawing with different ink. The muted alpha is
# Apple's secondary label, which is what the timestamp is.
MODES = {
    "light": {"tint": (255, 255, 255), "ink": (0, 0, 0), "muted": 0.45,
              "edge": (255, 255, 255, 150), "shadow_a": 60},
    "dark": {"tint": (30, 30, 32), "ink": (255, 255, 255), "muted": 0.45,
             "edge": (255, 255, 255, 28), "shadow_a": 96},
}


def height_for(width):
    """The banner's height at a given width, so a caller can lay out around it
    before drawing."""
    return round(width * H_PT / W_PT)


# SF Pro is one variable font covering Text and Display. Its Optical Size axis
# defaults to 28, so asking for a weight by name and nothing else renders 13pt
# copy in the Display cut -- thinner strokes and tighter spacing than the Text
# cut macOS actually sets a notification in. The axis is driven by the design
# size in points, not by the pixel size we happen to be rasterising at.
#
# The axis floors at 17, and the banner sets copy at 13, so the closest cut the
# system font can give is still a little wider than the one macOS itself uses --
# about 1% over a title and 2% over a body line, measured against Apple's own
# export. Closing that would mean shipping a font file rather than reading the
# one on the machine, and it is not worth a font.
OPTICAL_MIN = 17
WEIGHTS = {"Regular": 400, "Medium": 510, "Semibold": 590, "Bold": 700}


def _font(px, weight, design_pt):
    font = ImageFont.truetype(SYSTEM_FONT, px)
    try:
        width, optical, grad, _ = (a["default"] for a in font.get_variation_axes())
        font.set_variation_by_axes(
            [width, max(OPTICAL_MIN, design_pt), grad, WEIGHTS[weight]])
    except (OSError, ValueError, KeyError):
        try:
            font.set_variation_by_name(weight)
        except OSError:
            pass
    return font


def _tracked(draw, xy, text, font, fill, tracking):
    """PIL has no letter-spacing, and Apple's is negative at this size -- over a
    word it is the difference between the real thing and something close.

    Each glyph is placed at its position in the whole string, not at the sum of
    the ones before it: a character's width on its own is not its width after
    the character before it, and advancing by that sum throws the font's kerning
    away and reads as cramped.

    Drawn from the baseline, so a change of weight or optical size moves the
    glyphs' own shapes and not the line they sit on."""
    x, y = xy
    for i, ch in enumerate(text):
        draw.text((x + draw.textlength(text[:i], font=font) + i * tracking, y),
                  ch, font=font, fill=fill, anchor="ls")
    return x + draw.textlength(text, font=font) + len(text) * tracking


def _tracked_width(draw, text, font, tracking):
    return draw.textlength(text, font=font) + tracking * (len(text) - 1)


def icon_art(path, size):
    """The app icon, cropped to its own artwork.

    `icon-1024.png` is the unmasked square -- macOS applies the squircle itself,
    so using it gives a hard-cornered tile. The `mac-` icons are masked but carry
    the transparent margin macOS composites them with, which lands the artwork at
    86% of the slot and reads as small beside Apple's own icons. Cropping the
    masked one to its alpha gives a squircle that fills the slot."""
    art = Image.open(path).convert("RGBA")
    # The opaque artwork, not everything with any alpha at all: the macOS icon
    # carries its own drop shadow, and cropping to that lands the squircle at
    # 93% of the slot, sitting high, casting a second shadow inside a banner
    # that already has one.
    box = art.getchannel("A").point(lambda v: 255 if v > 128 else 0).getbbox()
    return art.crop(box).resize((size, size), Image.LANCZOS)


def draw(canvas, x, y, width, mode, title, body, when, icon_path):
    """Draw the banner with its top left at (x, y), `width` px wide.

    `canvas` is RGBA and is read as well as written: the glass is a blur of
    whatever is already underneath, so this has to be called after the ground and
    anything the banner overlaps."""
    look = MODES[mode]
    pt = width / W_PT
    height = height_for(width)
    radius = round(RADIUS_PT * pt)

    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, width - 1, height - 1], radius=radius, fill=255)

    # Cast before the glass, following the card's own shape. Blur is kept under
    # the gap the caller leaves above it -- a wider blur reaches past the frame
    # edge, where it stops being a shadow and becomes a band.
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    silhouette = Image.new("RGBA", (width, height), (18, 18, 24, 255))
    silhouette.putalpha(mask.point(lambda v: v * look["shadow_a"] // 255))
    shadow.alpha_composite(silhouette, (x, y + round(10 * pt)))
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(round(13 * pt))))

    behind = canvas.crop((x, y, x + width, y + height)).convert("RGB")
    glass = Image.blend(
        behind.filter(ImageFilter.GaussianBlur(round(BLUR_PT * pt))),
        Image.new("RGB", (width, height), look["tint"]),
        TINT_A,
    ).convert("RGBA")
    glass.putalpha(mask)
    canvas.alpha_composite(glass, (x, y))

    # The hairline the material carries at its edge. Without it a light banner
    # on a light ground has no boundary at all.
    edge = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    ImageDraw.Draw(edge).rounded_rectangle(
        [0, 0, width - 1, height - 1], radius=radius,
        outline=look["edge"], width=max(1, round(pt)))
    canvas.alpha_composite(edge, (x, y))

    icon = icon_art(icon_path, round(ICON_PT * pt))
    canvas.alpha_composite(icon, (x + round(ICON_X_PT * pt), y + round(ICON_Y_PT * pt)))

    d = ImageDraw.Draw(canvas)
    ink = look["ink"]
    muted = ink + (round(255 * look["muted"]),)
    size = round(TEXT_PT * pt)
    title_font = _font(size, "Bold", TEXT_PT)
    body_font = _font(size, "Regular", TEXT_PT)

    text_x = x + round(TEXT_X_PT * pt)
    base = y + round(TITLE_BASE_PT * pt)
    line = round(LINE_PT * pt)

    when_size = round(WHEN_PT * pt)
    when_font = _font(when_size, "Regular", WHEN_PT)
    when_track = -0.008 * when_size
    when_w = _tracked_width(d, when, when_font, when_track)
    _tracked(d, (x + width - round(RIGHT_PT * pt) - when_w, base), when,
             when_font, muted, when_track)

    _tracked(d, (text_x, base), title, title_font, ink + (255,), -0.02 * size)
    _tracked(d, (text_x, base + line), body, body_font, ink + (255,), -0.008 * size)
