"""Generate small-scale two-terrain preview and transparency audit for raw sprites."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw


ROOT = Path(__file__).resolve().parent
IDS = [f"{kind}_{index:02d}" for kind in ("sword", "spear", "bow") for index in (2, 3, 4)]
BACKGROUNDS = ((62, 76, 59), (173, 151, 112))


def main() -> None:
    report = {}
    sheet = Image.new("RGB", (1080, 1050), (25, 26, 25))
    draw = ImageDraw.Draw(sheet)
    for index, asset_id in enumerate(IDS):
        file = ROOT / f"{asset_id}.png"
        image = Image.open(file).convert("RGBA")
        alpha = image.getchannel("A")
        bbox_1 = alpha.getbbox()
        bbox_32 = alpha.point(lambda v: 255 if v >= 32 else 0).getbbox()
        corners = [alpha.getpixel(point) for point in ((0, 0), (image.width - 1, 0), (0, image.height - 1), (image.width - 1, image.height - 1))]
        report[asset_id] = {
            "sha256": hashlib.sha256(file.read_bytes()).hexdigest(),
            "size": list(image.size),
            "mode": image.mode,
            "alpha_range": list(alpha.getextrema()),
            "bbox_alpha_1": list(bbox_1) if bbox_1 else None,
            "bbox_alpha_32": list(bbox_32) if bbox_32 else None,
            "corner_alpha": corners,
        }
        x = (index % 3) * 360
        y = (index // 3) * 350
        draw.text((x + 8, y + 8), asset_id, fill=(242, 236, 220))
        for col, color in enumerate(BACKGROUNDS):
            cell = Image.new("RGB", (180, 315), color)
            sprite = image.copy()
            sprite.thumbnail((150, 270), Image.Resampling.LANCZOS)
            cell.paste(sprite, ((180 - sprite.width) // 2, (315 - sprite.height) // 2), sprite)
            sheet.paste(cell, (x + 180 * col, y + 32))
    sheet.save(ROOT / "qa-preview.png")
    (ROOT / "qa-report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
