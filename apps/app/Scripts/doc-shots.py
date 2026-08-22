"""Crop the raw simulator captures into the figures /docs shows.

`make doc-shots` runs shots.sh for the screens below and then this, so the
two published figures are never cropped by hand. The boxes are in the raw
1320x2868 capture's pixels; each output is halved, so the file's own pixel
size is the size the page displays it at, and gen-site reads that off the
file rather than being told.

Re-run it after any change to the Settings screen or a key's screen.
"""

from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
RAW = Path("/tmp/notifi-shots")
OUT = ROOT / "apps/api/public/shots"

FIGURES = [
    ("settings", "settings-reject-invalid-sends.png", (0, 150, 1320, 800)),
    ("key", "key-critical-alerts.png", (0, 120, 1320, 1750)),
]


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for shot, name, box in FIGURES:
        source = RAW / f"{shot}.png"
        if not source.exists():
            raise SystemExit(f"no capture at {source} — run make doc-shots, not this alone")
        image = Image.open(source).crop(box)
        image = image.resize((image.width // 2, image.height // 2), Image.LANCZOS)
        image.save(OUT / name, optimize=True)
        print(f"{OUT / name} {image.width}x{image.height}")


if __name__ == "__main__":
    main()
