"""Prepare the separately generated foundation art for the asset workbench.

Each manifest source is either a previously approved atlas region or one
independent image_gen result. This script only crops, trims transparent margins,
and scales bitmaps; it never invents art or derives a new variant by recoloring.
Run from the repository root with: python tools/prepare_foundation_assets.py
"""

from __future__ import annotations

import copy
import argparse
import json
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
PRODUCTION = ROOT / "art" / "production" / "foundation-20260923"
PROJECT_DIR = ROOT / "art" / "workbench" / "projects"
CURRENT = PROJECT_DIR / "current.asset.json"
FOUNDATION = PROJECT_DIR / "foundation.asset.json"
MANIFEST = PRODUCTION / "manifest.json"
ASSETS = PRODUCTION / "assets"

CATEGORIES = (
    "body", "face", "hair", "beard", "linen", "padded", "outer",
    "shield", "sword", "axe", "spear", "bow", "scar", "bandage", "blood",
)
TEMPLATE = {"body": "skin", "outer": "mail", "axe": "sword"}
NAMES = {
    "body": ("原型肤色躯干", "深肤精瘦躯干", "浅肤年长躯干", "暖棕健壮躯干"),
    "face": ("沧桑方脸", "深肤锐脸", "浅肤宽脸", "暖棕年长脸"),
    "hair": ("棕色后梳发", "深棕卷发", "浅金束发", "银灰短发"),
    "beard": ("棕灰全须", "深色山羊须", "赤褐编须", "灰色短须"),
    "linen": ("深灰亚麻衫", "原白亚麻衫", "靛蓝亚麻衫", "锈红亚麻衫"),
    "padded": ("赭黄绗缝衣", "苔绿竖纹绗缝衣", "酒红V纹绗缝衣", "灰蓝横纹绗缝衣"),
    "outer": ("锁子甲", "铆钉布面甲", "硬化皮甲", "钢鳞甲"),
    "shield": ("红白鸢盾", "蓝日圆盾", "黑白纹盾", "铁质圆盾"),
    "sword": ("铁制长剑", "重刃砍刀", "宽刃短剑", "骑兵弯刃"),
    "axe": ("新月战斧", "长钩战斧", "伐木战斧", "双刃军斧"),
    "spear": ("铁制长矛", "钩刃长矛", "叶刃长矛", "翼刃长矛"),
    "bow": ("紫杉木弓", "细长长弓", "短猎弓", "反曲复合弓"),
    "scar": ("脸部划伤", "交叉旧疤", "锯齿长疤", "面颊灼疤"),
    "bandage": ("额部布带", "斜缠额带", "下颌绷带", "遮眼绷带"),
    "blood": ("旧血迹", "新鲜血痕", "细密血点", "干涸血痕"),
}


def trim_generated(image: Image.Image, category: str) -> Image.Image:
    image = image.convert("RGBA")
    alpha = image.getchannel("A").point(lambda value: 0 if value < 12 else value)
    image.putalpha(alpha)
    bbox = alpha.point(lambda value: 255 if value >= 16 else 0).getbbox()
    if bbox is None:
        raise ValueError("generated source has no visible alpha")
    image = image.crop(bbox)
    if category == "body":
        # Four naked busts share the existing skin atlas cell's exact pixel spec.
        target = (647, 353)
        limit = (625, 335)
        image.thumbnail(limit, Image.Resampling.LANCZOS)
        canvas = Image.new("RGBA", target)
        canvas.alpha_composite(image, ((target[0] - image.width) // 2, target[1] - image.height - 8))
        return canvas
    image.thumbnail((720, 720), Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (image.width + 16, image.height + 16))
    canvas.alpha_composite(image, (8, 8))
    return canvas


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--register", nargs=4, metavar=("ID", "SOURCE", "NAME", "PROMPT"))
    args = parser.parse_args()
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    if args.register:
        asset_id, source, name, prompt = args.register
        if not source.startswith("art/production/foundation-20260923/sources/"):
            raise ValueError("registered image must be copied to this batch's sources directory")
        manifest["items"][asset_id] = {
            "name": name,
            "source": source,
            "origin": "OpenAI built-in image_gen",
            "tool": "built-in image_gen",
            "prompt": prompt,
        }
    current = json.loads(CURRENT.read_text(encoding="utf-8"))
    draft = copy.deepcopy(current)
    ASSETS.mkdir(parents=True, exist_ok=True)
    ready = []
    pending = []
    ready_damage = []
    pending_damage = []
    specs = []
    for category in CATEGORIES:
        for number in range(1, 5):
            asset_id = f"{category}_{number:02d}"
            specs.append((asset_id, category, TEMPLATE.get(category, category), NAMES[category][number - 1], False))
    for category in ("padded", "outer"):
        for number in range(1, 5):
            asset_id = f"{category}_{number:02d}_damaged"
            template = "padded_damaged" if category == "padded" else "mail_damaged"
            specs.append((asset_id, category, template, NAMES[category][number - 1] + "（破损）", True))
    specs.append(("base", "base", "base", "铁质底座", False))
    for asset_id, category, template_id, display_name, damaged in specs:
            entry = manifest["items"].get(asset_id)
            if entry is None or not entry.get("source"):
                (pending_damage if damaged else pending).append(asset_id)
                continue
            source = ROOT / entry["source"]
            if not source.is_file():
                (pending_damage if damaged else pending).append(asset_id)
                continue
            image = Image.open(source).convert("RGBA")
            if "rect" in entry:
                x, y, width, height = entry["rect"]
                image = image.crop((x, y, x + width, y + height))
            else:
                image = trim_generated(image, category)
            output = ASSETS / f"{asset_id}.png"
            image.save(output, optimize=True)
            asset = copy.deepcopy(current["assets"][template_id])
            asset["id"] = asset_id
            asset["name"] = display_name
            asset["image"] = f"../../production/foundation-20260923/assets/{asset_id}.png"
            asset["rect"] = [0, 0, image.width, image.height]
            asset["source"] = {
                "origin": entry.get("origin", "openai-imagegen"),
                "image": entry["source"],
                "tool": entry.get("tool", "built-in image_gen"),
                "prompt": entry.get("prompt", ""),
            }
            asset["tags"] = ["foundation-20260923", category]
            # Parent references remain the existing canonical face/skin nodes.
            draft["assets"][asset_id] = asset
            (ready_damage if damaged else ready).append(asset_id)
    draft["editor"]["scene"] = current["editor"]["scene"]
    FOUNDATION.write_text(json.dumps(draft, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    manifest["ready"] = ready
    manifest["pending"] = pending
    manifest["ready_damage"] = ready_damage
    manifest["pending_damage"] = pending_damage
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"ready={len(ready)}/61 damaged={len(ready_damage)}/8 pending={len(pending)}+{len(pending_damage)} project={FOUNDATION}")


if __name__ == "__main__":
    main()
