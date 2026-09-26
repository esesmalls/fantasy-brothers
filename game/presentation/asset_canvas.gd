extends Control
const Visuals = preload("res://presentation/asset_visuals.gd")
const Runtime = preload("res://presentation/asset_runtime.gd")
var ui: Control
var zoom := 4.0
var pan := Vector2.ZERO
var mode := "move"
var grid := true
var snap := false
var individual := false
var dragging := false
var boxing := false
var panning := false
var start := Vector2.ZERO
var current := Vector2.ZERO
var original: Dictionary = {}
var center := Vector2.ZERO
var additive := false
var context := PopupMenu.new()
var context_ids: Array = []
var preview := "组合"
var ghost := false
var ghost_alpha := 0.25
var cached_context: Dictionary = {}

func _ready() -> void:
	clip_contents = true; focus_mode = Control.FOCUS_ALL
	add_child(context)
	context.id_pressed.connect(func(index): ui.select([context_ids[index]]))

func origin() -> Vector2:
	return size * Vector2(0.5, 0.62) + pan

func logical(point: Vector2) -> Vector2:
	return (point - origin()) / zoom

func action() -> Dictionary:
	return ui.current_action() if ui.animation_mode else {}

func ids() -> Array:
	var result := []
	var candidates: Array = ui.doc.data.editor.scene
	if preview == "单件" and not ui.placement_selected: candidates = ui.selected
	for id in candidates:
		if ui.doc.data.assets.has(id) and id not in ui.doc.data.editor.hidden and (ui.solo.is_empty() or id in ui.solo): result.append(id)
	return result

func anchors_for(visible: Array) -> Dictionary:
	# Hidden reference parents still supply explicit anchors, never implicit rendering.
	var result := {}
	for id: String in visible:
		var a: Dictionary = ui.doc.asset(id, ui.adaptation)
		var parent: String = a.get("parent", "")
		if not parent.is_empty() and ui.doc.data.assets.has(parent):
			var owner: Dictionary = ui.doc.asset(parent, ui.adaptation)
			var point := Visuals.vector(owner.anchors.get(a.anchor, [0, 0]))
			result[parent + ":" + a.anchor] = Visuals.world_transform(ui.doc.data, parent, ui.adaptation, action(), ui.time) * Transform2D(0.0, point)
	return result

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("202226"))
	var at := origin()
	if grid:
		for x in range(-12, 13):
			for y in range(-8, 9):
				var point := at + Vector2(x * sqrt(3.0) * 34 + (sqrt(3.0) * 17 if y % 2 else 0), y * 51) * zoom
				var polygon := PackedVector2Array()
				for i in range(7): polygon.append(point + Vector2.from_angle(deg_to_rad(30 + 60 * i)) * 34 * zoom)
				draw_polyline(polygon, Color("32363d"), 1, true)
	draw_line(at - Vector2(12, 0), at + Vector2(12, 0), Color("c1786a"))
	draw_line(at - Vector2(0, 12), at + Vector2(0, 12), Color("78a58b"))
	var visible := ids()
	if ghost:
		var reference: Dictionary = ui.doc.data.duplicate(true); reference.assets = ui.doc.data.baseline.duplicate(true)
		Visuals.draw(self, reference, visible.filter(func(id): return reference.assets.has(id)), at, zoom, ui.doc.base_dir, "", {}, 0, anchors_for(visible), false, ghost_alpha)
	var errors := Visuals.draw(self, ui.doc.data, visible, at, zoom, ui.doc.base_dir, ui.adaptation, action(), ui.time, anchors_for(visible))
	Runtime.draw_arrow(self, ui.doc.data, visible, at, zoom, ui.doc.base_dir, ui.adaptation, action(), ui.time)
	if not errors.is_empty(): draw_string(get_theme_default_font(), Vector2(16, 30), str(errors[0]), HORIZONTAL_ALIGNMENT_LEFT, size.x - 32, 14, Color("edaf79"))
	if preview == "战场":
		Visuals.draw(self, ui.doc.data, visible, Vector2(90, size.y - 45), 1, ui.doc.base_dir, ui.adaptation, action(), ui.time, anchors_for(visible))
		draw_string(get_theme_default_font(), Vector2(25, size.y - 15), "1× 游戏尺寸", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("aeb5c1"))
	for id: String in ui.selected:
		if not ui.doc.data.assets.has(id): continue
		var a: Dictionary = ui.doc.asset(id, ui.adaptation)
		var transform := Visuals.world_transform(ui.doc.data, id, ui.adaptation, action(), ui.time)
		var polygon := Visuals.quad(a, transform)
		for i in range(polygon.size()): polygon[i] = at + polygon[i] * zoom
		polygon.append(polygon[0]); draw_polyline(polygon, Color("79b4f5"), 1.5, true)
		var pivot := at + transform.origin * zoom
		draw_circle(pivot, 3, Color("79b4f5"))
	if not ui.selected.is_empty() or ui.placement_selected:
		var pivot := at + selection_center() * zoom
		if mode == "move":
			draw_line(pivot, pivot + Vector2(34, 0), Color("e49a8b"), 2)
			draw_line(pivot, pivot + Vector2(0, -34), Color("8ecbad"), 2)
		elif mode == "rotate": draw_arc(pivot, 38, 0, TAU, 48, Color("79b4f5"), 2, true)
		elif mode == "scale": draw_rect(Rect2(pivot - Vector2(5, 5), Vector2(10, 10)), Color("79b4f5"), false, 2)
	if boxing: draw_rect(Rect2(start, current - start).abs(), Color(0.4, 0.65, 1, 0.15)); draw_rect(Rect2(start, current - start).abs(), Color("79b4f5"), false)

func selection_center() -> Vector2:
	if ui.placement_selected: return Visuals.placement(ui.doc.data)
	var point := Vector2.ZERO
	for id: String in ui.selected: point += Visuals.world_transform(ui.doc.data, id, ui.adaptation, action(), ui.time).origin
	return point / max(1, ui.selected.size())

func focus_selection() -> void:
	pan = -selection_center() * zoom
	queue_redraw()

func fit() -> void:
	var bounds := Rect2()
	var first := true
	for id: String in ids():
		for point: Vector2 in Visuals.quad(ui.doc.asset(id, ui.adaptation), Visuals.world_transform(ui.doc.data, id, ui.adaptation)):
			if first: bounds = Rect2(point, Vector2.ONE); first = false
			else: bounds = bounds.expand(point)
	zoom = clampf(minf((size.x - 100) / maxf(1, bounds.size.x), (size.y - 100) / maxf(1, bounds.size.y)), 0.1, 12)
	pan = size * Vector2(0, -0.12) - bounds.get_center() * zoom
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var before := logical(event.position)
			zoom = clampf(zoom * (1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.15), 0.1, 24)
			pan += event.position - (origin() + before * zoom); queue_redraw(); accept_event(); return
		if event.button_index == MOUSE_BUTTON_MIDDLE or (event.button_index == MOUSE_BUTTON_LEFT and Input.is_key_pressed(KEY_SPACE)):
			panning = event.pressed; grab_focus(); accept_event(); return
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			context_ids = Visuals.hits(ui.doc.data, ids(), logical(event.position), ui.doc.base_dir, ui.adaptation, action(), ui.time)
			context.clear()
			for id in context_ids: context.add_item(ui.doc.asset(id).name)
			context.position = Vector2i(get_global_mouse_position()); context.popup(); return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		if event.pressed:
			grab_focus(); start = event.position; current = start; additive = event.shift_pressed
			if ui.placement_selected and not event.ctrl_pressed and not event.shift_pressed:
				if ui.animation_mode or mode != "move":
					ui.message("人物整体只在基础姿态下平移；请使用移动工具。"); return
				original = ui.doc.data.duplicate(true); center = selection_center(); dragging = true; return
			var hits := Visuals.hits(ui.doc.data, ids(), logical(start), ui.doc.base_dir, ui.adaptation, action(), ui.time)
			var hit: String = ""
			# Locked foreground still occludes the underlying object for selection.
			if not hits.is_empty() and hits[0] not in ui.doc.data.editor.locked: hit = hits[0]
			if event.ctrl_pressed and not hit.is_empty():
				var selection: Array = ui.selected.duplicate()
				if hit in selection: selection.erase(hit)
				else: selection.append(hit)
				ui.select(selection); return
			if hit.is_empty(): boxing = true; queue_redraw(); return
			if hit not in ui.selected: ui.select([hit])
			if mode == "select": return
			if ui.animation_mode and not ui.auto_key:
				ui.message("动作模式：启用自动关键帧后拖动，或使用时间轴手动落帧。")
				return
			original = ui.doc.data.duplicate(true); center = selection_center(); dragging = true
		else:
			if boxing: finish_box()
			if dragging:
				if ui.doc.data != original:
					ui.doc.history.append({"label": "画布变换", "data": original}); ui.doc.future.clear()
				dragging = false; ui.refresh()
		accept_event()
	elif event is InputEventMouseMotion:
		current = event.position
		if panning: pan += event.relative; queue_redraw()
		elif boxing: queue_redraw()
		elif dragging: transform_drag(); queue_redraw()

func transform_drag() -> void:
	ui.doc.data = original.duplicate(true)
	var delta := (current - start) / zoom
	if snap: delta = delta.snapped(Vector2.ONE)
	if ui.placement_selected:
		var offset := Visuals.placement(original) + delta
		ui.doc.data.game.placement = [offset.x, offset.y]; return
	var targets := []
	for id in ui.selected:
		if id not in ui.doc.data.editor.locked: targets.append(id)
	var roots := []
	for id: String in targets:
		var parent: String = ui.doc.asset(id, ui.adaptation).parent
		var carried := false
		while not parent.is_empty():
			if parent in targets: carried = true; break
			parent = str(ui.doc.asset(parent, ui.adaptation).get("parent", ""))
		if not carried: roots.append(id)
	targets = roots
	if ui.animation_mode:
		for id: String in targets:
			var state := Visuals.sample(original.actions[ui.action_id], id, ui.time)
			var parent: String = ui.doc.asset(id, ui.adaptation).parent
			var parent_transform := Transform2D.IDENTITY if parent.is_empty() else Visuals.world_transform(original, parent, ui.adaptation, original.actions[ui.action_id], ui.time)
			var local_delta := parent_transform.basis_xform_inv(delta)
			if mode != "move" and not individual:
				var world := Visuals.world_transform(original, id, ui.adaptation, original.actions[ui.action_id], ui.time)
				var angle := (logical(start) - center).angle_to(logical(current) - center)
				var factor := maxf(0.01, 1 + (current.x - start.x) / 150)
				var position := center + ((world.origin - center).rotated(angle) if mode == "rotate" else (world.origin - center) * factor)
				var offset := parent_transform.basis_xform_inv(position - world.origin)
				ui.put_key(id, "x", float(state.get("x", 0)) + offset.x, false)
				ui.put_key(id, "y", float(state.get("y", 0)) + offset.y, false)
			if mode == "move":
				ui.put_key(id, "x", float(state.get("x", 0)) + local_delta.x, false)
				ui.put_key(id, "y", float(state.get("y", 0)) + local_delta.y, false)
			elif mode == "rotate": ui.put_key(id, "rotation", float(state.get("rotation", 0)) + rad_to_deg((logical(start) - center).angle_to(logical(current) - center)), false)
			elif mode == "scale":
				var factor := maxf(0.01, 1 + (current.x - start.x) / 150)
				ui.put_key(id, "scale_x", float(state.get("scale_x", 1)) * factor, false)
				ui.put_key(id, "scale_y", float(state.get("scale_y", 1)) * factor, false)
		return
	if mode == "move": ui.doc.move_selection(targets, delta, original, ui.adaptation); return
	var angle := (logical(start) - center).angle_to(logical(current) - center)
	if snap: angle = snappedf(angle, deg_to_rad(15))
	var factor := maxf(0.01, 1 + (current.x - start.x) / 150)
	for id: String in targets:
		var a := Visuals.resolve(original, id, ui.adaptation)
		var parent: String = a.parent
		var ancestor := parent
		var carried := false
		while not ancestor.is_empty():
			if ancestor in targets: carried = true; break
			ancestor = str(Visuals.resolve(original, ancestor, ui.adaptation).get("parent", ""))
		if carried: continue
		var world := Visuals.world_transform(original, id, ui.adaptation)
		if not individual:
			var position := center + ((world.origin - center).rotated(angle) if mode == "rotate" else (world.origin - center) * factor)
			if not parent.is_empty():
				var owner := Visuals.resolve(original, parent, ui.adaptation)
				position = Visuals.world_transform(original, parent, ui.adaptation).affine_inverse() * position - Visuals.vector(owner.anchors.get(a.anchor, [0, 0]))
			else: position -= Visuals.placement(original)
			ui.doc.set_value(id, "position", [position.x, position.y], ui.adaptation)
		if mode == "rotate": ui.doc.set_value(id, "rotation", float(a.rotation) + rad_to_deg(angle), ui.adaptation)
		else: ui.doc.set_value(id, "scale", [a.scale[0] * factor, a.scale[1] * factor], ui.adaptation)

func finish_box() -> void:
	boxing = false
	var rect := Rect2(logical(start), (current - start) / zoom).abs()
	var result: Array = ui.selected.duplicate() if additive else []
	if start.distance_to(current) > 3:
		# Sample source opaque pixels after shared clipping; test frontmost visibility.
		var visible := ids()
		Visuals.hits(ui.doc.data, visible, rect.position, ui.doc.base_dir, ui.adaptation, action(), ui.time)
		for id: String in visible:
			if id in result or id in ui.doc.data.editor.locked: continue
			var asset: Dictionary = ui.doc.asset(id, ui.adaptation)
			var transform := Visuals.world_transform(ui.doc.data, id, ui.adaptation, action(), ui.time)
			var bounds := Rect2(transform.origin, Vector2.ZERO)
			for point in Visuals.quad(asset, transform): bounds = bounds.expand(point)
			if not rect.intersects(bounds): continue
			var intersection := rect.intersection(bounds)
			var step := maxf(0.15, 0.5 / zoom)
			var found := false
			var y := intersection.position.y
			while y <= intersection.end.y and not found:
				var x := intersection.position.x
				while x <= intersection.end.x:
					var hits := Visuals.hit_prepared(Vector2(x, y))
					if (id in hits if ui.through_box else not hits.is_empty() and hits[0] == id): found = true; break
					x += step
				y += step
			if found: result.append(id)
	ui.select(result)

func cancel_drag() -> void:
	if dragging: ui.doc.data = original; dragging = false; ui.refresh()
	boxing = false; panning = false; queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE: cancel_drag()
	if event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT and (dragging or boxing):
		# Release outside viewport must still finish the transaction.
		if not Rect2(Vector2.ZERO, size).has_point(get_local_mouse_position()): cancel_drag()
