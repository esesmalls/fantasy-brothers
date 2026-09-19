extends HBoxContainer
## Read-only world view and explicit commands. Campaign rules own every journey.
const MapView = preload("res://presentation/world_map.gd")
const Campaign = preload("res://core/campaign_rules.gd")
var controller: Control
var map: Control
var advance_button: Button
var return_button: Button
var camp_button: Button
var continue_button: Button
var route_buttons: Dictionary = {}
var location_title: Label
var location_body: Label
var world_view: Dictionary = {}

func build(owner_control: Control) -> void:
	controller = owner_control
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	world_view = Campaign.get_world_view(controller.campaign)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	add_child(left)
	var heading: Label = controller._text(left, "灰岸边境  /  旗帜所至，故事随行", 23, controller.GOLD)
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	map = MapView.new()
	map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_child(map)
	map.set_world(world_view)
	map.location_selected.connect(inspect_location)
	var details := PanelContainer.new()
	details.add_theme_stylebox_override("panel", controller._style("1c2a2b", "4b6255", 12))
	left.add_child(details)
	var detail_box := VBoxContainer.new()
	detail_box.add_theme_constant_override("separation", 4)
	details.add_child(detail_box)
	location_title = controller._text(detail_box, "", 18, controller.GOLD)
	location_body = controller._text(detail_box, "", 15, controller.MUTED)
	location_body.custom_minimum_size.y = 46
	inspect_location(str(world_view.location_id))
	var actions: VBoxContainer = controller._panel(self, 370, false)
	actions.add_theme_constant_override("separation", 9)
	controller._text(actions, "佣兵团的位置", 15, controller.MUTED)
	controller._text(actions, _location_name(str(world_view.location_id)), 25, controller.GOLD)
	var c: Dictionary = controller.campaign
	var alive := 0
	for unit: Dictionary in c.roster:
		if int(unit.hp) > 0: alive += 1
	controller._text(actions, "%s · %d 名存活队员" % [str(c.company_name), alive], 16)
	var phase: String = str(c.phase)
	if phase == "camp":
		camp_button = controller._button(actions, "进入营地生活 · 名册与整备", controller._show_camp_view)
		controller._text(actions, "整备行囊，再接下一份工作。归来的见闻与伤亡记录留在营地。", 15, controller.MUTED)
		if bool(c.flags.get("ending_seen", false)):
			controller._text(actions, "渡桥的钟声已收束 · 可在营地重读团志", 14, controller.GOLD)
		for offer: Dictionary in Campaign.get_contract_offers(c, str(world_view.location_id)):
			controller._text(actions, "契约 · " + str(offer.title), 21, controller.GOLD)
			controller._text(actions, str(offer.description), 15, controller.MUTED)
			for route: Dictionary in offer.routes:
				var id: String = str(route.id)
				var button: Button = controller._button(actions, str(route.name) + " · 接约出发", func(): controller._start_expedition(id))
				button.tooltip_text = str(route.description)
				button.disabled = not bool(route.available)
				route_buttons[id] = button
				controller._text(actions, "%d 粮 · %d 天  /  %s  /  %d 金\n油 %d · 火 %d · 水 %d" % [int(route.food_cost), int(route.days), ["小股劫匪", "有备而来", "增援集结"][int(route.difficulty)], int(route.reward), int(route.supplies.oil), int(route.supplies.fire), int(route.supplies.water)], 15, controller.GOLD)
				if not bool(route.available):
					controller._text(actions, str(route.reason), 14, controller.RED)
	elif phase == "travel":
		controller._text(actions, str(c.expedition.get("route_name", "行军途中")), 22, controller.GOLD)
		controller._text(actions, "行程 %d / %d\n下一站 · %s" % [int(world_view.step), int(world_view.total_steps), _location_name(str(world_view.next_location_id))], 18)
		advance_button = controller._button(actions, "继续行军 · " + _location_name(str(world_view.next_location_id)), controller._advance_travel)
		controller._text(actions, str(world_view.report), 16, controller.MUTED)
		controller._text(actions, "去程口粮与天数已在出发时计入。逐站行军不会重复扣费，事件选择仍有各自的代价。", 15, controller.MUTED)
		controller._text(actions, "契约目的地 · 雨夜粮仓\n击退敌人，尽量保住粮食。", 17, controller.GOLD)
	elif phase == "returning":
		controller._text(actions, "收起战旗，准备返营", 22, controller.GOLD)
		return_button = controller._button(actions, "返回灰岸营地", controller._return_to_camp)
		controller._text(actions, str(c.last_report), 17)
		controller._text(actions, "报酬、消耗和伤亡已清点。返营后可休养、修甲、补给和补员；返回不会再次领取奖励。", 15, controller.MUTED)
	else:
		continue_button = controller._button(actions, "处理途中事件" if phase == "event" else "查看契约 · 准备交锋", controller._close_world_overview)
		controller._text(actions, str(world_view.report), 17)
		controller._text(actions, "地图记录队伍所在地点。查看地点不会推进旅程或更改已作出的选择。", 15, controller.MUTED)
	controller._text(actions, "点击地点查看见闻 · 旗帜表示队伍\n金线为本次行程，青绿为已走路段", 13, controller.MUTED)

func _location_name(id: String) -> String:
	for location: Dictionary in world_view.get("locations", []):
		if str(location.id) == id: return str(location.name)
	return "前方"

func inspect_location(id: String) -> void:
	for location: Dictionary in world_view.get("locations", []):
		if str(location.id) != id: continue
		if not bool(location.get("discovered", false)):
			location_title.text = "未探明的地方"
			location_body.text = "远方的地形尚未记录在团志里。"
		else:
			location_title.text = str(location.name) + (" · 佣兵团在此" if id == str(world_view.location_id) else "")
			location_body.text = str(location.description)
			var record: Dictionary = controller.campaign.get("world", {}).get("location_states", {}).get(id, {})
			var flags: Dictionary = record.get("flags", {})
			if flags.has("last_outcome"):
				var outcomes := {"victory": "胜利", "retreat": "撤退", "defeat": "败北"}
				location_body.text += "\n上次契约 · %s · %s" % [str(outcomes.get(str(flags.last_outcome), "已清点")), "保住粮食" if bool(flags.get("grain_saved", false)) else "未取得护仓谢礼"]
		return
