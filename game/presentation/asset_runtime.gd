extends RefCounted
## Game-owned asset selection. Editor scenes, eyes and locks are never consumed.
const Document = preload("res://presentation/asset_document.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Motion = preload("res://presentation/static_bust_motion.gd")
const Appearance = preload("res://core/appearance_rules.gd")
const WeaponFeedback = preload("res://presentation/weapon_feedback.gd")
const WEAPONS := {"weapon_guard_sword": "sword", "weapon_guard_cleaver": "sword", "weapon_spear_long": "spear", "weapon_spear_hooked": "spear", "weapon_archer_bow": "bow", "weapon_archer_longbow": "bow", "weapon_hunter_bow": "bow", "weapon_hunter_recurve": "bow", "weapon_skirmisher_blade": "sword", "weapon_skirmisher_axe": "sword"}
const ARMORS := {"armor_padded": "padded", "armor_leather": "padded", "armor_brigandine": "mail", "armor_mail": "mail"}
static var cached_revision := "!"
static var cached_data: Dictionary = {}
static var cached_directory := ""
static var identity_cache: Dictionary = {}
static var cached_frame := -1
static var cached_publication := -1
static var cached_override := "!"

static func current() -> Dictionary:
	var frame := Engine.get_process_frames()
	if frame == cached_frame and cached_publication == Document.publication_serial and cached_override == Document.storage_override:
		return cached_data
	cached_frame = frame
	cached_publication = Document.publication_serial
	cached_override = Document.storage_override
	var directory := Document.runtime_dir()
	var pointer := Document.read_json(directory.path_join("current.json"))
	if pointer.is_empty():
		directory = "res://assets/art/paperdoll"
		pointer = Document.read_json(directory.path_join("current.json"))
	var revision: String = pointer.get("revision", "")
	if revision != cached_revision or directory != cached_directory:
		identity_cache.clear()
		cached_revision = revision; cached_directory = directory
		cached_data = {} if revision.is_empty() else Document.read_json(directory.path_join(revision + ".json"))
	return cached_data

static func supports(unit: Dictionary) -> bool:
	return str(unit.get("kind", "")) != "dog" and unit.has("appearance") and current().get("assets", {}).has("body_01")

static func data_for_unit(unit: Dictionary) -> Dictionary:
	var source := current()
	if not supports(unit) or unit.has("visual_assets"):
		return source
	var key := JSON.stringify([unit.get("appearance", {}), unit.get("visual_loadout", {}), unit.get("visual_adaptation", "")])
	if identity_cache.has(key): return identity_cache[key]
	var data := source.duplicate(true)
	data._render_cache_key = cached_revision + key
	var variants: Dictionary = unit.appearance.duplicate(true)
	var gear: Dictionary = unit.get("visual_loadout", {})
	variants.merge(Appearance.ARMOR_ASSETS.get(gear.get("armor", ""), {}), true)
	var weapon_id := str(gear.get("weapon", ""))
	var weapon_slot: String = WEAPONS.get(weapon_id, "")
	if not weapon_slot.is_empty(): variants[weapon_slot] = Appearance.WEAPON_ASSETS.get(weapon_id, "")
	var adaptation := str(unit.get("visual_adaptation", ""))
	for slot: String in variants:
		var variant_id := str(variants[slot])
		if not data.assets.has(variant_id): continue
		var canonical := "mail" if slot == "outer" else ("skin" if slot == "body" else slot)
		var definition := Visuals.resolve(source, variant_id, adaptation)
		definition.id = canonical
		data.assets[canonical] = definition
		if canonical in ["padded", "mail"] and data.assets.has(variant_id + "_damaged"):
			var damaged := Visuals.resolve(source, variant_id + "_damaged", adaptation)
			damaged.id = canonical + "_damaged"
			data.assets[canonical + "_damaged"] = damaged
		# Variant-specific calibration has already been resolved above.
		if data.adaptations.get(adaptation, {}).has(canonical):
			data.adaptations[adaptation].erase(canonical)
	# Batch editor compositions attach to real variant IDs. At runtime those
	# functional slots refer to this character's selected identity, never to a
	# hidden body/face left over from the editor's last random composition.
	for id: String in ["skin", "face", "hair", "beard", "linen", "padded", "padded_damaged", "mail", "mail_damaged", "shield", "sword", "spear", "bow", "scar", "bandage", "blood"]:
		if not data.assets.has(id): continue
		for field: String in ["parent", "clip_to"]:
			data.assets[id][field] = _canonical_reference(source, str(data.assets[id].get(field, "")))
	for mask: Dictionary in data.get("masks", {}).values():
		if mask.has("follow"): mask.follow = _canonical_reference(source, str(mask.follow))
	data.game.appearance = {"head": "modular", "skin": true, "hair": true, "beard": bool(variants.get("has_beard", false))}
	identity_cache[key] = data
	return data

static func _canonical_reference(source: Dictionary, reference: String) -> String:
	if not source.assets.has(reference): return reference
	var slot := Document.functional_slot(reference, source.assets[reference])
	return {"outer": "mail", "outer_damaged": "mail_damaged", "axe": "sword"}.get(slot, slot)

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
	if armor == "mail" or (unit.has("appearance") and data.assets.has("outer_01") and gear.get("armor", "") == "armor_leather"):
		result.append("mail_damaged" if damaged else "mail")
	if appearance.get("head", "legacy") == "modular":
		result.append("face")
		for id: String in ["hair", "beard", "bandage", "blood", "scar"]:
			if appearance.get(id, false) or (id == "blood" and wounded) or (id == "bandage" and not unit.get("injury", {}).is_empty()) or (id == "scar" and not unit.get("permanent_injuries", []).is_empty()): result.append(id)
	else:
		result.append("wounded" if wounded else "head")
		for id: String in ["bandage", "blood", "scar"]:
			if appearance.get(id, false): result.append(id)
	if not weapon.is_empty(): result.append(weapon)
	if weapon == "sword" and (not data.assets.has("body_01") or str(gear.get("weapon", "")) in ["weapon_guard_sword", "weapon_guard_cleaver"]): result.append("shield")
	return result

static func draw_asset(canvas: CanvasItem, asset_id: String, origin: Vector2, zoom: float = 1, adaptation: String = "", action_id: String = "", time: float = 0, anchors: Dictionary = {}, root_mode: bool = true) -> Array:
	var data := current()
	if data.is_empty(): return ["没有已应用的资产版本"]
	return Visuals.draw(canvas, data, [asset_id], origin, zoom, cached_directory, adaptation, data.actions.get(action_id, {}), time, anchors, root_mode)

static func action_for_unit(unit: Dictionary, kind: String) -> Dictionary:
	var data := current()
	var weapon_id := str(unit.get("visual_loadout", {}).get("weapon", "weapon_guard_sword"))
	var weapon: String = WEAPONS.get(weapon_id, "")
	if supports(unit) and kind == "defend" and weapon_id in ["weapon_guard_sword", "weapon_guard_cleaver"]:
		return data.actions.get("defend_shield", WeaponFeedback.defend_action())
	var id: String = unit.get("visual_actions", {}).get(kind, unit.get("visual_action", weapon) if kind in ["attack", "slash", "shield_bash"] else "")
	if supports(unit) and kind in ["attack", "slash", "shield_bash"] and not unit.has("visual_action") and not unit.get("visual_actions", {}).has(kind):
		var authored_id := ("shield_bash_" if kind == "shield_bash" else "attack_") + weapon_id
		if data.actions.has(authored_id): return _selected_action(data.actions[authored_id], weapon_id, weapon)
		return WeaponFeedback.authored_action(data.actions.get(weapon, {}), weapon_id, kind)
	return data.get("actions", {}).get(id, {})

static func _selected_action(source: Dictionary, weapon_id: String, slot: String) -> Dictionary:
	var action := source.duplicate(true)
	var variant := str(Appearance.WEAPON_ASSETS.get(weapon_id, ""))
	for track: Dictionary in action.get("tracks", []):
		if str(track.target) == variant: track.target = slot
	return action

static func draw_unit(canvas: CanvasItem, unit: Dictionary, origin: Vector2, zoom: float, pose: Dictionary) -> bool:
	var data := data_for_unit(unit)
	if data.is_empty(): return false
	if int(unit.get("hp", 1)) <= 0 or pose.get("action", "idle") == "death":
		if supports(unit): return _draw_terminal(canvas, data, unit, origin, zoom, pose)
		return false
	var ids := selection(data, unit)
	var action: Dictionary = action_for_unit(unit, str(pose.get("action", "idle")))
	var time := float(pose.get("progress", 0)) * float(action.get("duration", 1))
	var adaptation: String = unit.get("visual_adaptation", "")
	var facing := facing_for(unit, pose)
	var frame := Transform2D(0.0, Vector2(facing, 1.0), 0.0, Vector2.ZERO)
	var errors := Visuals.draw(canvas, data, ids, origin, zoom, cached_directory, adaptation, action, time, {}, false, 1.0, frame)
	if not errors.is_empty(): push_warning("; ".join(errors)); return false
	if pose.has("target_position") and "bow" in ids:
		var target: Vector2 = (pose.target_position - origin) / zoom
		draw_battle_arrow(canvas, data, origin, zoom, adaptation, action, time, target, facing, str(pose.get("outcome", "hit")))
	else:
		draw_arrow(canvas, data, ids, origin, zoom, cached_directory, adaptation, action, time, str(pose.get("outcome", "hit")), frame)
	return true

static func facing_for(unit: Dictionary, pose: Dictionary) -> float:
	if pose.get("action", "idle") in ["attack", "slash", "shield_bash"]:
		var direction: Vector2 = pose.get("direction", Vector2.ZERO)
		if absf(direction.x) > 0.001: return -1.0 if direction.x < 0 else 1.0
	return -1.0 if unit.get("team", "player") == "enemy" else 1.0

static func impact_offset(unit: Dictionary) -> Vector2:
	if unit.get("kind", "") == "dog": return Vector2(0, -16)
	if supports(unit):
		var data := data_for_unit(unit)
		var ids := selection(data, unit)
		var adaptation := str(unit.get("visual_adaptation", ""))
		for id: String in ["mail_damaged", "mail", "padded_damaged", "padded", "skin"]:
			if id not in ids: continue
			var asset := Visuals.resolve(data, id, adaptation)
			var center := (Vector2(0.5, 0.5) - Visuals.vector(asset.pivot)) * Visuals.vector(asset.size)
			return (Visuals.world_transform(data, id, adaptation) * center) * Vector2(facing_for(unit, {}), 1)
	return Vector2(0, -38)

static func _draw_terminal(canvas: CanvasItem, data: Dictionary, unit: Dictionary, origin: Vector2, zoom: float, pose: Dictionary) -> bool:
	# A fallen unit retains its actual face, clothes and weapon. Final tuning is
	# stored in the same published game data as the other assembly settings.
	var down := bool(unit.get("incapacitated", false)) and str(unit.get("casualty_status", "pending")) != "dead"
	var key := "incapacitated" if down else "dead"
	var setting: Dictionary = data.get("game", {}).get("terminal", {}).get(key, {})
	var progress := float(pose.get("progress", 1.0)) if pose.get("action", "") == "death" else 1.0
	var amount := smoothstep(0.0, 0.8, progress)
	var angle := deg_to_rad(float(setting.get("rotation", 72 if down else 86))) * amount
	var offset := Visuals.vector(setting.get("offset", [-15, -3])) * amount
	var scale := Vector2.ONE.lerp(Visuals.vector(setting.get("scale", [0.8, 0.55])), amount)
	var facing := Transform2D(0.0, Vector2(facing_for(unit, pose), 1), 0.0, Vector2.ZERO)
	var transform := facing * Transform2D(angle, scale, 0.0, offset)
	var ids := selection(data, unit)
	ids.erase("base")
	var adaptation := str(unit.get("visual_adaptation", ""))
	var overlay := "state_down" if down else "state_dead"
	var ground: Array = ["base"]
	if data.assets.has(overlay): ground.append(overlay)
	Visuals.draw(canvas, data, ground, origin, zoom, cached_directory, adaptation)
	var errors := Visuals.draw(canvas, data, ids, origin, zoom, cached_directory, adaptation, {}, 0, {}, false, 1.0, transform)
	return errors.is_empty()

static func draw_arrow(canvas: CanvasItem, data: Dictionary, ids: Array, origin: Vector2, zoom: float, directory: String, adaptation: String, action: Dictionary, time: float, outcome: String = "hit", frame: Transform2D = Transform2D.IDENTITY) -> void:
	if "bow" not in ids or not data.assets.has("arrow"): return
	var arrow := arrow_pose(data, adaptation, action, time, outcome)
	if not arrow.get("visible", true): return
	var copy := data.duplicate()
	copy.assets = data.assets.duplicate()
	copy.assets.arrow = data.assets.arrow.duplicate(true)
	copy.erase("_render_cache_key")
	var local_position: Vector2 = arrow.position
	copy.assets.arrow.position = [local_position.x, local_position.y]
	copy.assets.arrow.rotation = rad_to_deg(arrow.angle)
	copy.assets.arrow.parent = ""
	Visuals.draw(canvas, copy, ["arrow"], origin, zoom, directory, adaptation, {}, 0, {}, true, 1.0, frame)

static func battle_arrow_pose(data: Dictionary, adaptation: String, action: Dictionary, time: float, target: Vector2, facing: float, outcome: String = "hit") -> Dictionary:
	if outcome == "miss": target += Vector2(18 * facing, 8)
	var release := float(action.get("duration", 1.48)) * 0.4
	var contact := float(action.get("duration", 1.48)) * 0.72
	for marker: Dictionary in action.get("events", []):
		if marker.id == "release": release = float(marker.time)
		if marker.id == "contact": contact = float(marker.time)
	var launch := arrow_pose(data, adaptation, action, minf(time, maxf(0, release - 0.0001)))
	var start: Vector2 = (launch.position + Visuals.placement(data)) * Vector2(facing, 1)
	if time < release:
		var direction := Vector2.UP.rotated(float(launch.angle)) * Vector2(facing, 1)
		return {"position": start, "angle": direction.angle() + PI / 2, "visible": true}
	var t := clampf((time - release) / maxf(0.001, contact - release), 0, 1)
	var arc := minf(24, start.distance_to(target) * 0.12)
	var position := start.lerp(target, t) + Vector2(0, -4 * arc * t * (1 - t))
	var tangent := target - start + Vector2(0, -4 * arc * (1 - 2 * t))
	return {"position": position, "angle": tangent.angle() + PI / 2, "visible": time <= contact + 0.06}

static func draw_battle_arrow(canvas: CanvasItem, data: Dictionary, origin: Vector2, zoom: float, adaptation: String, action: Dictionary, time: float, target: Vector2, facing: float, outcome: String = "hit") -> void:
	if not data.assets.has("arrow"): return
	var arrow := battle_arrow_pose(data, adaptation, action, time, target, facing, outcome)
	if not arrow.visible: return
	var copy := {"assets": {"arrow": Visuals.resolve(data, "arrow", adaptation)}, "game": {"placement": [0, 0]}, "adaptations": {}, "masks": {}}
	copy.assets.arrow.position = [arrow.position.x, arrow.position.y]
	copy.assets.arrow.rotation = rad_to_deg(float(arrow.angle))
	copy.assets.arrow.parent = ""
	Visuals.draw(canvas, copy, ["arrow"], origin, zoom, cached_directory, "", {}, 0, {}, true)

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
