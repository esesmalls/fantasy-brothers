extends Control
## Isolated motion review. It owns an in-memory battle fixture and never touches SaveStore.

signal review_closed

const Battle = preload("res://core/battle_rules.gd")
const BattleBoard = preload("res://presentation/battle_board.gd")
const EquipmentData = preload("res://core/equipment_data.gd")

const GOLD := Color("c8aa6e")
const CREAM := Color("e7ddc6")
const MUTED := Color("9caeaa")
const RED := Color("e49b80")

class ActorPreview extends Control:
	const ModularActor = preload("res://presentation/modular_actor.gd")
	var unit: Dictionary = {}
	var pose: Dictionary = {"template": "b", "action": "idle", "progress": 0.0, "direction": Vector2.RIGHT, "clock": 0.0}
	var background_mode := "deep"

	func _ready() -> void:
		custom_minimum_size = Vector2(330, 300)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	func set_review(sample: Dictionary, next_pose: Dictionary) -> void:
		unit = sample.duplicate(true)
		pose = next_pose.duplicate(true)
		queue_redraw()

	func set_background(mode: String) -> void:
		background_mode = mode
		queue_redraw()

	func _draw() -> void:
		var background: Color = {"white": Color("eee8d8"), "deep": Color("111c1d"), "battle": Color("26352a")}.get(background_mode, Color("111c1d"))
		draw_rect(Rect2(Vector2.ZERO, size), background)
		var origin := Vector2(size.x * 0.5, size.y * 0.73)
		var actor_scale := clampf(minf(size.x / 110.0, size.y / 110.0), 2.2, 4.1)
		if not ModularActor.draw_actor(self, unit, origin, actor_scale, pose):
			var font := SystemFont.new()
			font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "Arial"])
			var message_color := Color("574b37") if background_mode == "white" else Color("d3b976")
			draw_string(font, Vector2(30, size.y * 0.5), "该模板资源尚未就绪", HORIZONTAL_ALIGNMENT_CENTER, size.x - 60, 18, message_color)

var battle: Dictionary = {}
var board: Control
var actor_preview: ActorPreview
var template_id := "b"
var armor_id := "armor_mail"
var preview_action := "idle"
var preview_progress := 0.0
var preview_paused := false
var battle_action := "attack"
var playback_speed := 1.0
var progress_slider: HSlider
var progress_label: Label
var pause_button: Button
var battle_status: Label
var template_buttons: Dictionary = {}
var armor_buttons: Dictionary = {}
var preview_buttons: Dictionary = {}
var battle_buttons: Dictionary = {}
var background_buttons: Dictionary = {}
var preview_background := "deep"
var _preview_clock := 0.0
var _smoke_running := false
var _smoke_failures: Array[String] = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	reset_fixture()
	set_process(true)

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("101b1d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var heading := HBoxContainer.new()
	root.add_child(heading)
	var title := _label("H标准动作样板评审", 25, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	_button(heading, "重置试打", reset_fixture)
	_button(heading, "返回主菜单", func(): review_closed.emit())
	var note := _label("本轮比较朝右的剑盾动作：左侧放大查看，右侧真实战场试打。其他朝向尚未制作专用姿势。", 14, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(note)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 5)
	root.add_child(choices)
	var row_one := HBoxContainer.new()
	choices.add_child(row_one)
	_label_into(row_one, "模板")
	var template_names := {"a": "A 简练", "b": "B 重量", "c": "C 细腻"}
	for id in ["a", "b", "c"]:
		template_buttons[id] = _button(row_one, str(template_names[id]), func(value: String = id): _set_template(value), true)
	_label_into(row_one, "护甲")
	armor_buttons["armor_padded"] = _button(row_one, "轻型衬甲", func(): _set_armor("armor_padded"), true)
	armor_buttons["armor_mail"] = _button(row_one, "重型链甲", func(): _set_armor("armor_mail"), true)
	_label_into(row_one, "背景")
	for entry in [{"id": "white", "name": "白"}, {"id": "deep", "name": "深"}, {"id": "battle", "name": "战场"}]:
		var background_id: String = entry.id
		background_buttons[background_id] = _button(row_one, str(entry.name), func(value: String = background_id): _set_preview_background(value), true)
	_label_into(row_one, "播放")
	_button(row_one, "1×", func(): _set_speed(1.0))
	_button(row_one, "2×", func(): _set_speed(2.0))
	_button(row_one, "跳过", _skip_board)
	var description := _label("A：短促清楚，适合频繁交锋　·　B：停顿与重量更明显　·　C：预备和恢复更舒展；两套护甲共用身份与握点。换甲会重置右侧试打，并采用实际护甲上限（10 / 24）。", 13, MUTED)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choices.add_child(description)
	var row_two := HBoxContainer.new()
	choices.add_child(row_two)
	_label_into(row_two, "近景动作")
	var actions := {"idle": "待机", "move": "移动", "slash": "挥砍", "shield_bash": "盾击", "defend": "防御", "hit": "受击", "death": "倒下"}
	for id in actions:
		preview_buttons[id] = _button(row_two, str(actions[id]), func(value: String = id): _set_preview_action(value), true)
	pause_button = _button(row_two, "暂停", _toggle_preview_pause)
	progress_slider = HSlider.new()
	progress_slider.min_value = 0.0
	progress_slider.max_value = 1.0
	progress_slider.step = 0.01
	progress_slider.custom_minimum_size.x = 150
	progress_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_slider.value_changed.connect(_on_progress_changed)
	row_two.add_child(progress_slider)
	progress_label = _label("0%", 14, MUTED)
	progress_label.custom_minimum_size.x = 44
	row_two.add_child(progress_label)
	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	split.split_offset = 388
	root.add_child(split)
	var close_panel := PanelContainer.new()
	close_panel.custom_minimum_size.x = 360
	split.add_child(close_panel)
	var close_box := VBoxContainer.new()
	close_box.add_theme_constant_override("separation", 6)
	close_panel.add_child(close_box)
	close_box.add_child(_label("放大动作与锚点连续性", 18, GOLD))
	actor_preview = ActorPreview.new()
	actor_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	close_box.add_child(actor_preview)
	actor_preview.set_background(preview_background)
	var close_note := _label("拖动时间查看预备、接触与恢复；暂停后可逐帧检查手、武器、盾和腰底。倒下在当前版本中代表确认死亡。", 13, MUTED)
	close_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	close_box.add_child(close_note)
	var field_panel := PanelContainer.new()
	field_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(field_panel)
	var field_box := VBoxContainer.new()
	field_box.add_theme_constant_override("separation", 5)
	field_panel.add_child(field_box)
	var actual_row := HBoxContainer.new()
	field_box.add_child(actual_row)
	_label_into(actual_row, "真实战场试打")
	for entry in [{"id": "move", "name": "移动"}, {"id": "attack", "name": "普通攻击"}, {"id": "shield_bash", "name": "盾击"}, {"id": "defend", "name": "防御"}]:
		var id: String = entry.id
		battle_buttons[id] = _button(actual_row, str(entry.name), func(value: String = id): _select_battle_action(value), true)
	battle_status = _label("", 14, MUTED)
	battle_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	battle_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	battle_status.max_lines_visible = 2
	battle_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	actual_row.add_child(battle_status)
	board = BattleBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.custom_minimum_size = Vector2(620, 410)
	board.cell_clicked.connect(_on_board_cell_clicked)
	field_box.add_child(board)

func reset_fixture() -> void:
	if is_instance_valid(board):
		board.skip_animations()
	var armor_value := int(EquipmentData.get_definition(armor_id).get("armor", 0))
	var roster: Array = [{
		"id": "crew_1", "name": "H样板佣兵", "kind": "guard", "max_hp": 42, "hp": 42,
		"max_armor": armor_value, "armor": armor_value, "attack": 14, "accuracy": 100,
		"weapon_style": "guard", "presentation_sample": true,
		"visual_loadout": {"weapon": "weapon_guard_sword", "armor": armor_id}, "perks": []
	}]
	battle = Battle.create_battle(roster, 20260920, {"id": "motion_review", "difficulty": 0})
	# Review fixture setup is deterministic and isolated. The combat rules still own
	# every action, AP cost, hit, status and event emitted after this arrangement.
	var sample := _sample_unit()
	var target := _unit("enemy_0")
	target.q = int(sample.q) + 1
	target.r = int(sample.r)
	target.max_hp = 80
	target.hp = 80
	target.armor = 20
	target.max_armor = 20
	battle_action = "attack"
	board.set_motion_review_actor("crew_1")
	board.set_motion_template(template_id)
	board.set_animation_speed(playback_speed)
	board.set_battle(battle)
	board.set_selected("crew_1")
	_refresh_overlay()
	_refresh_sample()
	_update_button_states()

func _set_template(value: String) -> void:
	board.skip_animations()
	template_id = value
	board.set_motion_template(value)
	_refresh_sample()
	_update_button_states()

func _set_armor(value: String) -> void:
	armor_id = value
	reset_fixture()
	battle_status.text = "已换装%s并重置试打" % str(EquipmentData.get_definition(value).get("name", value))

func _set_preview_background(value: String) -> void:
	preview_background = value if value in ["white", "deep", "battle"] else "deep"
	actor_preview.set_background(preview_background)
	_update_button_states()

func _set_preview_action(value: String) -> void:
	preview_action = value
	preview_progress = 0.0
	progress_slider.set_value_no_signal(0.0)
	_refresh_sample()
	_update_button_states()

func _toggle_preview_pause() -> void:
	if preview_action == "death" and preview_progress >= 0.999:
		preview_progress = 0.0
		progress_slider.set_value_no_signal(0.0)
		preview_paused = false
		pause_button.text = "暂停"
		_refresh_sample()
		return
	preview_paused = not preview_paused
	pause_button.text = "继续" if preview_paused else "暂停"

func _on_progress_changed(value: float) -> void:
	preview_progress = value
	preview_paused = true
	pause_button.text = "继续"
	_refresh_sample()

func _set_speed(value: float) -> void:
	playback_speed = value
	board.set_animation_speed(value)

func _skip_board() -> void:
	board.skip_animations()
	battle_status.text = "已跳到最终画面"

func _select_battle_action(value: String) -> void:
	battle_action = value
	_refresh_overlay()
	_update_button_states()
	battle_status.text = "已选%s，请点击目标格" % str({"move": "移动", "attack": "普通攻击", "shield_bash": "盾击", "defend": "防御"}.get(value, value))

func _on_board_cell_clicked(q: int, r: int) -> void:
	if board.has_pending_animation():
		battle_status.text = "上一段动作仍在播放；可等待结束或点击“跳过”。"
		return
	var active := Battle.active_unit(battle)
	if active.is_empty() or str(active.get("id", "")) != "crew_1":
		battle_status.text = "样板佣兵当前不能行动；可点击“重置试打”。"
		return
	var result: Dictionary = Battle.apply_action(battle, "crew_1", battle_action, {"q": q, "r": r})
	if not bool(result.get("ok", false)):
		battle_status.text = str(result.get("reason", "该目标不可用"))
		return
	board.set_battle(battle)
	board.play_events(result.get("events", []))
	battle_status.text = "动作完成 · 反馈%d条" % result.get("events", []).size()
	_refresh_overlay()
	_refresh_sample()
	_update_button_states()

func _refresh_overlay() -> void:
	var active := Battle.active_unit(battle)
	if active.is_empty() or str(active.get("id", "")) != "crew_1":
		board.set_action_overlay({})
		return
	var overlay := Battle.action_overlay(battle, "crew_1", battle_action)
	overlay.action_id = battle_action
	board.set_action_overlay(overlay)

func _refresh_sample() -> void:
	var sample := _sample_unit().duplicate(true)
	if sample.is_empty():
		return
	sample.visual_loadout.armor = armor_id
	if preview_action == "death":
		sample.hp = 0
	else:
		sample.hp = maxi(1, int(sample.get("hp", 1)))
	var pose := {"template": template_id, "action": preview_action, "progress": preview_progress, "direction": Vector2.RIGHT, "clock": _preview_clock, "show_anchors": preview_paused}
	actor_preview.set_review(sample, pose)
	progress_label.text = "%d%%" % roundi(preview_progress * 100.0)

func _update_button_states() -> void:
	for id in template_buttons:
		template_buttons[id].button_pressed = str(id) == template_id
	for id in armor_buttons:
		armor_buttons[id].button_pressed = str(id) == armor_id
	for id in preview_buttons:
		preview_buttons[id].button_pressed = str(id) == preview_action
	for id in battle_buttons:
		battle_buttons[id].button_pressed = str(id) == battle_action
	for id in background_buttons:
		background_buttons[id].button_pressed = str(id) == preview_background

func _process(delta: float) -> void:
	_preview_clock += delta
	if not preview_paused:
		var duration: float = BattleBoard.motion_duration(template_id, preview_action)
		var next_progress := preview_progress + delta * playback_speed / maxf(0.05, duration)
		if preview_action == "death":
			preview_progress = minf(1.0, next_progress)
			if preview_progress >= 1.0:
				preview_paused = true
				pause_button.text = "重播"
		else:
			preview_progress = fmod(next_progress, 1.0)
		progress_slider.set_value_no_signal(preview_progress)
		_refresh_sample()

func _sample_unit() -> Dictionary:
	return _unit("crew_1")

func _unit(id: String) -> Dictionary:
	for item: Dictionary in battle.get("units", []):
		if str(item.get("id", "")) == id:
			return item
	return {}

func run_smoke(output_dir: String) -> void:
	if _smoke_running:
		return
	_smoke_running = true
	_smoke_failures.clear()
	var output := ProjectSettings.globalize_path(output_dir if not output_dir.is_empty() else "user://motion-review")
	DirAccess.make_dir_recursive_absolute(output)
	_set_preview_action("slash")
	preview_paused = true
	pause_button.text = "继续"
	for review_template in ["a", "b", "c"]:
		for review_armor in ["armor_padded", "armor_mail"]:
			_set_template(review_template)
			_set_armor(review_armor)
			preview_progress = BattleBoard.motion_contact(review_template)
			progress_slider.set_value_no_signal(preview_progress)
			_refresh_sample()
			await get_tree().process_frame
			await _capture(output.path_join("motion-review-%s-%s.png" % [review_template, review_armor.trim_prefix("armor_")]))
	_set_template("b")
	_set_preview_action("death")
	preview_paused = true
	preview_progress = 1.0
	progress_slider.set_value_no_signal(1.0)
	for review_armor in ["armor_padded", "armor_mail"]:
		_set_armor(review_armor)
		_refresh_sample()
		await get_tree().process_frame
		await _capture(output.path_join("motion-review-death-%s.png" % review_armor.trim_prefix("armor_")))
	# Exercise all four real controls, both speeds and skip. Each reset discards only
	# presentation queues and creates a fresh deterministic in-memory battle.
	for trial in [{"action": "attack", "speed": 1.0}, {"action": "shield_bash", "speed": 2.0}, {"action": "defend", "speed": 1.0}, {"action": "move", "speed": 2.0}]:
		reset_fixture()
		_set_speed(float(trial.speed))
		battle_buttons[str(trial.action)].pressed.emit()
		var cell := _first_valid_target(str(trial.action))
		if cell.x < 0:
			_smoke_fail("动作评审自动流程找不到目标：" + str(trial.action))
			continue
		var action_count: int = battle.get("action_log", []).size()
		board.cell_clicked.emit(cell.x, cell.y)
		await get_tree().process_frame
		if battle.get("action_log", []).size() != action_count + 1 or str(battle.action_log[-1].get("action", "")) != str(trial.action):
			_smoke_fail("真实按钮没有执行预期动作：" + str(trial.action))
		var settled := JSON.stringify(battle)
		await get_tree().create_timer(0.18).timeout
		await _capture(output.path_join("motion-review-real-%s-%dx.png" % [str(trial.action), int(trial.speed)]))
		board.skip_animations()
		if JSON.stringify(battle) != settled:
			_smoke_fail("播放速度或跳过改变了战斗结果：" + str(trial.action))
	if DisplayServer.get_name() != "headless":
		await export_motion_frames(output)
	get_window().size = Vector2i(1180, 740)
	await get_tree().process_frame
	await get_tree().process_frame
	await _capture(output.path_join("motion-review-1180x740.png"))
	print("Motion review smoke: attack/bash/defend/move at 1x/2x/skip completed" + ("; six armor comparisons, two terminal views and 24 sequence frames saved to " + output if DisplayServer.get_name() != "headless" else " (headless capture skipped)"))
	if not _smoke_failures.is_empty():
		for failure in _smoke_failures:
			printerr("MOTION REVIEW FAIL: " + failure)
	get_tree().quit(0 if _smoke_failures.is_empty() else 1)

func export_motion_frames(output: String) -> void:
	_set_template("b")
	preview_paused = true
	pause_button.text = "继续"
	for action in ["slash", "shield_bash"]:
		_set_preview_action(action)
		preview_paused = true
		for frame in range(12):
			preview_progress = float(frame) / 11.0
			progress_slider.set_value_no_signal(preview_progress)
			_refresh_sample()
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var image := get_viewport().get_texture().get_image()
			var error := image.save_png(output.path_join("b-%s-%02d.png" % [action, frame]))
			if error != OK:
				_smoke_fail("无法保存动作序列帧：%s %d" % [action, frame])

func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		_smoke_fail("无法保存动作评审截图：" + path)

func _smoke_fail(message: String) -> void:
	_smoke_failures.append(message)
	push_error(message)

func _first_valid_target(action: String) -> Vector2i:
	var sample := _sample_unit()
	if sample.is_empty():
		return Vector2i(-1, -1)
	if action == "defend":
		return Vector2i(int(sample.q), int(sample.r))
	for q in range(int(battle.get("width", 9))):
		for r in range(int(battle.get("height", 7))):
			if bool(Battle.preview(battle, "crew_1", action, {"q": q, "r": r}).get("ok", false)):
				return Vector2i(q, r)
	return Vector2i(-1, -1)

func _label(text: String, size_value: int, color: Color = CREAM) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size_value)
	label.add_theme_color_override("font_color", color)
	return label

func _label_into(parent: Node, text: String) -> void:
	var label := _label(text, 14, MUTED)
	label.custom_minimum_size.x = 46
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(label)

func _button(parent: Node, text: String, callable: Callable, toggle: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(52, 34)
	button.toggle_mode = toggle
	button.pressed.connect(callable)
	parent.add_child(button)
	return button
