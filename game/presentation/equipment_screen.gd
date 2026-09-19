extends HBoxContainer
## Camp equipment is a read-only projection; commands go through the controller.
const Equipment = preload("res://core/equipment_rules.gd")
const Glyph = preload("res://presentation/tactical_glyph.gd")
const CharacterPortrait = preload("res://presentation/character_portrait.gd")
var controller: Control
var view: Dictionary = {}
var unit_buttons: Dictionary = {}
var buy_buttons: Dictionary = {}
var sell_buttons: Dictionary = {}
var equip_buttons: Dictionary = {}
var back_button: Button
var character_button: Button
var portrait: Control

func build(owner_control: Control, unit_id: String) -> void:
	controller = owner_control
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 14)
	view = Equipment.get_view(controller.campaign, unit_id)
	var roster: VBoxContainer = controller._panel(self, 245, false)
	_heading(roster, "军需帐", "guard")
	controller._text(roster, "选一名队员，清点他的行装。武器改变招式与射程，人物经历与专长保留。", 15, controller.MUTED)
	for unit: Dictionary in view.get("units", []):
		var id: String = str(unit.id)
		var button: Button = controller._button(roster, str(unit.name) + " · " + str(controller.KINDS.get(unit.kind, unit.kind)), func(): controller._show_equipment(id))
		unit_buttons[id] = button
		if id == str(view.get("selected_unit", {}).get("id", "")):
			button.add_theme_color_override("font_color", controller.GOLD)
		controller._text(roster, "已阵亡" if int(unit.hp) <= 0 else "生命 %d / %d" % [int(unit.hp), int(unit.max_hp)], 14, controller.MUTED)
	back_button = controller._button(roster, "返回营地生活", controller._show_camp_view)
	controller._text(roster, "随身装备不可直接出售。替换后，旧物回到公用行囊。", 15, controller.MUTED)
	var gear: VBoxContainer = controller._panel(self)
	var selected: Dictionary = view.get("selected_unit", {})
	controller.equipment_unit_id = str(selected.get("id", ""))
	_heading(gear, str(selected.get("name", "队员")) + " · 随身行装", str(selected.get("kind", "guard")))
	portrait = CharacterPortrait.new()
	portrait.custom_minimum_size = Vector2(220, 200)
	gear.add_child(portrait)
	for unit: Dictionary in controller.campaign.roster:
		if str(unit.id) == str(selected.get("id", "")):
			portrait.set_unit(unit)
			break
	if not selected.is_empty():
		controller._text(gear, "攻击 %d  ·  命中 %d%%\n护甲 %d / %d  ·  射程 %d 格" % [int(selected.attack), int(selected.accuracy), int(selected.armor), int(selected.max_armor), int(selected.range)], 19, controller.GOLD)
		character_button = controller._button(gear, "人物帐 · 查看属性与培养", func(): controller._show_characters(str(selected.get("id", ""))))
	for slot: Dictionary in view.get("slots", []):
		controller._text(gear, str(slot.get("name", "")), 20)
		controller._text(gear, str(slot.get("description", "")), 15, controller.MUTED)
	controller._text(gear, "公用行囊", 24, controller.GOLD)
	var stored: Array = view.get("inventory", []).filter(func(item: Dictionary) -> bool: return not bool(item.get("equipped", false)))
	if stored.is_empty():
		controller._text(gear, "行囊中暂无备用装备。右侧商贩可添置行装。", 16, controller.MUTED)
	for item: Dictionary in stored:
		gear.add_child(HSeparator.new())
		controller._text(gear, str(item.name), 19)
		controller._text(gear, str(item.get("description", "")), 15, controller.MUTED)
		var comparison: Dictionary = item.get("comparison", {})
		if bool(item.get("equippable", false)) and not comparison.is_empty():
			controller._text(gear, "换装变化 · 攻击 %+d  命中 %+d%%  护甲上限 %+d" % [int(comparison.get("attack", 0)), int(comparison.get("accuracy", 0)), int(comparison.get("armor", 0))], 15, controller.GOLD)
		var row := HBoxContainer.new()
		gear.add_child(row)
		var id: String = str(item.id)
		var equip: Button = controller._button(row, "换装", func(): controller._equipment_action("equip", id))
		equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		equip.disabled = not bool(item.get("equippable", false))
		equip.tooltip_text = str(item.get("reason", ""))
		equip_buttons[id] = equip
		var sell: Button = controller._button(row, "出售 · %d 金" % int(item.get("sell_price", 0)), func(): controller._equipment_action("sell", id))
		sell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sell.disabled = bool(item.get("equipped", false)) or not bool(item.get("sellable", true)) or int(item.get("sell_price", 0)) <= 0
		if int(item.get("sell_price", 0)) <= 0:
			sell.text = "不予回购"
			sell.tooltip_text = "商贩不回购此装备；可继续留作换装备用。"
		sell_buttons[id] = sell
		if not bool(item.get("equippable", false)):
			controller._text(gear, str(item.get("reason", "")), 14, controller.MUTED)
	var shop: VBoxContainer = controller._panel(self, 355, false)
	_heading(shop, "营地商贩", "skirmisher")
	controller._text(shop, "金币 %d · 为下一程留些口粮钱。" % int(controller.campaign.gold), 17, controller.GOLD)
	if not controller.equipment_notice.is_empty():
		controller._text(shop, controller.equipment_notice, 16, controller.GOLD)
	controller._text(shop, "购买后放入公用行囊，需要另行换装。护甲损耗随物品保留。", 15, controller.MUTED)
	for item: Dictionary in view.get("shop", []):
		shop.add_child(HSeparator.new())
		controller._text(shop, str(item.name), 19)
		controller._text(shop, str(item.get("description", "")), 15, controller.MUTED)
		var comparison: Dictionary = item.get("comparison", {})
		if not comparison.is_empty() and not selected.is_empty() and str(selected.get("kind", "")) != "dog":
			controller._text(shop, "与随身相比 · 攻击 %+d  命中 %+d%%  护甲上限 %+d" % [int(comparison.get("attack", 0)), int(comparison.get("accuracy", 0)), int(comparison.get("armor", 0))], 14, controller.GOLD)
		var id: String = str(item.id)
		var buy: Button = controller._button(shop, "购入 · %d 金" % int(item.price), func(): controller._equipment_action("buy", id))
		buy.disabled = not bool(item.get("available", false))
		buy.tooltip_text = str(item.get("reason", ""))
		buy_buttons[id] = buy

func _heading(parent: VBoxContainer, title: String, glyph: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var icon := Glyph.new()
	icon.custom_minimum_size = Vector2(28, 28)
	icon.set_glyph(glyph)
	row.add_child(icon)
	var label: Label = controller._text(row, title, 23, controller.GOLD)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
