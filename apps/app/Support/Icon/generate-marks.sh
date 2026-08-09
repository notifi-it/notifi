#!/usr/bin/env bash
# Regenerates every copy of the bell from notifi-logo.svg, then hands off to the
# two scripts that rasterise it. Requires: rsvg-convert (librsvg), magick
# (ImageMagick 7), python3.
#
# The mark is drawn once, in notifi-logo.svg. Everything else is a reframing or
# a recolouring of that one drawing, and every one of them used to be a
# hand-kept copy: raising the stroke meant editing four files in step, and the
# session that missed one is why the site's badge spent a release sitting off
# the bell's shoulder. They are generated now. Edit the master, run this.
#
# The two viewBoxes are declared rather than measured. Things outside this
# directory are positioned as fractions of them — BellMark's unread dot, the
# badge disc in the site's CSS — so they are numbers to change deliberately,
# with those call sites, and not to drift under a stroke change. The script
# checks the artwork still fits inside them and stops if it does not.
set -euo pipefail

cd "$(dirname "$0")"
MASTER="notifi-logo.svg"
ASSETS="../../Shared/Assets.xcassets"
WEB="../../../api/public"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# The mark's ink bounds squared off, centred, with a hair of margin. BellMark
# reads its unread dot off this, and so does the site.
LOGO_BOX="5.2700 6.5395 21.4600 21.4600"
# Looser, so the bell sits at the same live area as the akar key and gear it
# shares the tab bar with rather than filling the 24pt canvas on its own.
TAB_BOX="4.30 5.19 23.40 23.40"
BADGE_CX=20.3047
BADGE_CY=9.7539
BADGE_R=2.9

# --- what the artwork actually covers, at 100px per unit -------------------
rsvg-convert -w 3200 -h 3200 "$MASTER" -o "$TMP/ink.png"
INK="$(magick "$TMP/ink.png" -format "%@" info:)"    # bounding box of the ink, WxH+X+Y

python3 - "$MASTER" "$INK" "$LOGO_BOX" "$TAB_BOX" "$BADGE_CX" "$BADGE_CY" "$BADGE_R" \
         "$ASSETS" "$WEB" "$TMP" <<'PY'
import math, re, subprocess as sub, sys

master, ink, logo_box, tab_box, bcx, bcy, br, assets, web, TMP = sys.argv[1:11]
bcx, bcy, br = float(bcx), float(bcy), float(br)

w, h, x, y = map(float, re.match(r"(\d+)x(\d+)\+(-?\d+)\+(-?\d+)", ink).groups())
ink = (x/100, y/100, (x+w)/100, (y+h)/100)

def check(box, name):
    bx, by, bw, bh = map(float, box.split())
    if not (bx <= ink[0] and by <= ink[1] and bx+bw >= ink[2] and by+bh >= ink[3]):
        sys.exit("%s does not contain the artwork: ink is %.4f %.4f %.4f %.4f, box is %s\n"
                 "Refit it, and re-measure everything positioned as a fraction of it."
                 % (name, *ink, box))
    print("  %-9s ink %.3f x %.3f in a %.3f box; badge at %.4f / %.4f, %.4f across"
          % (name, ink[2]-ink[0], ink[3]-ink[1], bw,
             (bcx-bx)/bw, (bcy-by)/bh, 2*br/bw))
print("artwork fits:")
check(logo_box, "BellLogo")
check(tab_box, "BellTab")

src = open(master).read()
BRAND = "rgb(73.699951%, 12.89978%, 13.299561%)"
paths = re.findall(r"<path[^>]*/>", src)
clapper, outline = paths[0], paths[2]     # paths[1] is the badge, redrawn below

def mark(box, colour, badge, indent="  "):
    """The bell in one colour with the badge laid over it, framed to `box`."""
    return "\n".join(indent + p for p in (
        clapper.replace(BRAND, colour),
        '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (bcx, bcy, br, badge),
        outline.replace(BRAND, colour),
    ))

GHOST = dict(px=1400, eps=2.6, smooth=3, dash="1.5 0.95", width=0.5, notch=4.85, keep=120)

def silhouette(box):
    """The outline of the bell and its clapper as one shape, traced off a render.

    Stroking the two paths without their fills draws the clapper's centre line
    straight through the skirt and closes the ribbon's ends off with a cap, and
    what is wanted is the outline of the two shapes merged. That is a boolean
    union of a filled path with a stroked one, which SVG cannot express and
    neither rsvg nor ImageMagick will compute, so it is traced instead: render
    the pair, walk the boundary, simplify, round the corners off.
    """
    n = GHOST["px"]
    open(TMP + "/ghost.svg", "w").write(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="%s">%s%s</svg>'
        % (box, clapper.replace(BRAND, "#000"), outline.replace(BRAND, "#000")))
    sub.run(["rsvg-convert", "-w", str(n), "-h", str(n), TMP + "/ghost.svg",
             "-o", TMP + "/ghost.png"], check=True)
    sub.run(["magick", TMP + "/ghost.png", "-alpha", "extract", "-depth", "8",
             TMP + "/ghost.pgm"], check=True)
    raw = open(TMP + "/ghost.pgm", "rb").read()
    head, pos = [], 0                      # P5 <w> <h> <maxval>, then bytes
    while len(head) < 4:
        end = raw.index(b"\n", pos)
        head += raw[pos:end].split(); pos = end + 1
    grid = [[1 if raw[pos + y*n + x] > 128 else 0 for x in range(n)] for y in range(n)]

    # marching squares: one segment per cell, chained into closed loops
    seg = {}
    for y in range(n-1):
        for x in range(n-1):
            k = (grid[y][x] << 3) | (grid[y][x+1] << 2) | (grid[y+1][x+1] << 1) | grid[y+1][x]
            T_, R, B, L = (x+.5, y), (x+1, y+.5), (x+.5, y+1), (x, y+.5)
            for p, q in {1: [(B, L)], 2: [(R, B)], 3: [(R, L)], 4: [(T_, R)],
                         5: [(T_, L), (R, B)], 6: [(T_, B)], 7: [(T_, L)], 8: [(L, T_)],
                         9: [(B, T_)], 10: [(L, B), (T_, R)], 11: [(R, T_)], 12: [(L, R)],
                         13: [(B, R)], 14: [(L, B)]}.get(k, []):
                seg.setdefault(p, []).append(q)
    loops, seen = [], set()
    for start in list(seg):
        if start in seen: continue
        loop, cur = [], start
        while cur in seg and cur not in seen:
            seen.add(cur); loop.append(cur); cur = seg[cur][0]
        if len(loop) > 20: loops.append(loop)

    def rdp(pts, eps):                     # Ramer-Douglas-Peucker
        if len(pts) < 3: return pts
        (x0, y0), (x1, y1) = pts[0], pts[-1]
        dx, dy = x1-x0, y1-y0
        norm = math.hypot(dx, dy) or 1e-9
        worst, idx = 0, 0
        for i, (x, y) in enumerate(pts[1:-1], 1):
            dist = abs(dy*x - dx*y + x1*y0 - y1*x0) / norm
            if dist > worst: worst, idx = dist, i
        if worst <= eps: return [pts[0], pts[-1]]
        return rdp(pts[:idx+1], eps)[:-1] + rdp(pts[idx:], eps)

    def chaikin(pts, rounds):
        for _ in range(rounds):
            out = []
            for i, p in enumerate(pts):
                q = pts[(i+1) % len(pts)]
                out.append((.75*p[0] + .25*q[0], .75*p[1] + .25*q[1]))
                out.append((.25*p[0] + .75*q[0], .25*p[1] + .75*q[1]))
            pts = out
        return pts

    bx, by, bw, _ = [float(v) for v in box.split()]
    s = bw / n
    out = []
    for loop in loops:
        pts = [(bx + x*s, by + y*s) for x, y in chaikin(rdp(loop, GHOST["eps"]), GHOST["smooth"])]
        # The hole inside the clapper's hoop, whose top is the skirt's own edge
        # rather than anything the drawing has: a lidded crescent, and busy at
        # the size this is drawn. The hoop reads as a hoop without it.
        if len(pts) < GHOST["keep"]: continue
        out.append(pts)
    return out

def ghost(colour, box, indent="  "):
    """The mark as one dashed outline: hollow, and drawn as if pencilled in.

    The two ends that face the badge are left open rather than capped off — the
    line stops where the drawing stops, which is what an unfinished outline
    does. The badge stays, dashed like the rest, because the notch the bell cuts
    around it is part of the mark and reads as damage without it.
    """
    d = []
    for pts in silhouette(box):
        keep = [math.hypot(x - bcx, y - bcy) > GHOST["notch"] for x, y in pts]
        if all(keep):
            d.append("M " + " L ".join("%.2f %.2f" % p for p in pts) + " Z")
            continue
        cut = keep.index(False)
        pts, keep = pts[cut:] + pts[:cut], keep[cut:] + keep[:cut]
        run = []
        for p, k in zip(pts, keep):
            if k:
                run.append(p)
            else:
                if len(run) > 3: d.append("M " + " L ".join("%.2f %.2f" % q for q in run))
                run = []
        if len(run) > 3: d.append("M " + " L ".join("%.2f %.2f" % q for q in run))
    stroke = ('fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" '
              'stroke-dasharray="%s"' % (colour, GHOST["width"], GHOST["dash"]))
    return "\n".join(indent + p for p in (
        '<path d="%s" %s/>' % (" ".join(d), stroke),
        '<circle cx="%s" cy="%s" r="%s" %s/>' % (bcx, bcy, br, stroke),
    ))

def svg(path, width, height, box, body, note=""):
    open(path, "w").write(
        '<svg xmlns="http://www.w3.org/2000/svg" width="%s" height="%s" viewBox="%s">\n'
        '  <!-- Generated by Support/Icon/generate-marks.sh from notifi-logo.svg.\n'
        '       Edit the master and re-run it; edits here are overwritten.%s -->\n'
        '%s\n</svg>\n' % (width, height, box, note, body))
    print("  wrote", path)

print("marks:")
# Template images: the asset catalogue renders them from alpha, so the colour
# only has to be opaque. The unread badge is laid on in SwiftUI, over the disc.
svg("%s/BellLogo.imageset/bell.svg" % assets, 32, 32, logo_box, mark(logo_box, "#000", "#000"))
svg("%s/BellTab.imageset/bell.svg" % assets, 24, 24, tab_box, mark(tab_box, "#000", "#000"),
    note="\n\n       Framed looser than BellLogo so the bell carries the same weight in the\n"
         "       tab bar as the akar icons beside it.")
# The bells that ring are split into two layers, because the clapper swings a
# beat behind the body when a message arrives. Cropped by the same box, so
# drawing one over the other aligns by construction — the same trick
# generate-menu-icon.sh plays with menu_dot.
def body(colour, badge, indent="  "):
    return "\n".join(indent + p for p in (
        '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (bcx, bcy, br, badge),
        outline.replace(BRAND, colour),
    ))

def clap(colour, indent="  "):
    return indent + clapper.replace(BRAND, colour)

svg("%s/BellLogoBody.imageset/bell.svg" % assets, 32, 32, logo_box, body("#000", "#000"))
svg("%s/BellLogoClapper.imageset/bell.svg" % assets, 32, 32, logo_box, clap("#000"))
svg("%s/BellTabBody.imageset/bell.svg" % assets, 24, 24, tab_box, body("#000", "#000"))
svg("%s/BellTabClapper.imageset/bell.svg" % assets, 24, 24, tab_box, clap("#000"))
# The unread body renders as original rather than template, exactly like
# BellTabUnread and for the same reason: the tab tint must not flatten the red.
for name, ink in (("bell-light", "#1A1A1A"), ("bell-dark", "#EDEDED")):
    svg("%s/BellTabUnreadBody.imageset/%s.svg" % (assets, name), 24, 24, tab_box,
        body(ink, "#BC2122"))

svg("%s/EmptyBell.imageset/bell.svg" % assets, 32, 32, logo_box, ghost("#000", logo_box),
    note="\n\n       The empty inbox: the mark hollowed out, drawn from its own outline.")
# The launch screen renders before any Swift runs, so it cannot tint a template
# through Theme.mark — both inks are baked in and the system's own scheme picks
# one. The hexes are Theme.mark's pair (0.63 light, 0.355 dark).
for name, ink in (("bell-light", "#A1A1A1"), ("bell-dark", "#5B5B5B")):
    svg("%s/LaunchBell.imageset/%s.svg" % (assets, name), 88, 88, logo_box,
        mark(logo_box, ink, ink),
        note="\n\n       The iOS launch screen's mark, quiet on purpose: the ground it sits\n"
             "       on is the same one the app paints first.")
# The site masks this one with currentColor and lays its own disc over the
# badge, so what matters here is the alpha, not the fill.
svg("%s/bell.svg" % web, 32, 32, logo_box, mark(logo_box, "#000", "#000"))
# The header's bell rings, so the site needs the same two layers the app rings:
# one box, one over the other, the clapper free to trail the body.
svg("%s/bell-body.svg" % web, 32, 32, logo_box, body("#000", "#000"))
svg("%s/bell-clapper.svg" % web, 32, 32, logo_box, clap("#000"))

# The favicon and the touch icon are the two marks that are not templates: they
# carry their own colours. They are separate files because a browser tab and an
# iOS home screen want opposite things — see each one below.

def favicon_ink(colour):
    return "\n".join("    " + p for p in (
        clapper.replace(BRAND, colour).replace("<path", '<path class="ink"', 1),
        '<circle cx="%s" cy="%s" r="%s" fill="#BC2122"/>' % (bcx, bcy, br),
        outline.replace(BRAND, colour).replace("<path", '<path class="ink"', 1),
    ))

# The favicon has no plate. A 32px bell inside a rounded rectangle inside a
# 16px tab is a dark blob; without the plate the bell gets the whole square and
# the browser's own tab colour behind it. That only works if the ink follows the
# tab, so the light ink is an inline override the CSS wins against — a favicon
# has no document to inherit currentColor from, and the media query is the one
# thing a standalone SVG can still answer with.
DARK_TAB = '  <style>@media (prefers-color-scheme: dark) {\n' \
           '    .ink { fill: #EDEDED; stroke: #EDEDED }\n' \
           '  }</style>'
svg("%s/favicon.svg" % web, 32, 32, logo_box,
    "%s\n%s" % (DARK_TAB, favicon_ink("#1A1A1A")))

# The touch icon keeps the plate: iOS composites a home screen icon onto no
# ground of its own, so a transparent one is a black square. It is never
# committed — it exists to be rasterised on the next line.
plate = ('  <rect width="32" height="32" rx="7" fill="#1C1C1E"/>\n'
         '  <g transform="translate(16 16) scale(0.78) translate(-16 -16)">\n'
         '%s\n  </g>' % mark("0 0 32 32", "#EDEDED", "#BC2122", indent="    "))
svg("%s/touch-icon.svg" % TMP, 32, 32, "0 0 32 32", plate)
PY

rsvg-convert -w 180 -h 180 "$TMP/touch-icon.svg" -o "$WEB/apple-touch-icon.png"
echo "  wrote $WEB/apple-touch-icon.png"

echo "rasters:"
./generate-menu-icon.sh
./generate-icons.sh
