extends Control
# Battle-only layout. Rules and inspection data are supplied by the controller.
const Glyph = preload("res://presentation/tactical_glyph.gd")
const CREAM := Color("e7ddc6")
const MUTED := Color("aeb4a0")
const GOLD := Color("cfaf70")
const RED := Color("df987e")
const SHORT_ACTIONS = {"move":"移动", "attack":"攻击", "shield_bash":"盾击", "push":"推开", "defend":"戒备", "oil":"油瓶", "fire":"火种", "water":"水具", "mark":"标记", "command_follow":"跟随", "command_pin":"牵制", "command_recall":"撤回"}
var controller: Control
var board: Control
var dock: PanelContainer
var log_panel: PanelContainer
var log_toggle: Button
var log_scroll: ScrollContainer
var log_label: Label
var top_summary: PanelContainer
var toolbar: HBoxContainer
var active_label: Label
var actor_stats: Label
var actor_glyph: Control
var preview_label: Label
var turn_label: Label
var outcome_label: Label
var supplies_label: Label
var action_box: GridContainer
var item_box: GridContainer
var queue_box: HBoxContainer
var queue_ids: Array[String] = []
var end_button: Button
var resolve_button: Button
var retreat_button: Button
var save_label: Label
var inspection_panel: PanelContainer
var inspection_title: Label
var inspection_subtitle: Label
var inspection_body: Label
var inspection_preview: Label
var log_expanded := false

func build(owner_control: Control, battle_board: Control) -> void:
	controller = owner_control
	board = battle_board
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(board)
	board.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_top()
	_build_dock()
	_build_inspection()
	resized.connect(layout)
	call_deferred("layout")

func _frame(parent: Node, padding: int = 10) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", controller._style("202923ed", "8d7954", padding))
	parent.add_child(panel)
	return panel

func _vbox(parent: Node, gap: int = 5) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", gap)
	parent.add_child(box)
	return box

func _label(parent: Node, value: String, font_size: int = 14, color: Color = CREAM) -> Label:
	var label: Label = controller._text(parent, value, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

func _button(parent: Node, value: String, callback: Callable, height: float = 32) -> Button:
	var button: Button = controller._button(parent, value, callback)
	button.custom_minimum_size.y = height
	button.add_theme_font_size_override("font_size", 13)
	return button

func _build_top() -> void:
	log_panel = _frame(self, 5)
	var log_box := _vbox(log_panel, 4)
	log_toggle = _button(log_box, "战报 ▾  等待交锋", toggle_log, 32)
	log_toggle.clip_text = true
	log_toggle.alignment = HORIZONTAL_ALIGNMENT_LEFT
	log_toggle.tooltip_text = "展开/收起完整战斗日志"
	log_scroll = ScrollContainer.new()
	log_scroll.custom_minimum_size.y = 152
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_box.add_child(log_scroll)
	log_label = _label(log_scroll, "尚无交锋记录。", 13, MUTED)
	log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	log_label.custom_minimum_size.x = 270
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.hide()
	top_summary = _frame(self, 7)
	var summary := _vbox(top_summary, 2)
	turn_label = _label(summary, "", 16, GOLD)
	turn_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outcome_label = _label(summary, "击退敌人 · 守住粮仓", 12, MUTED)
	outcome_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toolbar = HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	add_child(toolbar)
	_button(toolbar, "手册", controller._show_help)
	_button(toolbar, "存档", controller._manual_save)
	_button(toolbar, "读档", controller._confirm_load)
	_button(toolbar, "菜单", controller._confirm_menu)

func _build_dock() -> void:
	dock = _frame(self, 10)
	var rows := _vbox(dock, 7)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 12)
	rows.add_child(main)
	var actor := _vbox(main, 5)
	actor.custom_minimum_size.x = 242
	var identity := HBoxContainer.new()
	identity.add_theme_constant_override("separation", 8)
	actor.add_child(identity)
	actor_glyph = Glyph.new()
	actor_glyph.custom_minimum_size = Vector2(40, 40)
	actor_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.add_child(actor_glyph)
	active_label = _label(identity, "", 18, GOLD)
	active_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actor_stats = _label(actor, "", 14)
	save_label = _label(actor, "空格 · 结束回合    Esc · 移动", 11, MUTED)
	main.add_child(VSeparator.new())
	var commands := _vbox(main, 3)
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var groups := HBoxContainer.new()
	groups.add_theme_constant_override("separation", 12)
	commands.add_child(groups)
	var skills := _vbox(groups, 3)
	_label(skills, "招式", 12, GOLD)
	action_box = GridContainer.new()
	# A hunter carrying sword and shield keeps commands as well as weapon skills.
	action_box.columns = 9
	action_box.add_theme_constant_override("h_separation", 4)
	skills.add_child(action_box)
	groups.add_child(VSeparator.new())
	var items := _vbox(groups, 3)
	supplies_label = _label(items, "战具 · 全团共用", 12, GOLD)
	item_box = GridContainer.new()
	item_box.columns = 3
	item_box.add_theme_constant_override("h_separation", 4)
	items.add_child(item_box)
	preview_label = _label(commands, "", 13, MUTED)
	preview_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_label.custom_minimum_size.x = 280
	preview_label.max_lines_visible = 2
	preview_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	preview_label.custom_minimum_size.y = 36
	var controls := _vbox(main, 5)
	controls.custom_minimum_size.x = 152
	end_button = _button(controls, "结束回合  [空格]", controller._end_turn, 35)
	resolve_button = _button(controls, "清点战果 · 离场", controller._resolve, 35)
	retreat_button = _button(controls, "撤离战场", func(): controller._confirm("撤离战场？", "未完成契约没有报酬；伤亡与消耗仍会保留。", controller._retreat), 29)
	var speeds := HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 3)
	controls.add_child(speeds)
	for entry in [["1×", 1.0], ["3×", 3.0], ["跳过", 0.0]]:
		var speed: float = float(entry[1])
		var button := _button(speeds, str(entry[0]), func(): controller._set_speed(speed), 27)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(HSeparator.new())
	var timeline := HBoxContainer.new()
	timeline.add_theme_constant_override("separation", 8)
	rows.add_child(timeline)
	_label(timeline, "行动顺序\n悬停查看", 11, MUTED)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size.y = 41
	timeline.add_child(scroll)
	queue_box = HBoxContainer.new()
	queue_box.add_theme_constant_override("separation", 5)
	scroll.add_child(queue_box)

func _build_inspection() -> void:
	inspection_panel = _frame(self, 12)
	inspection_panel.custom_minimum_size.x = 320
	inspection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspection_panel.add_theme_stylebox_override("panel", controller._style("252a21f8", "c3a368", 12))
	var box := _vbox(inspection_panel, 5)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inspection_title = _label(box, "", 19, GOLD)
	inspection_subtitle = _label(box, "", 13, MUTED)
	var separator := HSeparator.new()
	separator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(separator)
	inspection_body = _label(box, "", 14)
	inspection_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspection_body.custom_minimum_size.x = 296
	inspection_preview = _label(box, "", 13, GOLD)
	inspection_preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspection_preview.custom_minimum_size.x = 296
	inspection_panel.hide()

func layout() -> void:
	if not is_inside_tree() or dock == null or size.x <= 0:
		return
	var dock_height: float = maxf(202.0, dock.get_combined_minimum_size().y)
	dock.position = Vector2(12, size.y - dock_height - 10)
	dock.size = Vector2(size.x - 24, dock_height)
	log_panel.position = Vector2(12, 12)
	log_panel.size = Vector2(300, 42 if not log_expanded else 202)
	top_summary.position = Vector2(size.x * 0.5 - 165, 10)
	top_summary.size = Vector2(330, 52)
	toolbar.position = Vector2(size.x - toolbar.get_combined_minimum_size().x - 12, 12)
	toolbar.size = toolbar.get_combined_minimum_size()
	board.set_playfield_rect(Rect2(22, 70, size.x - 44, maxf(220.0, dock.position.y - 80)))
	position_inspection()

func toggle_log() -> void:
	log_expanded = not log_expanded
	log_scroll.visible = log_expanded
	update_log(controller.campaign.battle)
	log_panel.reset_size()
	layout()

func update_log(battle: Dictionary) -> void:
	var lines: Array[String] = []
	for entry in battle.get("log", []):
		lines.append(str(entry.get("text", "")) if entry is Dictionary else str(entry))
	log_label.text = "\n".join(lines) if not lines.is_empty() else "尚无交锋记录。"
	log_toggle.text = "战报 %s  %s" % ["▴" if log_expanded else "▾", lines.back() if not lines.is_empty() else "等待交锋"]
	if log_expanded:
		log_scroll.set_deferred("scroll_vertical", 100000)

func refresh_actor(active: Dictionary, battle: Dictionary) -> void:
	var friendly := 0
	var hostile := 0
	for unit: Dictionary in battle.units:
		if int(unit.hp) > 0:
			if str(unit.team) == "player": friendly += 1
			else: hostile += 1
	turn_label.text = "第 %d 轮   ·   我方 %d   /   敌方 %d" % [int(battle.round), friendly, hostile]
	if active.is_empty():
		actor_stats.text = "胜败与伤亡已定\n清点后继续佣兵团的旅程"
		actor_glyph.set_glyph("defend")
	else:
		actor_glyph.set_glyph(str(active.kind))
		actor_glyph.tint = GOLD if str(active.team) == "player" else RED
		actor_glyph.queue_redraw()
		actor_stats.text = "生命 %d/%d   护甲 %d/%d\n行动 %d/%d   攻击 %d   射程 %d" % [int(active.hp), int(active.max_hp), int(active.armor), int(active.max_armor), int(active.ap), int(active.max_ap), int(active.attack), int(active.range)]
	retreat_button.disabled = not str(battle.outcome).is_empty()
	refresh_queue(battle)
	update_log(battle)
	call_deferred("layout")

func refresh_queue(battle: Dictionary) -> void:
	for child in queue_box.get_children():
		queue_box.remove_child(child)
		child.queue_free()
	queue_ids.clear()
	var start: int = int(battle.turn_index)
	for step in range(battle.order.size()):
		var order_index: int = (start + step) % battle.order.size()
		var id: String = str(battle.order[order_index])
		var unit: Dictionary = {}
		for candidate: Dictionary in battle.units:
			if str(candidate.id) == id: unit = candidate; break
		if unit.is_empty() or int(unit.hp) <= 0:
			continue
		if order_index == 0 and step > 0:
			_label(queue_box, "下轮 ›", 11, MUTED)
		queue_ids.append(id)
		var current: bool = step == 0 and str(battle.outcome).is_empty()
		var card := _button(queue_box, ("▶ " if current else "") + str(unit.name), func(): pass, 38)
		card.custom_minimum_size.x = 102
		card.clip_text = true
		card.add_theme_color_override("font_color", GOLD if unit.team == "player" else RED)
		card.add_theme_stylebox_override("normal", controller._style("474332" if current else "29302a", "d4b775" if current else "59604c", 5))
		card.tooltip_text = ""
		card.mouse_entered.connect(func(): controller._inspect_unit(id))
		card.mouse_exited.connect(func(): controller._hide_inspection())

func make_action_button(action: Dictionary, count: int, selected: bool, disabled: bool) -> Button:
	var id: String = str(action.id)
	var item: bool = id in ["oil", "fire", "water"]
	var button := _button(item_box if item else action_box, "", func(): controller._choose_action(id), 76)
	button.custom_minimum_size.x = 58
	button.disabled = disabled
	button.tooltip_text = "%s · %d行动点\n%s" % [str(action.name), int(action.cost), str(action.description)]
	button.add_theme_stylebox_override("normal", controller._style("4a4632" if selected else "293329", "d6b66f" if selected else "657057", 3))
	var box := _vbox(button, 1)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 3; box.offset_right = -3; box.offset_top = 3; box.offset_bottom = -3
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var glyph := Glyph.new()
	glyph.glyph = id
	glyph.tint = GOLD if selected else CREAM
	glyph.custom_minimum_size = Vector2(27, 27)
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(glyph)
	var title := _label(box, str(SHORT_ACTIONS.get(id, action.name)) + ("×%d" % count if item else ""), 12, GOLD if selected else CREAM)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_OFF
	var cost := _label(box, "%d点%s" % [int(action.cost), "·%d格" % int(action.range) if int(action.range) > 0 and id != "move" else ""], 11, MUTED)
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.autowrap_mode = TextServer.AUTOWRAP_OFF
	if disabled: box.modulate.a = 0.4
	return button

func show_inspection(info: Dictionary, preview: Dictionary = {}) -> void:
	if info.is_empty():
		inspection_panel.hide()
		return
	inspection_title.text = str(info.get("title", ""))
	inspection_title.add_theme_color_override("font_color", RED if info.get("team", "") == "enemy" else GOLD)
	inspection_subtitle.text = str(info.get("subtitle", ""))
	inspection_body.text = "\n".join(info.get("lines", []))
	# Experienced units can carry several perks and statuses. Give those cards
	# more width so complete descriptions still fit above the command dock.
	var card_width: float = 600.0 if info.get("lines", []).size() > 12 else 320.0
	inspection_panel.custom_minimum_size.x = card_width
	inspection_body.custom_minimum_size.x = card_width - 24.0
	inspection_preview.custom_minimum_size.x = card_width - 24.0
	inspection_preview.text = str(preview.get("summary", ""))
	inspection_preview.visible = not inspection_preview.text.is_empty()
	inspection_preview.add_theme_color_override("font_color", GOLD if preview.get("ok", true) else RED)
	inspection_panel.size = Vector2(card_width, 0)
	inspection_panel.show()
	position_inspection()

func position_inspection() -> void:
	if not is_inside_tree() or inspection_panel == null or not inspection_panel.visible:
		return
	# Containers finish text reflow after the initial assignment. Shrink to the
	# updated minimum as well, instead of retaining a previous card's height.
	inspection_panel.reset_size()
	var pointer := get_local_mouse_position()
	var extent := inspection_panel.size
	var point := pointer + Vector2(20, 16)
	if point.x + extent.x > size.x - 12: point.x = pointer.x - extent.x - 18
	if point.y + extent.y > dock.position.y - 8: point.y = pointer.y - extent.y - 16
	point.x = clampf(point.x, 12, maxf(12, size.x - extent.x - 12))
	point.y = clampf(point.y, 12, maxf(12, dock.position.y - extent.y - 8))
	inspection_panel.position = point
