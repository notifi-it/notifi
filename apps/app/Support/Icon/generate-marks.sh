#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
MASTER="notifi-logo.svg"
ASSETS="../../Shared/Assets.xcassets"
WEB="../../../api/public"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

LOGO_BOX="5.2700 6.5395 21.4600 21.4600"
TAB_BOX="4.30 5.19 23.40 23.40"
BADGE_CX=20.3047
BADGE_CY=9.7539
BADGE_R=2.9

rsvg-convert -w 3200 -h 3200 "$MASTER" -o "$TMP/ink.png"
INK="$(magick "$TMP/ink.png" -format "%@" info:)"

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
clapper, outline = paths[0], paths[2]

def mark(box, colour, badge, indent="  "):
    """The bell in one colour with the badge laid over it, framed to `box`."""
    return "\n".join(indent + p for p in (
        clapper.replace(BRAND, colour),
        '<circle cx="%s" cy="%s" r="%s" fill="%s"/>' % (bcx, bcy, br, badge),
        outline.replace(BRAND, colour),
    ))

GHOST = dict(px=1400, eps=2.6, smooth=3, dash="1.5 0.95", width=0.5, notch=4.85, keep=120)

def outset(box, pad):
    """`box` with `pad` added on every side.

    The ghost is stroked, not filled, so it reaches half a stroke width past
    the silhouette it traces and the round caps push a little further still.
    LOGO_BOX is fitted to the solid artwork, so framing a ghost in it slices
    the topmost and bottommost dashes off. A whole stroke width of slack
    covers the overhang with room to spare.
    """
    bx, by, bw, bh = map(float, box.split())
    return "%.4f %.4f %.4f %.4f" % (bx - pad, by - pad, bw + 2*pad, bh + 2*pad)

ghost_box = outset(logo_box, GHOST["width"])

def framed(path, n=512):
    """Fail if the mark just written runs off its own viewBox."""
    sub.run(["rsvg-convert", "-w", str(n), "-h", str(n), path, "-o", TMP + "/fit.png"], check=True)
    out = sub.run(["magick", TMP + "/fit.png", "-alpha", "extract", "-format", "%@", "info:"],
                  capture_output=True, text=True, check=True).stdout
    w, h, x, y = map(int, re.match(r"(\d+)x(\d+)\+(-?\d+)\+(-?\d+)", out).groups())
    edge = min(x, y, n - (x + w), n - (y + h))
    if edge <= 0:
        sys.exit("%s is clipped by its own viewBox: ink is %dx%d+%d+%d in %dpx.\n"
                 "Widen the box it is framed in." % (path, w, h, x, y, n))
    print("  %s clears its frame by %dpx of %d" % (path, edge, n))

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
    head, pos = [], 0
    while len(head) < 4:
        end = raw.index(b"\n", pos)
        head += raw[pos:end].split(); pos = end + 1
    grid = [[1 if raw[pos + y*n + x] > 128 else 0 for x in range(n)] for y in range(n)]

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

    def rdp(pts, eps):
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

svg("%s/BellLogo.imageset/bell.svg" % assets, 32, 32, logo_box, mark(logo_box, "#000", "#000"))
svg("%s/BellTab.imageset/bell.svg" % assets, 24, 24, tab_box, mark(tab_box, "#000", "#000"),
    note="\n\n       Framed looser than BellLogo so the bell carries the same weight in the\n"
         "       tab bar as the akar icons beside it.")

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

for name, ink in (("bell-light", "#1A1A1A"), ("bell-dark", "#EDEDED")):
    svg("%s/BellTabUnreadBody.imageset/%s.svg" % (assets, name), 24, 24, tab_box,
        body(ink, "#BC2122"))

svg("%s/EmptyBell.imageset/bell.svg" % assets, 32, 32, ghost_box, ghost("#000", ghost_box),
    note="\n\n       The empty inbox: the mark hollowed out, drawn from its own outline.")
framed("%s/EmptyBell.imageset/bell.svg" % assets)

for name, ink in (("bell-light", "#A1A1A1"), ("bell-dark", "#5B5B5B")):
    svg("%s/LaunchBell.imageset/%s.svg" % (assets, name), 88, 88, logo_box,
        mark(logo_box, ink, ink),
        note="\n\n       The iOS launch screen's mark, quiet on purpose: the ground it sits\n"
             "       on is the same one the app paints first.")

svg("%s/bell.svg" % web, 32, 32, logo_box, mark(logo_box, "#000", "#000"))

svg("%s/bell-empty.svg" % web, 32, 32, ghost_box, ghost("#000", ghost_box),
    note="\n\n       The 404 page's mark: the same hollowed-out bell the app shows over an\n"
         "       empty inbox.")
framed("%s/bell-empty.svg" % web)

svg("%s/bell-body.svg" % web, 32, 32, logo_box, body("#000", "#000"))
svg("%s/bell-clapper.svg" % web, 32, 32, logo_box, clap("#000"))

def favicon_ink(colour):
    return "\n".join("    " + p for p in (
        clapper.replace(BRAND, colour).replace("<path", '<path class="ink"', 1),
        '<circle cx="%s" cy="%s" r="%s" fill="#EDEDED"/>' % (bcx, bcy, br),
        outline.replace(BRAND, colour).replace("<path", '<path class="ink"', 1),
    ))

svg("%s/favicon.svg" % web, 32, 32, logo_box, favicon_ink("#BC2122"),
    note="\n\n       Brand red with a white badge: at 16px the dot is the only detail\n"
         "       that has to survive, and it reads as itself only against the bell.")

svg("%s/favicon-flat.svg" % TMP, 32, 32, logo_box, mark(logo_box, "#BC2122", "#BC2122"))

plate = ('  <rect width="32" height="32" rx="7" fill="#1C1C1E"/>\n'
         '  <g transform="translate(16 16) scale(0.78) translate(-16 -16)">\n'
         '%s\n  </g>' % mark("0 0 32 32", "#EDEDED", "#BC2122", indent="    "))
svg("%s/touch-icon.svg" % TMP, 32, 32, "0 0 32 32", plate)
PY

rsvg-convert -w 180 -h 180 "$TMP/touch-icon.svg" -o "$WEB/apple-touch-icon.png"
echo "  wrote $WEB/apple-touch-icon.png"

for s in 16 32 48; do
  rsvg-convert -w "$s" -h "$s" "$TMP/favicon-flat.svg" -o "$TMP/favicon-$s.png"
done
magick "$TMP/favicon-16.png" "$TMP/favicon-32.png" "$TMP/favicon-48.png" "$WEB/favicon.ico"
echo "  wrote $WEB/favicon.ico"

echo "rasters:"
./generate-menu-icon.sh
./generate-icons.sh
