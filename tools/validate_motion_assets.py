"""Validate the shipped cutout contract without modifying pixels or game state."""
from pathlib import Path
import hashlib
import json
import math
from itertools import combinations
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "game/assets/art/motion/catalog.json"
CORE_REQUIRED = {"head", "head_hit", "right_arm", "left_arm", "shield", "base"}


def _string_set(value, label, errors):
    if not isinstance(value, list) or any(not isinstance(item, str) or not item for item in value):
        errors.append(f"catalog: {label} must be a list of non-empty IDs")
        return set()
    result = set(value)
    if len(result) != len(value):
        errors.append(f"catalog: {label} contains duplicate IDs")
    return result


def _part_contract(data, errors):
    armor_ids = _string_set(data.get("compatible_armor_ids", []), "compatible_armor_ids", errors)
    weapon_parts = data.get("weapon_parts", {})
    if not isinstance(weapon_parts, dict) or any(
        not isinstance(item_id, str) or not item_id or not isinstance(part_id, str) or not part_id
        for item_id, part_id in weapon_parts.items()
    ):
        errors.append("catalog: weapon_parts must map non-empty equipment IDs to non-empty part IDs")
        weapon_parts = {}
    if not armor_ids:
        errors.append("catalog: compatible_armor_ids cannot be empty")
    if not weapon_parts:
        errors.append("catalog: weapon_parts cannot be empty")
    return armor_ids, set(weapon_parts.values())


def _validate_part(template_id, name, part, image, alpha, report, errors):
    report["checks"] += 1
    if not isinstance(part, dict):
        errors.append(f"{template_id}/{name}: part entry must be an object")
        return None
    rect = part.get("rect")
    dimensions = part.get("size")
    pivot = part.get("pivot")
    if not isinstance(rect, list) or len(rect) != 4 or not all(isinstance(value, (int, float)) for value in rect):
        errors.append(f"{template_id}/{name}: rect must contain four numbers")
        return None
    if not isinstance(dimensions, list) or len(dimensions) != 2 or not all(isinstance(value, (int, float)) for value in dimensions):
        errors.append(f"{template_id}/{name}: size must contain two numbers")
        return None
    if not isinstance(pivot, list) or len(pivot) != 2 or not all(isinstance(value, (int, float)) for value in pivot):
        errors.append(f"{template_id}/{name}: pivot must contain two numbers")
        return None
    x, y, w, h = rect
    if min(x, y) < 0 or min(w, h) <= 0 or x + w > image.width or y + h > image.height:
        errors.append(f"{template_id}/{name}: source rectangle outside image")
        return None
    bounds = (int(x), int(y), int(x + w), int(y + h))
    histogram = alpha.crop(bounds).histogram()
    if sum(histogram[31:]) < w * h * 0.08:
        errors.append(f"{template_id}/{name}: empty or implausibly sparse region")
    if min(dimensions) <= 0 or not all(0 <= value <= 1 for value in pivot):
        errors.append(f"{template_id}/{name}: invalid display dimensions or pivot")
    # Extra rig metadata such as a full-arm grip, pose tag or layer hint is
    # intentionally allowed. The renderer, not this audit, defines its meaning.
    return bounds


def _number_sequence(value, length):
    return (
        isinstance(value, list)
        and len(value) == length
        and all(isinstance(item, (int, float)) and not isinstance(item, bool) and math.isfinite(item) for item in value)
    )


def _validate_v2_contract(template_id, spec, parts, errors):
    anchors = spec.get("anchors")
    if not isinstance(anchors, dict):
        errors.append(f"{template_id}: missing v2 anchors object")
    else:
        for anchor_id in ("waist", "neck", "right_shoulder", "left_shoulder"):
            if not _number_sequence(anchors.get(anchor_id), 2):
                errors.append(f"{template_id}: anchor {anchor_id} must be a finite 2D coordinate")
    for arm_id in ("right_arm", "left_arm"):
        arm = parts.get(arm_id, {})
        grip = arm.get("grip") if isinstance(arm, dict) else None
        if not _number_sequence(grip, 2) or not all(0 <= value <= 1 for value in grip):
            errors.append(f"{template_id}/{arm_id}: grip must be a normalized 2D coordinate")
    right_arm = parts.get("right_arm", {})
    hand_region = right_arm.get("hand_region") if isinstance(right_arm, dict) else None
    if not _number_sequence(hand_region, 4):
        errors.append(f"{template_id}/right_arm: hand_region must be a normalized non-zero rectangle")
    else:
        x, y, width, height = hand_region
        if x < 0 or y < 0 or width <= 0 or height <= 0 or x + width > 1 or y + height > 1:
            errors.append(f"{template_id}/right_arm: hand_region must be a normalized non-zero rectangle")


def validate():
    data = json.loads(CATALOG.read_text(encoding="utf-8"))
    report = {"schema": data["schema"], "errors": [], "atlases": [], "checks": 0}
    errors = report["errors"]
    armor_ids, weapon_part_ids = _part_contract(data, errors)
    required_template_parts = CORE_REQUIRED | armor_ids | weapon_part_ids
    templates = data.get("templates", {})
    if not isinstance(templates, dict):
        errors.append("catalog: templates must be an object")
        templates = {}
    for required_id in ("a", "b", "c"):
        if required_id not in templates:
            errors.append(f"catalog: missing required review template {required_id}")
    entries = list(templates.items()) + [("terminal", data.get("terminal", {}))]
    template_parts = {}
    for template_id, spec in entries:
        if not isinstance(spec, dict):
            errors.append(f"{template_id}: template entry must be an object")
            continue
        path = ROOT / "game" / spec.get("atlas", "").removeprefix("res://")
        if not path.is_file():
            errors.append(f"{template_id}: missing atlas {path}")
            continue
        parts = spec.get("parts", {})
        if not isinstance(parts, dict):
            errors.append(f"{template_id}: parts must be an object")
            continue
        required = armor_ids if template_id == "terminal" else required_template_parts
        for missing in sorted(required - set(parts)):
            errors.append(f"{template_id}: missing required part {missing}")
        template_parts[template_id] = parts
        if template_id != "terminal":
            _validate_v2_contract(template_id, spec, parts, errors)
        with Image.open(path) as image:
            alpha = image.getchannel("A") if image.mode == "RGBA" else None
            if alpha is None or alpha.getextrema()[0] != 0 or alpha.getextrema()[1] < 240:
                errors.append(f"{template_id}: expected transparent RGBA and solid painted interior")
                continue
            bounds = {}
            for name, part in parts.items():
                bounds_value = _validate_part(template_id, name, part, image, alpha, report, errors)
                if bounds_value is not None:
                    bounds[name] = bounds_value
            for first, second in combinations(bounds, 2):
                a, b = bounds[first], bounds[second]
                overlap = max(a[0], b[0]), max(a[1], b[1]), min(a[2], b[2]), min(a[3], b[3])
                if overlap[0] < overlap[2] and overlap[1] < overlap[3]:
                    if sum(alpha.crop(overlap).histogram()[31:]) > 4:
                        errors.append(f"{template_id}: {first} and {second} share painted pixels")
            if template_id != "terminal":
                motion = spec.get("motion", {})
                if not isinstance(motion, dict) or not all(key in motion for key in ("contact", "slash", "shield_bash")):
                    errors.append(f"{template_id}: missing contact or duration motion values")
                elif not 0 < motion["contact"] < 1 or min(motion["slash"], motion["shield_bash"]) <= 0:
                    errors.append(f"{template_id}: invalid contact or duration")
            report["atlases"].append({"id": template_id, "file": str(path.relative_to(ROOT)), "size": image.size,
                                     "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
                                     "alpha_extrema": alpha.getextrema(), "parts": len(parts)})
    comparable_ids = [key for key in ("a", "b", "c") if key in template_parts]
    if len(comparable_ids) == 3:
        for name in sorted(required_template_parts):
            if not all(name in template_parts[key] for key in comparable_ids):
                continue
            dims = [template_parts[key][name].get("size") for key in comparable_ids]
            if dims[0] != dims[1] or dims[1] != dims[2]:
                errors.append(f"{name}: incompatible logical dimensions across templates")
    report["passed"] = not errors
    output = ROOT / "builds/motion-review/asset-audit.json"
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"Motion assets: {report['checks']} part checks, {len(errors)} errors")
    for error in errors:
        print(error)
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(validate())
