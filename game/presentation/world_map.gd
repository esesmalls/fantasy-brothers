extends Control
## Read-only border-map presentation. Campaign rules own travel, discovery and contracts.

signal location_selected(location_id: String)

const DESIGN_SIZE := Vector2(920.0, 580.0)
const MAP_RECT := Rect2(Vector2(66.0, 62.0), Vector2(788.0, 436.0))
const INK := Color("26302b")
const DARK_INK := Color("18221f")
const PARCHMENT := Color("c9b98a")
const PARCHMENT_LIGHT := Color("ded1a2")
const LAND := Color("41543a")
const LAND_DARK := Color("304633")
const RIVER := Color("6e9b9a")
const ROAD := Color("765f3d")
const ROAD_UNWALKED := Color("91794c")
const IVORY := Color("ece1bd")
const GOLD := Color("c6a35f")
const MOSS := Color("213d32")

var _world: Dictionary = {}
var _font: SystemFont
var _scale := 1.0
var _offset := Vector2.ZERO
var _hover_id := ""

func _ready() -> void:
	custom_minimum_size = Vector2(700.0, 440.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Microsoft YaHei UI", "Noto Sans CJK SC", "Arial"])
	resized.connect(queue_redraw)
	mouse_exited.connect(_clear_hover)

## Expected keys: locations, edges, location_id, route_path, visited_ids and travel_status.
## Unknown keys are deliberately ignored so this stays a narrow presentation boundary.
func set_world(view: Dictionary) -> void:
	_world = view.duplicate(true)
	_hover_id = ""
	tooltip_text = ""
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	_layout()
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var location := _location_at(event.position)
		if not location.is_empty() and bool(location.get("discovered", false)):
			location_selected.emit(str(location.get("id", "")))
			accept_event()

func _update_hover(screen_point: Vector2) -> void:
	var location := _location_at(screen_point)
	var next_id := ""
	if not location.is_empty() and bool(location.get("discovered", false)):
		next_id = str(location.get("id", ""))
	if next_id == _hover_id:
		return
	_hover_id = next_id
	tooltip_text = _location_tooltip(location) if not next_id.is_empty() else ""
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if not next_id.is_empty() else Control.CURSOR_ARROW
	queue_redraw()

func _clear_hover() -> void:
	_hover_id = ""
	tooltip_text = ""
	mouse_default_cursor_shape = Control.CURSOR_ARROW
	queue_redraw()

func _layout() -> void:
	var available := size.max(Vector2(1.0, 1.0))
	_scale = maxf(0.01, minf(available.x / DESIGN_SIZE.x, available.y / DESIGN_SIZE.y))
	_offset = (available - DESIGN_SIZE * _scale) * 0.5

func _location_at(screen_point: Vector2) -> Dictionary:
	var point := (screen_point - _offset) / _scale
	var closest: Dictionary = {}
	var closest_distance := 28.0
	for item in _world.get("locations", []):
		if not item is Dictionary:
			continue
		var location: Dictionary = item
		var distance := point.distance_to(_location_point(location))
		if distance < closest_distance:
			closest_distance = distance
			closest = location
	return closest

func _location_point(location: Dictionary) -> Vector2:
	var x := clampf(float(location.get("x", 0.5)), 0.0, 1.0)
	var y := clampf(float(location.get("y", 0.5)), 0.0, 1.0)
	return MAP_RECT.position + Vector2(x * MAP_RECT.size.x, y * MAP_RECT.size.y)

func _location_by_id(location_id: String) -> Dictionary:
	for item in _world.get("locations", []):
		if item is Dictionary and str(item.get("id", "")) == location_id:
			return item
	return {}

func _draw() -> void:
	if _font == null:
		return
	_layout()
	draw_rect(Rect2(Vector2.ZERO, size), DARK_INK)
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))
	_draw_geography()
	_draw_routes()
	_draw_locations()
	_draw_labels()
	_draw_company_flag()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_geography() -> void:
	# These brush-like marks establish the borderland only; none expresses a gameplay rule.
	draw_rect(Rect2(Vector2(18.0, 16.0), DESIGN_SIZE - Vector2(36.0, 32.0)), PARCHMENT)
	draw_rect(Rect2(Vector2(24.0, 22.0), DESIGN_SIZE - Vector2(48.0, 44.0)), PARCHMENT_LIGHT, false, 2.0)
	draw_rect(MAP_RECT, LAND)
	_draw_parchment_flecks()
	_draw_river()
	_draw_ridges()
	_draw_forests()
	_draw_map_frame()

func _draw_parchment_flecks() -> void:
	for index in range(48):
		var point := Vector2(35.0 + float((index * 127) % 842), 31.0 + float((index * 79) % 511))
		draw_circle(point, 0.8 + float(index % 3) * 0.35, Color("9d8d63", 0.34))
	for index in range(14):
		var left := Vector2(30.0, 45.0 + float(index) * 34.0)
		draw_line(left, left + Vector2(10.0 + float(index % 3) * 5.0, -3.0), Color("8c7b56", 0.30), 0.9, true)

func _draw_river() -> void:
	var river := PackedVector2Array([
		Vector2(92.0, 124.0), Vector2(188.0, 148.0), Vector2(263.0, 210.0),
		Vector2(340.0, 247.0), Vector2(425.0, 305.0), Vector2(535.0, 324.0),
		Vector2(641.0, 377.0), Vector2(823.0, 435.0),
	])
	draw_polyline(river, Color("365e5d", 0.78), 20.0, true)
	draw_polyline(river, RIVER, 13.0, true)
	draw_polyline(river, Color("b6cfbf", 0.45), 1.2, true)
	for index in range(8):
		var point := river[index] + Vector2(10.0, 4.0)
		draw_arc(point, 6.0, 3.4, 5.9, 8, Color("d0d5b0", 0.42), 0.8, true)

func _draw_ridges() -> void:
	for index in range(7):
		var point := Vector2(548.0 + float(index) * 39.0, 145.0 + float((index % 3) * 20))
		var mountain := PackedVector2Array([point + Vector2(-27.0, 22.0), point, point + Vector2(28.0, 22.0)])
		draw_colored_polygon(mountain, Color("566052"))
		draw_polyline(mountain, Color("28352e"), 1.5, true)
		draw_line(point + Vector2(-7.0, 7.0), point + Vector2(1.0, 2.0), Color("b7b58e", 0.60), 1.2, true)
		draw_line(point + Vector2(1.0, 2.0), point + Vector2(9.0, 10.0), Color("b7b58e", 0.60), 1.2, true)

func _draw_forests() -> void:
	for cluster in range(4):
		var origin := Vector2(164.0 + float(cluster) * 157.0, 326.0 - float(cluster % 2) * 118.0)
		for tree in range(8):
			var point := origin + Vector2(float((tree * 23) % 74), float((tree * 37) % 52))
			_draw_tree(point, 0.72 + float(tree % 3) * 0.12, Color("264434") if tree % 2 == 0 else MOSS)

func _draw_tree(point: Vector2, tree_scale: float, tint: Color) -> void:
	draw_line(point + Vector2(0.0, 5.0) * tree_scale, point + Vector2(0.0, 16.0) * tree_scale, Color("554331"), 2.2 * tree_scale, true)
	var canopy := PackedVector2Array([
		point + Vector2(0.0, -18.0) * tree_scale,
		point + Vector2(-13.0, 5.0) * tree_scale,
		point + Vector2(13.0, 5.0) * tree_scale,
	])
	draw_colored_polygon(canopy, tint)
	draw_polyline(canopy, Color("172b22", 0.8), 0.9, true)

func _draw_map_frame() -> void:
	draw_rect(MAP_RECT.grow(7.0), Color("4b4733", 0.48), false, 2.2)
	draw_rect(MAP_RECT, Color("d7c990", 0.32), false, 1.1)
	draw_string(_font, Vector2(53.0, 48.0), "边境行图", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, DARK_INK)
	var status := str(_world.get("travel_status", ""))
	if not status.is_empty():
		var labels := {"idle": "驻扎营地", "traveling": "行军途中", "event": "途中抉择", "ready": "抵达战场", "battle": "战斗中", "returning": "准备返营", "completed": "已返营"}
		var text := "行程：" + str(labels.get(status, "行军途中"))
		var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_RIGHT, -1, 15).x
		draw_string(_font, Vector2(866.0 - width, 48.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("4c4938"))

func _draw_routes() -> void:
	var path: Array = _world.get("route_path", [])
	var visited: Array = _world.get("visited_ids", [])
	for item in _world.get("edges", []):
		if not item is Dictionary:
			continue
		var edge: Dictionary = item
		var from_id := str(edge.get("from", ""))
		var to_id := str(edge.get("to", ""))
		var from := _location_by_id(from_id)
		var to := _location_by_id(to_id)
		if from.is_empty() or to.is_empty():
			continue
		var is_current := _path_contains_edge(path, from_id, to_id)
		if not is_current and (not bool(from.get("discovered", false)) or not bool(to.get("discovered", false))):
			continue
		var a := _location_point(from)
		var b := _location_point(to)
		var is_visited := from_id in visited and to_id in visited
		if is_current:
			_draw_worn_route(a, b, Color("73ada0") if is_visited else Color("d8c57f"), 6.0, not is_visited)
		elif is_visited:
			_draw_worn_route(a, b, ROAD, 5.0, false)
		else:
			_draw_worn_route(a, b, ROAD_UNWALKED, 3.2, true)

func _path_contains_edge(path: Array, from_id: String, to_id: String) -> bool:
	for index in range(maxi(0, path.size() - 1)):
		var first := str(path[index])
		var second := str(path[index + 1])
		if (first == from_id and second == to_id) or (first == to_id and second == from_id):
			return true
	return false

func _draw_worn_route(a: Vector2, b: Vector2, tint: Color, width: float, dashed: bool) -> void:
	draw_line(a, b, Color("332f25", 0.72), width + 3.0, true)
	if not dashed:
		draw_line(a, b, tint, width, true)
		return
	var direction := a.direction_to(b)
	var distance := a.distance_to(b)
	for offset in range(0, int(distance), 16):
		var start := a + direction * float(offset)
		var finish := a + direction * minf(float(offset + 9), distance)
		draw_line(start, finish, tint, width, true)

func _draw_locations() -> void:
	for item in _world.get("locations", []):
		if not item is Dictionary:
			continue
		var location: Dictionary = item
		var point := _location_point(location)
		var discovered := bool(location.get("discovered", false))
		var is_hovered := str(location.get("id", "")) == _hover_id
		if discovered:
			draw_circle(point, 24.0 if is_hovered else 21.0, Color("1b2923", 0.78))
			draw_circle(point, 19.0 if is_hovered else 17.0, Color("d1bf82"))
			draw_arc(point, 21.0 if is_hovered else 19.0, 0.0, TAU, 20, IVORY if is_hovered else DARK_INK, 1.5, true)
			_draw_location_icon(point, str(location.get("kind", "")))
		else:
			draw_circle(point, 17.0, Color("26352c", 0.82))
			draw_arc(point, 17.0, 0.0, TAU, 16, Color("75806b"), 1.2, true)
			draw_string(_font, point + Vector2(-5.5, 6.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("c9c39a"))

func _draw_location_icon(point: Vector2, kind: String) -> void:
	var key := kind.to_lower()
	if key.contains("camp"):
		_draw_tent(point)
	elif key.contains("ferry") or key.contains("crossing"):
		_draw_ferry(point)
	elif key.contains("ridge") or key.contains("pass"):
		_draw_peak(point)
	elif key.contains("hunter") or key.contains("forest") or key.contains("wild"):
		_draw_hunter_mark(point)
	elif key.contains("granary") or key.contains("grain") or key.contains("contract"):
		_draw_granary(point)
	elif key.contains("bridge") or key.contains("landmark"):
		_draw_bridgehead(point)
	else:
		draw_circle(point, 5.0, DARK_INK)
		draw_circle(point, 2.0, IVORY)

func _draw_tent(point: Vector2) -> void:
	var tent := PackedVector2Array([point + Vector2(-11.0, 9.0), point + Vector2(0.0, -12.0), point + Vector2(12.0, 9.0)])
	draw_colored_polygon(tent, Color("526d68"))
	draw_polyline(tent, DARK_INK, 1.5, true)
	draw_line(point + Vector2(0.0, -10.0), point + Vector2(0.0, 10.0), Color("d8cfab"), 1.1, true)

func _draw_ferry(point: Vector2) -> void:
	draw_line(point + Vector2(-11.0, 7.0), point + Vector2(12.0, 7.0), DARK_INK, 3.0, true)
	draw_line(point + Vector2(-8.0, 2.0), point + Vector2(7.0, 2.0), Color("526d68"), 4.0, true)
	draw_line(point + Vector2(-2.0, 1.0), point + Vector2(-2.0, -12.0), DARK_INK, 1.4, true)
	draw_line(point + Vector2(-2.0, -11.0), point + Vector2(8.0, -5.0), Color("b75341"), 3.0, true)

func _draw_peak(point: Vector2) -> void:
	var peak := PackedVector2Array([point + Vector2(-12.0, 10.0), point + Vector2(-2.0, -12.0), point + Vector2(5.0, 2.0), point + Vector2(12.0, 10.0)])
	draw_colored_polygon(peak, Color("596154"))
	draw_polyline(peak, DARK_INK, 1.4, true)
	draw_line(point + Vector2(-2.0, -12.0), point + Vector2(2.0, -4.0), IVORY, 1.4, true)

func _draw_hunter_mark(point: Vector2) -> void:
	_draw_tree(point + Vector2(-4.0, 2.0), 0.56, Color("294633"))
	draw_arc(point + Vector2(8.0, -2.0), 6.0, 3.6, 5.7, 8, Color("d6c38b"), 1.5, true)
	draw_arc(point + Vector2(8.0, -2.0), 6.0, -2.5, -0.4, 8, Color("d6c38b"), 1.5, true)

func _draw_granary(point: Vector2) -> void:
	draw_rect(Rect2(point + Vector2(-10.0, -2.0), Vector2(20.0, 12.0)), Color("815d3e"))
	var roof := PackedVector2Array([point + Vector2(-13.0, -2.0), point + Vector2(0.0, -12.0), point + Vector2(13.0, -2.0)])
	draw_colored_polygon(roof, Color("4b3b2c"))
	draw_line(point + Vector2(0.0, -1.0), point + Vector2(0.0, 10.0), Color("d1b976"), 2.0, true)
	for x in [-6.0, 6.0]:
		draw_line(point + Vector2(x, 3.0), point + Vector2(x, 9.0), Color("d1b976"), 1.0, true)

func _draw_bridgehead(point: Vector2) -> void:
	draw_rect(Rect2(point + Vector2(-8.0, -13.0), Vector2(16.0, 20.0)), Color("677064"))
	draw_polyline(PackedVector2Array([point + Vector2(-10.0, -13.0), point + Vector2(-5.0, -18.0), point + Vector2(0.0, -13.0), point + Vector2(5.0, -18.0), point + Vector2(10.0, -13.0)]), DARK_INK, 1.2, true)
	draw_line(point + Vector2(-13.0, 10.0), point + Vector2(13.0, 10.0), Color("5b4330"), 3.0, true)

func _draw_labels() -> void:
	var destination_id := _contract_destination_id()
	for item in _world.get("locations", []):
		if not item is Dictionary:
			continue
		var location: Dictionary = item
		var point := _location_point(location)
		var label := str(location.get("name", "")) if bool(location.get("discovered", false)) else "未知地点"
		if label.is_empty():
			label = "未知地点"
		_draw_label(point, label, bool(location.get("discovered", false)))
		if str(location.get("id", "")) == destination_id:
			_draw_destination_tag(point)

func _draw_label(point: Vector2, label: String, discovered: bool) -> void:
	var font_size := 16
	var width := _font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var x := clampf(point.x - width * 0.5, MAP_RECT.position.x + 4.0, MAP_RECT.end.x - width - 4.0)
	var y := clampf(point.y + 43.0, MAP_RECT.position.y + 22.0, MAP_RECT.end.y - 5.0)
	draw_rect(Rect2(Vector2(x - 5.0, y - 18.0), Vector2(width + 10.0, 23.0)), Color("242d25", 0.78))
	draw_string(_font, Vector2(x, y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, IVORY if discovered else Color("b6b49a"))

func _contract_destination_id() -> String:
	var path: Array = _world.get("route_path", [])
	for index in range(path.size() - 1, -1, -1):
		var location := _location_by_id(str(path[index]))
		var kind := str(location.get("kind", "")).to_lower()
		if kind.contains("granary") or kind.contains("grain") or kind.contains("contract"):
			return str(location.get("id", ""))
	return ""

func _draw_destination_tag(point: Vector2) -> void:
	var text := "契约目的地"
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
	var x := clampf(point.x - width * 0.5, MAP_RECT.position.x + 3.0, MAP_RECT.end.x - width - 3.0)
	var y := clampf(point.y - 30.0, MAP_RECT.position.y + 16.0, MAP_RECT.end.y - 30.0)
	draw_rect(Rect2(Vector2(x - 5.0, y - 15.0), Vector2(width + 10.0, 20.0)), Color("5c3f2d", 0.92))
	draw_string(_font, Vector2(x, y), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("f0d58b"))

func _draw_company_flag() -> void:
	var current_id := str(_world.get("location_id", ""))
	var location := _location_by_id(current_id)
	if location.is_empty() or not bool(location.get("discovered", false)):
		return
	var point := _location_point(location)
	var pole := point + Vector2(23.0, -17.0)
	draw_line(pole, pole + Vector2(0.0, 31.0), DARK_INK, 2.0, true)
	var banner := PackedVector2Array([pole + Vector2(1.0, 1.0), pole + Vector2(19.0, 6.0), pole + Vector2(1.0, 13.0)])
	draw_colored_polygon(banner, Color("a84e3f"))
	draw_polyline(banner, Color("f0d187"), 1.0, true)
	draw_circle(pole, 3.0, GOLD)

func _location_tooltip(location: Dictionary) -> String:
	if location.is_empty() or not bool(location.get("discovered", false)):
		return ""
	var name := str(location.get("name", ""))
	var description := str(location.get("description", ""))
	return name if description.is_empty() else name + "\n" + description
