extends HBoxContainer
## Camp commands are delegated to saved company rules; this view owns no random state.
const Company = preload("res://core/company_rules.gd")
var controller: Control
var pending: Array = []
var feedback := ""
const STARTS := [[2, 2], [2, 3], [1, 3], [1, 4]]

func build(owner_control: Control, message: String = "") -> void:
	controller = owner_control
	feedback = message
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var view := Company.get_view(controller.campaign)
	pending = view.deployment.duplicate(true)
	var left: VBoxContainer = controller._panel(self)
	controller._text(left, "佣兵团 · 招聘与出战", 27, controller.GOLD)
	controller._text(left, "最多四人出战，其余留营。重伤休养中的队员不能出征。", 16, controller.MUTED)
	if not feedback.is_empty(): controller._text(left, feedback, 17, controller.GOLD)
	for unit: Dictionary in view.roster:
		if int(unit.hp) <= 0: continue
		var row := HBoxContainer.new()
		left.add_child(row)
		var selected := _slot_for(str(unit.id))
		var toggle := CheckButton.new()
		toggle.text = "%s · %s · 生命%d/%d" % [str(unit.name), str(unit.get("background_name", unit.kind)), int(unit.hp), int(unit.max_hp)]
		toggle.button_pressed = selected >= 0
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var recovering := int(unit.get("recovery_until_day", 0)) > int(controller.campaign.day)
		toggle.disabled = recovering and selected < 0
		row.add_child(toggle)
		toggle.toggled.connect(func(enabled: bool): _toggle_member(str(unit.id), enabled))
		if selected >= 0:
			var position_choice := OptionButton.new()
			for index in range(STARTS.size()): position_choice.add_item("位置%d (%d,%d)" % [index + 1, STARTS[index][0], STARTS[index][1]])
			for index in range(STARTS.size()):
				if int(pending[selected].q) == STARTS[index][0] and int(pending[selected].r) == STARTS[index][1]: position_choice.select(index)
			position_choice.item_selected.connect(func(index: int): _place(str(unit.id), index))
			row.add_child(position_choice)
		var history: Array = unit.get("character_history", [])
		if unit.has("permanent_injuries") or unit.has("personality") or recovering:
			controller._text(left, "休养至第%d天" % int(unit.recovery_until_day) if recovering else str(history.back()) if not history.is_empty() else "经历已记录", 14, controller.MUTED)
		if not str(unit.get("permanent_injury_description", "")).is_empty():
			controller._text(left, str(unit.permanent_injury_description), 14, controller.MUTED)
	controller._button(left, "返回营地", controller._show_camp_view)
	var right: VBoxContainer = controller._panel(self, 410, false)
	var maintenance: Dictionary = view.maintenance
	controller._text(right, "每日维护 %d 金 · 欠薪 %d 金" % [int(maintenance.daily_cost), int(maintenance.debt)], 20, controller.GOLD)
	controller._text(right, "下次结算：第%d天。存读档和重开菜单不会重复扣款。" % int(maintenance.next_day), 14, controller.MUTED)
	controller._button(right, "渡口短工 · 恢复钱粮", func(): _result(Company.short_work(controller.campaign)))
	controller._button(right, "紧急补员 · 预支签约", func(): _result(Company.emergency_recruit(controller.campaign)))
	controller._text(right, "招聘候选", 23, controller.GOLD)
	for candidate: Dictionary in view.candidates:
		controller._text(right, "%s · %s" % [str(candidate.name), str({"ordinary": "新兵", "veteran": "老兵"}.get(candidate.background, candidate.background))], 18)
		controller._text(right, "%s\n签约%d金 · 每日%d金" % [str(candidate.description), int(candidate.fee), int(candidate.wage)], 14, controller.MUTED)
		var button: Button = controller._button(right, "招募 " + str(candidate.name), func(): _result(Company.recruit(controller.campaign, str(candidate.id))))
		button.disabled = not bool(candidate.get("available", false))
		button.tooltip_text = str(candidate.get("reason", ""))
	controller._button(right, "更新招聘名单 · %d金" % int(view.get("refresh_cost", 6)), func(): _result(Company.refresh(controller.campaign)))
	var event: Dictionary = view.get("event", {})
	if not event.is_empty():
		controller._text(right, str(event.title), 21, controller.GOLD)
		controller._text(right, str(event.text), 15)
		for choice: Dictionary in event.get("choices", []):
			controller._button(right, str(choice.title), func(): _result(Company.resolve_event(controller.campaign, str(choice.id))), str(choice.get("description", "")))

func _slot_for(id: String) -> int:
	for index in range(pending.size()):
		if str(pending[index].unit_id) == id: return index
	return -1

func _toggle_member(id: String, enabled: bool) -> void:
	var next := pending.duplicate(true)
	var index := _slot_for(id)
	if not enabled and index >= 0: next.remove_at(index)
	elif enabled and index < 0:
		for pos: Array in STARTS:
			var used := false
			for slot: Dictionary in next:
				if int(slot.q) == pos[0] and int(slot.r) == pos[1]: used = true
			if not used:
				next.append({"unit_id": id, "q": pos[0], "r": pos[1]}); break
		if next.size() == pending.size():
			controller._show_company("最多四名出战者，请先取消一位。"); return
	_result(Company.select_deployment(controller.campaign, next))

func _place(id: String, index: int) -> void:
	var next := pending.duplicate(true)
	var current := _slot_for(id)
	var old: Dictionary = next[current].duplicate(true)
	for slot: Dictionary in next:
		if int(slot.q) == STARTS[index][0] and int(slot.r) == STARTS[index][1]:
			slot.q = old.q; slot.r = old.r
	next[current].q = STARTS[index][0]; next[current].r = STARTS[index][1]
	_result(Company.select_deployment(controller.campaign, next))

func _result(result: Dictionary) -> void:
	if result.get("ok", false): controller._autosave()
	controller._show_company(str(result.get("reason", "")))
