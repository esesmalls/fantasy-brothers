extends HBoxContainer
## Character ledger is a read-only view; the controller owns all commands and saves.
const Characters = preload("res://core/character_rules.gd")
const Portrait = preload("res://presentation/character_portrait.gd")
const Glyph = preload("res://presentation/tactical_glyph.gd")
var controller: Control
var view: Dictionary = {}
var unit_buttons: Dictionary = {}
var upgrade_buttons: Dictionary = {}
var training_buttons: Dictionary = {}
var stat_labels: Dictionary = {}
var back_button: Button
var equipment_button: Button
var points_label: Label
var experience_label: Label
var portrait: Control
var history_button: Button
var history_box: VBoxContainer
var heading_labels: Array[Label] = []
var abilities_label: Label

func build(owner_control: Control, unit_id: String) -> void:
	controller = owner_control
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	view = Characters.get_view(controller.campaign, unit_id)
	var selected: Dictionary = view.get("selected_unit", {})
	controller.character_unit_id = str(selected.get("id", ""))
	var roster: VBoxContainer = controller._panel(self, 228, false)
	_heading(roster, "人物帐", "guard")
	controller._text(roster, "选一名伙伴，决定他下一步学什么。", 15, controller.MUTED)
	for unit: Dictionary in view.get("units", []):
		var id: String = str(unit.id)
		var button: Button = controller._button(roster, "%s · %d级" % [str(unit.name), int(unit.get("level", 1))], func(): controller._show_characters(id))
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.clip_text = true
		button.tooltip_text = str(unit.get("background_name", controller.KINDS.get(str(unit.kind), "")))
		unit_buttons[id] = button
		if id == str(selected.get("id", "")):
			button.add_theme_color_override("font_color", controller.GOLD)
		if int(unit.get("hp", 0)) <= 0:
			controller._text(roster, "已阵亡 · 经历留在团志", 14, controller.RED)
	portrait = Portrait.new()
	portrait.custom_minimum_size = Vector2(184, 185)
	roster.add_child(portrait)
	if not selected.is_empty(): portrait.set_unit(selected)
	equipment_button = controller._button(roster, "查看随身装备", func(): controller._show_equipment(str(selected.get("id", ""))))
	back_button = controller._button(roster, "返回营地生活", controller._show_camp_view)
	var ledger: VBoxContainer = controller._panel(self)
	controller._text(ledger, str(selected.get("name", "暂无队员")), 30, controller.GOLD)
	controller._text(ledger, str(view.get("background_name", "")), 19)
	controller._text(ledger, str(view.get("background_description", "出身是来时的路，训练决定下一段路。")), 15, controller.MUTED)
	if selected.is_empty(): return
	controller._text(ledger, "生命 %d / %d   ·   护甲 %d / %d" % [int(selected.hp), int(selected.max_hp), int(selected.armor), int(selected.max_armor)], 18)
	var xp_next: int = int(view.get("xp_next", 0))
	var xp: int = int(view.get("xp", 0))
	experience_label = controller._text(ledger, "%d级 · 累计经验 %d / %d" % [int(view.get("level", 1)), xp, xp_next] if xp_next > 0 else "%d级 · 累计经验 %d" % [int(view.get("level", 1)), xp], 17, controller.GOLD)
	if int(view.get("level", 1)) >= Characters.Data.MAX_LEVEL:
		experience_label.text = "%d级 · 当前等级上限 · 累计经验 %d" % [int(view.level), xp]
	var progress := ProgressBar.new()
	progress.custom_minimum_size.y = 7
	progress.show_percentage = false
	progress.max_value = maxi(1, xp_next if xp_next > 0 else xp)
	progress.value = xp
	progress.add_theme_stylebox_override("background", controller._style("111c1d", "111c1d", 0))
	progress.add_theme_stylebox_override("fill", controller._style("b2945e", "b2945e", 0))
	ledger.add_child(progress)
	points_label = controller._text(ledger, "可分配培养点 · %d" % int(view.get("attribute_points", 0)), 19, controller.GOLD)
	controller._text(ledger, "每次提升花费 1 点。选择前可查看数值变化；换装备不会抹去练出的本领。", 14, controller.MUTED)
	for stat: Dictionary in view.get("stats", []):
		_stat_card(ledger, stat)
	controller._text(ledger, "已学本领", 20, controller.GOLD)
	var abilities: Array[String] = []
	for ability in view.get("capabilities", []): abilities.append(str(ability))
	for perk in selected.get("perks", []):
		abilities.append(str(controller.Campaign.PERK_INFO.get(str(perk), {"title": str(perk)}).title))
	abilities_label = controller._text(ledger, " · ".join(abilities) if not abilities.is_empty() else "从基础训练开始，远征会带来新的经历。", 15, controller.MUTED)
	var training: VBoxContainer = controller._panel(self, 336, false)
	_heading(training, "营地操练", "spear")
	controller._text(training, "实践额度 %d · 口粮 %d · 金币 %d" % [int(view.get("training_credits", 0)), int(controller.campaign.food), int(controller.campaign.gold)], 16, controller.GOLD)
	if not controller.character_notice.is_empty():
		var notice := PanelContainer.new()
		notice.add_theme_stylebox_override("panel", controller._style("314037", "9a8255", 10))
		training.add_child(notice)
		controller._text(notice, controller.character_notice, 15, controller.GOLD)
	controller._text(training, "训练的耗时、花费与效果列在下方。实践额度有限，出征历练后再继续深造。", 14, controller.MUTED)
	for option: Dictionary in view.get("training_options", []):
		training.add_child(HSeparator.new())
		controller._text(training, str(option.get("name", "训练")), 19)
		controller._text(training, str(option.get("description", "")), 15, controller.MUTED)
		controller._text(training, str(option.get("cost_text", "")), 14, controller.GOLD)
		var id: String = str(option.id)
		var button: Button = controller._button(training, "安排 · " + str(option.get("name", "训练")), func(): controller._character_action("train", id))
		button.disabled = not bool(option.get("available", false))
		button.tooltip_text = str(option.get("reason", ""))
		training_buttons[id] = button
		if button.disabled and not str(option.get("reason", "")).is_empty():
			controller._text(training, str(option.reason), 14, controller.MUTED)
	training.add_child(HSeparator.new())
	history_button = controller._button(training, "展开个人履历 ▾", _toggle_history)
	history_box = VBoxContainer.new()
	training.add_child(history_box)
	var history: Array = view.get("history", [])
	if history.is_empty(): controller._text(history_box, "旅程刚刚开始。训练与成长会记在这里。", 15, controller.MUTED)
	for line in history: controller._text(history_box, str(line), 14, controller.MUTED)
	history_box.hide()

func _stat_card(parent: VBoxContainer, stat: Dictionary) -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", controller._style("23332f", "485b4d", 10))
	parent.add_child(card)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	card.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	box.add_child(row)
	var name_label: Label = controller._text(row, "%s  %d" % [str(stat.name), int(stat.value)], 21, controller.GOLD)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_labels[str(stat.id)] = name_label
	var stat_id: String = str(stat.id)
	var button: Button = controller._button(row, "+%d · 1点" % int(stat.get("upgrade_amount", 0)), func(): controller._character_action("attribute", stat_id))
	button.custom_minimum_size = Vector2(94, 36)
	button.add_theme_font_size_override("font_size", 15)
	button.disabled = not bool(stat.get("can_upgrade", false))
	button.tooltip_text = str(stat.get("upgrade_reason", "")) if button.disabled else "确认提升%s：%d → %d，消耗1培养点。" % [str(stat.name), int(stat.value), int(stat.value) + int(stat.get("upgrade_amount", 0))]
	upgrade_buttons[stat_id] = button
	var source: String = "基础 %d" % int(stat.get("base", 0))
	for component: Array in [["growth", "培养"], ["equipment", "装备"], ["compat", "既有能力"], ["perk", "专长"]]:
		var amount: int = int(stat.get(str(component[0]), 0))
		if amount != 0: source += "  ·  %s %+d" % [str(component[1]), amount]
	var detail: Label = controller._text(box, source, 13, controller.MUTED)
	detail.tooltip_text = str(stat.get("description", ""))
	controller._text(box, str(stat.get("description", "")), 14, controller.MUTED)

func _toggle_history() -> void:
	history_box.visible = not history_box.visible
	history_button.text = "收起个人履历 ▴" if history_box.visible else "展开个人履历 ▾"

func _heading(parent: Node, title: String, glyph: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var icon := Glyph.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.set_glyph(glyph)
	row.add_child(icon)
	var label: Label = controller._text(row, title, 23, controller.GOLD)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_labels.append(label)
