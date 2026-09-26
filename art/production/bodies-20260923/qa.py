"""Make a repeatable transparency and size preview of the three body source PNGs."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageStat


ROOT = Path(__file__).resolve().parent
IDS = ("body_02", "body_03", "body_04")
BACKGROUNDS = ((62, 76, 59), (173, 151, 112))


def main() -> None:
    sheet = Image.new("RGB", (1024, 780), (25, 26, 25))
    draw = ImageDraw.Draw(sheet)
    report = {}
    for row, asset_id in enumerate(IDS):
        path = ROOT / f"{asset_id}.png"
        image = Image.open(path).convert("RGBA")
        alpha = image.getchannel("A")
        mask = alpha.point(lambda value: 255 if value >= 128 else 0)
        report[asset_id] = {
            "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "pixel_size": list(image.size),
            "mode": image.mode,
            "alpha_range": list(alpha.getextrema()),
            "alpha_32_bbox": list(alpha.point(lambda value: 255 if value >= 32 else 0).getbbox()),
            "corner_alpha": [alpha.getpixel(point) for point in ((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1))],
            "opaque_area_mean_rgb": [round(value, 1) for value in ImageStat.Stat(image.convert("RGB"), mask=mask).mean],
        }
        for col, color in enumerate(BACKGROUNDS):
            x = col * 512
            y = row * 260
            cell = Image.new("RGB", (512, 260), color)
            for size, left in ((64, 20), (256, 180)):
                sprite = image.copy()
                sprite.thumbnail((size, size), Image.Resampling.LANCZOS)
                cell.paste(sprite, (left, 70 + (140 - sprite.height) // 2), sprite)
            sheet.paste(cell, (x, y))
            draw.text((x + 12, y + 10), f"{asset_id} / 64px and 256px width", fill=(242, 236, 220))
    sheet.save(ROOT / "qa-preview.png")
    (ROOT / "qa-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
