extends Control
var ui: Control
var selected: Array = []
var rows: Array = []
var scroll := 0
var dragging := false
var boxing := false
var start := Vector2.ZERO
var current := Vector2.ZERO
var before: Dictionary = {}
var pixels := 100.0
var scrubbing := false

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL; clip_contents = true

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("262930"))
	var action: Dictionary = ui.current_action()
	var duration := float(action.get("duration", 1))
	pixels = maxf(20, (size.x - 160) / duration)
	rows = []
	for track: Dictionary in action.get("tracks", []):
		if ui.selected.is_empty() or track.target in ui.selected: rows.append(track)
	scroll = clampi(scroll, 0, maxi(0, rows.size() - 3))
	for i in range(11):
		var x := 145 + i * (size.x - 160) / 10
		draw_line(Vector2(x, 22), Vector2(x, size.y), Color("363b44"))
		draw_string(get_theme_default_font(), Vector2(x, 16), "%.2f" % (duration * i / 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("aab3c1"))
	for index in range(scroll, mini(rows.size(), scroll + 4)):
		var track: Dictionary = rows[index]; var y := 42.0 + (index - scroll) * 25
		draw_string(get_theme_default_font(), Vector2(6, y + 4), track.target + " / " + track.property, HORIZONTAL_ALIGNMENT_LEFT, 135, 11, Color("cbd3df"))
		for key: Dictionary in track.keys:
			var x := 145 + float(key.time) * pixels
			var points := PackedVector2Array([Vector2(x, y - 5), Vector2(x + 5, y), Vector2(x, y + 5), Vector2(x - 5, y)])
			draw_colored_polygon(points, Color("ffd192") if key.id in selected else Color("82b6ee"))
	var playhead: float = 145 + ui.time * pixels
	draw_line(Vector2(playhead, 20), Vector2(playhead, size.y), Color("eec884"), 2)
	if boxing: draw_rect(Rect2(start, current - start).abs(), Color("79b4f5"), false)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			scroll += -1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1; queue_redraw(); return
		if event.button_index != MOUSE_BUTTON_LEFT: return
		if event.pressed:
			grab_focus(); ui.playing = false; start = event.position; current = start
			if event.position.y < 24:
				scrubbing = true
				ui.time = clampf((event.position.x - 145) / pixels, 0, float(ui.current_action().get("duration", 1))); ui.refresh_time(); return
			var hit := ""
			for index in range(scroll, mini(rows.size(), scroll + 4)):
				if rows[index].target in ui.doc.data.editor.locked: continue
				for key: Dictionary in rows[index].keys:
					if Vector2(145 + float(key.time) * pixels, 42 + (index - scroll) * 25).distance_to(start) < 8: hit = key.id
			if hit.is_empty():
				if not event.shift_pressed: selected.clear()
				boxing = true
			else:
				if event.ctrl_pressed:
					if hit in selected: selected.erase(hit)
					else: selected.append(hit)
				elif hit not in selected: selected = [hit]
				dragging = true; before = ui.doc.data.duplicate(true)
		else:
			if boxing:
				var rect := Rect2(start, current - start).abs()
				for index in range(scroll, mini(rows.size(), scroll + 4)):
					for key: Dictionary in rows[index].keys:
						if rect.has_point(Vector2(145 + float(key.time) * pixels, 42 + (index - scroll) * 25)) and key.id not in selected: selected.append(key.id)
			if dragging and ui.doc.data != before:
				var errors: Array = ui.doc.validate({}, false)
				if not errors.is_empty(): ui.doc.data = before; ui.message("关键帧不能重叠或超出时长")
				else: ui.doc.history.append({"label": "移动关键帧", "data": before}); ui.doc.future.clear()
			dragging = false; boxing = false; scrubbing = false; ui.refresh_time()
		queue_redraw(); accept_event()
	elif event is InputEventMouseMotion:
		current = event.position
		if scrubbing:
			ui.time = clampf((event.position.x - 145) / pixels, 0, float(ui.current_action().get("duration", 1))); ui.refresh_time()
		if dragging:
			ui.doc.data = before.duplicate(true)
			for track: Dictionary in ui.current_action().tracks:
				if track.target in ui.doc.data.editor.locked: continue
				for key: Dictionary in track.keys:
					if key.id in selected: key.time = clampf(float(key.time) + (current.x - start.x) / pixels, 0, float(ui.current_action().duration))
				track.keys.sort_custom(func(a, b): return a.time < b.time)
			ui.refresh_time()
		queue_redraw()

func copy_keys() -> void:
	if selected.is_empty(): return
	var original: Dictionary = ui.doc.data.duplicate(true)
	ui.doc.checkpoint("复制关键帧")
	var minimum := INF
	for track: Dictionary in ui.current_action().tracks:
		for key: Dictionary in track.keys:
			if key.id in selected: minimum = minf(minimum, key.time)
	for track: Dictionary in ui.current_action().tracks:
		var copies := []
		if track.target in ui.doc.data.editor.locked: continue
		for key: Dictionary in track.keys:
			if key.id in selected:
				var copy := key.duplicate(true); copy.id = "copy-" + str(randi()); copy.time = ui.time + float(key.time) - minimum; copies.append(copy)
		track.keys.append_array(copies); track.keys.sort_custom(func(a, b): return a.time < b.time)
	if not ui.doc.validate({}, false).is_empty(): ui.doc.data = original; ui.doc.history.pop_back(); ui.message("复制位置重叠或超出动作时长，请移动播放头后重试")
	ui.refresh_time()

func delete_keys() -> void:
	if selected.is_empty(): return
	ui.doc.checkpoint("删除关键帧")
	for track: Dictionary in ui.current_action().tracks:
		if track.target not in ui.doc.data.editor.locked: track.keys = track.keys.filter(func(key): return key.id not in selected)
	selected.clear(); ui.refresh_time()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if dragging: ui.doc.data = before
		dragging = false; boxing = false; scrubbing = false; ui.refresh_time()
