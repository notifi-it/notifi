#!/usr/bin/env bash
#
# Social banners, from the same master every other mark comes from.
#
# The two-tone recolour below is lifted from generate-icons.sh rather than
# re-derived: the badge is path index 1 and everything else is the bell, and a
# second copy of that rule would be free to drift from the icon it has to match.
#
# Output is docs/socials/images/. Do not edit those files; edit notifi-logo.svg
# and run this.
set -euo pipefail

cd "$(dirname "$0")"
OUT="../../../../docs/socials/images"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT"

# Two bells, differing only in the badge.
#
# Red badge for the mark standing alone, which is the icon's colouring and the
# reason the silhouette reads as an `i`.
#
# Light badge for the lockup, because the wordmark ends in a dotless `i` whose
# tittle is already brand red. Two red discs a few hundred pixels apart do not
# read as one idea repeated, they read as two dots competing, and the eye lands
# on the bell's — the wrong one, since the word's is the one carrying meaning.
# The notch the artwork cuts around the badge stays either way; against a light
# disc it reads as the spacing it is.
render_bell() {
  python3 - "$1" "$2" <<'PY'
import re, sys
out_path, badge = sys.argv[1], sys.argv[2]
src = open("notifi-logo.svg").read()
BRAND = "rgb(73.699951%, 12.89978%, 13.299561%)"
LIGHT = "rgb(92.9%, 92.9%, 92.9%)"
RED   = "rgb(85.9%, 29%, 29.4%)"
out, cursor = [], 0
for i, m in enumerate(re.finditer(r"<path[^>]*>", src)):
    colour = (RED if badge == "red" else LIGHT) if i == 1 else LIGHT
    out.append(src[cursor:m.start()])
    out.append(m.group(0).replace(BRAND, colour))
    cursor = m.end()
out.append(src[cursor:])
open(out_path, "w").write("".join(out))
PY
}

render_bell "$TMP/bell-red.svg" red
render_bell "$TMP/bell-light.svg" light

# The same grain the app icon carries, at the same seed, blur and 22% blend, so
# an avatar sitting next to the App Store listing is the same surface and not a
# flat cut-out of it. It survives the downscale and the re-encode every platform
# puts an avatar through — checked at 176px and JPEG q70, which is roughly
# Facebook's treatment.
plate() {
  local w=$1 h=$2 out=$3
  magick -size "${w}x${h}" xc:'#1C1C1E' "$TMP/plate-flat.png"
  magick -size "${w}x${h}" -seed 42 xc: +noise Random -colorspace Gray -blur 0x0.4 \
    "$TMP/plate-grain.png"
  # -type TrueColorAlpha, not just png:color-type: the plate is entirely greys,
  # so ImageMagick writes it as a palette image, and compositing a coloured
  # lockup onto a palette quantises it to that palette. The wordmark's red
  # tittle came out grey until this was here.
  magick "$TMP/plate-flat.png" "$TMP/plate-grain.png" \
    -compose Blend -define compose:args=22% -composite \
    -colorspace sRGB -type TrueColorAlpha -define png:color-type=6 "$out"
}

# -colorspace sRGB -type TrueColorAlpha matters on the light bell, which has no
# colour in it at all and is otherwise written as GrayscaleAlpha. The lockup
# takes its type from the first image in the list, so a grey bell silently
# quantises the wordmark's red tittle — the only colour in the composition — and
# the result looks like a deliberate monochrome logo rather than a bug.
for v in red light; do
  rsvg-convert -w 2400 -h 2400 "$TMP/bell-$v.svg" -o "$TMP/bell-$v-raw.png"
  magick "$TMP/bell-$v-raw.png" -trim +repage \
    -colorspace sRGB -type TrueColorAlpha "$TMP/bell-$v.png"
done

rsvg-convert -w 3450 -h 1000 ../../../api/public/wordmark.svg -o "$TMP/word-raw.png"
magick "$TMP/word-raw.png" -trim +repage "$TMP/word.png"

# One lockup, scaled per banner. The wordmark's cap height is shorter than the
# bell's full height, so matching their pixel heights makes the word look large
# next to the mark; 0.62 is the ratio the site header uses (19px word to 24px
# bell) and is kept here rather than re-eyeballed per size.
WORD_RATIO=0.62

# $1 width  $2 height  $3 bell height  $4 output name
banner() {
  local w=$1 h=$2 bell=$3 name=$4
  local word gap
  word=$(python3 -c "print(round($bell * $WORD_RATIO))")
  gap=$(python3 -c "print(round($bell * 0.30))")

  magick "$TMP/bell-light.png" -resize "x$bell" "$TMP/b.png"
  magick "$TMP/word.png" -resize "x$word" "$TMP/w.png"

  # The -colorspace has to sit between the two reads, not after them. The light
  # bell has no colour in it, so it lands in the list as GrayscaleAlpha, and the
  # smush takes its type from the first image — quantising the wordmark's red
  # tittle, the one piece of colour in the composition, to grey. Converting
  # after the smush is too late: the value is already gone. PNG stores the bell
  # as grey whatever is asked of it on write, so this is fixed on read.
  magick "$TMP/b.png" -colorspace sRGB -type TrueColorAlpha "$TMP/w.png" \
    -background none -gravity center +smush "$gap" "$TMP/lockup.png"

  # -strip so a re-run that changes no pixel changes no file. PNG carries a
  # creation timestamp otherwise, and all four images show up modified in git
  # every time this is run, which buries the one that actually moved.
  plate "$w" "$h" "$TMP/plate.png"
  magick "$TMP/plate.png" "$TMP/lockup.png" \
    -gravity center -composite \
    -strip -define png:color-type=6 "$OUT/$name"
  echo "  $name  ${w}x${h}"
}

echo "writing $OUT:"

# X. 3:1, and the whole frame is shown, so the lockup can breathe.
banner 1500 500 150 x-banner.png

# Facebook. The file is 1640x856 but most people see a 640x360 crop out of the
# middle, so the lockup is sized against that box, not against the file.
banner 1640 856 110 facebook-cover.png

# LinkedIn. 5.9:1 and only 191 tall; a lockup is all that fits.
banner 1128 191 96 linkedin-banner.png

# Square profile picture: the mark alone. The lockup does not belong here — a
# wordmark wide enough to read has to shrink until the bell is a speck, and
# every platform crops this to a circle anyway, which would cut the word's ends
# off first.
#
# This is the app icon's artwork on the app icon's plate, and deliberately so:
# the App Store listing and the avatar are seen together often enough that a
# flat version of one beside the grained version of the other looks like two
# apps. It is regenerated here rather than copied from the appiconset because
# that file is 1024 square with the icon's own corner treatment.
plate 1024 1024 "$TMP/profile-plate.png"
magick "$TMP/profile-plate.png" \( "$TMP/bell-red.png" -resize x560 \) \
  -gravity center -composite \
  -strip -define png:color-type=6 "$OUT/profile.png"
echo "  profile.png  1024x1024"
