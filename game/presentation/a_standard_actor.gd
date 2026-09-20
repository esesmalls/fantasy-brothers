extends RefCounted
## A production family, built from lossless atlases and explicit anchors.
## The input unit and pose are read-only. Equipment and damage select real assets.

const Original = preload("res://presentation/modular_actor.gd")
const Hands = preload("res://presentation/hand_style_actor.gd")
const Motion = preload("res://presentation/a_standard_motion.gd")
const CATALOG_PATH := "res://assets/art/a-standard/catalog.json"
static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty() and FileAccess.file_exists(CATALOG_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if parsed is Dictionary:
			_catalog = parsed
	return _catalog

static func weapon_id(unit: Dictionary) -> String:
	var fallback := {"guard":"weapon_guard_sword", "spear":"weapon_spear_long", "archer":"weapon_archer_bow", "skirmisher":"weapon_skirmisher_blade", "hunter":"weapon_hunter_bow", "raider":"weapon_skirmisher_axe"}
	var result := str(unit.get("visual_loadout", {}).get("weapon", ""))
	return result if not result.is_empty() else str(fallback.get(str(unit.get("kind", "guard")), "weapon_guard_sword"))

static func armor_id(unit: Dictionary) -> String:
	var fallback := {"guard":"armor_mail", "spear":"armor_brigandine", "archer":"armor_padded", "skirmisher":"armor_leather", "hunter":"armor_leather", "raider":"armor_leather"}
	var result := str(unit.get("visual_loadout", {}).get("armor", ""))
	return result if not result.is_empty() else str(fallback.get(str(unit.get("kind", "guard")), "armor_padded"))

static func identity(unit: Dictionary) -> int:
	if unit.has("visual_identity"):
		return clampi(int(unit.visual_identity), 0, 11)
	# Version 1 never changes its modulo or order when later identities are added.
	var id := str(unit.get("id", ""))
	if id.begins_with("enemy_"):
		return 8 + posmod(int(id.trim_prefix("enemy_")), 4)
	if id.begins_with("crew_"):
		return posmod(int(id.trim_prefix("crew_")) - 1, 8)
	var value := 17
	for code in (id + str(unit.get("name", ""))).to_utf32_buffer():
		value = posmod(value * 31 + int(code), 2147483647)
	return posmod(value, 8)

static func damage_stage(unit: Dictionary) -> int:
	var ratio := float(unit.get("armor", 0)) / maxf(1.0, float(unit.get("max_armor", 1)))
	return 3 if ratio <= 0 else (2 if ratio < 0.30 else (1 if ratio < 0.67 else 0))

static func supports(unit: Dictionary) -> bool:
	if str(unit.get("kind", "")) == "dog":
		return catalog().has("dog")
	return catalog().get("weapons", {}).has(weapon_id(unit)) and catalog().get("armors", {}).has(armor_id(unit))

static func _draw(canvas: CanvasItem, entry: Dictionary, origin: Vector2, scale: float, position: Vector2, angle: float = 0.0) -> void:
	if entry.is_empty():
		return
	var texture := Original._texture(str(entry.get("atlas", "")))
	if texture != null:
		Original._draw_part(canvas, texture, entry, origin, scale, position, angle)

static func _skin(unit: Dictionary) -> Color:
	return [Color.WHITE,Color(.92,.86,.80),Color(1,.98,.97),Color(.77,.68,.60),Color(.93,.86,.77),Color.WHITE,Color(.94,.88,.82),Color(1,.96,.94),Color(.95,.88,.80),Color(.91,.84,.76),Color(1,.97,.94),Color(.62,.53,.46)][identity(unit)]

static func _draw_arm(canvas: CanvasItem, unit: Dictionary, entry: Dictionary, origin: Vector2, scale: float, position: Vector2, angle: float = 0.0) -> void:
	_draw(canvas, entry, origin, scale, position, angle)
	var tinted := entry.duplicate(true)
	tinted.modulate = _skin(unit)
	Original._draw_region(canvas, Original._texture(str(entry.atlas)), tinted, origin, scale, position, angle, Rect2(.78,0,.22,1))

static func rig(unit: Dictionary, pose: Dictionary) -> Dictionary:
	var action := str(pose.get("action", "idle"))
	var p := clampf(float(pose.get("progress", 0)), 0, 1)
	var weapon := weapon_id(unit)
	var motion := Motion.sample(weapon, action, p, str(pose.get("outcome", "hit")))
	var wind := float(motion.wind)
	var drive := float(motion.drive)
	var body_angle := 0.105 - 0.055 * wind + 0.048 * drive
	if action == "hit":
		body_angle -= sin(p * PI) * 0.085
	elif action == "move":
		body_angle += sin(p * TAU) * 0.016
	var waist := Vector2(0, 1.5)
	var neck := waist + Vector2(3.5, -32.0).rotated(body_angle)
	var shoulder := waist + Vector2(-16.0, -28.0).rotated(body_angle)
	var index := 0
	if wind > 0.45:
		index = 1
	elif drive > 0.28:
		index = 2
	var arm := Hands.arm_info(index)
	var arm_angle := body_angle - 0.32 * wind - 0.06 * drive
	var grip := shoulder + (arm.grip_offset as Vector2).rotated(arm_angle)
	var kind := str(motion.time.family)
	var angle := 0.88 - 2.0 * wind + 0.70 * drive
	angle -= float(motion.resistance) * 0.035 + float(motion.recoil)
	if kind in ["spear", "hook"]:
		angle = PI * 0.5
		grip = Vector2(-14 - 2 * wind + 5 * drive, -25) + Original._vector(catalog().arms.spear_rear.grip).rotated(-0.48)
	elif Motion.is_bow(kind):
		angle = 0.0
		grip = Vector2(26.46, -20.93)
	var shield_position := Vector2(23, -17) + Vector2(8.0 * drive, -1.0 * drive) if action in ["shield_bash", "push"] else Vector2(23 - 2.5 * wind, -17 - 2.0 * wind)
	if action == "defend":
		shield_position += Vector2(-2,-4) * sin(p * PI)
	if action in ["shield_bash", "push", "defend"]:
		angle = .7
	return {"motion":motion, "waist":waist, "neck":neck, "shoulder":shoulder,
		"body_angle":body_angle, "arm":arm, "arm_angle":arm_angle, "grip":grip,
		"weapon_angle":angle, "shield":shield_position, "action":action, "progress":p,
		"kind":kind, "front":bool(motion.weapon_front)}

static func draw_actor(canvas: CanvasItem, unit: Dictionary, origin: Vector2, scale: float = 1.0, pose: Dictionary = {}) -> bool:
	if not supports(unit):
		return false
	if str(unit.get("kind", "")) == "dog":
		return _draw_dog(canvas, unit, origin, scale, pose)
	var action := str(pose.get("action", "idle"))
	if int(unit.get("hp", 1)) <= 0 or action in ["death", "downed"]:
		return _draw_terminal(canvas, unit, origin, scale, pose)
	var data := rig(unit, pose)
	var original_parts: Dictionary = Original.template_info("b").get("parts", {})
	var base: Dictionary = original_parts.base.duplicate(true)
	base["size"] = [43,8]
	base["atlas"] = "res://assets/art/motion/b-atlas-v2.png"
	_draw(canvas, base, origin, scale, Vector2.ZERO)
	var layer_limit := int(pose.get("layer_limit", 4))
	_draw(canvas, catalog().linen, origin, scale, data.waist, data.body_angle)
	if layer_limit >= 1 and armor_id(unit) != "armor_padded":
		_draw(canvas, catalog().underlayer, origin, scale, data.waist, data.body_angle)
	var body: Dictionary = catalog().armors[armor_id(unit)][damage_stage(unit)]
	if layer_limit >= 2:
		_draw(canvas, body, origin, scale, data.waist, data.body_angle)
	var arm: Dictionary = data.arm.duplicate(true)
	arm["atlas"] = Hands.PARTS_PATH
	if not Motion.is_bow(str(data.kind)) and not str(data.kind) in ["spear", "hook"]:
		if action not in ["command", "mark"]:
			_draw(canvas, arm, origin, scale, data.shoulder, data.arm_angle)
	var head_state := 0
	if float(unit.get("hp", 1)) / maxf(1, float(unit.get("max_hp", 1))) < 0.50:
		head_state = 2
	elif action == "hit" or float(data.motion.drive) > 0.40:
		head_state = 1
	var head: Dictionary = catalog().faces[identity(unit)][head_state]
	_draw(canvas, head, origin, scale, data.neck, float(data.body_angle) * 0.22)
	# Original source UV regions are separate draw layers: the front collar closes
	# over the neck, shoulder cap over the sleeve, and belt over the outer cuirass.
	if layer_limit >= 3:
		var trim: Dictionary = catalog().trim[armor_id(unit)]
		var trim_texture := Original._texture(str(trim.atlas))
		Original._draw_region(canvas, trim_texture, trim, origin, scale, data.waist, data.body_angle, Rect2(0.25,0.02,0.57,0.18))
		Original._draw_region(canvas, trim_texture, trim, origin, scale, data.waist, data.body_angle, Rect2(0.02,0.12,0.36,0.25))
		Original._draw_region(canvas, trim_texture, trim, origin, scale, data.waist, data.body_angle, Rect2(0.16,0.68,0.73,0.20))
	var shield_key := "heavy" if weapon_id(unit) == "weapon_guard_cleaver" else "round"
	if layer_limit >= 4 and weapon_id(unit) in ["weapon_guard_sword", "weapon_guard_cleaver"]:
		var supporting := Hands.arm_info(2 if action in ["shield_bash", "push"] else 0)
		supporting["atlas"] = Hands.PARTS_PATH
		_draw(canvas, supporting, origin, scale * 0.78, Vector2(14,-21) / 0.78, -0.22)
		_draw(canvas, catalog().shields[shield_key], origin, scale, data.shield, -0.04)
	# Body, head and shield are complete before the weapon's foreground pass.
	# In battle this pass is deferred beyond every unit to prevent neighbour cover.
	if layer_limit >= 4 and (not bool(pose.get("defer_weapon", false)) or not bool(data.front)):
		draw_weapon_front(canvas, unit, origin, scale, pose)
	var texture := Original._texture(str(base.atlas))
	Original._draw_base_front(canvas, texture, base, origin, scale, 0.43)
	return true

static func draw_weapon_front(canvas: CanvasItem, unit: Dictionary, origin: Vector2, scale: float, pose: Dictionary) -> void:
	if not supports(unit) or str(unit.get("kind", "")) == "dog" or int(unit.get("hp",1)) <= 0:
		return
	var data := rig(unit, pose)
	if str(data.action) in ["death", "downed"]:
		return
	if str(data.action) in ["command", "mark"]:
		_draw_arm(canvas, unit, catalog().arms.command, origin, scale, Vector2(-13,-26), -.2 * sin(float(data.progress)*PI))
		return
	var weapon: Dictionary = catalog().weapons[weapon_id(unit)]
	_draw(canvas, weapon, origin, scale, data.grip, data.weapon_angle)
	var arm: Dictionary = data.arm
	var hand: Dictionary = arm.hand.duplicate(true)
	hand["atlas"] = Hands.PARTS_PATH
	hand["modulate"] = _skin(unit)
	if not Motion.is_bow(str(data.kind)) and not str(data.kind) in ["spear", "hook"]:
		_draw(canvas, hand, origin, scale, data.shoulder, data.arm_angle)
	else:
		_draw_two_handed(canvas, unit, origin, scale, data)

static func _draw_two_handed(canvas: CanvasItem, unit: Dictionary, origin: Vector2, scale: float, data: Dictionary) -> void:
	var kind := str(data.kind)
	var arms: Dictionary = catalog().get("arms", {})
	if arms.is_empty():
		return
	if Motion.is_bow(kind):
		var timing: Dictionary = data.motion.time
		var t := float(data.motion.seconds)
		var pull := smoothstep(0.0, float(timing.release) - 0.02, t)
		if t >= float(timing.release):
			pull = 1.0 - smoothstep(float(timing.release), float(timing.release) + 0.045, t)
		if not bool(data.front):
			pull = 0.0
		var bow: Dictionary = catalog().weapons[weapon_id(unit)]
		var string_top: Vector2 = data.grip + Original._vector(bow.string_ends[0])
		var string_bottom: Vector2 = data.grip + Original._vector(bow.string_ends[1])
		var pulling: Dictionary = arms.bow_string_full if pull > .72 else (arms.bow_string_half if pull > .30 else arms.bow_string_rest)
		var rear_shoulder := Vector2(-8,-27)
		var pull_angle := -.58 * pull
		var nock: Vector2 = rear_shoulder + Original._vector(pulling.grip).rotated(pull_angle)
		canvas.draw_polyline(PackedVector2Array([origin + string_top * scale, origin + nock * scale, origin + string_bottom * scale]), Color("d5c8a1"), maxf(0.7, scale * 0.42), true)
		_draw_arm(canvas, unit, arms.bow_front, origin, scale, Vector2(11,-27))
		_draw_arm(canvas, unit, pulling, origin, scale, rear_shoulder, pull_angle)
		if t < float(timing.release) and bool(data.front):
			canvas.draw_line(origin + (nock + Vector2(-3,0)) * scale, origin + Vector2(data.grip.x+17,nock.y) * scale, Color("bb9e69"), maxf(.7, scale * .45), true)
	else:
		var rear_position: Vector2 = data.grip - Original._vector(arms.spear_rear.grip).rotated(-.48)
		var front_position: Vector2 = data.grip + Vector2(22,0) - Original._vector(arms.spear_front.grip).rotated(-.48)
		_draw_arm(canvas, unit, arms.spear_rear, origin, scale, rear_position, -.48)
		_draw_arm(canvas, unit, arms.spear_front, origin, scale, front_position, -.48)

static func _draw_terminal(canvas: CanvasItem, unit: Dictionary, origin: Vector2, scale: float, pose: Dictionary) -> bool:
	var parts: Dictionary = catalog().get("terminal", {})
	if not parts.has(armor_id(unit)):
		return false
	var index := 1 if str(pose.get("action", "")) == "downed" else 0
	var body: Dictionary = parts[armor_id(unit)][index].duplicate(true)
	if damage_stage(unit) == 0:
		body.atlas = body.intact_atlas
	elif damage_stage(unit) >= 2 or armor_id(unit)=="armor_padded":
		body.atlas = "res://assets/art/a-standard/terminal-damaged.png"
	var head: Dictionary = catalog().faces[identity(unit)][3]
	var settle := 1.0-smoothstep(0,.65,float(pose.get("progress",1.0)))
	var landed_origin := origin + Vector2(0,-4*settle)*scale
	_draw(canvas, head, landed_origin, scale * 0.72, Original._vector(body.neck) / 0.72, -1.48)
	_draw(canvas, body, landed_origin, scale, Vector2.ZERO)
	if weapon_id(unit) in ["weapon_guard_sword", "weapon_guard_cleaver"]:
		_draw(canvas, catalog().shields["heavy" if weapon_id(unit)=="weapon_guard_cleaver" else "round"], origin, scale*.60,Vector2(24,6)/.60,1.15)
	_draw(canvas, catalog().weapons[weapon_id(unit)], origin, scale * 0.80, Vector2(16,3) / 0.80, 1.32)
	return true

static func _draw_dog(canvas: CanvasItem, unit: Dictionary, origin: Vector2, scale: float, pose: Dictionary) -> bool:
	var dog: Array = catalog().get("dog", [])
	if dog.is_empty():
		return false
	var action := str(pose.get("action", "idle"))
	var p := float(pose.get("progress", 0))
	var index := 0
	if int(unit.get("hp",1)) <= 0 or action == "death":
		index = 5
	elif action == "downed":
		index = 4
	elif float(unit.get("hp",1)) < float(unit.get("max_hp",1)) * 0.5 or action == "hit":
		index = 3
	elif action in ["bite", "attack", "slash"]:
		index = 1 if p < 0.37 else 2
	var offset := Vector2.ZERO
	if action in ["bite", "attack", "slash"]:
		var motion := Motion.sample("", "bite", p, str(pose.get("outcome", "hit")))
		offset.x = float(motion.drive) * 5.0
	_draw(canvas, dog[index], origin, scale, offset)
	return true
