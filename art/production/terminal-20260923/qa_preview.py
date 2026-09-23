"""Inspect staged terminal overlays without changing their source pixels."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
NAMES = ("state_down", "state_dead")
BACKGROUNDS = ((62, 76, 59), (173, 151, 112))


def main() -> None:
    canvas = Image.new("RGB", (800, 440), (30, 31, 30))
    draw = ImageDraw.Draw(canvas)
    report = {}
    for row, name in enumerate(NAMES):
        source = ROOT / f"{name}.png"
        sprite = Image.open(source).convert("RGBA")
        alpha = sprite.getchannel("A")
        report[name] = {
            "sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
            "pixel_size": list(sprite.size),
            "mode": sprite.mode,
            "alpha_min_max": list(alpha.getextrema()),
            "alpha_32_bbox": list(alpha.point(lambda v: 255 if v >= 32 else 0).getbbox()),
            "alpha_128_bbox": list(alpha.point(lambda v: 255 if v >= 128 else 0).getbbox()),
        }
        for col, color in enumerate(BACKGROUNDS):
            for scale_index, size in enumerate((90, 180)):
                x = col * 400 + scale_index * 200
                y = row * 220
                cell = Image.new("RGB", (200, 220), color)
                reduced = sprite.resize((size, size), Image.Resampling.LANCZOS)
                cell.paste(reduced, ((200 - size) // 2, (190 - size) // 2), reduced)
                canvas.paste(cell, (x, y))
                draw.text((x + 8, y + 198), f"{name} / {size}px", fill=(240, 235, 220))
    canvas.save(ROOT / "qa-preview.png")
    (ROOT / "qa-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
