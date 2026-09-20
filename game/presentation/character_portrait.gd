extends Control
class_name CharacterPortrait
## Read-only procedural character layers shared by the battle board and camp view.
## Layer order: back cloth, carried gear, body, armor, head, face wounds,
## hands/weapon, then the foreground shield. Future helmets and capes have
## deliberate insertion points around the head and foreground layers.

const INK := Color("172225")
const IVORY := Color("e5dbc0")
const GOLD := Color("b79b64")
const ModularActor = preload("res://presentation/modular_actor.gd")

var _unit: Dictionary = {}

func _init() -> void:
	custom_minimum_size = Vector2(220.0, 200.0)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	resized.connect(queue_redraw)

## Stores a display snapshot only. It never writes equipment, health, or rules.
func set_unit(unit: Dictionary) -> void:
	_unit = unit.duplicate(true)
	queue_redraw()

func _draw() -> void:
	if _unit.is_empty():
		return
	var scale := minf(size.x / 96.0, size.y / 88.0)
	var origin := Vector2(size.x * 0.5, size.y * 0.86)
	var allied := str(_unit.get("team", "player")) == "player"
	var accent := Color("548f91") if allied else Color("a85945")
	draw_character(self, _unit, origin, scale, allied, accent)

static func draw_character(canvas: CanvasItem, unit: Dictionary, origin: Vector2, scale: float = 1.0, allied: bool = true, accent: Color = Color.WHITE) -> void:
	if ModularActor.draw_actor(canvas, unit, origin, scale):
		return
	var kind := str(unit.get("kind", "guard"))
	if kind == "dog":
		_draw_dog(canvas, unit, origin, scale, allied, accent)
		return
	var identity := _identity(unit)
	var skin := Color("c7a37e") if allied else Color("ba9676")
	var hp_ratio := _ratio(unit, "hp", "max_hp")
	var armor_ratio := _ratio(unit, "armor", "max_armor")
	var armor_id := _armor_id(unit)
	var weapon_id := _weapon_id(unit)
	# 1. Back cloth. A stable hue comes from the unit ID, never from equipment.
	var cloths := [Color("586c62"), Color("735a45"), Color("4d6070")]
	var cloth: Color = cloths[identity % cloths.size()]
	_poly(canvas, [Vector2(-15, -37), Vector2(-23, -8), Vector2(-12, 3), Vector2(15, 2), Vector2(22, -8), Vector2(13, -37)], origin, scale, cloth.darkened(0.34), INK)
	# 2. Back-carried gear. Quiver remains behind the torso and bow hand.
	if weapon_id.contains("bow") or weapon_id.contains("recurve") or weapon_id.contains("longbow"):
		for index in range(3):
			_line(canvas, Vector2(-16 + index * 4, -44 - index), Vector2(-9 + index * 4, -17), origin, scale, Color("c5b17c"), 1.2)
			_line(canvas, Vector2(-19 + index * 4, -46 - index), Vector2(-14 + index * 4, -42 - index), origin, scale, IVORY, 1.4)
	# 3. Body and tunic.
	_poly(canvas, [Vector2(-15, -34), Vector2(-11, -9), Vector2(0, -4), Vector2(12, -10), Vector2(16, -34), Vector2(7, -40), Vector2(-8, -40)], origin, scale, cloth, INK)
	_line(canvas, Vector2(-10, -13), Vector2(11, -13), origin, scale, Color("2b332f"), 3.6)
	_line(canvas, Vector2(-9, -30), Vector2(8, -15), origin, scale, Color("b59866"), 2.4)
	# 4. Armor. The definition ID controls material/outline rather than the role.
	_draw_armor(canvas, armor_id, armor_ratio, origin, scale)
	# 5. Head and stable hair/feature silhouette. A future helmet belongs after this.
	_poly(canvas, [Vector2(-7, -48), Vector2(-8, -41), Vector2(-5, -34), Vector2(4, -33), Vector2(9, -41), Vector2(7, -49)], origin, scale, skin, INK)
	_draw_hair(canvas, identity, origin, scale)
	# 6. Real wounds: health determines face injury; armor loss marks the worn layer.
	_line(canvas, Vector2(-5, -44), Vector2(-2, -44), origin, scale, INK, 1.35)
	_line(canvas, Vector2(4, -44), Vector2(7, -44), origin, scale, INK, 1.35)
	if hp_ratio < 0.38:
		# Pain, not a separate morale stat: brows and a tense mouth follow real HP.
		_line(canvas, Vector2(-6, -47), Vector2(-2, -46), origin, scale, INK, 1.0)
		_line(canvas, Vector2(3, -46), Vector2(7, -47), origin, scale, INK, 1.0)
		_line(canvas, Vector2(-2, -36), Vector2(1, -38), origin, scale, INK, 1.0)
		_line(canvas, Vector2(1, -38), Vector2(4, -36), origin, scale, INK, 1.0)
	else:
		_line(canvas, Vector2(-1, -37), Vector2(3, -37), origin, scale, INK, 1.0)
	if hp_ratio < 0.74:
		_line(canvas, Vector2(3, -47), Vector2(0, -40), origin, scale, Color("8d453e"), 1.15)
		if hp_ratio < 0.38:
			_line(canvas, Vector2(-6, -39), Vector2(-1, -38), origin, scale, Color("8d453e"), 1.25)
	# 7. Hands and held weapon.
	_draw_weapon(canvas, weapon_id, str(unit.get("weapon_style", kind)), skin, origin, scale)
	# 8. Foreground shoulder and shield. This keeps the shield in front of the hand.
	if weapon_id.contains("guard") or str(unit.get("weapon_style", kind)) == "guard":
		_draw_shield(canvas, accent, armor_ratio, origin, scale)

static func _draw_armor(canvas: CanvasItem, armor_id: String, armor_ratio: float, origin: Vector2, scale: float) -> void:
	var plate := Color("536368")
	if armor_id.contains("padded"):
		plate = Color("8a7657")
		_poly(canvas, [Vector2(-14, -36), Vector2(-16, -12), Vector2(-8, -7), Vector2(9, -8), Vector2(15, -13), Vector2(13, -36), Vector2(6, -40), Vector2(-7, -40)], origin, scale, plate, INK)
		for row in range(3):
			_line(canvas, Vector2(-11, -30 + row * 7), Vector2(11, -30 + row * 7), origin, scale, Color("c2aa78"), 1.0)
	elif armor_id.contains("leather"):
		plate = Color("70533a")
		_poly(canvas, [Vector2(-16, -36), Vector2(-17, -11), Vector2(-8, -6), Vector2(10, -7), Vector2(16, -12), Vector2(14, -36), Vector2(7, -41), Vector2(-8, -41)], origin, scale, plate, INK)
		_line(canvas, Vector2(-10, -34), Vector2(9, -10), origin, scale, Color("b18c60"), 1.25)
		_line(canvas, Vector2(9, -34), Vector2(-8, -11), origin, scale, Color("b18c60"), 1.25)
	elif armor_id.contains("brigandine"):
		plate = Color("68777a")
		_poly(canvas, [Vector2(-17, -37), Vector2(-18, -12), Vector2(-8, -6), Vector2(11, -7), Vector2(17, -13), Vector2(14, -37), Vector2(7, -42), Vector2(-8, -42)], origin, scale, plate, INK)
		for row in range(3):
			for column in range(3):
				_circle(canvas, Vector2(-8 + column * 8, -31 + row * 7), origin, scale, 1.25, Color("d1c7a6"))
	else:
		# Mail is the fallback for legacy guards and the visible heavy armor choice.
		plate = Color("7a8887")
		_poly(canvas, [Vector2(-18, -38), Vector2(-18, -11), Vector2(-8, -5), Vector2(11, -6), Vector2(18, -12), Vector2(15, -38), Vector2(7, -43), Vector2(-8, -43)], origin, scale, plate, INK)
		for row in range(4):
			for column in range(4):
				_arc(canvas, Vector2(-10 + column * 7, -32 + row * 6), origin, scale, 2.0, 0.2, 3.0, Color("c0cbc2"), 0.8)
	if armor_ratio < 0.67:
		_line(canvas, Vector2(-12, -22), Vector2(-3, -17), origin, scale, Color("413c38"), 1.35)
		_line(canvas, Vector2(7, -30), Vector2(12, -20), origin, scale, Color("413c38"), 1.35)
	if armor_ratio < 0.30:
		_poly(canvas, [Vector2(2, -18), Vector2(9, -16), Vector2(7, -10), Vector2(1, -11)], origin, scale, Color("342f2d"), INK)

static func _draw_hair(canvas: CanvasItem, identity: int, origin: Vector2, scale: float) -> void:
	var hair: Color = Color([Color("37342e"), Color("5c4432"), Color("7a5b3c")][identity % 3])
	if identity % 3 == 0:
		_poly(canvas, [Vector2(-9, -45), Vector2(-7, -54), Vector2(3, -57), Vector2(10, -51), Vector2(8, -45), Vector2(4, -50), Vector2(-4, -51)], origin, scale, hair, INK)
	elif identity % 3 == 1:
		_poly(canvas, [Vector2(-10, -43), Vector2(-10, -51), Vector2(-4, -57), Vector2(6, -55), Vector2(11, -48), Vector2(7, -43), Vector2(3, -51), Vector2(-5, -50)], origin, scale, hair, INK)
	else:
		_poly(canvas, [Vector2(-11, -45), Vector2(-7, -55), Vector2(5, -57), Vector2(11, -49), Vector2(7, -44), Vector2(3, -52), Vector2(-6, -50)], origin, scale, hair, INK)

static func _draw_weapon(canvas: CanvasItem, weapon_id: String, weapon_style: String, skin: Color, origin: Vector2, scale: float) -> void:
	var style := weapon_style
	if style.is_empty():
		style = "guard" if weapon_id.contains("sword") or weapon_id.contains("cleaver") else "skirmisher"
	if weapon_id.contains("cleaver") or weapon_id.contains("axe") or style == "skirmisher":
		_line(canvas, Vector2(17, -14), Vector2(31, -42), origin, scale, Color("aa8958"), 3.0)
		_poly(canvas, [Vector2(29, -45), Vector2(39, -44), Vector2(43, -31), Vector2(31, -34), Vector2(25, -38)], origin, scale, Color("b9c1b8"), INK)
		_line(canvas, Vector2(16, -24), Vector2(25, -27), origin, scale, skin, 4.0)
	elif weapon_id.contains("spear") or weapon_id.contains("hooked") or style == "spear":
		_line(canvas, Vector2(22, 1), Vector2(31, -65), origin, scale, Color("b39463"), 3.0)
		_poly(canvas, [Vector2(31, -76), Vector2(25, -63), Vector2(30, -56), Vector2(35, -64)], origin, scale, Color("c7cfbc"), INK)
		if weapon_id.contains("hooked"):
			_arc(canvas, Vector2(30, -62), origin, scale, 7.0, 0.2, 2.0, Color("c7cfbc"), 1.5)
		_line(canvas, Vector2(17, -25), Vector2(28, -27), origin, scale, skin, 4.0)
	elif weapon_id.contains("bow") or weapon_id.contains("recurve") or weapon_id.contains("longbow") or style in ["archer", "hunter"]:
		var bow := PackedVector2Array([_point(origin, Vector2(24, -50), scale), _point(origin, Vector2(32, -38), scale), _point(origin, Vector2(32, -20), scale), _point(origin, Vector2(25, -4), scale)])
		canvas.draw_polyline(bow, Color("c2a376"), 3.0 * scale, true)
		_line(canvas, Vector2(24, -50), Vector2(25, -4), origin, scale, Color("d9ceb0"), 1.0)
		_line(canvas, Vector2(17, -25), Vector2(28, -26), origin, scale, skin, 4.0)
	else:
		_line(canvas, Vector2(18, -12), Vector2(32, -43), origin, scale, Color("aa8958"), 3.0)
		_poly(canvas, [Vector2(29, -42), Vector2(36, -53), Vector2(35, -37), Vector2(30, -33)], origin, scale, Color("d1d0b9"), INK)
		_line(canvas, Vector2(16, -24), Vector2(25, -27), origin, scale, skin, 4.0)

static func _draw_shield(canvas: CanvasItem, accent: Color, armor_ratio: float, origin: Vector2, scale: float) -> void:
	_poly(canvas, [Vector2(-31, -30), Vector2(-18, -35), Vector2(-6, -30), Vector2(-8, -10), Vector2(-18, 1), Vector2(-29, -8)], origin, scale, accent.darkened(0.12), Color("c2b897"))
	_line(canvas, Vector2(-18, -29), Vector2(-17, -7), origin, scale, GOLD, 2.0)
	_line(canvas, Vector2(-25, -18), Vector2(-11, -18), origin, scale, GOLD, 1.8)
	if armor_ratio < 0.52:
		_line(canvas, Vector2(-27, -25), Vector2(-13, -10), origin, scale, Color("493f37"), 1.25)

static func _draw_dog(canvas: CanvasItem, unit: Dictionary, origin: Vector2, scale: float, allied: bool, accent: Color) -> void:
	var fur := Color("aa9674") if allied else Color("897562")
	_poly(canvas, [Vector2(-25, -14), Vector2(-20, -23), Vector2(-3, -25), Vector2(9, -20), Vector2(18, -28), Vector2(29, -23), Vector2(30, -16), Vector2(20, -12), Vector2(11, -9), Vector2(-10, -8)], origin, scale, fur, INK)
	_poly(canvas, [Vector2(12, -22), Vector2(11, -38), Vector2(19, -28), Vector2(25, -34), Vector2(27, -21)], origin, scale, fur.darkened(0.12), INK)
	_poly(canvas, [Vector2(-12, -25), Vector2(3, -24), Vector2(7, -11), Vector2(-12, -10)], origin, scale, accent, Color("c4b38a"))
	_circle(canvas, Vector2(23, -24), origin, scale, 1.6, INK)
	_circle(canvas, Vector2(30, -19), origin, scale, 2.2, INK)
	if _ratio(unit, "hp", "max_hp") < 0.5:
		_line(canvas, Vector2(-4, -23), Vector2(3, -16), origin, scale, Color("8d453e"), 1.25)

static func _armor_id(unit: Dictionary) -> String:
	var loadout: Dictionary = unit.get("visual_loadout", {})
	var armor_id := str(loadout.get("armor", ""))
	if not armor_id.is_empty():
		return armor_id
	var maximum := int(unit.get("max_armor", 0))
	if maximum >= 22:
		return "armor_mail"
	if maximum >= 16:
		return "armor_brigandine"
	if maximum >= 13:
		return "armor_leather"
	return "armor_padded"

static func _weapon_id(unit: Dictionary) -> String:
	var loadout: Dictionary = unit.get("visual_loadout", {})
	var weapon_id := str(loadout.get("weapon", ""))
	if not weapon_id.is_empty():
		return weapon_id
	var kind := str(unit.get("weapon_style", unit.get("kind", "guard")))
	var fallback := {"guard": "weapon_guard_sword", "spear": "weapon_spear_long", "archer": "weapon_archer_bow", "hunter": "weapon_hunter_bow", "skirmisher": "weapon_skirmisher_blade"}
	return str(fallback.get(kind, "weapon_skirmisher_blade"))

static func _identity(unit: Dictionary) -> int:
	return posmod(str(unit.get("id", "mercenary")).hash(), 2147483647)

static func _ratio(unit: Dictionary, current: String, maximum: String) -> float:
	return clampf(float(unit.get(current, 0)) / maxf(1.0, float(unit.get(maximum, 1))), 0.0, 1.0)

static func _point(origin: Vector2, local: Vector2, scale: float) -> Vector2:
	return origin + local * scale

static func _poly(canvas: CanvasItem, locals: Array, origin: Vector2, scale: float, fill: Color, outline: Color = Color.TRANSPARENT) -> void:
	var points := PackedVector2Array()
	for local: Vector2 in locals:
		points.append(_point(origin, local, scale))
	canvas.draw_colored_polygon(points, fill)
	if outline.a > 0.0:
		points.append(points[0])
		canvas.draw_polyline(points, outline, 1.3 * scale, true)

static func _line(canvas: CanvasItem, start: Vector2, end: Vector2, origin: Vector2, scale: float, color: Color, width: float) -> void:
	canvas.draw_line(_point(origin, start, scale), _point(origin, end, scale), color, width * scale, true)

static func _circle(canvas: CanvasItem, local: Vector2, origin: Vector2, scale: float, radius: float, color: Color) -> void:
	canvas.draw_circle(_point(origin, local, scale), radius * scale, color)

static func _arc(canvas: CanvasItem, local: Vector2, origin: Vector2, scale: float, radius: float, start: float, end: float, color: Color, width: float) -> void:
	canvas.draw_arc(_point(origin, local, scale), radius * scale, start, end, 12, color, width * scale, true)
