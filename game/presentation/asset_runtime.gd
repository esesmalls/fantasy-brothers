extends RefCounted
## Game-owned asset selection. Editor scenes, eyes and locks are never consumed.
const Document = preload("res://presentation/asset_document.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Motion = preload("res://presentation/static_bust_motion.gd")
const WEAPONS := {"weapon_guard_sword": "sword", "weapon_guard_cleaver": "sword", "weapon_spear_long": "spear", "weapon_spear_hooked": "spear", "weapon_archer_bow": "bow", "weapon_archer_longbow": "bow", "weapon_hunter_bow": "bow", "weapon_hunter_recurve": "bow", "weapon_skirmisher_blade": "sword", "weapon_skirmisher_axe": "sword"}
const ARMORS := {"armor_padded": "padded", "armor_leather": "padded", "armor_brigandine": "mail", "armor_mail": "mail"}
static var cached_revision := "!"
static var cached_data: Dictionary = {}
static var cached_directory := ""

static func current() -> Dictionary:
	var directory := Document.runtime_dir()
	var pointer := Document.read_json(directory.path_join("current.json"))
	if pointer.is_empty():
		directory = "res://assets/art/paperdoll"
		pointer = Document.read_json(directory.path_join("current.json"))
	var revision: String = pointer.get("revision", "")
	if revision != cached_revision or directory != cached_directory:
		cached_revision = revision; cached_directory = directory
		cached_data = {} if revision.is_empty() else Document.read_json(directory.path_join(revision + ".json"))
	return cached_data

static func selection(data: Dictionary, unit: Dictionary) -> Array:
	if unit.has("visual_assets"): return unit.visual_assets.duplicate()
	var gear: Dictionary = unit.get("visual_loadout", {})
	var armor: String = ARMORS.get(gear.get("armor", "armor_mail"), "")
	var weapon: String = WEAPONS.get(gear.get("weapon", "weapon_guard_sword"), "")
	var appearance: Dictionary = data.get("game", {}).get("appearance", {})
	var damaged := float(unit.get("armor", 1)) / maxf(1, float(unit.get("max_armor", 1))) < 0.67
	var wounded := float(unit.get("hp", 1)) / maxf(1, float(unit.get("max_hp", 1))) < 0.74
	var result: Array = ["base", "body"]
	if appearance.get("skin", true): result.append("skin")
	if not armor.is_empty(): result.append_array(["linen", "padded_damaged" if damaged and armor == "padded" else "padded"])
	if armor == "mail": result.append("mail_damaged" if damaged else "mail")
	if appearance.get("head", "legacy") == "modular":
		result.append("face")
		for id: String in ["hair", "beard", "bandage", "blood", "scar"]:
			if appearance.get(id, false) or (id == "scar" and wounded): result.append(id)
	else:
		result.append("wounded" if wounded else "head")
		for id: String in ["bandage", "blood", "scar"]:
			if appearance.get(id, false): result.append(id)
	if not weapon.is_empty(): result.append(weapon)
	if weapon == "sword": result.append("shield")
	return result

static func draw_asset(canvas: CanvasItem, asset_id: String, origin: Vector2, zoom: float = 1, adaptation: String = "", action_id: String = "", time: float = 0, anchors: Dictionary = {}, root_mode: bool = true) -> Array:
	var data := current()
	if data.is_empty(): return ["没有已应用的资产版本"]
	return Visuals.draw(canvas, data, [asset_id], origin, zoom, cached_directory, adaptation, data.actions.get(action_id, {}), time, anchors, root_mode)

static func action_for_unit(unit: Dictionary, kind: String) -> Dictionary:
	var data := current()
	var weapon: String = WEAPONS.get(unit.get("visual_loadout", {}).get("weapon", "weapon_guard_sword"), "")
	var id: String = unit.get("visual_actions", {}).get(kind, unit.get("visual_action", weapon) if kind in ["attack", "slash", "shield_bash"] else "")
	return data.get("actions", {}).get(id, {})

static func draw_unit(canvas: CanvasItem, unit: Dictionary, origin: Vector2, zoom: float, pose: Dictionary) -> bool:
	var data := current()
	if data.is_empty(): return false
	# Terminal states continue through the existing terminal-state renderer.
	if int(unit.get("hp", 1)) <= 0 or pose.get("action", "idle") == "death": return false
	var ids := selection(data, unit)
	var weapon: String = WEAPONS.get(unit.get("visual_loadout", {}).get("weapon", "weapon_guard_sword"), "")
	var action_id: String = unit.get("visual_actions", {}).get(pose.get("action", "idle"), unit.get("visual_action", weapon) if pose.get("action", "idle") in ["attack", "slash", "shield_bash"] else "")
	var action: Dictionary = data.actions.get(action_id, {})
	var time := float(pose.get("progress", 0)) * float(action.get("duration", 1))
	var adaptation: String = unit.get("visual_adaptation", "")
	var errors := Visuals.draw(canvas, data, ids, origin, zoom, cached_directory, adaptation, action, time)
	if not errors.is_empty(): push_warning("; ".join(errors)); return false
	draw_arrow(canvas, data, ids, origin, zoom, cached_directory, adaptation, action, time, str(pose.get("outcome", "hit")))
	return true

static func draw_arrow(canvas: CanvasItem, data: Dictionary, ids: Array, origin: Vector2, zoom: float, directory: String, adaptation: String, action: Dictionary, time: float, outcome: String = "hit") -> void:
	if "bow" not in ids or not data.assets.has("arrow"): return
	var arrow := arrow_pose(data, adaptation, action, time, outcome)
	if not arrow.get("visible", true): return
	var copy := data.duplicate(true)
	var local_position: Vector2 = arrow.position
	copy.assets.arrow.position = [local_position.x, local_position.y]
	copy.assets.arrow.rotation = rad_to_deg(arrow.angle)
	copy.assets.arrow.parent = ""
	Visuals.draw(canvas, copy, ["arrow"], origin, zoom, directory, adaptation, {}, 0, {}, true)

static func arrow_pose(data: Dictionary, adaptation: String, action: Dictionary, time: float, outcome: String = "hit") -> Dictionary:
	# Flight and its preview target share the assembly frame; draw applies placement once.
	var duration := float(action.get("duration", 1.48))
	var progress := time / duration
	var legacy: Dictionary = action.get("legacy_action", Motion.default_action("bow"))
	# Event timings are authored in the common timeline; projectile stays presentation-only.
	legacy = legacy.duplicate(true)
	for event: Dictionary in action.get("events", []):
		if event.id in ["release", "contact"]: legacy[event.id] = float(event.time) / duration
	var transform := Visuals.world_transform(data, "bow", adaptation, action, minf(time, float(legacy.release) * duration))
	var angle := transform.get_rotation()
	var launch := {"position": transform.origin - Visuals.placement(data) + Vector2(10, -2).rotated(angle), "angle": angle + PI / 2}
	var arrow: Dictionary = launch
	if progress >= float(legacy.release): arrow = Motion.arrow_sample(progress, outcome, launch, legacy)
	return arrow
