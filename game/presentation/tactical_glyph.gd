extends Control
## Small original line icons for battle HUD controls. They describe an action category only.

var glyph: String = "attack"
var tint: Color = Color("d8c58e")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = custom_minimum_size.max(Vector2(22.0, 22.0))
	resized.connect(queue_redraw)

func set_glyph(id: String) -> void:
	glyph = id
	queue_redraw()

func _draw() -> void:
	var icon_rect := Rect2(Vector2(2.0, 2.0), (size - Vector2(4.0, 4.0)).max(Vector2(1.0, 1.0)))
	var center := icon_rect.get_center()
	var scale := minf(icon_rect.size.x, icon_rect.size.y) / 20.0
	draw_set_transform(center, 0.0, Vector2(scale, scale))
	match glyph:
		"heart": _poly([Vector2(0, 8), Vector2(-8, 0), Vector2(-8, -5), Vector2(-4, -8), Vector2(0, -4), Vector2(4, -8), Vector2(8, -5), Vector2(8, 0)], Color(tint, 0.22))
		"hourglass":
			_poly([Vector2(-6, -8), Vector2(6, -8), Vector2(5, -4), Vector2(-5, 4), Vector2(-6, 8), Vector2(6, 8), Vector2(5, 4), Vector2(-5, -4)])
		"broken_shield":
			_shield(false)
			_line(Vector2(7, -9), Vector2(-7, 8), 2.4)
		"flame": _poly([Vector2(0, 9), Vector2(-7, 4), Vector2(-7, -1), Vector2(-3, -6), Vector2(-2, 0), Vector2(2, -9), Vector2(7, 0), Vector2(7, 5)], Color(tint, 0.25))
		"steam":
			for y in [-5, 0, 5]:
				draw_polyline(PackedVector2Array([Vector2(-9, y + 2), Vector2(-4, y), Vector2(2, y + 2), Vector2(8, y)]), tint, 1.5, true)
		"unknown":
			_poly([Vector2(0, -9), Vector2(9, 0), Vector2(0, 9), Vector2(-9, 0)])
			_line(Vector2(0, -4), Vector2(0, 2))
			draw_circle(Vector2(0, 5), 1.0, tint)
		"move": _boots()
		"attack": _sword()
		"shield_bash": _shield(true)
		"push": _push()
		"defend", "guard": _shield(false)
		"oil": _flask(Color("b89a57"))
		"fire": _flask(Color("dc8b50"), true)
		"water": _flask(Color("87b9bd"))
		"mark": _mark()
		"command_follow": _command(false)
		"pin", "command_pin": _pin()
		"recall", "command_recall": _command(true)
		"spear": _spear()
		"archer", "hunter": _bow()
		"dog": _dog()
		"skirmisher": _dagger()
		"raider": _axe()
		_: _sword()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _line(from: Vector2, to: Vector2, width: float = 1.7) -> void:
	draw_line(from, to, tint, width, true)

func _poly(vertices: Array[Vector2], fill: Color = Color.TRANSPARENT) -> void:
	var points := PackedVector2Array(vertices)
	if fill.a > 0.0:
		draw_colored_polygon(points, fill)
	points.append(points[0])
	draw_polyline(points, tint, 1.45, true)

func _sword() -> void:
	_line(Vector2(-7, 7), Vector2(6, -6), 2.2)
	_poly([Vector2(5, -8), Vector2(9, -9), Vector2(7, -5)])
	_line(Vector2(-8, 3), Vector2(-3, 8), 2.1)
	_line(Vector2(-10, 8), Vector2(-5, 3), 1.6)

func _dagger() -> void:
	_line(Vector2(-5, 8), Vector2(5, -5), 2.4)
	_poly([Vector2(4, -8), Vector2(8, -7), Vector2(6, -3)])
	_line(Vector2(-8, 5), Vector2(-2, 9), 2.0)

func _spear() -> void:
	_line(Vector2(-8, 8), Vector2(6, -7), 1.8)
	_poly([Vector2(5, -9), Vector2(9, -9), Vector2(7, -5)])
	_line(Vector2(-8, 8), Vector2(-3, 7), 2.8)

func _axe() -> void:
	_line(Vector2(-2, 8), Vector2(3, -8), 2.1)
	_poly([Vector2(2, -6), Vector2(8, -7), Vector2(8, -1), Vector2(4, 2), Vector2(2, -1)])

func _shield(bashing: bool) -> void:
	_poly([Vector2(-6, -7), Vector2(6, -7), Vector2(7, 0), Vector2(0, 8), Vector2(-7, 0)], Color(tint, 0.18))
	_line(Vector2(0, -6), Vector2(0, 5), 1.1)
	if bashing:
		_line(Vector2(8, -3), Vector2(11, -5), 1.4)
		_line(Vector2(9, 1), Vector2(12, 1), 1.4)
		_line(Vector2(8, 5), Vector2(11, 7), 1.4)

func _push() -> void:
	_poly([Vector2(-8, -5), Vector2(-2, -5), Vector2(-2, -8), Vector2(6, 0), Vector2(-2, 8), Vector2(-2, 5), Vector2(-8, 5)])
	_line(Vector2(8, -7), Vector2(8, 7), 1.3)

func _boots() -> void:
	_poly([Vector2(-7, -7), Vector2(-3, -7), Vector2(-2, 3), Vector2(-7, 6), Vector2(-9, 4)])
	_poly([Vector2(2, -5), Vector2(6, -5), Vector2(8, 5), Vector2(3, 7), Vector2(0, 5)])

func _flask(fill: Color, flaming: bool = false) -> void:
	_poly([Vector2(-4, -8), Vector2(4, -8), Vector2(3, -3), Vector2(7, 2), Vector2(4, 8), Vector2(-4, 8), Vector2(-7, 2), Vector2(-3, -3)], Color(fill, 0.34))
	_line(Vector2(-3, -5), Vector2(3, -5), 1.0)
	if flaming:
		_poly([Vector2(-2, 4), Vector2(-3, 0), Vector2(0, -3), Vector2(3, 1), Vector2(2, 4)], Color(fill, 0.55))

func _mark() -> void:
	draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 18, tint, 1.5, true)
	draw_arc(Vector2.ZERO, 3.0, 0.0, TAU, 14, tint, 1.3, true)
	_line(Vector2(-10, 0), Vector2(-5, 0), 1.2)
	_line(Vector2(5, 0), Vector2(10, 0), 1.2)

func _command(recall: bool) -> void:
	_poly([Vector2(-8, -7), Vector2(0, -4), Vector2(7, -7), Vector2(5, 7), Vector2(0, 4), Vector2(-5, 7)])
	if recall:
		draw_arc(Vector2.ZERO, 10.0, 0.25, 4.8, 16, tint, 1.3, true)
		_poly([Vector2(-8, -5), Vector2(-11, -8), Vector2(-11, -3)])
	else:
		_line(Vector2(0, -3), Vector2(0, 2), 1.2)

func _pin() -> void:
	_poly([Vector2(-5, -7), Vector2(5, -7), Vector2(3, -1), Vector2(6, 2), Vector2(-6, 2), Vector2(-3, -1)])
	_line(Vector2(0, 2), Vector2(0, 9), 1.8)

func _bow() -> void:
	draw_arc(Vector2(-2, 0), 9.0, -1.05, 1.05, 14, tint, 1.7, true)
	_line(Vector2(2, -8), Vector2(2, 8), 1.0)
	_line(Vector2(-7, 0), Vector2(8, 0), 1.3)
	_poly([Vector2(8, 0), Vector2(5, -2), Vector2(5, 2)])

func _dog() -> void:
	_poly([Vector2(-8, 3), Vector2(-6, -3), Vector2(1, -4), Vector2(4, -8), Vector2(8, -4), Vector2(7, 2), Vector2(10, 4), Vector2(4, 5), Vector2(1, 8), Vector2(-2, 5), Vector2(-7, 6)])
	_line(Vector2(-5, 5), Vector2(-5, 8), 1.4)
	_line(Vector2(3, 5), Vector2(3, 8), 1.4)
