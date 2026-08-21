"""Write a rendered screenshot only when it differs from the committed one.

Every capture differs from the last: the seeded fixture is clock-relative, so
the times on screen move, and the ground's grain is random per launch and
animated off the wall clock. Written straight out, all 34 published images
change on every run and `git status` says nothing about what actually moved.

So a new render replaces the committed file only when enough pixels differ by
enough to be something other than that. Measured across a run where only the
inbox changed: grain and clock reached 0.026% of pixels, the smallest real
change (an iPad inbox losing one line) 0.128%. The gate sits between them,
nearer the noise.

    from publish_image import publish
    publish(image, "apps/api/public/screens/keys.webp", "WEBP", quality=80)

The comparison is against the encoded file, not the image in memory, because
that is what lands in the repository.
"""
import os
import tempfile

from PIL import Image, ImageChops

EPS = 48
THRESHOLD = 0.0005


def _changed_fraction(a_path, b_path):
    a = Image.open(a_path).convert("RGBA")
    b = Image.open(b_path).convert("RGBA")
    if a.size != b.size:
        return 1.0
    over = None
    for band_a, band_b in zip(a.split(), b.split()):
        past = ImageChops.difference(band_a, band_b).point(
            lambda v: 255 if v > EPS else 0
        )
        over = past if over is None else ImageChops.lighter(over, past)
    return over.histogram()[255] / (a.size[0] * a.size[1])


def publish(image, path, fmt=None, **save_kwargs):
    """Save `image` to `path`, or keep what is there if only noise moved.

    PUBLISH_ALL=1 writes regardless. A change can be real and still fall under
    the gate: insetting the key icon moved about 60 pixels of a 3.6M-pixel
    frame, so every screen carrying a tab bar was kept and the fix reached
    only the frames that happened to churn for other reasons."""
    suffix = os.path.splitext(path)[1] or ".png"
    handle, temp = tempfile.mkstemp(suffix=suffix)
    os.close(handle)
    try:
        image.save(temp, fmt, **save_kwargs)
        forced = os.environ.get("PUBLISH_ALL") == "1"
        if os.path.exists(path):
            fraction = _changed_fraction(path, temp)
            if fraction < THRESHOLD and not forced:
                print(f"kept {path} ({fraction * 100:.3f}% differs)")
                return False
            print(f"wrote {path} ({fraction * 100:.3f}% differs)")
        else:
            print(f"wrote {path} (new)")
        os.replace(temp, path)
        return True
    finally:
        if os.path.exists(temp):
            os.remove(temp)
