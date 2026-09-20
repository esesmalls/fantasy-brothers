extends Control
## Isolated A/B presentation review. It owns no battle or save state.

signal review_closed

const ACTOR_PATH := "res://presentation/hand_style_actor.gd"
const REQUIRED_ACTOR_RESOURCES := [
	"res://assets/art/motion/b-atlas-v2.png",
	"res://assets/art/motion/hand-style-parts.png",
	"res://assets/art/motion/hand-style-body.png"
]
const GOLD := Color("d2b36f")
const CREAM := Color("eee4cf")
const MUTED := Color("aab7b2")
const INK := Color("17201e")
const ARMOR_MAX := 24
const PRE_ROLL := 0.35
const POST_ROLL := 1.0

class ReviewCanvas extends Control:
	var actor_script: Variant
	var style_id := "a_hand"
	var style_name := "A · 精细自然握持"
	var action := "idle"
	var progress := 0.0
	var clock := 0.0
	var armor_damage := 0
	var effects_enabled := true
	var background_mode := "battle"
	var compact_only := false
	var unit := {
		"id": "hand_style_sample",
		"name": "H样板佣兵",
		"kind": "guard",
		"hp": 42,
		"max_hp": 42,
		"armor": ARMOR_MAX,
		"max_armor": ARMOR_MAX,
		"presentation_sample": true,
		"visual_loadout": {"weapon": "weapon_guard_sword", "armor": "armor_mail"}
	}
	var font := SystemFont.new()

	func _init() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		custom_minimum_size = Vector2(500, 390)

	func set_style(next_script: Variant, next_id: String, next_name: String) -> void:
		actor_script = next_script
		style_id = next_id
		style_name = next_name
		queue_redraw()

	func set_review(next_action: String, next_progress: float, next_clock: float, damage: int, show_effects: bool, next_background: String) -> void:
		action = next_action
		progress = clampf(next_progress, 0.0, 1.0)
		clock = next_clock
		armor_damage = clampi(damage, 0, ARMOR_MAX)
		effects_enabled = show_effects
		background_mode = next_background
		queue_redraw()

	func _draw() -> void:
		var background: Color = {
			"light": Color("e9e1d1"),
			"deep": Color("13201f"),
			"battle": Color("26382e")
		}.get(background_mode, Color("26382e"))
		var text_color := Color("313a35") if background_mode == "light" else CREAM
		var soft_color := Color("68716a") if background_mode == "light" else MUTED
		draw_rect(Rect2(Vector2.ZERO, size), background)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Color(GOLD, 0.32), false, 2.0)
		draw_string(font, Vector2(18, 29), style_name, HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 20, text_color)
		if not compact_only:
			draw_string(font, Vector2(18, 53), "同一角色 · 链甲 · 剑盾 · 同步时序", HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, 14, soft_color)

		var top_space := 48.0 if compact_only else 67.0
		var ground_y := size.y * (0.86 if compact_only else 0.62)
		var large_scale := clampf(minf(size.x / 175.0, (size.y - top_space) / 104.0), 2.05, 4.0)
		var actor_x := size.x * 0.31
		# The target plate's left edge is 13 logical pixels behind its origin.
		# A 50px origin gap puts that contact plane at actor x+37. The deliberate
		# overlap keeps both the blade tip and shield edge visibly inside the target.
		var target_x := actor_x + 50.0 * large_scale
		var contact := 0.48
		var actor_origin := Vector2(actor_x, ground_y)
		var target_origin := Vector2(target_x, ground_y)
		_draw_ground(actor_origin, target_origin)

		var display_unit: Dictionary = unit.duplicate(true)
		display_unit["armor"] = ARMOR_MAX
		display_unit["max_armor"] = ARMOR_MAX
		var pose := {
			"action": action,
			"progress": progress,
			"clock": clock,
			"direction": Vector2.RIGHT,
			"armor_ratio": 1.0,
			"show_anchors": false
		}
		var drawn := false
		if actor_script != null and actor_script.has_method("draw_actor"):
			drawn = bool(actor_script.call("draw_actor", self, style_id, display_unit, actor_origin, large_scale, pose))
		if not drawn:
			_draw_missing_actor(actor_origin, large_scale, text_color)

		var reaction := _reaction_amount(action, progress, contact)
		_draw_training_target(target_origin + Vector2(reaction, 0), large_scale, action == "shield_bash", armor_damage, text_color, soft_color)
		if effects_enabled:
			_draw_contact_effects(target_origin + Vector2(reaction, -large_scale * 30.0), large_scale, contact)

		if not compact_only:
			var small_origin := Vector2(size.x - 86, size.y - 17)
			draw_string(font, Vector2(size.x - 176, size.y - 96), "战场尺寸 1×", HORIZONTAL_ALIGNMENT_CENTER, 160, 13, soft_color)
			if actor_script != null and actor_script.has_method("draw_actor"):
				actor_script.call("draw_actor", self, style_id, display_unit, small_origin, 1.0, pose)
			_draw_training_target(small_origin + Vector2(50, 0), 1.0, action == "shield_bash", armor_damage, text_color, soft_color, false)
			var armor_left := ARMOR_MAX - armor_damage
			draw_string(font, Vector2(18, size.y - 20), "训练靶护甲 %d / %d" % [armor_left, ARMOR_MAX], HORIZONTAL_ALIGNMENT_LEFT, 190, 14, soft_color)

	func _draw_ground(actor_origin: Vector2, target_origin: Vector2) -> void:
		var line_y := actor_origin.y + 4.0
		draw_line(Vector2(18, line_y), Vector2(size.x - 18, line_y), Color("8ca08b", 0.28), 1.0)
		_draw_oval(actor_origin + Vector2(0, 3), Vector2(39, 8), Color("07100e", 0.22))
		_draw_oval(target_origin + Vector2(0, 3), Vector2(34, 7), Color("07100e", 0.22))

	func _draw_oval(center: Vector2, radii: Vector2, color: Color) -> void:
		var points := PackedVector2Array()
		for index in range(25):
			var angle := TAU * float(index) / 24.0
			points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
		draw_colored_polygon(points, color)

	func _draw_missing_actor(origin: Vector2, actor_scale: float, text_color: Color) -> void:
		draw_circle(origin + Vector2(0, -26 * actor_scale), 12 * actor_scale, Color("745f49"))
		draw_rect(Rect2(origin + Vector2(-15, -24) * actor_scale, Vector2(30, 24) * actor_scale), Color("665f57"))
		draw_string(font, origin + Vector2(-78, 26), "人物绘制资源载入中", HORIZONTAL_ALIGNMENT_CENTER, 156, 13, text_color)

	func _draw_training_target(origin: Vector2, actor_scale: float, blocking: bool, damage: int, text_color: Color, soft_color: Color, show_label := true) -> void:
		var recoil := 0.0
		if progress >= 0.48 and action != "idle":
			recoil = sin(clampf((progress - 0.48) / 0.30, 0.0, 1.0) * PI) * 0.08
		var post_top := origin + Vector2(0, -44 * actor_scale).rotated(recoil)
		var post_bottom := origin + Vector2(0, -3 * actor_scale)
		draw_line(post_bottom, post_top, Color("6e4d32"), maxf(4.0, actor_scale * 4.2))
		draw_circle(origin + Vector2(0, -45 * actor_scale), actor_scale * 6.5, Color("8f7050"))
		var torso_center := origin + Vector2(0, -25 * actor_scale)
		var plate := PackedVector2Array([
			torso_center + Vector2(-13, -12) * actor_scale,
			torso_center + Vector2(14, -11) * actor_scale,
			torso_center + Vector2(12, 11) * actor_scale,
			torso_center + Vector2(0, 16) * actor_scale,
			torso_center + Vector2(-12, 11) * actor_scale
		])
		draw_colored_polygon(plate, Color("787d77") if damage < 14 else Color("62635e"))
		draw_polyline(plate, Color("c0b58f"), maxf(1.0, actor_scale * 0.7), true)
		var scratch_count := clampi(int(ceil(float(damage) / 3.0)), 0, 8)
		for index in range(scratch_count):
			var x := float((index * 7) % 21 - 10) * actor_scale
			var y := float((index * 11) % 22 - 10) * actor_scale
			draw_line(torso_center + Vector2(x - 3 * actor_scale, y - 2 * actor_scale), torso_center + Vector2(x + 4 * actor_scale, y + 3 * actor_scale), Color("413e38"), maxf(1.0, actor_scale * 0.65))
		if blocking:
			var shield_center := torso_center + Vector2(-6, 3) * actor_scale
			draw_circle(shield_center, 15 * actor_scale, Color("565d58"))
			draw_arc(shield_center, 15 * actor_scale, 0, TAU, 28, Color("c6b06e"), maxf(1.4, actor_scale * 1.0))
			draw_circle(shield_center, 4 * actor_scale, Color("a88b52"))
		if not compact_only and show_label:
			draw_string(font, origin + Vector2(-48, 21), "训练装备靶", HORIZONTAL_ALIGNMENT_CENTER, 96, 12, soft_color if background_mode != "light" else text_color)

	func _draw_contact_effects(contact_point: Vector2, actor_scale: float, contact: float) -> void:
		if action == "idle" or progress < contact or progress > 0.68:
			return
		var fade := 1.0 - clampf((progress - contact) / 0.20, 0.0, 1.0)
		var color := Color("f0c467", fade)
		if action == "slash":
			draw_arc(contact_point + Vector2(-12, 2) * actor_scale, 25 * actor_scale, -1.1, 0.75, 24, color, maxf(2.0, actor_scale * 1.4))
		else:
			for angle in [-0.8, -0.3, 0.25, 0.75]:
				var start := contact_point + Vector2.RIGHT.rotated(angle) * actor_scale * 8.0
				var finish := contact_point + Vector2.RIGHT.rotated(angle) * actor_scale * 22.0
				draw_line(start, finish, color, maxf(1.3, actor_scale))

	func _reaction_amount(kind: String, p: float, contact: float) -> float:
		if kind == "idle" or p < contact:
			return 0.0
		return sin(clampf((p - contact) / 0.38, 0.0, 1.0) * PI) * (7.0 if kind == "slash" else 10.0)


var _actor_script: Variant
var _canvases: Array[ReviewCanvas] = []
var _action := "idle"
var _progress := 0.0
var _clock := 0.0
var _action_time := 0.0
var _paused := false
var _speed := 1.0
var _armor_damage := 0
var _action_start_damage := 0
var _impact_applied := false
var _wind_sound_played := false
var _effects_enabled := true
var _sound_enabled := true
var _background_mode := "battle"
var _capture_mode := false
var _strip_mode := false
var _slider_editing := false
var _scrub_preview := false
var _smoke_running := false
var _smoke_failures: Array[String] = []

var _header: Control
var _note: Control
var _toolbar: Control
var _footer: Control
var _content: Control
var _slider: HSlider
var _pause_button: Button
var _speed_buttons: Dictionary = {}
var _action_buttons: Dictionary = {}
var _fx_button: Button
var _sound_button: Button
var _status_label: Label
var _time_label: Label
var _audio_player: AudioStreamPlayer
var _sounds: Dictionary = {}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	if ResourceLoader.exists(ACTOR_PATH):
		_actor_script = load(ACTOR_PATH)
	_build_ui()
	_build_sounds()
	_refresh_all()
	set_process(true)

func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color("0f1817")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.name = "ReviewMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 7)
	margin.add_child(root_box)

	_header = HBoxContainer.new()
	root_box.add_child(_header)
	var title := _label("手部表现方案并排评审", 25, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header.add_child(title)
	_button(_header, "重置与修复", reset_review)
	_button(_header, "返回", func(): review_closed.emit())

	_note = _label("只比较手部与武器动作的表达；角色、链甲、剑盾、时序、训练靶、效果与声音完全相同。", 14, MUTED)
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(_note)

	_toolbar = VBoxContainer.new()
	_toolbar.add_theme_constant_override("separation", 4)
	root_box.add_child(_toolbar)
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 5)
	controls.add_theme_constant_override("v_separation", 4)
	_toolbar.add_child(controls)
	_label_into(controls, "动作")
	_action_buttons["idle"] = _button(controls, "待机", func(): play_action("idle"), true)
	_action_buttons["slash"] = _button(controls, "普通攻击", func(): play_action("slash"), true)
	_action_buttons["shield_bash"] = _button(controls, "盾击", func(): play_action("shield_bash"), true)
	_pause_button = _button(controls, "暂停", toggle_pause)
	_label_into(controls, "速度")
	_speed_buttons[1.0] = _button(controls, "1×", func(): set_speed(1.0), true)
	_speed_buttons[2.0] = _button(controls, "2×", func(): set_speed(2.0), true)
	_fx_button = _button(controls, "特效：开", toggle_effects, true)
	_sound_button = _button(controls, "声音：开", toggle_sound, true)
	_label_into(controls, "背景")
	_button(controls, "战场", func(): set_background("battle"))
	_button(controls, "浅色", func(): set_background("light"))
	_button(controls, "深色", func(): set_background("deep"))

	var scrub_row := HBoxContainer.new()
	_toolbar.add_child(scrub_row)
	_time_label = _label("待机 · 0%", 14, MUTED)
	_time_label.custom_minimum_size.x = 128
	scrub_row.add_child(_time_label)
	_slider = HSlider.new()
	_slider.min_value = 0.0
	_slider.max_value = 1.0
	_slider.step = 0.005
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.drag_started.connect(func(): _slider_editing = true; _scrub_preview = true; _paused = true; _update_controls())
	_slider.drag_ended.connect(func(_changed: bool): _slider_editing = false)
	_slider.value_changed.connect(_on_slider_changed)
	scrub_row.add_child(_slider)
	_status_label = _label("护甲完整", 14, CREAM)
	_status_label.custom_minimum_size.x = 235
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	scrub_row.add_child(_status_label)

	_content = HBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	root_box.add_child(_content)
	_add_review_column("a_hand", "A · 精细自然握持")
	_add_review_column("b_abstract", "B · 无手抽象武器运动")

	_footer = _label("观察顺序：待机防护关系 → 预备 → 接触 → 恢复 → 命中后持续甲损。关闭特效后仍应看清攻击方向。", 13, MUTED)
	_footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(_footer)

	_audio_player = AudioStreamPlayer.new()
	_audio_player.name = "ReviewAudio"
	add_child(_audio_player)

func _add_review_column(style_id: String, title: String) -> void:
	var canvas := ReviewCanvas.new()
	canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	canvas.set_style(_actor_script, style_id, title)
	_content.add_child(canvas)
	_canvases.append(canvas)

func play_action(next_action: String) -> void:
	_action = next_action if next_action in ["idle", "slash", "shield_bash"] else "idle"
	_progress = 0.0
	_action_time = -PRE_ROLL if _action != "idle" else 0.0
	_action_start_damage = _armor_damage
	_impact_applied = false
	_wind_sound_played = false
	_scrub_preview = false
	_paused = false
	_refresh_all()

func toggle_pause() -> void:
	_paused = not _paused
	if not _paused:
		_scrub_preview = false
	_refresh_all()

func set_speed(value: float) -> void:
	_speed = 2.0 if value >= 2.0 else 1.0
	_update_controls()

func toggle_effects() -> void:
	_effects_enabled = not _effects_enabled
	_refresh_all()

func toggle_sound() -> void:
	_sound_enabled = not _sound_enabled
	if not _sound_enabled:
		_audio_player.stop()
	_update_controls()

func set_background(mode: String) -> void:
	_background_mode = mode if mode in ["battle", "light", "deep"] else "battle"
	_refresh_all()

func reset_review() -> void:
	_armor_damage = 0
	play_action("idle")

func preflight_errors() -> Array[String]:
	var errors: Array[String] = []
	if not ResourceLoader.exists(ACTOR_PATH):
		errors.append("缺少人物绘制脚本：" + ACTOR_PATH)
	elif _actor_script == null:
		errors.append("人物绘制脚本载入失败：" + ACTOR_PATH)
	else:
		if not _actor_script.has_method("draw_actor"):
			errors.append("人物绘制脚本缺少draw_actor接口")
		if not _actor_script.has_method("get_timing"):
			errors.append("人物绘制脚本缺少get_timing接口")
	for resource_path in REQUIRED_ACTOR_RESOURCES:
		if not ResourceLoader.exists(resource_path):
			errors.append("缺少人物渲染资源：" + resource_path)
	return errors

func get_review_state() -> Dictionary:
	return {
		"action": _action,
		"progress": _progress,
		"armor_damage": _armor_damage,
		"impact_applied": _impact_applied,
		"paused": _paused
	}

func set_fixed_frame(next_action: String, next_progress: float, damage: int = 0) -> void:
	_capture_mode = true
	_paused = true
	_action = next_action if next_action in ["idle", "slash", "shield_bash"] else "idle"
	_progress = clampf(next_progress, 0.0, 1.0)
	_action_time = _progress * _timing(_action).duration
	_armor_damage = clampi(damage, 0, ARMOR_MAX)
	_action_start_damage = _armor_damage
	_impact_applied = _progress >= _timing(_action).contact
	_wind_sound_played = true
	_scrub_preview = false
	_refresh_all()

func set_capture_strip_mode(enabled: bool) -> void:
	_strip_mode = enabled
	_header.visible = not enabled
	_note.visible = not enabled
	_toolbar.visible = not enabled
	_footer.visible = not enabled
	for canvas in _canvases:
		canvas.compact_only = enabled
		canvas.queue_redraw()

func run_smoke(output_dir: String) -> void:
	if _smoke_running:
		return
	_smoke_running = true
	_smoke_failures.clear()
	var output := ProjectSettings.globalize_path(output_dir if not output_dir.is_empty() else "user://hand-style-review")
	DirAccess.make_dir_recursive_absolute(output)
	var setup_errors := preflight_errors()
	if not setup_errors.is_empty():
		for setup_error in setup_errors:
			printerr("HAND STYLE REVIEW FAIL: " + setup_error)
		get_tree().quit(1)
		return
	if DisplayServer.get_name() == "headless":
		printerr("HAND STYLE REVIEW FAIL: headless模式无法生成评审截图")
		get_tree().quit(1)
		return
	_capture_mode = true
	get_window().content_scale_size = Vector2i(1440, 900)
	get_window().size = Vector2i(1440, 900)
	set_fixed_frame("idle", 0.22, 0)
	await get_tree().process_frame
	await _capture_png(output.path_join("hand-style-static-1440x900.png"))
	for capture_action in ["slash", "shield_bash"]:
		for index in range(9):
			var frame_progress := float(index) / 8.0
			var frame_damage := (6 if capture_action == "slash" else 3) if frame_progress >= 0.48 else 0
			set_fixed_frame(capture_action, frame_progress, frame_damage)
			await _capture_png(output.path_join("hand-style-%s-%02d.png" % [capture_action, index]))
	set_fixed_frame("idle", 0.22, 9)
	get_window().content_scale_size = Vector2i(1180, 740)
	get_window().size = Vector2i(1180, 740)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture_png(output.path_join("hand-style-small-1180x740.png"))
	set_capture_strip_mode(true)
	get_window().content_scale_size = Vector2i(1120, 440)
	get_window().size = Vector2i(1120, 440)
	await get_tree().process_frame
	await get_tree().process_frame
	for capture_action in ["slash", "shield_bash"]:
		for index in range(16):
			var frame_progress := float(index) / 15.0
			var frame_damage := (6 if capture_action == "slash" else 3) if frame_progress >= 0.48 else 0
			set_fixed_frame(capture_action, frame_progress, frame_damage)
			await _capture_png(output.path_join("strip-%s-%02d.png" % [capture_action, index]))
	print("Hand style review smoke: static, action sequences, 1180x740 view and no-UI strips saved to " + output)
	if not _smoke_failures.is_empty():
		for failure in _smoke_failures:
			printerr("HAND STYLE REVIEW FAIL: " + failure)
	get_tree().quit(0 if _smoke_failures.is_empty() else 1)

func _capture_png(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(path)
	if error != OK:
		_smoke_failures.append("无法保存动作评审截图：" + path)

func _process(delta: float) -> void:
	_clock += delta * _speed
	if _capture_mode or _paused or _slider_editing:
		return
	if _action == "idle":
		var idle_duration := float(_timing("idle").duration)
		_progress = fmod(_progress + delta * _speed / maxf(0.1, idle_duration), 1.0)
		_refresh_all()
		return
	var timing := _timing(_action)
	_action_time += delta * _speed
	if not _wind_sound_played:
		if _action == "shield_bash":
			# The shield has no sword whoosh; its first sound is the contact block.
			_wind_sound_played = true
		else:
			var wind_end := float(timing.get("wind_end", timing.get("windup_end", 0.30)))
			if _action_time >= wind_end * float(timing.duration):
				_wind_sound_played = true
				_play_sound("swing")
	_progress = clampf(_action_time / maxf(0.1, float(timing.duration)), 0.0, 1.0)
	var contact_time := float(timing.duration) * float(timing.contact)
	if not _impact_applied and _action_time >= contact_time:
		_impact_applied = true
		_armor_damage = mini(ARMOR_MAX, _action_start_damage + (6 if _action == "slash" else 3))
		_play_sound("armor" if _action == "slash" else "block")
	if _action_time >= float(timing.duration) + POST_ROLL:
		_action = "idle"
		_action_time = 0.0
		_progress = 0.0
		_action_start_damage = _armor_damage
		_impact_applied = false
		_wind_sound_played = false
	_refresh_all()

func _on_slider_changed(value: float) -> void:
	if _slider == null or is_equal_approx(_progress, float(value)):
		return
	_progress = float(value)
	_action_time = _progress * float(_timing(_action).duration)
	_scrub_preview = true
	_refresh_all()

func _timing(kind: String) -> Dictionary:
	if _actor_script != null and _actor_script.has_method("get_timing"):
		var result = _actor_script.call("get_timing", "a_hand", kind)
		if result is Dictionary and not result.is_empty():
			return result
	return {
		"duration": 1.4 if kind == "idle" else (0.72 if kind == "slash" else 0.62),
		"contact": 0.48,
		"windup_end": 0.30,
		"hold_end": 0.56
	}

func _refresh_all() -> void:
	var display_damage := _armor_damage
	if _scrub_preview and not _capture_mode and _action != "idle":
		display_damage = _action_start_damage
		if _progress >= float(_timing(_action).contact):
			display_damage = mini(ARMOR_MAX, display_damage + (6 if _action == "slash" else 3))
	for canvas in _canvases:
		canvas.set_review(_action, _progress, _clock, display_damage, _effects_enabled, _background_mode)
	if _slider != null:
		_slider.set_value_no_signal(_progress)
	if _time_label != null:
		var name: String = {"idle": "待机", "slash": "普通攻击", "shield_bash": "盾击"}.get(_action, _action)
		var stage := "静态准备" if _action_time < 0.0 else ("伤损观察" if _action != "idle" and _action_time > float(_timing(_action).duration) else "%d%%" % roundi(_progress * 100.0))
		_time_label.text = "%s · %s" % [name, stage]
	if _status_label != null:
		_status_label.text = "训练靶护甲 %d / %d · 损伤会保留" % [ARMOR_MAX - display_damage, ARMOR_MAX]
	_update_controls()

func _update_controls() -> void:
	if _pause_button == null:
		return
	_pause_button.text = "继续" if _paused else "暂停"
	for key in _action_buttons:
		_action_buttons[key].button_pressed = str(key) == _action
	for key in _speed_buttons:
		_speed_buttons[key].button_pressed = is_equal_approx(float(key), _speed)
	_fx_button.button_pressed = _effects_enabled
	_fx_button.text = "特效：开" if _effects_enabled else "特效：关"
	_sound_button.button_pressed = _sound_enabled
	_sound_button.text = "声音：开" if _sound_enabled else "声音：关"

func _build_sounds() -> void:
	_sounds["swing"] = _synth_sound("swing", 0.13)
	_sounds["armor"] = _synth_sound("armor", 0.20)
	_sounds["block"] = _synth_sound("block", 0.17)

func export_preview_sounds(output_dir: String) -> Array[String]:
	if _sounds.is_empty():
		_build_sounds()
	var output := ProjectSettings.globalize_path(output_dir)
	DirAccess.make_dir_recursive_absolute(output)
	var failures: Array[String] = []
	for sound_name in ["swing", "armor", "block"]:
		var path := output.path_join(sound_name + ".wav")
		var error: Error = _sounds[sound_name].save_to_wav(path)
		if error != OK:
			failures.append(path)
	return failures

func _synth_sound(kind: String, duration: float) -> AudioStreamWAV:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.stereo = false
	var count := int(duration * stream.mix_rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	for index in range(count):
		var t := float(index) / float(stream.mix_rate)
		var envelope := pow(maxf(0.0, 1.0 - t / duration), 2.2)
		var sample := 0.0
		if kind == "swing":
			sample = (sin(TAU * (180.0 + 900.0 * t) * t) + 0.35 * sin(TAU * 91.0 * t)) * envelope * 0.22
		elif kind == "armor":
			sample = (sin(TAU * 430.0 * t) + 0.7 * sin(TAU * 780.0 * t) + 0.35 * sin(TAU * 1230.0 * t)) * envelope * 0.23
		else:
			sample = (sin(TAU * 155.0 * t) + 0.48 * sin(TAU * 610.0 * t)) * envelope * 0.28
		var encoded := clampi(roundi(sample * 32767.0), -32768, 32767)
		if encoded < 0:
			encoded += 65536
		bytes[index * 2] = encoded & 0xff
		bytes[index * 2 + 1] = (encoded >> 8) & 0xff
	stream.data = bytes
	return stream

func _play_sound(kind: String) -> void:
	if not _sound_enabled or _capture_mode or not _sounds.has(kind):
		return
	_audio_player.stream = _sounds[kind]
	_audio_player.play()

func _label(text: String, font_size: int, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _label_into(parent: Node, text: String) -> void:
	var label := _label(text, 14, MUTED)
	label.custom_minimum_size.x = 42
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _button(parent: Node, text: String, callable: Callable, toggle := false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(58, 34)
	button.toggle_mode = toggle
	button.pressed.connect(callable)
	parent.add_child(button)
	return button
