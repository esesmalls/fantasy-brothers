extends RefCounted
## A read-only, single-body-template cutout rig. Atlas rectangles and anchors are data.
## All coordinates below are board logical pixels, relative to the ground origin.

const CATALOG_PATH := "res://assets/art/motion/catalog.json"
static var _catalog: Dictionary = {}
static var _textures: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty() and FileAccess.file_exists(CATALOG_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if parsed is Dictionary:
			_catalog = parsed
	return _catalog

static func template_info(template_id: String) -> Dictionary:
	return catalog().get("templates", {}).get(template_id, {})

static func supports(unit: Dictionary) -> bool:
	if str(unit.get("kind", "")) == "dog":
		return false
	if str(unit.get("id", "")) not in catalog().get("sample_unit_ids", ["crew_1"]) and not bool(unit.get("presentation_sample", false)):
		return false
	var gear: Dictionary = unit.get("visual_loadout", {})
	return catalog().get("weapon_parts", {}).has(str(gear.get("weapon", ""))) and str(gear.get("armor", "")) in catalog().get("compatible_armor_ids", [])

static func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		if not ResourceLoader.exists(path):
			return null
		_textures[path] = load(path)
	return _textures[path]

static func draw_actor(canvas: CanvasItem, unit: Dictionary, origin: Vector2, scale: float = 1.0, pose: Dictionary = {}) -> bool:
	if not supports(unit):
		return false
	var template_id := str(pose.get("template", "b"))
	var info := template_info(template_id)
	if info.is_empty():
		return false
	var texture := _texture(str(info.get("atlas", "")))
	if texture == null:
		return false
	var action := str(pose.get("action", "idle"))
	var progress := clampf(float(pose.get("progress", 0.0)), 0.0, 1.0)
	var armor := str(unit.get("visual_loadout", {}).get("armor", "armor_mail"))
	if action == "death" or int(unit.get("hp", 1)) <= 0:
		if action == "death" and progress < 0.28:
			var display_copy := unit.duplicate(true)
			display_copy["hp"] = 1
			var recoil_pose := pose.duplicate(true)
			recoil_pose["action"] = "hit"
			recoil_pose["progress"] = progress / 0.28
			return draw_actor(canvas, display_copy, origin, scale, recoil_pose)
		var terminal: Dictionary = catalog().get("terminal", {})
		var terminal_texture := _texture(str(terminal.get("atlas", "")))
		if terminal_texture == null:
			return false
		var terminal_part: Dictionary = terminal.get("parts", {}).get(armor, {})
		if terminal_part.is_empty():
			return false
		_draw_part(canvas, terminal_texture, terminal_part, origin, scale, Vector2.ZERO, 0.0)
		return true
	var parts: Dictionary = info.get("parts", {})
	return _draw_connected_rig(canvas, unit, texture, parts, info, origin, scale, pose)

static func _draw_connected_rig(canvas: CanvasItem, unit: Dictionary, texture: Texture2D, parts: Dictionary, info: Dictionary, origin: Vector2, scale: float, pose: Dictionary) -> bool:
	var action := str(pose.get("action", "idle"))
	var p := clampf(float(pose.get("progress", 0)), 0, 1)
	var clock := float(pose.get("clock", 0))
	var settings: Dictionary = info.get("motion", {})
	var amplitude := float(settings.get("amplitude", 1))
	var contact := float(settings.get("contact", 0.5))
	var wind_end := contact - float(settings.get("strike_span", 0.13))
	var wind := 0.0
	var drive := 0.0
	if p < wind_end:
		wind = smoothstep(0, wind_end, p)
	elif p < contact:
		drive = smoothstep(wind_end, contact, p)
		wind = 1.0 - drive
	elif p < contact + float(settings.get("hold", 0.07)):
		drive = 1.0
	else:
		drive = 1.0 - smoothstep(contact + float(settings.get("hold", 0.07)), 1, p)
	var body_angle := 0.0
	var right_angle := 0.0
	var left_angle := 0.0
	var head_angle := sin(clock * 1.8) * float(settings.get("breathing", .3)) * .02
	# This reviewed family has one right-facing arm pose. The board retains the
	# complete target direction for its approach and impact; reverse poses require
	# dedicated artwork instead of mirroring the identity or detaching the wrist.
	if action == "slash":
		body_angle = (-0.025 * wind + 0.045 * drive) * amplitude
		right_angle = (-0.32 * wind + 1.05 * drive) * amplitude
		head_angle = -body_angle * 0.45
	elif action == "shield_bash":
		body_angle = (-0.03 * wind + 0.065 * drive) * amplitude
		left_angle = (0.14 * wind - 0.72 * drive) * amplitude
		right_angle = -0.09 * drive
	elif action == "defend":
		body_angle = -0.02
		left_angle = 0.30
		right_angle = -0.10
	elif action == "hit":
		body_angle = -sin(p * PI) * 0.07 * amplitude
		head_angle = -body_angle * 0.30
		right_angle = sin(p * PI) * 0.08
	elif action == "move":
		body_angle = sin(p * TAU) * 0.015 * amplitude
		right_angle = sin(p * PI) * 0.05
	var anchors: Dictionary = info.get("anchors", {})
	var waist := _vector(anchors.get("waist", [0, -3]))
	var neck := waist + (_vector(anchors.get("neck", [0, -35])) - waist).rotated(body_angle)
	var right_shoulder := waist + (_vector(anchors.get("right_shoulder", [16, -31])) - waist).rotated(body_angle)
	var left_shoulder := waist + (_vector(anchors.get("left_shoulder", [-16, -31])) - waist).rotated(body_angle)
	var right_total := right_angle + body_angle
	var left_total := left_angle + body_angle
	var right_grip := right_shoulder + _grip_vector(parts.get("right_arm", {})).rotated(right_total)
	var left_grip := left_shoulder + _grip_vector(parts.get("left_arm", {})).rotated(left_total)
	var sword_angle := float(anchors.get("sword_angle", 0.4)) + right_total
	var shield_angle := float(anchors.get("shield_angle", -0.06)) + left_total * 0.35
	# The waist remains planted. Shoulder, neck and held-object transforms descend
	# from it; no detached forearm or arbitrary hand translation is used here.
	_draw_part(canvas, texture, parts.get("base", {}), origin, scale, Vector2.ZERO, 0)
	var armor := str(unit.get("visual_loadout", {}).get("armor", "armor_mail"))
	_draw_part(canvas, texture, parts.get(armor, {}), origin, scale, waist, body_angle)
	var injured := int(unit.get("hp", 1)) < float(unit.get("max_hp", 1)) * 0.38
	var expression := "head_hit" if injured or (action == "hit" and p < 0.8) else "head"
	# The short neck goes behind the front collar, never on top of its rim.
	_draw_part(canvas, texture, parts.get(expression, parts.get("head", {})), origin, scale, neck, body_angle + head_angle)
	_draw_lower_slice(canvas, texture, parts.get(armor, {}), origin, scale, waist, body_angle, float(anchors.get("collar_front_fraction", 0.25)))
	_draw_base_front(canvas, texture, parts.get("base", {}), origin, scale, float(anchors.get("base_front_fraction", 0.60)))
	var weapon_key := str(catalog().get("weapon_parts", {}).get(str(unit.get("visual_loadout", {}).get("weapon", "")), "sword"))
	_draw_part(canvas, texture, parts.get("left_arm", {}), origin, scale, left_shoulder, left_total)
	_draw_part(canvas, texture, parts.get("right_arm", {}), origin, scale, right_shoulder, right_total)
	_draw_part(canvas, texture, parts.get(weapon_key, {}), origin, scale, right_grip, sword_angle)
	var hand_region: Array = parts.get("right_arm", {}).get("hand_region", [0, 0.7, 0.43, 0.3])
	_draw_region(canvas, texture, parts.get("right_arm", {}), origin, scale, right_shoulder, right_total, Rect2(float(hand_region[0]), float(hand_region[1]), float(hand_region[2]), float(hand_region[3])))
	_draw_part(canvas, texture, parts.get("shield", {}), origin, scale, left_grip, shield_angle)
	if bool(pose.get("show_anchors", false)):
		for point: Vector2 in [waist, neck, left_shoulder, right_shoulder, left_grip, right_grip]:
			canvas.draw_circle(origin + point * scale, maxf(1.0, scale * 0.6), Color("f4c665"))
	return true

static func _draw_base_front(canvas: CanvasItem, texture: Texture2D, base: Dictionary, origin: Vector2, scale: float, fraction: float) -> void:
	# Redraw only the lower rim over the waist to seat the bust inside its base.
	# This uses the original texture's UVs, with no raster editing or new asset.
	_draw_lower_slice(canvas, texture, base, origin, scale, Vector2.ZERO, 0, fraction)

static func _draw_lower_slice(canvas: CanvasItem, texture: Texture2D, part: Dictionary, origin: Vector2, scale: float, offset: Vector2, angle: float, fraction: float) -> void:
	var cut := clampf(fraction, 0.1, 0.95)
	_draw_region(canvas, texture, part, origin, scale, offset, angle, Rect2(0, cut, 1, 1 - cut))

static func _draw_region(canvas: CanvasItem, texture: Texture2D, part: Dictionary, origin: Vector2, scale: float, offset: Vector2, angle: float, region: Rect2) -> void:
	if part.is_empty():
		return
	var front := part.duplicate(true)
	var source: Array = front.rect
	var size_value := _vector(front.size)
	var pivot := _vector(front.pivot)
	front.rect = [float(source[0]) + float(source[2]) * region.position.x, float(source[1]) + float(source[3]) * region.position.y, float(source[2]) * region.size.x, float(source[3]) * region.size.y]
	front.size = [size_value.x * region.size.x, size_value.y * region.size.y]
	front.pivot = [(pivot.x - region.position.x) / region.size.x, (pivot.y - region.position.y) / region.size.y]
	_draw_part(canvas, texture, front, origin, scale, offset, angle)

static func _vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func _grip_vector(part: Dictionary) -> Vector2:
	return (_vector(part.get("grip", [0.5, 0.5])) - _vector(part.get("pivot", [0.5, 0.5]))) * _vector(part.get("size", [1, 1]))

static func _draw_part(canvas: CanvasItem, texture: Texture2D, part: Dictionary, origin: Vector2, scale: float, offset: Vector2, angle: float) -> void:
	if part.is_empty():
		return
	var source: Array = part.get("rect", [0, 0, 1, 1])
	var dimensions: Array = part.get("size", [1, 1])
	var anchor: Array = part.get("pivot", [0.5, 0.5])
	var position: Array = part.get("position", [0, 0])
	var width := float(dimensions[0])
	var height := float(dimensions[1])
	var pivot := Vector2(float(anchor[0]) * width, float(anchor[1]) * height)
	var local_position := Vector2(float(position[0]), float(position[1]))
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO, Vector2(width, 0), Vector2(width, height), Vector2(0, height)]:
		points.append(origin + ((corner - pivot).rotated(angle) + local_position + offset) * scale)
	var tex_size := texture.get_size()
	var uv_origin := Vector2(float(source[0]), float(source[1])) / tex_size
	var uv_size := Vector2(float(source[2]), float(source[3])) / tex_size
	var uvs := PackedVector2Array([uv_origin, uv_origin + Vector2(uv_size.x, 0), uv_origin + uv_size, uv_origin + Vector2(0, uv_size.y)])
	canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uvs, texture)
