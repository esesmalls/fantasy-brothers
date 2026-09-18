extends Control
## Read-only battle presentation. Rules own positions, damage and resources.

signal cell_clicked(q: int, r: int)
signal cell_hovered(q: int, r: int)

const CANVAS := Vector2(800.0, 560.0)
const HEX_RADIUS := 34.0
const ORIGIN := Vector2(66.0, 138.0)
const INK := Color("172225")
const GOLD := Color("b79b64")
const IVORY := Color("e5dbc0")
const ALLY := Color("548f91")
const ENEMY := Color("a85945")
const MOVE_HINT := Color("79b9a5")
const RANGE_HINT := Color("d2ab58")
const BLOCKED_HINT := Color("8c7780")
const TARGET_HINT := Color("d87970")
const IMPACT_HINT := Color("b895cf")

var _battle: Dictionary = {}
var _selected: String = ""
var _preview: Dictionary = {}
var _action_overlay: Dictionary = {}
var _hover := Vector2i(-1, -1)
var _font: SystemFont
var _scale: float = 1.0
var _offset := Vector2.ZERO
var _clock: float = 0.0
var _animation_speed: float = 1.0
var _event_queue: Array = []
var _event_remaining: float = 0.0
var _motions: Dictionary = {}
var _flashes: Dictionary = {}
var _floating: Array = []
var _rings: Array = []
var _old_positions: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(440.0, 330.0)
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Microsoft YaHei UI", "Noto Sans CJK SC", "Arial"])
	resized.connect(queue_redraw)
	mouse_exited.connect(_clear_hover)
	set_process(true)

func set_battle(state: Dictionary) -> void:
	_old_positions.clear()
	for item in _battle.get("units", []):
		var unit: Dictionary = item
		_old_positions[str(unit.get("id", ""))] = _hex_center(int(unit.get("q", 0)), int(unit.get("r", 0)))
	_battle = state.duplicate(true)
	queue_redraw()

func set_selected(unit_id: String) -> void:
	_selected = unit_id
	queue_redraw()

func set_preview(info: Dictionary) -> void:
	_preview = info.duplicate(true)
	queue_redraw()

## Receives a rule-calculated action map. This view never derives range or targets.
## {range_cells, blocked_cells, valid_targets, action_name, action_id}
func set_action_overlay(info: Dictionary) -> void:
	_action_overlay = info.duplicate(true)
	queue_redraw()

func set_animation_speed(speed: float) -> void:
	_animation_speed = clampf(speed, 0.0, 8.0)
	if _animation_speed <= 0.001:
		_event_queue.clear()
		_motions.clear()
		_flashes.clear()
		_floating.clear()
		_rings.clear()
		_event_remaining = 0.0
	queue_redraw()

func play_events(events: Array, speed: float = 1.0) -> void:
	if _animation_speed <= 0.001 or speed <= 0.001:
		return
	for item in events:
		if not item is Dictionary:
			continue
		var event: Dictionary = item.duplicate(true)
		event["_speed"] = clampf(speed, 0.1, 8.0)
		_event_queue.append(event)
	# The queue affects presentation only, and can always be discarded safely.
	if _event_queue.size() > 96:
		_event_queue = _event_queue.slice(_event_queue.size() - 96)
	queue_redraw()

func _process(delta: float) -> void:
	_clock += delta
	var elapsed: float = delta * maxf(_animation_speed, 0.01)
	_event_remaining -= elapsed
	if _event_remaining <= 0.0 and not _event_queue.is_empty():
		_begin_event(_event_queue.pop_front())
	for unit_id in _motions.keys():
		var motion: Dictionary = _motions[unit_id]
		motion["time"] = float(motion["time"]) + elapsed
		if float(motion["time"]) >= float(motion["duration"]):
			_motions.erase(unit_id)
	for unit_id in _flashes.keys():
		_flashes[unit_id] = float(_flashes[unit_id]) - elapsed
		if float(_flashes[unit_id]) <= 0.0:
			_flashes.erase(unit_id)
	for collection in [_floating, _rings]:
		for index in range(collection.size() - 1, -1, -1):
			collection[index]["time"] = float(collection[index]["time"]) + elapsed
			if float(collection[index]["time"]) >= float(collection[index]["duration"]):
				collection.remove_at(index)
	queue_redraw()

func _begin_event(event: Dictionary) -> void:
	var kind: String = str(event.get("type", ""))
	var actor: String = str(event.get("actor", ""))
	var target: String = str(event.get("target", ""))
	var point: Vector2 = _event_position(event)
	var batch_speed: float = float(event.get("_speed", 1.0))
	_event_remaining = 0.12 / batch_speed
	if kind == "move":
		var origin: Vector2 = _old_positions.get(actor, point)
		if event.has("from_q") and event.has("from_r"):
			origin = _hex_center(int(event["from_q"]), int(event["from_r"]))
		_motions[actor] = {"from": origin, "to": point, "time": 0.0, "duration": 0.27 / batch_speed, "kind": "move"}
		_event_remaining = 0.27 / batch_speed
	elif kind == "attack":
		var unit: Dictionary = _unit_by_id(actor)
		if not unit.is_empty():
			var origin: Vector2 = _hex_center(int(unit.get("q", 0)), int(unit.get("r", 0)))
			var reach: Vector2 = origin.direction_to(point) * 12.0
			_motions[actor] = {"from": origin, "to": origin + reach, "time": 0.0, "duration": 0.24 / batch_speed, "kind": "attack"}
			_event_remaining = 0.15 / batch_speed
	elif kind == "hit":
		_flashes[target] = 0.30 / batch_speed
		_float_text(point, "−%s" % str(event.get("amount", "")), Color("f2ae85"))
	elif kind == "miss":
		_float_text(point, "闪避", IVORY)
	elif kind == "death":
		_float_text(point, "倒下", Color("c9826d"))
	elif kind == "fire" or kind == "water":
		var color: Color = Color("e79b52") if kind == "fire" else Color("8fcbcc")
		_rings.append({"point": point, "color": color, "time": 0.0, "duration": 0.55})
	elif kind == "status":
		var message: String = str(event.get("text", "状态变化"))
		if message.length() > 10:
			message = message.substr(0, 10) + "…"
		_float_text(point, message, Color("d8c583"))

func _float_text(point: Vector2, message: String, color: Color) -> void:
	_floating.append({"point": point, "text": message, "color": color, "time": 0.0, "duration": 0.85})

func _event_position(event: Dictionary) -> Vector2:
	if event.has("q") and event.has("r"):
		return _hex_center(int(event["q"]), int(event["r"]))
	var unit: Dictionary = _unit_by_id(str(event.get("target", event.get("actor", ""))))
	return _hex_center(int(unit.get("q", 4)), int(unit.get("r", 3)))

func _unit_by_id(unit_id: String) -> Dictionary:
	for item in _battle.get("units", []):
		if str(item.get("id", "")) == unit_id:
			return item
	return {}

func _layout() -> void:
	_scale = maxf(0.01, minf(size.x / CANVAS.x, size.y / CANVAS.y))
	_offset = (size - CANVAS * _scale) * 0.5

func _gui_input(event: InputEvent) -> void:
	_layout()
	if event is InputEventMouseMotion:
		var cell: Vector2i = _point_to_hex((event.position - _offset) / _scale)
		if cell != _hover:
			_hover = cell
			cell_hovered.emit(cell.x, cell.y)
			queue_redraw()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var cell: Vector2i = _point_to_hex((event.position - _offset) / _scale)
			if _valid_cell(cell):
				cell_clicked.emit(cell.x, cell.y)
				accept_event()

func _clear_hover() -> void:
	_hover = Vector2i(-1, -1)
	cell_hovered.emit(-1, -1)
	queue_redraw()

func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < int(_battle.get("width", 9)) and cell.y >= 0 and cell.y < int(_battle.get("height", 7))

func _point_to_hex(point: Vector2) -> Vector2i:
	var local: Vector2 = point - ORIGIN
	var raw_r: float = local.y / (1.5 * HEX_RADIUS)
	var raw_q: float = local.x / (sqrt(3.0) * HEX_RADIUS) - raw_r * 0.5
	var raw_s: float = -raw_q - raw_r
	var q: int = roundi(raw_q)
	var r: int = roundi(raw_r)
	var s: int = roundi(raw_s)
	var dq: float = absf(float(q) - raw_q)
	var dr: float = absf(float(r) - raw_r)
	var ds: float = absf(float(s) - raw_s)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	var cell := Vector2i(q, r)
	return cell if _valid_cell(cell) else Vector2i(-1, -1)

func _hex_center(q: int, r: int) -> Vector2:
	return ORIGIN + Vector2(sqrt(3.0) * HEX_RADIUS * (float(q) + float(r) * 0.5), 1.5 * HEX_RADIUS * float(r))

func _hex_points(point: Vector2, radius: float = HEX_RADIUS - 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle: float = deg_to_rad(30.0 + 60.0 * index)
		points.append(point + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw() -> void:
	if _font == null:
		return
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), Color("111a1d"))
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))
	draw_rect(Rect2(Vector2(8, 8), CANVAS - Vector2(16, 16)), Color("1c292b"))
	draw_rect(Rect2(Vector2(8, 8), CANVAS - Vector2(16, 16)), Color("56605a"), false, 1.0)
	draw_rect(Rect2(Vector2(14, 14), CANVAS - Vector2(28, 28)), Color("827552"), false, 1.0)
	_draw_ornaments()
	_text("灰烬边境  /  战场", Vector2(30, 43), 18, IVORY)
	_text("第 %s 轮" % str(_battle.get("round", 1)), Vector2(643, 43), 16, GOLD, 125, HORIZONTAL_ALIGNMENT_RIGHT)
	for r in range(int(_battle.get("height", 7))):
		for q in range(int(_battle.get("width", 9))):
			_draw_cell(q, r)
	_draw_preview()
	_draw_action_overlay_ground()
	var drawables: Array = []
	for prop in _battle.get("props", []):
		drawables.append({"value": prop, "type": "prop", "y": _hex_center(int(prop.get("q", 0)), int(prop.get("r", 0))).y})
	for unit in _battle.get("units", []):
		drawables.append({"value": unit, "type": "unit", "y": _hex_center(int(unit.get("q", 0)), int(unit.get("r", 0))).y + 0.5})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for item in drawables:
		if str(item["type"]) == "prop":
			_draw_prop(item["value"])
		else:
			_draw_unit(item["value"])
	_draw_effects()
	_draw_action_overlay_foreground()
	_draw_active_indicator()
	_draw_legend()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_ornaments() -> void:
	for corner in [Vector2(24, 24), Vector2(776, 24), Vector2(24, 536), Vector2(776, 536)]:
		var motif := PackedVector2Array([corner + Vector2(0, -5), corner + Vector2(5, 0), corner + Vector2(0, 5), corner + Vector2(-5, 0)])
		draw_colored_polygon(motif, GOLD)
	# Sparse map hatching is decoration, not interactable terrain.
	for index in range(13):
		var p := Vector2(37 + index * 58, 479 + (index % 3) * 4)
		draw_line(p, p + Vector2(19, -8), Color("34413d"), 1.0, true)
		draw_line(p + Vector2(8, 2), p + Vector2(27, -6), Color("34413d"), 1.0, true)
	draw_line(Vector2(30, 57), Vector2(770, 57), Color("66654f"), 1.0, true)
	draw_line(Vector2(30, 503), Vector2(770, 503), Color("66654f"), 1.0, true)

func _draw_cell(q: int, r: int) -> void:
	var point: Vector2 = _hex_center(q, r)
	var cells: Dictionary = _battle.get("cells", {})
	var cell: Dictionary = cells.get("%d,%d" % [q, r], {})
	var color := Color("34413a") if (q + r) % 2 == 0 else Color("303d36")
	if bool(cell.get("blocked", false)):
		color = Color("30312c")
	var surface: String = str(cell.get("surface", "dry"))
	if surface == "oil":
		color = Color("242928")
	elif surface == "water":
		color = Color("2b4b50")
	var polygon: PackedVector2Array = _hex_points(point)
	draw_colored_polygon(polygon, color)
	polygon.append(polygon[0])
	draw_polyline(polygon, Color("596454"), 1.0, true)
	if surface == "oil":
		_ellipse(point, Vector2(22, 13), Color("171e20"))
		draw_arc(point + Vector2(-2, 0), 14, 0.2, 2.7, 14, Color("8e794b"), 1.4, true)
		draw_arc(point + Vector2(5, -3), 8, 3.2, 5.9, 12, Color("5e6755"), 1.0, true)
	elif surface == "water":
		for index in range(3):
			var start := point + Vector2(-19 + index * 3, -7 + index * 7)
			draw_line(start, start + Vector2(29, -3), Color("759f9e"), 1.0, true)
	else:
		var shift: float = float((q * 13 + r * 7) % 9)
		draw_line(point + Vector2(-19, 11), point + Vector2(-11 + shift, 9), Color("647057"), 1.0)
		draw_line(point + Vector2(10, -11), point + Vector2(15, -14), Color("4a5744"), 1.0)
	var field: String = str(cell.get("field", ""))
	if field == "fire":
		for index in range(3):
			var flame := point + Vector2(-13 + index * 12, 7 + (index % 2) * 4)
			var flicker: float = sin(_clock * 6.0 + q + r + index) * 2.0
			_polygon([Vector2(-7, 4), Vector2(-10, -5), Vector2(-3, -17 - flicker), Vector2(1, -7), Vector2(6, -24 + flicker), Vector2(11, -5), Vector2(7, 4)], flame, Color("c46638"), Color("793d29"))
			_polygon([Vector2(-3, 3), Vector2(-4, -6), Vector2(2, -15), Vector2(5, -3), Vector2(3, 3)], flame, Color("edb25e"))
	elif field == "steam":
		for index in range(4):
			var drift: float = sin(_clock * 1.3 + index + q) * 2.0
			_ellipse(point + Vector2(-15 + index * 10, -6 + drift), Vector2(12, 9 + (index % 2) * 4), Color(0.69, 0.79, 0.74, 0.30))
		draw_arc(point + Vector2(2, -5), 19, 3.6, 5.9, 16, Color("9faea3"), 1.0, true)
	if q == _hover.x and r == _hover.y:
		var hover_points: PackedVector2Array = _hex_points(point, HEX_RADIUS - 2.0)
		hover_points.append(hover_points[0])
		draw_polyline(hover_points, Color("d0bd86"), 2.0, true)

func _draw_preview() -> void:
	for cell in _preview.get("reachable", []):
		if cell is Dictionary and cell.has("q") and cell.has("r"):
			var center: Vector2 = _hex_center(int(cell.q), int(cell.r))
			draw_colored_polygon(_hex_points(center, HEX_RADIUS - 5.0), Color(MOVE_HINT, 0.13))
			draw_circle(center, 2.1, MOVE_HINT)
	var valid: bool = bool(_preview.get("ok", false))
	var path := PackedVector2Array()
	for cell in _preview.get("path", []):
		if cell is Dictionary and cell.has("q") and cell.has("r"):
			path.append(_hex_center(int(cell["q"]), int(cell["r"])))
	if path.size() > 1:
		draw_polyline(path, MOVE_HINT if valid else Color("bc7864"), 2.5, true)
	for point in path:
		draw_circle(point, 3.5, Color("ded7a9"))

func _draw_action_overlay_ground() -> void:
	# Warm diamond marks communicate nominal attack reach, even across empty cells.
	for cell in _action_overlay.get("range_cells", []):
		if _is_cell_dictionary(cell):
			var center := _hex_center(int(cell["q"]), int(cell["r"]))
			draw_colored_polygon(_hex_points(center, HEX_RADIUS - 7.0), Color(RANGE_HINT, 0.10))
			_draw_diamond(center, 8.0, RANGE_HINT, 1.4)
	# A cross-hatched slate cell is geometrically in range, but line of sight is blocked.
	for cell in _action_overlay.get("blocked_cells", []):
		if _is_cell_dictionary(cell):
			var center := _hex_center(int(cell["q"]), int(cell["r"]))
			draw_colored_polygon(_hex_points(center, HEX_RADIUS - 6.0), Color(BLOCKED_HINT, 0.20))
			draw_line(center + Vector2(-11, -9), center + Vector2(11, 9), BLOCKED_HINT, 2.0, true)
			draw_line(center + Vector2(-11, 9), center + Vector2(11, -9), BLOCKED_HINT, 2.0, true)
	# Area tools can affect most open cells. Keep their legal centres understated and below
	# pieces, then reserve the full reticle for the one cell the player is inspecting.
	if _is_area_cell_action():
		for cell in _action_overlay.get("valid_targets", []):
			if _is_cell_dictionary(cell):
				_draw_target_reticle(_hex_center(int(cell["q"]), int(cell["r"])), 6.0, Color(TARGET_HINT, 0.62))

func _draw_action_overlay_foreground() -> void:
	# The preview is supplied by Battle.preview for the hovered cell. Draw its result above
	# units so an area action remains visible when its centre contains a character or prop.
	if bool(_preview.get("ok", false)) and str(_action_overlay.get("action_id", "")) != "move":
		for cell in _preview.get("affected", []):
			if _is_cell_dictionary(cell):
				var polygon: PackedVector2Array = _hex_points(_hex_center(int(cell["q"]), int(cell["r"])), HEX_RADIUS - 4.0)
				draw_colored_polygon(polygon, Color(IMPACT_HINT, 0.16))
				polygon.append(polygon[0])
				draw_polyline(polygon, IMPACT_HINT, 1.6, true)
	# Unit and prop attacks retain strong foreground reticles. An area tool only promotes
	# the currently legal hover centre, leaving the board and friendly pieces readable.
	if _is_area_cell_action():
		if bool(_preview.get("ok", false)) and _preview.has("q") and _preview.has("r"):
			_draw_target_reticle(_hex_center(int(_preview["q"]), int(_preview["r"])))
	else:
		for cell in _action_overlay.get("valid_targets", []):
			if _is_cell_dictionary(cell):
				_draw_target_reticle(_hex_center(int(cell["q"]), int(cell["r"])))

func _is_area_cell_action() -> bool:
	return str(_action_overlay.get("action_id", "")) in ["oil", "fire", "water"]

func _is_cell_dictionary(value: Variant) -> bool:
	return value is Dictionary and value.has("q") and value.has("r")

func _draw_diamond(center: Vector2, radius: float, color: Color, width: float = 1.0) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])
	draw_polyline(points, color, width, true)

func _draw_target_reticle(center: Vector2, radius: float = 17.0, color: Color = TARGET_HINT) -> void:
	draw_arc(center, radius, 0.0, TAU, 20, color, maxf(1.0, radius * 0.12), true)
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + direction * radius * 1.24, center + direction * radius * 0.76, color, maxf(1.2, radius * 0.15), true)
	draw_circle(center, maxf(1.4, radius * 0.19), color)

func _draw_prop(prop: Dictionary) -> void:
	var point: Vector2 = _hex_center(int(prop.get("q", 0)), int(prop.get("r", 0)))
	var kind: String = str(prop.get("kind", "cover"))
	if int(prop.get("hp", 0)) <= 0:
		for index in range(4):
			draw_line(point + Vector2(-17 + index * 9, -3 + (index % 2) * 7), point + Vector2(-7 + index * 7, 3 + (index % 2) * 4), Color("827257"), 2.0, true)
		return
	_ellipse(point + Vector2(2, 6), Vector2(23, 8), Color(0.0, 0.0, 0.0, 0.30))
	if kind == "oil" or kind == "water":
		_polygon([Vector2(-13, -24), Vector2(13, -24), Vector2(16, -3), Vector2(11, 7), Vector2(-11, 7), Vector2(-16, -3)], point, Color("816247"), Color("282826"))
		for x in [-8, 0, 8]:
			draw_line(point + Vector2(x, -21), point + Vector2(x, 4), Color("4b4032"), 1.0, true)
		_ellipse(point + Vector2(0, -23), Vector2(13, 5), Color("b09a69"))
		_ellipse(point + Vector2(0, -24), Vector2(9, 3), Color("20282a") if kind == "oil" else Color("71a4a5"))
		draw_line(point + Vector2(-14, -15), point + Vector2(14, -15), Color("aaad9b"), 3.0, true)
		draw_line(point + Vector2(-14, 0), point + Vector2(14, 0), Color("aaad9b"), 3.0, true)
		_polygon([Vector2(0, -14), Vector2(-4, -7), Vector2(0, -4), Vector2(4, -7)], point, Color("e0c981") if kind == "oil" else Color("b6e0dc"))
	elif kind == "grain":
		_polygon([Vector2(-22, -30), Vector2(22, -30), Vector2(22, 8), Vector2(-22, 8)], point, Color("a08b66"), Color("303229"))
		for x in [-16, -5, 6, 17]:
			draw_line(point + Vector2(x, -27), point + Vector2(x, 5), Color("6c644c"), 2.0)
		_polygon([Vector2(-27, -28), Vector2(0, -49), Vector2(28, -28)], point, Color("776443"), Color("30332c"))
		for index in range(4):
			draw_line(point + Vector2(-19 + index * 6, -28), point + Vector2(0 + index * 5, -41 + index * 4), Color("b19b68"), 1.0)
		draw_rect(Rect2(point + Vector2(-6, -12), Vector2(13, 20)), Color("323c32"))
		_ellipse(point + Vector2(15, 5), Vector2(6, 9), Color("c4ae78"))
		draw_line(point + Vector2(11, -2), point + Vector2(18, -2), Color("695c40"), 1.5)
		_text("粮仓", point + Vector2(-18, -55), 12, IVORY)
	else:
		for index in range(4):
			var base := point + Vector2(-19 + index * 12, 0)
			_polygon([Vector2(-4, 5), Vector2(-4, -23), Vector2(0, -32), Vector2(4, -24), Vector2(4, 5)], base, Color("9e8058"), Color("3c3c30"))
			draw_line(base + Vector2(0, -21), base + Vector2(0, 3), Color("d0b082"), 1.0)
		draw_line(point + Vector2(-25, -9), point + Vector2(25, -18), Color("62573b"), 5.0, true)
	var ratio: float = clampf(float(prop.get("hp", 0)) / maxf(1.0, float(prop.get("max_hp", 1))), 0.0, 1.0)
	draw_rect(Rect2(point + Vector2(-17, 12), Vector2(34, 3)), Color("152020"))
	draw_rect(Rect2(point + Vector2(-17, 12), Vector2(34 * ratio, 3)), Color("af9662"))

func _draw_unit(unit: Dictionary) -> void:
	var unit_id: String = str(unit.get("id", ""))
	var point: Vector2 = _unit_display_point(unit)
	var selected: bool = unit_id == _selected
	var allied: bool = str(unit.get("team", "enemy")) == "player"
	var accent: Color = ALLY if allied else ENEMY
	if int(unit.get("hp", 0)) <= 0:
		_ellipse(point, Vector2(16, 6), Color("272b27"))
		draw_line(point + Vector2(-8, -7), point + Vector2(8, 5), Color("a28b69"), 3.0)
		draw_line(point + Vector2(8, -7), point + Vector2(-8, 5), Color("a28b69"), 3.0)
		return
	if _flashes.has(unit_id):
		point.x += sin(_clock * 95.0) * 2.5
		accent = accent.lerp(IVORY, 0.45)
	_ellipse(point + Vector2(2, 5), Vector2(25, 10), Color(0.0, 0.0, 0.0, 0.40))
	if selected:
		_ellipse(point + Vector2(0, 0), Vector2(27, 11), Color("a1d0c5"))
	_ellipse(point + Vector2(0, 2), Vector2(22, 9), Color("131d21"))
	_ellipse(point, Vector2(22, 8), accent.darkened(0.23))
	_ellipse(point + Vector2(0, -2), Vector2(19, 6), Color("6b7465"))
	var kind: String = str(unit.get("kind", "guard"))
	var body: Vector2 = point + Vector2(0, -4)
	if kind == "dog":
		_draw_dog(body, accent, allied)
	else:
		_draw_humanoid(body, kind, accent, allied)
	_draw_bars(unit, point)
	if (not selected) and _hover.x == int(unit.get("q", -2)) and _hover.y == int(unit.get("r", -2)):
		var name_text: String = str(unit.get("name", "佣兵"))
		_text(name_text, point + Vector2(-49, -64), 12, IVORY, 98, HORIZONTAL_ALIGNMENT_CENTER)
	var statuses: Dictionary = unit.get("statuses", {})
	if not statuses.is_empty():
		draw_circle(point + Vector2(27, -28), 6.0, Color("202725"))
		_text("!", point + Vector2(24, -24), 13, Color("e4bc6e"))

func _unit_display_point(unit: Dictionary) -> Vector2:
	var unit_id: String = str(unit.get("id", ""))
	var point: Vector2 = _hex_center(int(unit.get("q", 0)), int(unit.get("r", 0)))
	if not _motions.has(unit_id):
		return point
	var motion: Dictionary = _motions[unit_id]
	var progress: float = clampf(float(motion["time"]) / float(motion["duration"]), 0.0, 1.0)
	if str(motion["kind"]) == "attack":
		return (motion["from"] as Vector2).lerp(motion["to"], sin(progress * PI))
	point = (motion["from"] as Vector2).lerp(motion["to"], progress * progress * (3.0 - 2.0 * progress))
	point.y -= sin(progress * PI) * 5.0
	return point

func _draw_active_indicator() -> void:
	if not str(_battle.get("outcome", "")).is_empty():
		return
	var unit: Dictionary = _unit_by_id(_active_id())
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return
	var point := _unit_display_point(unit)
	# Deliberately drawn after depth-sorted pieces: a foreground unit cannot hide whose turn it is.
	_ellipse_outline(point + Vector2(0, 2), Vector2(33, 13), Color(GOLD, 0.86), 2.2)
	_ellipse_outline(point + Vector2(0, 2), Vector2(27, 10), Color(IVORY, 0.90), 1.2)
	for offset_x in [-31.0, 31.0]:
		_draw_diamond(point + Vector2(offset_x, 2), 4.0, GOLD, 1.5)
	var tag_top := clampf(point.y - 96.0, 63.0, 470.0)
	var arrow_origin := Vector2(point.x, tag_top + 22.0)
	_polygon([Vector2(-6, 0), Vector2(6, 0), Vector2(0, 10)], arrow_origin, GOLD, INK)
	draw_rect(Rect2(Vector2(point.x - 60, tag_top), Vector2(120, 19)), Color("162022"))
	draw_rect(Rect2(Vector2(point.x - 60, tag_top), Vector2(120, 19)), GOLD, false, 1.2)
	var role_names := {"guard": "盾卫", "spear": "长枪", "archer": "弓手", "hunter": "猎人", "skirmisher": "游击", "raider": "劫掠", "dog": "战犬"}
	var label := "%s · %s" % [str(unit.get("name", "佣兵")), str(role_names.get(str(unit.get("kind", "")), "佣兵"))]
	if label.length() > 13:
		label = label.substr(0, 12) + "…"
	_text(label, Vector2(point.x - 56, tag_top + 14), 12, IVORY, 112, HORIZONTAL_ALIGNMENT_CENTER)

func _ellipse_outline(center: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, width, true)

func _draw_humanoid(point: Vector2, kind: String, accent: Color, allied: bool) -> void:
	var steel := Color("909b98")
	var dark_steel := Color("536368")
	var skin := Color("c7a37e") if allied else Color("ba9676")
	# A tapered cloak and shoulders keep the silhouette legible above a small base.
	_polygon([Vector2(-14, -33), Vector2(-22, -5), Vector2(-8, 2), Vector2(13, 0), Vector2(21, -7), Vector2(13, -33)], point, accent.darkened(0.32), INK)
	_polygon([Vector2(-15, -32), Vector2(-11, -10), Vector2(0, -5), Vector2(12, -11), Vector2(16, -32), Vector2(7, -39), Vector2(-8, -39)], point, dark_steel if kind in ["guard", "spear"] else Color("716349"), INK)
	_polygon([Vector2(-18, -34), Vector2(-24, -28), Vector2(-21, -20), Vector2(-11, -23), Vector2(-10, -32)], point, steel if kind == "guard" else accent, INK)
	_polygon([Vector2(12, -33), Vector2(21, -29), Vector2(24, -20), Vector2(14, -20), Vector2(9, -29)], point, steel if kind == "guard" else accent, INK)
	draw_line(point + Vector2(-9, -29), point + Vector2(8, -14), Color("b59866"), 3.0, true)
	draw_line(point + Vector2(-11, -12), point + Vector2(12, -12), Color("2c3330"), 4.0, true)
	draw_rect(Rect2(point + Vector2(-2, -15), Vector2(6, 6)), GOLD)
	_polygon([Vector2(-7, -48), Vector2(-8, -41), Vector2(-5, -34), Vector2(4, -33), Vector2(9, -41), Vector2(7, -49)], point, skin, INK)
	if kind in ["guard", "spear"]:
		_polygon([Vector2(-10, -43), Vector2(-10, -53), Vector2(-5, -58), Vector2(5, -58), Vector2(11, -52), Vector2(11, -42), Vector2(7, -43), Vector2(7, -50), Vector2(-7, -50), Vector2(-7, -43)], point, steel, INK)
		draw_line(point + Vector2(-8, -50), point + Vector2(10, -50), Color("d0d1b7"), 1.5)
		draw_line(point + Vector2(1, -51), point + Vector2(1, -40), dark_steel, 3.0)
	elif kind in ["archer", "hunter"]:
		_polygon([Vector2(-12, -39), Vector2(-13, -49), Vector2(-5, -60), Vector2(7, -57), Vector2(14, -44), Vector2(9, -35), Vector2(6, -47), Vector2(-4, -51), Vector2(-8, -41)], point, accent.darkened(0.25), INK)
		# Fletched arrows behind the shoulder distinguish bow users.
		for index in range(3):
			var tail := point + Vector2(-20 + index * 3, -51 - index * 2)
			draw_line(tail, tail + Vector2(7, 27), Color("c5b17c"), 1.3)
			draw_line(tail + Vector2(-3, -2), tail + Vector2(2, 4), IVORY, 2.0)
	else:
		_polygon([Vector2(-10, -43), Vector2(-11, -52), Vector2(-7, -56), Vector2(-3, -53), Vector2(3, -58), Vector2(10, -53), Vector2(12, -44), Vector2(6, -48), Vector2(-4, -48)], point, Color("49423b"), INK)
		if kind == "raider":
			_polygon([Vector2(-9, -38), Vector2(-5, -30), Vector2(3, -28), Vector2(8, -39), Vector2(0, -36)], point, Color("60513f"))
	draw_line(point + Vector2(-5, -44), point + Vector2(-2, -44), INK, 1.5)
	draw_line(point + Vector2(4, -44), point + Vector2(7, -44), INK, 1.5)
	if kind == "guard":
		_polygon([Vector2(-30, -29), Vector2(-17, -33), Vector2(-6, -29), Vector2(-8, -10), Vector2(-17, 0), Vector2(-27, -8)], point, accent, Color("c2b897"))
		draw_line(point + Vector2(-18, -28), point + Vector2(-17, -6), GOLD, 2.0)
		draw_line(point + Vector2(-25, -18), point + Vector2(-11, -18), GOLD, 2.0)
		_ellipse(point + Vector2(-18, -18), Vector2(4, 5), steel)
		draw_line(point + Vector2(22, -6), point + Vector2(29, -37), steel, 4.0, true)
		draw_line(point + Vector2(18, -12), point + Vector2(28, -9), GOLD, 3.0)
	elif kind == "spear":
		draw_line(point + Vector2(23, 1), point + Vector2(31, -64), Color("b39463"), 3.0, true)
		_polygon([Vector2(31, -75), Vector2(25, -62), Vector2(30, -56), Vector2(35, -64)], point, Color("c7cfbc"), INK)
		draw_line(point + Vector2(17, -25), point + Vector2(28, -27), skin, 5.0, true)
	elif kind in ["archer", "hunter"]:
		var bow := PackedVector2Array([point + Vector2(24, -49), point + Vector2(31, -37), point + Vector2(32, -22), point + Vector2(25, -5)])
		draw_polyline(bow, Color("c2a376"), 3.0, true)
		draw_line(point + Vector2(24, -49), point + Vector2(25, -5), Color("d9ceb0"), 1.0, true)
		draw_line(point + Vector2(17, -25), point + Vector2(28, -26), skin, 4.0, true)
	else:
		draw_line(point + Vector2(19, -13), point + Vector2(32, -42), Color("aa8958"), 3.0, true)
		if kind == "raider":
			_polygon([Vector2(30, -45), Vector2(38, -44), Vector2(43, -31), Vector2(31, -34), Vector2(25, -38)], point, steel, INK)
		else:
			_polygon([Vector2(29, -41), Vector2(36, -52), Vector2(35, -37), Vector2(30, -33)], point, Color("d1d0b9"), INK)

func _draw_dog(point: Vector2, accent: Color, allied: bool) -> void:
	var fur := Color("aa9674") if allied else Color("897562")
	_polygon([Vector2(-25, -14), Vector2(-20, -23), Vector2(-3, -25), Vector2(9, -20), Vector2(18, -28), Vector2(29, -23), Vector2(30, -16), Vector2(20, -12), Vector2(11, -9), Vector2(-10, -8)], point, fur, INK)
	_polygon([Vector2(12, -22), Vector2(11, -38), Vector2(19, -28), Vector2(25, -34), Vector2(27, -21)], point, fur.darkened(0.12), INK)
	_polygon([Vector2(-21, -12), Vector2(-22, -1), Vector2(-15, 0), Vector2(-14, -11)], point, fur.darkened(0.18), INK)
	_polygon([Vector2(4, -13), Vector2(9, -1), Vector2(15, -1), Vector2(12, -14)], point, fur.darkened(0.18), INK)
	draw_polyline(PackedVector2Array([point + Vector2(-22, -19), point + Vector2(-30, -27), point + Vector2(-29, -32)]), fur, 5.0, true)
	_polygon([Vector2(-12, -25), Vector2(3, -24), Vector2(7, -11), Vector2(-12, -10)], point, accent, Color("c4b38a"))
	draw_line(point + Vector2(12, -22), point + Vector2(17, -14), Color("ac6b43"), 3.0)
	draw_circle(point + Vector2(23, -24), 1.6, INK)
	draw_circle(point + Vector2(30, -19), 2.2, INK)

func _draw_bars(unit: Dictionary, point: Vector2) -> void:
	var hp: float = clampf(float(unit.get("hp", 0)) / maxf(1.0, float(unit.get("max_hp", 1))), 0.0, 1.0)
	var armor: float = clampf(float(unit.get("armor", 0)) / maxf(1.0, float(unit.get("max_armor", 1))), 0.0, 1.0)
	draw_rect(Rect2(point + Vector2(-20, 11), Vector2(40, 5)), Color("142020"))
	draw_rect(Rect2(point + Vector2(-19, 12), Vector2(38 * hp, 3)), Color("a8b889") if hp > 0.35 else Color("cf8061"))
	draw_rect(Rect2(point + Vector2(-20, 17), Vector2(40, 4)), Color("142020"))
	draw_rect(Rect2(point + Vector2(-19, 18), Vector2(38 * armor, 2)), Color("98b8bc"))
	if str(unit.get("id", "")) == _selected:
		for index in range(int(unit.get("max_ap", 6))):
			draw_circle(point + Vector2(-15 + index * 6, 26), 1.8, GOLD if index < int(unit.get("ap", 0)) else Color("454e43"))

func _active_id() -> String:
	var order: Array = _battle.get("order", [])
	var index: int = int(_battle.get("turn_index", 0))
	if index >= 0 and index < order.size():
		return str(order[index])
	return ""

func _draw_effects() -> void:
	for effect in _rings:
		var ratio: float = float(effect["time"]) / float(effect["duration"])
		var color: Color = effect["color"]
		color.a = 1.0 - ratio
		draw_arc(effect["point"], 8.0 + ratio * 33.0, 0.0, TAU, 32, color, 2.0, true)
	for effect in _floating:
		var ratio: float = float(effect["time"]) / float(effect["duration"])
		var point: Vector2 = effect["point"]
		point += Vector2(-70, -49 - ratio * 32.0)
		var color: Color = effect["color"]
		color.a = 1.0 - ratio * ratio
		_text(str(effect["text"]), point + Vector2(1, 1), 16, Color(0.05, 0.08, 0.08, color.a), 140, HORIZONTAL_ALIGNMENT_CENTER)
		_text(str(effect["text"]), point, 16, color, 140, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_legend() -> void:
	var items: Array = [["油", Color("b39a62")], ["水", Color("86b9bd")], ["火", Color("d88a51")], ["汽", Color("b2c8ba")]]
	for index in range(items.size()):
		var point := Vector2(37 + index * 43, 519)
		_polygon([Vector2(0, -7), Vector2(5, -2), Vector2(0, 3), Vector2(-5, -2)], point, items[index][1])
		_text(str(items[index][0]), point + Vector2(9, 3), 12, IVORY)
	_text("上条生命 · 下条护甲 · 双环/箭头=当前回合", Vector2(220, 522), 11, Color("a6ae98"))
	draw_circle(Vector2(37, 541), 2.2, MOVE_HINT)
	_text("移动", Vector2(44, 545), 11, IVORY)
	_draw_diamond(Vector2(92, 540), 5.0, RANGE_HINT, 1.2)
	_text("射程", Vector2(101, 545), 11, IVORY)
	draw_line(Vector2(151, 535), Vector2(161, 545), BLOCKED_HINT, 1.8, true)
	draw_line(Vector2(161, 535), Vector2(151, 545), BLOCKED_HINT, 1.8, true)
	_text("遮挡", Vector2(166, 545), 11, IVORY)
	_draw_target_reticle(Vector2(218, 540), 5.5)
	_text("合法", Vector2(242, 545), 11, IVORY)
	_text("▱ 波及", Vector2(291, 545), 11, IMPACT_HINT)
	_text(str(_action_overlay.get("action_name", "")), Vector2(558, 545), 11, RANGE_HINT, 210, HORIZONTAL_ALIGNMENT_RIGHT)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _polygon(vertices: Array, origin: Vector2, fill: Color, outline: Color = Color.TRANSPARENT) -> void:
	var points := PackedVector2Array()
	for vertex in vertices:
		points.append(origin + vertex)
	draw_colored_polygon(points, fill)
	if outline.a > 0.0:
		points.append(points[0])
		draw_polyline(points, outline, 1.3, true)

func _text(value: String, point: Vector2, font_size: int, color: Color, width: float = -1.0, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font, point, value, alignment, width, font_size, color)
