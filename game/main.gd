extends Control

const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Saves = preload("res://core/save_store.gd")
const Board = preload("res://presentation/battle_board.gd")
const CREAM = Color("e7ddc6")
const MUTED = Color("9caeaa")
const GOLD = Color("c8aa6e")
const RED = Color("e49b80")
const KINDS = {"guard": "盾卫", "spear": "长枪手", "archer": "弓手", "skirmisher": "游击者", "hunter": "猎人", "dog": "战犬", "raider": "劫掠者"}

var campaign: Dictionary = {}
var save_path: String = "user://campaign.json"
var manual_path: String = "user://manual.json"
var selected_action: String = "move"
var animation_speed: float = 1.0
var screen: VBoxContainer
var body: Control
var banner: Label
var resources: Label
var footer: Label
var board: Control
var action_box: GridContainer
var active_label: Label
var preview_label: Label
var log_label: Label
var turn_label: Label
var supplies_label: Label
var end_button: Button
var resolve_button: Button
var action_buttons: Dictionary = {}
var ai_timer: float = 0.0
var busy: bool = false
var modal_open: bool = false
var notice: String = ""
var smoke_mode: bool = false
var outcome_label: Label
var reachable: Array = []
var route_buttons: Dictionary = {}

func _ready() -> void:
	_build_theme()
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--smoke-test":
			smoke_mode = true
			save_path = "user://qa/campaign.json"
			manual_path = "user://qa/manual.json"
	_build_shell()
	_show_title()
	if smoke_mode:
		call_deferred("_run_smoke")

func _build_theme() -> void:
	var skin: Theme = Theme.new()
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft YaHei", "Microsoft YaHei UI", "Noto Sans CJK SC", "Arial"])
	skin.default_font = font
	skin.default_font_size = 17
	skin.set_color("font_color", "Label", CREAM)
	skin.set_color("font_color", "Button", CREAM)
	skin.set_color("font_hover_color", "Button", Color("fff1ce"))
	skin.set_color("font_disabled_color", "Button", Color("687773"))
	skin.set_stylebox("normal", "Button", _style("283936", "526459", 9))
	skin.set_stylebox("hover", "Button", _style("374b43", "bb9d61", 9))
	skin.set_stylebox("pressed", "Button", _style("4b4b35", "d6bc80", 9))
	skin.set_stylebox("focus", "Button", _style("00000000", "d6bc80", 9))
	skin.set_stylebox("disabled", "Button", _style("202d2b", "34413d", 9))
	skin.set_stylebox("panel", "PanelContainer", _style("1c2a2b", "3d4d45", 18))
	skin.set_constant("separation", "VBoxContainer", 12)
	skin.set_constant("separation", "HBoxContainer", 18)
	theme = skin

func _style(fill: String, edge: String, padding: int) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(fill)
	style.border_color = Color(edge)
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _build_shell() -> void:
	var background: ColorRect = ColorRect.new()
	background.color = Color("101b1d")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24 if edge in ["left", "right"] else 16)
	add_child(margin)
	screen = VBoxContainer.new()
	margin.add_child(screen)
	var heading: HBoxContainer = HBoxContainer.new()
	screen.add_child(heading)
	var brand: Label = _label("灰 烬 誓 约", 27, GOLD)
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(brand)
	_button(heading, "玩法指引", _show_help)
	_button(heading, "手动保存", _manual_save)
	_button(heading, "读取手动档", _confirm_load)
	_button(heading, "主菜单", _confirm_menu)
	resources = _label("边境佣兵纪事   /   最小可玩验证 0.1.1", 17, MUTED)
	screen.add_child(resources)
	banner = _label("", 16, GOLD)
	screen.add_child(banner)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	screen.add_child(body)
	footer = _label("原创机制原型  ·  所有数值与美术均待试玩打磨", 14, MUTED)
	screen.add_child(footer)

func _clear_body() -> void:
	board = null
	for child in body.get_children():
		body.remove_child(child)
		child.queue_free()
	action_buttons.clear()
	route_buttons.clear()
	busy = false

func _label(text: String, font_size: int = 17, color: Color = CREAM) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _text(parent: Node, text: String, font_size: int = 17, color: Color = CREAM) -> Label:
	var label: Label = _label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable, tip: String = "") -> Button:
	var button: Button = Button.new()
	button.text = text
	button.tooltip_text = tip
	button.custom_minimum_size.y = 42
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _panel(parent: Node, width: float = 0.0, expand: bool = true) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = width
	if expand:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(panel)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	return box

func _show_title() -> void:
	_clear_body()
	banner.text = "序章   /   渡桥的钟声"
	resources.text = "边境佣兵纪事   /   最小可玩验证 0.1.1"
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var intro: VBoxContainer = _panel(columns)
	_text(intro, "钟声将歇，\n你的誓约仍在。", 42, GOLD)
	_text(intro, "旧王国的边境，粮仓与渡桥都需要守卫。\n你带着四个出战位、一面旗帜，和一群会受伤、会成长、也会死去的同伴，接下第一份契约。", 21)
	_text(intro, "每一次远征", 24, GOLD)
	_text(intro, "整备队伍  →  决定承诺  →  指挥战斗\n承担后果  →  选择成长  →  带着经历回营", 20)
	_text(intro, "三次远征形成一个短篇结尾，此后仍可继续。试着保住粮仓、让盾卫为长枪制造破绽，或用油火和水汽改变战线。", 18, MUTED)
	_text(intro, "原型边界：两类佣兵团、六个条件事件、一张机制战场、少量成长。当前用于判断玩法，不代表最终内容量与商业美术。", 16, MUTED)
	var setup: VBoxContainer = _panel(columns, 410, false)
	_text(setup, "接过这面旗帜", 26, GOLD)
	var loaded: Dictionary = Saves.load_campaign(save_path)
	var continue_button: Button = _button(setup, "继续上次的佣兵团", _continue_campaign)
	continue_button.disabled = not loaded.get("ok", false)
	if loaded.get("ok", false):
		_text(setup, "%s · 第 %d 天%s" % [str(loaded.campaign.company_name), int(loaded.campaign.day), "（将恢复备份）" if loaded.get("recovered", false) else ""], 16, MUTED)
	else:
		_text(setup, str(loaded.reason), 16, MUTED)
	_text(setup, "建立新的佣兵团", 22)
	var seed_input: LineEdit = LineEdit.new()
	seed_input.placeholder_text = "远征种子（留空随机，例如 1709）"
	seed_input.custom_minimum_size.y = 42
	setup.add_child(seed_input)
	_button(setup, "自由佣兵团  ·  盾 / 枪 / 弓 / 刃", func(): _request_new("free", seed_input.text))
	_text(setup, "四名佣兵直接听从指挥。盾击破绽与长枪配合，远程牵制后排。", 16, MUTED)
	_button(setup, "雾林猎团  ·  盾 / 枪 / 猎人 / 犬", func(): _request_new("hunters", seed_input.text))
	_text(setup, "战犬占一个出战位，按猎人指令在自身回合行动；也需要口粮，并承担伤亡。", 16, MUTED)
	_text(setup, "操作：选择动作，再点击目标格。\n空格结束当前回合，Esc 取消动作。\n事件、动作、结算与成长后自动保存。", 16, MUTED)

func _request_new(origin: String, seed_text: String) -> void:
	seed_text = seed_text.strip_edges()
	if not seed_text.is_empty() and (not seed_text.is_valid_int() or int(seed_text) < 0 or int(seed_text) > 2000000000):
		_popup("种子格式不正确", "请输入 0 到 2000000000 之间的整数，或留空使用随机种子。")
		return
	var seed_value: int = int(seed_text) if seed_text.is_valid_int() else int(Time.get_unix_time_from_system()) % 2000000000
	if Saves.load_campaign(save_path).get("ok", false):
		_confirm("建立新佣兵团？", "将替换自动存档；手动存档保留。你可先取消并手动保存当前旅程。", func(): _new_campaign(origin, seed_value))
	else:
		_new_campaign(origin, seed_value)

func _new_campaign(origin: String, seed_value: int) -> void:
	campaign = Campaign.create_campaign(origin, seed_value)
	notice = "新旅程开始。先查看四名队员，再接下契约。"
	_autosave()
	_show_campaign()

func _continue_campaign() -> void:
	_load(save_path)

func _load(path: String) -> void:
	var result: Dictionary = Saves.load_campaign(path)
	if not result.get("ok", false):
		_popup("读取失败", str(result.reason))
		return
	campaign = result.campaign
	notice = str(result.reason)
	_show_campaign()

func _autosave() -> void:
	var result: Dictionary = Saves.save_campaign(campaign, save_path)
	footer.text = "自动保存 · " + Time.get_time_string_from_system() if result.ok else str(result.reason)
	footer.add_theme_color_override("font_color", MUTED if result.ok else RED)

func _manual_save() -> void:
	if campaign.is_empty():
		_popup("尚未启程", "先建立或继续一支佣兵团。")
		return
	var result: Dictionary = Saves.save_campaign(campaign, manual_path)
	footer.text = "手动存档 · " + str(result.reason)

func _confirm_load() -> void:
	_confirm("读取手动存档？", "当前自动存档会保留。读取后继续行动时，将从手动存档的进度接续。", func(): _load(manual_path))

func _confirm_menu() -> void:
	if campaign.is_empty():
		_show_title()
	else:
		_confirm("返回主菜单？", "已完成的选择和战斗动作均已自动保存，可从主菜单继续。", _show_title)

func _show_campaign() -> void:
	_clear_body()
	_update_resources()
	var phase: String = str(campaign.phase)
	banner.text = "整备营地  /  途中抉择  /  战术交锋  /  命运与成长"
	if phase == "battle":
		_show_battle()
		return
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	_show_roster(_panel(columns, 302, false))
	var story: VBoxContainer = _panel(columns)
	var actions: VBoxContainer = _panel(columns, 310, false)
	if phase == "camp":
		_show_camp(story, actions)
	elif phase == "event":
		_text(story, "途中抉择", 16, GOLD)
		_text(story, str(campaign.event.title), 30)
		_text(story, str(campaign.event.body), 20)
		_text(story, "承诺会留在团志里，并改变这次远征的准备和回报。", 16, MUTED)
		_text(actions, "你的决定", 24, GOLD)
		for choice: Dictionary in campaign.event.choices:
			_button(actions, str(choice.title), func(): _event_choice(str(choice.id)))
			_text(actions, str(choice.description), 16, MUTED)
	elif phase == "ready":
		_text(story, "契约已立", 16, GOLD)
		_text(story, str(campaign.expedition.title), 32)
		_text(story, "行军路线 · " + str(campaign.expedition.get("route_name", "渡口旧道")), 18, GOLD)
		_text(story, str(campaign.last_report), 20)
		_text(story, "目标：击退所有敌人。\n额外承诺：保住粮仓，带回粮食与谢礼。\n死亡永久保留；生命与护甲损耗需要回营恢复。", 18, MUTED)
		_text(actions, "抵达战场", 24, GOLD)
		_text(actions, "报酬 %d 金\n敌情 %s\n油瓶 %d · 火种 %d · 水具 %d" % [int(campaign.expedition.reward), ["小股劫匪", "有备而来", "增援集结"][int(campaign.expedition.difficulty)], int(campaign.expedition.supplies.oil), int(campaign.expedition.supplies.fire), int(campaign.expedition.supplies.water)], 18)
		_button(actions, "进入战场", _enter_battle)
		_text(actions, "先看预览，再下命令。油火会波及友军，蒸汽也会挡住己方射线。", 16, MUTED)
	elif phase == "growth":
		_text(story, "远征归来", 16, GOLD)
		_text(story, "活下来的经验", 32)
		_text(story, str(campaign.last_report), 18)
		var student: String = "幸存队员"
		for unit: Dictionary in campaign.roster:
			if str(unit.id) == str(campaign.growth_unit_id):
				student = str(unit.name)
		_text(actions, student + "的成长", 24, GOLD)
		for offer: Dictionary in campaign.growth_offers:
			_button(actions, str(offer.title), func(): _growth_choice(str(offer.id)))
			_text(actions, str(offer.description), 16, MUTED)
		_text(actions, "只选择一项。候选已随远征保存，重新打开界面不会重抽。", 15, MUTED)
	if not notice.is_empty():
		banner.text = notice

func _update_resources() -> void:
	resources.text = "%s    /    第 %d 天    /    金币 %d    口粮 %d    声望 %d    /    远征 %d    /    种子 %d" % [str(campaign.company_name), int(campaign.day), int(campaign.gold), int(campaign.food), int(campaign.renown), int(campaign.flags.expeditions_started), int(campaign.seed)]

func _show_roster(box: VBoxContainer) -> void:
	_text(box, "旗帜之下", 25, GOLD)
	_text(box, "四个出战位 · 伤亡与成长持续保留", 15, MUTED)
	for unit: Dictionary in campaign.roster:
		_text(box, "%s  /  %s" % [str(unit.name), str(KINDS.get(unit.kind, unit.kind))], 21)
		if int(unit.hp) <= 0:
			_text(box, "已阵亡 · 回营可招募继承者", 16, RED)
		else:
			_text(box, "生命 %d/%d    护甲 %d/%d" % [int(unit.hp), int(unit.max_hp), int(unit.armor), int(unit.max_armor)], 16, MUTED)
			var bar: ProgressBar = ProgressBar.new()
			bar.max_value = int(unit.max_hp)
			bar.value = int(unit.hp)
			bar.show_percentage = false
			bar.custom_minimum_size.y = 6
			bar.add_theme_stylebox_override("background", _style("111c1d", "111c1d", 0))
			bar.add_theme_stylebox_override("fill", _style("619085", "619085", 0))
			box.add_child(bar)
			var perks: Array[String] = []
			for perk in unit.perks:
				perks.append(str(Campaign.PERK_INFO.get(perk, {"title": perk}).title))
			_text(box, " · ".join(perks) if not perks.is_empty() else "尚无专长 · 远征胜利后获得成长", 14, GOLD if not perks.is_empty() else MUTED)
		box.add_child(HSeparator.new())
	var memorial: Array = campaign.flags.get("memorial", [])
	if not memorial.is_empty():
		_text(box, "纪念册 · %d 位逝者" % memorial.size(), 17, RED)

func _show_camp(story: VBoxContainer, actions: VBoxContainer) -> void:
	_text(story, "营地  /  灰岸渡口", 16, GOLD)
	_text(story, "火未熄，路未尽。", 32)
	_text(story, str(campaign.last_report) if not str(campaign.last_report).is_empty() else "渡口的钟声从雾里传来。村民正在搬走最后一批粮食，粮仓外却已经出现劫掠者。你们需要决定，为谁留下，以及带什么回来。", 19)
	if bool(campaign.flags.get("ending_seen", false)):
		_text(story, "团志 · 渡桥的钟声", 23, GOLD)
		_text(story, str(campaign.flags.get("ending_text", "")), 17)
	_text(story, "新的契约 · 雨夜粮仓", 25, GOLD)
	_text(story, "先选路线，再处理途中事件。下列敌情、报酬与补给是出发时的准备，途中选择还会改变它们。", 16, MUTED)
	for route: Dictionary in Campaign.get_routes(campaign):
		var route_id: String = str(route.id)
		var route_button: Button = _button(story, str(route.name) + "  ·  接约出征", func(): _start_expedition(route_id))
		route_button.disabled = not bool(route.available)
		route_buttons[route_id] = route_button
		_text(story, str(route.description), 16, MUTED)
		_text(story, "%d 粮 · %d 天  /  %s  /  报酬 %d 金\n油瓶 %d · 火种 %d · 水具 %d" % [int(route.food_cost), int(route.days), ["小股劫匪", "有备而来", "增援集结"][int(route.difficulty)], int(route.reward), int(route.supplies.oil), int(route.supplies.fire), int(route.supplies.water)], 16, GOLD)
		if not bool(route.available):
			_text(story, str(route.reason), 15, RED)
	_text(actions, "整备与启程", 24, GOLD)
	_text(actions, "在中间选择行军路线。\n建议先恢复生命与护甲。", 16, MUTED)
	_button(actions, "休养一天", func(): _camp_action("rest"), "有粮消耗2粮，每人恢复18生命；缺粮恢复8。")
	_button(actions, "补给口粮", func(): _camp_action("resupply"), "12金币购买最多6粮；缺钱缺粮时短工换粮。")
	_button(actions, "修补护甲", func(): _camp_action("repair"), "每名受损队员4金币；无钱时用一天修补6护甲。")
	_button(actions, "补齐空缺", func(): _camp_action("recruit"), "佣兵28金，战犬18金；不足时预支，战利品最多扣三分之一还款。")
	_text(actions, "休养：2 粮恢复 18 生命\n补给：12 金换最多 6 粮\n修补：每名受损队员 4 金\n补员：佣兵 28 金 / 战犬 18 金", 16, MUTED)
	_text(actions, "缺钱时可短工、慢慢休养或预支补员。死亡不会被休养抹去。", 15, MUTED)
	if int(campaign.flags.get("advance_debt", 0)) > 0:
		_text(actions, "预支签约款：%d 金" % int(campaign.flags.advance_debt), 16, RED)

func _camp_action(action: String) -> void:
	_handle_campaign(Campaign.camp_action(campaign, action))

func _start_expedition(route_id: String = "road") -> void:
	_handle_campaign(Campaign.start_expedition(campaign, route_id))

func _event_choice(choice: String) -> void:
	_handle_campaign(Campaign.choose_event(campaign, choice))

func _growth_choice(offer: String) -> void:
	_handle_campaign(Campaign.choose_growth(campaign, offer))

func _handle_campaign(result: Dictionary) -> void:
	if not result.get("ok", false):
		_popup("暂时无法执行", str(result.get("reason", "")))
		return
	notice = ""
	_autosave()
	_show_campaign()

func _enter_battle() -> void:
	if str(campaign.phase) != "ready":
		return
	campaign.battle = Battle.create_battle(campaign.roster, int(campaign.seed) + int(campaign.expedition.index) * 7919, Campaign.battle_config(campaign))
	campaign.phase = "battle"
	selected_action = "move"
	notice = ""
	_autosave()
	_show_campaign()

func _show_battle() -> void:
	var columns: HBoxContainer = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(columns)
	var field: VBoxContainer = VBoxContainer.new()
	field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(field)
	turn_label = _text(field, "", 16, MUTED)
	board = Board.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field.add_child(board)
	board.cell_clicked.connect(_on_cell_clicked)
	board.cell_hovered.connect(_on_cell_hovered)
	board.set_animation_speed(animation_speed)
	outcome_label = _text(field, "目标：击退敌人  ·  尽量保住粮仓  ·  点击动作后，在棋盘选择目标", 17, GOLD)
	var side_panel: PanelContainer = PanelContainer.new()
	side_panel.custom_minimum_size.x = 325
	columns.add_child(side_panel)
	var sidebar: VBoxContainer = VBoxContainer.new()
	sidebar.add_theme_constant_override("separation", 8)
	side_panel.add_child(sidebar)
	active_label = _text(sidebar, "", 22, GOLD)
	supplies_label = _text(sidebar, "", 15, MUTED)
	var action_scroll: ScrollContainer = ScrollContainer.new()
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sidebar.add_child(action_scroll)
	var action_content: VBoxContainer = VBoxContainer.new()
	action_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_content.add_theme_constant_override("separation", 9)
	action_scroll.add_child(action_content)
	action_box = GridContainer.new()
	action_box.columns = 2
	action_box.add_theme_constant_override("h_separation", 6)
	action_box.add_theme_constant_override("v_separation", 6)
	action_content.add_child(action_box)
	preview_label = _text(action_content, "", 16)
	preview_label.custom_minimum_size.y = 80
	_text(action_content, "交锋记录", 19, GOLD)
	log_label = _text(action_content, "", 14, MUTED)
	end_button = _button(sidebar, "结束此人回合  [空格]", _end_turn)
	resolve_button = _button(sidebar, "清点伤亡，返回营地", _resolve)
	_button(sidebar, "撤离战场", func(): _confirm("撤离战场？", "未完成契约没有报酬；伤亡、消耗与粮仓失守都会计入结果。", _retreat))
	var speeds: HBoxContainer = HBoxContainer.new()
	speeds.add_theme_constant_override("separation", 5)
	sidebar.add_child(speeds)
	for entry in [["正常", 1.0], ["加速", 3.0], ["跳过", 0.0]]:
		var value: float = float(entry[1])
		var speed_button: Button = _button(speeds, str(entry[0]), func(): _set_speed(value))
		speed_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_refresh_battle()

func _refresh_battle(events: Array = []) -> void:
	if board == null:
		return
	var b: Dictionary = campaign.battle
	board.set_battle(b)
	board.play_events(events)
	var active: Dictionary = Battle.active_unit(b)
	var done: bool = not str(b.outcome).is_empty()
	var player: bool = not active.is_empty() and str(active.team) == "player" and str(active.kind) != "dog"
	if player:
		var known_action := false
		for action: Dictionary in Battle.get_actions(b, str(active.id)):
			known_action = known_action or str(action.id) == selected_action
		if not known_action:
			selected_action = "move"
	board.set_selected(str(active.get("id", "")))
	var order_names: Array[String] = []
	for unit_id in b.order:
		for unit in b.units:
			if str(unit.id) == str(unit_id) and int(unit.hp) > 0:
				order_names.append(("▶ " if str(unit_id) == str(active.get("id", "")) else "") + str(unit.name))
	turn_label.text = "第 %d 轮   /   %s" % [int(b.round), "  ·  ".join(order_names)]
	active_label.text = "交锋结束" if done else "%s · %s\n行动点 %d / %d" % [str(active.get("name", "")), str(KINDS.get(active.get("kind", ""), "")), int(active.get("ap", 0)), int(active.get("max_ap", 6))]
	supplies_label.text = "油瓶 %d   火种 %d   水具 %d" % [int(b.supplies.oil), int(b.supplies.fire), int(b.supplies.water)]
	for child in action_box.get_children():
		action_box.remove_child(child)
		child.queue_free()
	action_buttons.clear()
	if player and not done:
		for action: Dictionary in Battle.get_actions(b, str(active.id)):
			var range_text: String = " · %d 格" % int(action.range) if str(action.target) != "self" and str(action.id) != "move" else ""
			var button: Button = _button(action_box, ("◆ " if selected_action == str(action.id) else "") + "%s\n%d 行动点%s" % [str(action.name), int(action.cost), range_text], func(): _choose_action(str(action.id)), str(action.description))
			button.custom_minimum_size.y = 46
			button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			button.add_theme_font_size_override("font_size", 14)
			button.disabled = int(active.ap) < int(action.cost) or (str(action.id) in ["oil", "fire", "water"] and int(b.supplies.get(action.id, 0)) <= 0)
			action_buttons[str(action.id)] = button
	end_button.disabled = not player or done
	end_button.visible = not done
	resolve_button.visible = done
	preview_label.text = "选择攻击或技能显示范围；移到目标格查看结果，单击执行。" if player else "敌方正在行动……" if not done and str(active.get("team", "")) == "enemy" else "战犬正在执行指令……"
	preview_label.add_theme_color_override("font_color", CREAM)
	if not done:
		for prop: Dictionary in b.props:
			if str(prop.kind) == "grain":
				outcome_label.text = "目标：击退敌人  /  粮仓耐久 %d/%d  /  %s" % [maxi(0, int(prop.hp)), int(prop.max_hp), "守住粮仓有额外谢礼" if int(prop.hp) > 0 else "粮仓已毁，仍可完成契约"]
	if player and int(active.ap) < 2:
		preview_label.text = "行动点即将耗尽。可以结束此人的回合。"
	if done:
		var names: Dictionary = {"victory": "胜利 · 敌人已被击退", "defeat": "败北 · 队伍无人幸存", "retreat": "撤离 · 誓约留下了代价"}
		outcome_label.text = str(names.get(b.outcome, b.outcome))
		preview_label.text = "战斗结果已保存。清点伤亡与报酬后，决定佣兵团接下来的路。"
	var lines: Array[String] = []
	for entry in b.log.slice(maxi(0, b.log.size() - 5)):
		lines.append(str(entry.get("text", "")) if entry is Dictionary else str(entry))
	log_label.text = "\n".join(lines)
	banner.text = "盾击制造破绽 → 长枪利用   /   油 + 火 → 火区   /   水 + 火 → 蒸汽"
	reachable = []
	if player and not done and selected_action == "move":
		for q in range(9):
			for r in range(7):
				if Battle.preview(b, str(active.id), "move", {"q": q, "r": r}).ok:
					reachable.append({"q": q, "r": r})
	board.set_preview({"reachable": reachable})
	var overlay: Dictionary = {}
	if player and not done:
		overlay = Battle.action_overlay(b, str(active.id), selected_action)
		overlay.action_id = selected_action
		for action: Dictionary in Battle.get_actions(b, str(active.id)):
			if str(action.id) == selected_action:
				overlay.action_name = str(action.name)
	board.set_action_overlay(overlay)

func _choose_action(action: String) -> void:
	if not _can_command():
		return
	selected_action = action
	var active: Dictionary = Battle.active_unit(campaign.battle)
	for item: Dictionary in Battle.get_actions(campaign.battle, str(active.id)):
		if str(item.id) == action and str(item.target) == "self":
			_execute_action({"q": int(active.q), "r": int(active.r)})
			return
	_refresh_battle()
	for item: Dictionary in Battle.get_actions(campaign.battle, str(active.id)):
		if str(item.id) == action:
			preview_label.text = str(item.description)

func _can_command() -> bool:
	if campaign.is_empty() or str(campaign.phase) != "battle" or board == null or modal_open or busy:
		return false
	var active: Dictionary = Battle.active_unit(campaign.battle)
	return not active.is_empty() and str(active.team) == "player" and str(active.kind) != "dog"

func _on_cell_hovered(q: int, r: int) -> void:
	if not _can_command():
		return
	if q < 0 or r < 0:
		board.set_preview({"reachable": reachable})
		preview_label.text = "选择动作，将鼠标移到目标格查看结果；单击执行。"
		preview_label.add_theme_color_override("font_color", CREAM)
		return
	var active: Dictionary = Battle.active_unit(campaign.battle)
	var p: Dictionary = Battle.preview(campaign.battle, str(active.id), selected_action, {"q": q, "r": r})
	p.reachable = reachable
	board.set_preview(p)
	var detail: String = ""
	for unit: Dictionary in campaign.battle.units:
		if int(unit.q) == q and int(unit.r) == r and int(unit.hp) > 0:
			detail = "\n%s · 生命 %d/%d · 护甲 %d/%d" % [str(unit.name), int(unit.hp), int(unit.max_hp), int(unit.armor), int(unit.max_armor)]
			var status_names: Dictionary = {"exposed": "破绽", "marked": "标记", "defending": "戒备", "pinned": "牵制"}
			for status in unit.statuses:
				detail += " / " + str(status_names.get(status, status))
	for prop: Dictionary in campaign.battle.props:
		if int(prop.q) == q and int(prop.r) == r and int(prop.hp) > 0:
			detail += "\n%s · 耐久 %d/%d" % [str({"oil": "油罐", "water": "水桶", "cover": "木障碍", "grain": "粮仓"}.get(prop.kind, prop.kind)), int(prop.hp), int(prop.max_hp)]
	preview_label.text = str(p.summary) + detail
	preview_label.add_theme_color_override("font_color", CREAM if p.ok else RED)

func _on_cell_clicked(q: int, r: int) -> void:
	if _can_command():
		_execute_action({"q": q, "r": r})

func _execute_action(target: Dictionary) -> void:
	var active: Dictionary = Battle.active_unit(campaign.battle)
	var result: Dictionary = Battle.apply_action(campaign.battle, str(active.id), selected_action, target)
	if not result.ok:
		preview_label.text = str(result.reason)
		return
	_autosave()
	_refresh_battle(result.events)
	ai_timer = 0.5

func _end_turn() -> void:
	if not _can_command():
		return
	var events: Array = Battle.end_turn(campaign.battle)
	selected_action = "move"
	_autosave()
	_refresh_battle(events)
	ai_timer = 0.55

func _process(delta: float) -> void:
	if board == null or campaign.is_empty() or str(campaign.phase) != "battle" or modal_open or smoke_mode:
		return
	ai_timer -= delta
	if ai_timer > 0.0:
		return
	var active: Dictionary = Battle.active_unit(campaign.battle)
	if active.is_empty() or (str(active.team) == "player" and str(active.kind) != "dog"):
		return
	var result: Dictionary = Battle.ai_step(campaign.battle)
	_autosave()
	_refresh_battle(result.get("events", []))
	ai_timer = 0.6 / animation_speed if animation_speed > 0 else 0.03

func _set_speed(speed: float) -> void:
	animation_speed = speed
	if board != null:
		board.set_animation_speed(speed)

func _retreat() -> void:
	if campaign.is_empty() or str(campaign.phase) != "battle" or not str(campaign.battle.outcome).is_empty():
		return
	Battle.retreat(campaign.battle)
	_autosave()
	_refresh_battle()

func _resolve() -> void:
	_handle_campaign(Campaign.resolve_battle(campaign, campaign.battle))

func _unhandled_key_input(event: InputEvent) -> void:
	if modal_open or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_SPACE and _can_command():
		_end_turn()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and _can_command():
		selected_action = "move"
		_refresh_battle()

func _confirm(title: String, message: String, action: Callable) -> void:
	modal_open = true
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "确认"
	dialog.cancel_button_text = "取消"
	dialog.min_size = Vector2i(570, 170)
	add_child(dialog)
	dialog.confirmed.connect(func():
		modal_open = false
		dialog.queue_free()
		action.call())
	dialog.canceled.connect(func():
		modal_open = false
		dialog.queue_free())
	dialog.popup_centered()

func _popup(title: String, message: String) -> void:
	modal_open = true
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = title
	dialog.dialog_text = message
	dialog.ok_button_text = "明白了"
	dialog.min_size = Vector2i(620, 190)
	add_child(dialog)
	dialog.confirmed.connect(func():
		modal_open = false
		dialog.queue_free())
	dialog.canceled.connect(func():
		modal_open = false
		dialog.queue_free())
	dialog.popup_centered()

func _show_help() -> void:
	_popup("行军手册", "每人每回合 6 行动点。移动每格 2 点，攻击通常 3 点。\n友军可穿过，不能停在同一格；敌人和障碍仍会挡路。\n金色双环与头顶箭头指示当前行动者。\n点击攻击/技能显示射程，叉号表示遮挡，准星表示合法目标。\n先选择右侧动作，再指向棋盘看预览，单击执行。\n\n盾击命中制造破绽；长枪攻击消耗破绽获得命中优势。\n攻击先损护甲，再损生命；火区直接伤害生命，也伤友军。\n油与火形成火区；水可以灭火，产生遮挡远程的蒸汽。\n主动脱离贴身敌人可能遭反击，推开不触发脱离反击。\n猎人花行动点下令，战犬在自己的回合跟随、牵制或撤回。\n\n消灭敌人获胜，保护粮仓获得额外回报；随时可以撤退。\n空格结束当前队员回合，Esc 切回移动。\n每次行动自动保存；手动存档独立保留，读取不会重抽候选。\n正常 / 加速 / 跳过仅改变表现，不改变结算。")

func _run_smoke() -> void:
	var smoke = load("res://tests/ui_smoke.gd").new()
	await smoke.run(self)
