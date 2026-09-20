extends RefCounted
## Isolated comparison renderer: shared face, armor, weapon, shield and base.
## Local arm poses replace perspective changes; combat state is never mutated.

const Original = preload("res://presentation/modular_actor.gd")
const PARTS_PATH := "res://assets/art/motion/hand-style-parts.png"
const BODY_PATH := "res://assets/art/motion/hand-style-body.png"
const ARM_PIXEL_SCALE := 0.043

static func get_timing(_style_id: String, action: String) -> Dictionary:
	return {"duration": 0.62 if action == "shield_bash" else (1.4 if action == "idle" else 0.72), "contact": 0.48, "wind_end": 0.30, "hold_end": 0.56}

static func _part(rect: Rect2, anchor: Vector2, pixel_scale: float) -> Dictionary:
	return {"rect":[rect.position.x, rect.position.y, rect.size.x, rect.size.y], "size":[rect.size.x * pixel_scale, rect.size.y * pixel_scale], "pivot":[(anchor.x - rect.position.x) / rect.size.x, (anchor.y - rect.position.y) / rect.size.y], "position":[0,0]}

static func arm_info(index: int) -> Dictionary:
	var rectangles := [Rect2(45, 115, 580, 435), Rect2(680, 115, 520, 420), Rect2(40, 718, 666, 375)]
	var shoulders := [Vector2(164, 213), Vector2(799, 213), Vector2(160, 811)]
	var grips := [Vector2(549, 451), Vector2(1124, 292), Vector2(640, 944)]
	var part := _part(rectangles[index], shoulders[index], ARM_PIXEL_SCALE)
	part["grip_offset"] = (grips[index] - shoulders[index]) * ARM_PIXEL_SCALE
	# Only the curled fingers are redrawn over the separate sword handle.
	var hand_rectangles := [Rect2(486,380,130,146), Rect2(1050,218,140,165), Rect2(551,875,146,143)]
	part["hand"] = _part(hand_rectangles[index], shoulders[index], ARM_PIXEL_SCALE)
	return part

static func draw_actor(canvas: CanvasItem, style_id: String, unit: Dictionary, origin: Vector2, scale: float = 1.0, pose: Dictionary = {}) -> bool:
	var original_parts: Dictionary = Original.template_info("b").get("parts", {})
	var atlas := Original._texture("res://assets/art/motion/b-atlas-v2.png")
	var additions := Original._texture(PARTS_PATH)
	var body_atlas := Original._texture(BODY_PATH)
	if atlas == null or additions == null or body_atlas == null or original_parts.is_empty():
		return false
	var action := str(pose.get("action", "idle"))
	var p := clampf(float(pose.get("progress", 0.0)), 0.0, 1.0)
	var has_hands := style_id == "a_hand"
	var wind := 0.0
	var drive := 0.0
	if action in ["slash", "shield_bash"]:
		if p < 0.30:
			wind = smoothstep(0.0, 0.30, p)
		elif p < 0.48:
			drive = smoothstep(0.30, 0.48, p)
			wind = 1.0 - drive
		elif p < 0.56:
			drive = 1.0
		else:
			drive = 1.0 - smoothstep(0.56, 1.0, p)
	var hit := sin(p * PI) if action == "hit" else 0.0
	var body_angle := -0.018 * wind + 0.033 * drive - 0.055 * hit
	if not has_hands:
		body_angle *= 0.45
	var waist := Vector2(0, 2.0)
	var base: Dictionary = original_parts.base.duplicate(true)
	base["size"] = [43, 8.0]
	var body: Dictionary = {"rect":[815, 28, 425, 408], "size":[42,35], "pivot":[0.5,1.0], "position":[0,0]}
	var head: Dictionary = original_parts.head.duplicate(true)
	head["size"] = [29, 36]
	var neck := waist + Vector2(0, -31).rotated(body_angle)
	var shoulder := waist + Vector2(-18, -27).rotated(body_angle)
	var arm_index := 0
	if action == "slash" and p > 0.13 and p < 0.39:
		arm_index = 1
	elif action == "slash" and p >= 0.39 and p < 0.77:
		arm_index = 2
	var arm := arm_info(arm_index)
	var arm_angle := body_angle - 0.045 * wind + 0.025 * drive
	var rest_grip: Vector2 = arm_info(0).grip_offset
	var grip := shoulder + (arm.grip_offset as Vector2).rotated(arm_angle)
	if not has_hands:
		# B retains the same guard location but deliberately abstracts the limb.
		grip = shoulder + rest_grip + Vector2(3.5 * drive - wind, -4 * drive - 4 * wind)
	var sword: Dictionary = original_parts.sword.duplicate(true)
	sword["size"] = [15.2, 46]
	var sword_angle := -0.82 - 0.18 * wind
	if action == "slash":
		sword_angle += 1.98 * drive
		# Brief follow-through lowers the point beyond contact; recovery is separate.
		if p > 0.56 and p < 0.76:
			sword_angle += sin((p - 0.56) / 0.20 * PI) * 0.32
	elif action == "shield_bash":
		sword_angle -= 0.07 * drive
	var shield := _part(Rect2(765,655,421,535), Vector2(972,920), 0.062)
	var shield_shift := 10.5 * drive if action == "shield_bash" else -1.2 * drive
	var shield_position := Vector2(20 + shield_shift, -18.0 - wind)
	if action in ["block", "defend"]:
		shield_position += Vector2(-1, -3 - hit)
	var shield_angle := -0.04 - (0.06 * drive if action == "shield_bash" else 0.0)
	# Shared fixed base and a deliberately buried waist close the old annular gap.
	Original._draw_part(canvas, atlas, base, origin, scale, Vector2.ZERO, 0.0)
	Original._draw_part(canvas, body_atlas, body, origin, scale, waist, body_angle)
	if has_hands:
		# Shoulder overlap and the whole elbow silhouette stay visible over the torso.
		Original._draw_part(canvas, additions, arm, origin, scale, shoulder, arm_angle)
		var shield_arm := arm_info(2 if action == "shield_bash" and drive > 0.3 else 0)
		var sleeve_size: Array = shield_arm.size
		shield_arm["size"] = [float(sleeve_size[0]) * 0.8, float(sleeve_size[1]) * 0.8]
		Original._draw_part(canvas, additions, shield_arm, origin, scale, Vector2(13,-22), -0.20)
	# B uses the same continuous short-sleeved torso; no cut-off arm fragment.
	Original._draw_part(canvas, atlas, sword, origin, scale, grip, sword_angle)
	# The sword arm occupies the rear plane. The face occludes its return arc.
	Original._draw_part(canvas, atlas, head, origin, scale, neck, body_angle * 0.28)
	if has_hands:
		Original._draw_part(canvas, additions, arm.hand, origin, scale, shoulder, arm_angle)
	# The shield-side hand is naturally occluded in A as well as in B.
	Original._draw_part(canvas, additions, shield, origin, scale, shield_position, shield_angle)
	Original._draw_base_front(canvas, atlas, base, origin, scale, 0.43)
	var armor_ratio := float(pose.get("armor_ratio", unit.get("armor_ratio", 1.0)))
	if armor_ratio < 0.99:
		_draw_wear(canvas, origin, scale, body_angle, 1.0 - armor_ratio)
	if bool(pose.get("show_anchors", false)):
		for point: Vector2 in [waist, shoulder, grip, shield_position]:
			canvas.draw_circle(origin + point * scale, maxf(1.0, scale * 0.5), Color("f1ca76"))
	return true

static func _draw_wear(canvas: CanvasItem, origin: Vector2, scale: float, angle: float, amount: float) -> void:
	# Preview wear overlay follows the existing armor surface and fixture state.
	for pair: Array in [[Vector2(-8,-18), Vector2(-3,-22)], [Vector2(-5,-11), Vector2(0,-14)]]:
		var from: Vector2 = origin + (pair[0] as Vector2).rotated(angle) * scale
		var to: Vector2 = origin + (pair[1] as Vector2).rotated(angle) * scale
		canvas.draw_line(from, to, Color(0.12,0.10,0.08,amount), scale * 1.2, true)
