"""Export imagegen garment edits to the existing component canvas sizes.

Only resizes whole RGBA images; no painted pixels or transparency masks are
constructed here. Pillow's premultiplied RGBa mode avoids dark alpha fringes.
"""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT / "sources"
OUTPUT = ROOT / "assets"
# Measured from the edit targets before the production manifest was updated.
SIZES = {
    "padded_02": (655, 736),
    "padded_03": (671, 736),
    "padded_04": (656, 736),
    "outer_02": (654, 736),
    "outer_04": (660, 736),
}


def main() -> None:
    OUTPUT.mkdir(exist_ok=True)
    for asset_id, size in SIZES.items():
        source = SOURCE / f"{asset_id}-imagegen.png"
        if not source.exists():
            continue
        with Image.open(source) as generated:
            image = generated.convert("RGBA").convert("RGBa")
            image = image.resize(size, Image.Resampling.LANCZOS).convert("RGBA")
            image.save(OUTPUT / f"{asset_id}.png", optimize=True)
        print(f"{asset_id}: {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
