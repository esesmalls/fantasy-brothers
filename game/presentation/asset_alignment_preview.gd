extends Control
const Visuals = preload("res://presentation/asset_visuals.gd")
signal edit_started
signal edit_changed(world_offset: Vector2, uniform_scale: float)

var original: Dictionary = {}
var aligned: Dictionary = {}
var source := ""
var target := ""
var adaptation := ""
var base_dir := ""
var editable := false
var view_origin := Vector2.ZERO
var view_zoom := 1.0
var screen_target_quad := PackedVector2Array()
var drag_mode := ""
var drag_start := Vector2.ZERO
var drag_center := Vector2.ZERO
var drag_handle := Vector2.ZERO
var drag_view_origin := Vector2.ZERO
var drag_view_zoom := 1.0

func show_pair(before: Dictionary, after: Dictionary, source_id: String, target_id: String, scope: String, images_dir: String, can_edit: bool = false) -> void:
	if target_id != target or not can_edit: drag_mode = ""
	original = before
	aligned = after
	source = source_id
	target = target_id
	adaptation = scope
	base_dir = images_dir
	editable = can_edit
	queue_redraw()

func _outline(points: PackedVector2Array, origin: Vector2, zoom: float, color: Color) -> void:
	var path := PackedVector2Array()
	for point in points: path.append(origin + point * zoom)
	path.append(path[0])
	draw_polyline(path, color, 2.0, true)

func _anchors_for(data: Dictionary, id: String) -> Dictionary:
	var asset := Visuals.resolve(data, id, adaptation)
	var parent: String = str(asset.get("parent", ""))
	if parent.is_empty() or not data.assets.has(parent): return {}
	var owner := Visuals.resolve(data, parent, adaptation)
	var anchor: String = str(asset.get("anchor", "origin"))
	if not owner.get("anchors", {}).has(anchor): return {}
	var point := Visuals.vector(owner.anchors[anchor])
	return {parent + ":" + anchor: Visuals.world_transform(data, parent, adaptation) * Transform2D(0.0, point)}

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("202226"))
	if source.is_empty() or target.is_empty() or original.is_empty() or aligned.is_empty(): return
	var source_quad := Visuals.quad(Visuals.resolve(original, source, adaptation), Visuals.world_transform(original, source, adaptation))
	var before_quad := Visuals.quad(Visuals.resolve(original, target, adaptation), Visuals.world_transform(original, target, adaptation))
	var after_quad := Visuals.quad(Visuals.resolve(aligned, target, adaptation), Visuals.world_transform(aligned, target, adaptation))
	var bounds := Rect2(source_quad[0], Vector2.ZERO)
	for polygon in [source_quad, before_quad, after_quad]:
		for point in polygon: bounds = bounds.expand(point)
	var zoom := clampf(minf((size.x - 30) / maxf(1, bounds.size.x), (size.y - 30) / maxf(1, bounds.size.y)), 0.2, 12.0)
	var origin := size * 0.5 - bounds.get_center() * zoom
	if not drag_mode.is_empty(): origin = drag_view_origin; zoom = drag_view_zoom
	view_origin = origin; view_zoom = zoom
	Visuals.draw(self, original, [source], origin, zoom, base_dir, adaptation, {}, 0, _anchors_for(original, source), false, 0.4)
	Visuals.draw(self, original, [target], origin, zoom, base_dir, adaptation, {}, 0, _anchors_for(original, target), false, 0.2)
	Visuals.draw(self, aligned, [target], origin, zoom, base_dir, adaptation, {}, 0, _anchors_for(aligned, target), false, 0.85)
	_outline(source_quad, origin, zoom, Color("e5c47a"))
	_outline(before_quad, origin, zoom, Color("8995a6"))
	_outline(after_quad, origin, zoom, Color("79b4f5"))
	screen_target_quad = PackedVector2Array()
	for point in after_quad: screen_target_quad.append(origin + point * zoom)
	if editable: draw_rect(Rect2(screen_target_quad[2] - Vector2(6, 6), Vector2(12, 12)), Color("79b4f5"))

func _gui_input(event: InputEvent) -> void:
	if not editable: return
	if event is InputEventMouseButton:
		var click := event as InputEventMouseButton
		if click.button_index != MOUSE_BUTTON_LEFT: return
		if click.pressed:
			if screen_target_quad.size() != 4: return
			if click.position.distance_to(screen_target_quad[2]) <= 12.0: drag_mode = "scale"
			elif Geometry2D.is_point_in_polygon(click.position, screen_target_quad): drag_mode = "move"
			else: return
			drag_start = click.position
			drag_center = (screen_target_quad[0] + screen_target_quad[2]) * 0.5
			drag_handle = screen_target_quad[2]
			drag_view_origin = view_origin; drag_view_zoom = view_zoom
			edit_started.emit(); accept_event()
		elif not drag_mode.is_empty():
			_emit_edit(click.position)
			drag_mode = ""; queue_redraw(); accept_event()
	elif event is InputEventMouseMotion and not drag_mode.is_empty():
		_emit_edit((event as InputEventMouseMotion).position)
		accept_event()

func _emit_edit(pointer: Vector2) -> void:
	if drag_mode == "move":
		edit_changed.emit((pointer - drag_start) / drag_view_zoom, 1.0)
	elif drag_mode == "scale":
		var ray := drag_handle - drag_center
		var factor := (pointer - drag_center).dot(ray) / maxf(ray.length_squared(), 1.0)
		edit_changed.emit(Vector2.ZERO, clampf(factor, 0.05, 8.0))
