extends RefCounted
## Pure campaign equipment rules. Presentation receives copies from get_view;
## all mutations are camp-only and validate fully before changing state.

const Data = preload("res://core/equipment_data.gd")
const World = preload("res://core/world_data.gd")
const Character = preload("res://core/character_rules.gd")

static func initialize_new_campaign(c: Dictionary) -> void:
	c.equipment = {"schema": Data.SCHEMA, "next_instance_serial": 1, "instances": []}
	for unit: Dictionary in c.get("roster", []):
		_grant_basic_loadout(c, unit, true)

static func migrate_legacy(c: Dictionary) -> bool:
	if c.has("equipment"):
		return false
	c.equipment = {"schema": Data.SCHEMA, "next_instance_serial": 1, "instances": []}
	for unit: Dictionary in c.get("roster", []):
		unit.equipment = {"weapon": "", "armor": ""}
		unit.weapon_style = ""
		unit.visual_loadout = {"weapon": "", "armor": ""}
		if int(unit.get("hp", 0)) <= 0 or str(unit.get("kind", "")) == "dog":
			continue
		var weapon_id := Data.basic_weapon(str(unit.kind))
		var armor_id := Data.basic_armor(str(unit.kind))
		if not weapon_id.is_empty():
			var weapon := _new_instance(c, weapon_id, "issued")
			unit.equipment.weapon = str(weapon.id)
			unit.weapon_style = str(Data.get_definition(weapon_id).weapon_style)
			unit.visual_loadout.weapon = weapon_id
		if not armor_id.is_empty():
			var armor := _new_instance(c, armor_id, "issued", int(unit.get("armor", 0)), int(unit.get("max_armor", 0)))
			unit.equipment.armor = str(armor.id)
			unit.visual_loadout.armor = armor_id
	return true

static func grant_recruit_loadout(c: Dictionary, unit: Dictionary) -> void:
	_grant_basic_loadout(c, unit, true)

static func discard_unit_loadout(c: Dictionary, unit: Dictionary) -> void:
	var loadout: Dictionary = unit.get("equipment", {})
	for slot in ["weapon", "armor"]:
		var instance_id := str(loadout.get(slot, ""))
		if not instance_id.is_empty():
			_remove_instance(c, instance_id)
	unit.equipment = {"weapon": "", "armor": ""}
	unit.weapon_style = ""
	unit.visual_loadout = {"weapon": "", "armor": ""}
	if unit.get("stat_sources") is Dictionary:
		Character.recompute_character(unit, c)

static func get_view(c: Dictionary, unit_id: String = "") -> Dictionary:
	var units: Array = []
	var selected: Dictionary = {}
	for unit: Dictionary in c.get("roster", []):
		var summary := _unit_summary(unit)
		units.append(summary)
		if str(unit.id) == unit_id:
			selected = summary
	if selected.is_empty():
		for summary: Dictionary in units:
			if int(summary.hp) > 0 and str(summary.kind) != "dog":
				selected = summary
				break
	var selected_id := str(selected.get("id", ""))
	var selected_unit := _find_unit(c, selected_id)
	var owner_map := _owner_map(c)
	var slots: Array = []
	if not selected_unit.is_empty():
		for slot in ["weapon", "armor"]:
			var instance_id := str(selected_unit.get("equipment", {}).get(slot, ""))
			var instance := _find_instance(c, instance_id)
			var definition := Data.get_definition(str(instance.get("definition_id", "")))
			slots.append({
				"slot": slot, "name": str(definition.get("name", "无")),
				"instance_id": instance_id, "definition_id": str(definition.get("id", "")),
				"description": _instance_description(instance, definition)
			})
	var inventory: Array = []
	for instance: Dictionary in c.get("equipment", {}).get("instances", []):
		var definition := Data.get_definition(str(instance.get("definition_id", "")))
		var owner_id := str(owner_map.get(str(instance.id), ""))
		var owner := _find_unit(c, owner_id)
		var equip_reason := _equip_reason(c, selected_unit, instance)
		inventory.append({
			"id": str(instance.id), "definition_id": str(instance.definition_id),
			"slot": str(definition.get("slot", "")), "name": str(definition.get("name", "")),
			"description": _instance_description(instance, definition),
			"equipped": not owner_id.is_empty(), "owner_id": owner_id,
			"owner_name": str(owner.get("name", "")), "equippable": equip_reason.is_empty(),
			"reason": "可以换装。" if equip_reason.is_empty() else equip_reason,
			"sell_price": 0 if str(instance.get("acquisition", "")) == "issued" else int(definition.get("sell_price", 0)),
			"sellable": str(instance.get("acquisition", "")) != "issued",
			"kinds": definition.get("allowed_kinds", []).duplicate(),
			"comparison": _comparison(c, selected_unit, definition)
		})
	var shop: Array = []
	var camp_reason := _camp_reason(c)
	for definition_id: String in Data.SHOP_ORDER:
		var definition := Data.get_definition(definition_id)
		var reason := camp_reason
		if reason.is_empty() and int(c.get("gold", 0)) < int(definition.price):
			reason = "需要%d金。" % int(definition.price)
		shop.append({
			"id": definition_id, "definition_id": definition_id,
			"slot": str(definition.slot), "name": str(definition.name),
			"description": str(definition.description), "price": int(definition.price),
			"available": reason.is_empty(), "reason": "可以买入仓库。" if reason.is_empty() else reason,
			"kinds": definition.allowed_kinds.duplicate(),
			"comparison": _comparison(c, selected_unit, definition)
		})
	return {"ok": true, "reason": "", "units": units, "selected_unit": selected,
		"slots": slots, "inventory": inventory, "shop": shop, "repair": get_repair_preview(c)}

static func buy(c: Dictionary, definition_id: String) -> Dictionary:
	var reason := _camp_reason(c)
	var definition := Data.get_definition(definition_id)
	if not reason.is_empty():
		return _fail(reason)
	if definition.is_empty() or not definition_id in Data.SHOP_ORDER:
		return _fail("商店没有这件装备。")
	var price := int(definition.price)
	if int(c.get("gold", 0)) < price:
		return _fail("资金不足，需要%d金。" % price)
	# All checks precede the resource and inventory mutation.
	c.gold = int(c.gold) - price
	var instance := _new_instance(c, definition_id, "purchased")
	c.last_report = "花费%d金购入「%s」，实例编号%s。" % [price, str(definition.name), str(instance.id)]
	return {"ok": true, "reason": str(c.last_report), "instance_id": str(instance.id)}

static func sell(c: Dictionary, instance_id: String) -> Dictionary:
	var reason := _camp_reason(c)
	var instance := _find_instance(c, instance_id)
	if not reason.is_empty():
		return _fail(reason)
	if instance.is_empty():
		return _fail("仓库中没有这件装备。")
	if not str(_owner_map(c).get(instance_id, "")).is_empty():
		return _fail("已装备物品不能出售；先换上另一件同槽装备。")
	if str(instance.get("acquisition", "")) == "issued":
		return _fail("营团配发的基础装备不收购，避免补员与转卖套利。")
	var definition := Data.get_definition(str(instance.definition_id))
	var value := int(definition.get("sell_price", 0))
	# Removal and payment occur only after ownership and origin validation.
	_remove_instance(c, instance_id)
	c.gold = int(c.gold) + value
	c.last_report = "出售「%s」，收入%d金。" % [str(definition.name), value]
	return {"ok": true, "reason": str(c.last_report)}

static func equip(c: Dictionary, unit_id: String, instance_id: String) -> Dictionary:
	var reason := _camp_reason(c)
	var unit := _find_unit(c, unit_id)
	var instance := _find_instance(c, instance_id)
	if not reason.is_empty():
		return _fail(reason)
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return _fail("只能为存活队员换装。")
	if instance.is_empty():
		return _fail("仓库中没有这件装备。")
	reason = _equip_reason(c, unit, instance)
	if not reason.is_empty():
		return _fail(reason)
	var definition := Data.get_definition(str(instance.definition_id))
	var slot := str(definition.slot)
	var old_id := str(unit.get("equipment", {}).get(slot, ""))
	var old_instance := _find_instance(c, old_id)
	# Validation is complete. Preserve old armor wear on its instance before the
	# stable IDs are swapped; equipping the new instance restores only its own wear.
	if slot == "weapon":
		unit.visual_loadout.weapon = str(definition.id)
	else:
		if not old_instance.is_empty():
			old_instance.durability = clampi(int(unit.armor), 0, int(old_instance.max_durability))
		unit.max_armor = int(instance.max_durability)
		unit.armor = clampi(int(instance.durability), 0, int(instance.max_durability))
		unit.visual_loadout.armor = str(definition.id)
	unit.equipment[slot] = instance_id
	Character.recompute_character(unit, c)
	c.last_report = "%s换上「%s」；旧装备已返回仓库。" % [str(unit.name), str(definition.name)]
	return {"ok": true, "reason": str(c.last_report)}

static func battle_result_problem(c: Dictionary, battle: Dictionary) -> String:
	var results: Dictionary = {}
	for raw: Dictionary in battle.get("units", []):
		if str(raw.get("team", "")) == "player":
			results[str(raw.get("id", ""))] = raw
	for unit: Dictionary in c.get("roster", []):
		if int(unit.get("hp", 0)) <= 0 or not results.has(str(unit.id)):
			continue
		var armor := _find_instance(c, str(unit.get("equipment", {}).get("armor", "")))
		if str(unit.kind) != "dog" and armor.is_empty():
			return "出征队员的护甲实例缺失，未进行结算。"
	return ""

static func apply_battle_result(c: Dictionary, battle: Dictionary) -> Dictionary:
	var problem := battle_result_problem(c, battle)
	if not problem.is_empty():
		return _fail(problem)
	var results: Dictionary = {}
	for raw: Dictionary in battle.get("units", []):
		if str(raw.get("team", "")) == "player":
			results[str(raw.id)] = raw
	var lost: Array[String] = []
	for unit: Dictionary in c.get("roster", []):
		if int(unit.get("hp", 0)) <= 0 or not results.has(str(unit.id)):
			continue
		var result: Dictionary = results[str(unit.id)]
		if int(result.get("hp", 0)) <= 0:
			for slot in ["weapon", "armor"]:
				var item := _find_instance(c, str(unit.get("equipment", {}).get(slot, "")))
				if not item.is_empty():
					lost.append(str(Data.get_definition(str(item.definition_id)).get("name", item.definition_id)))
			discard_unit_loadout(c, unit)
		elif str(unit.kind) != "dog":
			var armor := _find_instance(c, str(unit.equipment.armor))
			armor.durability = clampi(int(result.get("armor", 0)), 0, int(armor.max_durability))
	return {"ok": true, "reason": "", "lost": lost}

static func repair_all(c: Dictionary) -> Dictionary:
	var damaged := _repair_targets(c)
	var missing_total := 0
	for target: Dictionary in damaged:
		missing_total += int(target.missing)
	if damaged.is_empty():
		return _fail("营团护甲与战犬天然护甲都已完整。")
	var price := maxi(1, int(ceil(float(missing_total) / 4.0)))
	if int(c.get("gold", 0)) >= price:
		c.gold = int(c.gold) - price
		for target: Dictionary in damaged:
			_repair_target(target, int(target.missing))
		_sync_roster_armor(c)
		return {"ok": true, "reason": "花费%d金，修复%d项防护的%d点损耗。" % [price, damaged.size(), missing_total]}
	c.day = int(c.day) + 1
	var free_budget := 6
	# The no-money recovery remains a soft-lock escape, but one day repairs at
	# most six points company-wide. Targets are equipped armor, dogs, then stock.
	for target: Dictionary in damaged:
		if free_budget <= 0:
			break
		var restored := mini(free_budget, int(target.missing))
		_repair_target(target, restored)
		free_budget -= restored
	_sync_roster_armor(c)
	return {"ok": true, "reason": "资金不足：用一天拾取与拼补，装备库合计恢复最多6点护甲。"}

static func get_repair_preview(c: Dictionary) -> Dictionary:
	var targets := _repair_targets(c)
	var missing := 0
	for target: Dictionary in targets:
		missing += int(target.missing)
	var price := 0 if missing == 0 else maxi(1, int(ceil(float(missing) / 4.0)))
	var affordable := missing > 0 and int(c.get("gold", 0)) >= price
	var description := "没有需要修复的防护。"
	if missing > 0:
		description = "%d项防护共损失%d点；支付%d金全部修复。资金不足时耗时1天，按已装备护甲、战犬、库存护甲顺序合计恢复最多6点。" % [targets.size(), missing, price]
	return {"damaged": targets.size(), "missing": missing, "price": price,
		"available": missing > 0, "affordable": affordable, "description": description}

static func sync_roster_armor_to_instances(c: Dictionary) -> void:
	for unit: Dictionary in c.get("roster", []):
		if str(unit.get("kind", "")) == "dog":
			continue
		var armor := _find_instance(c, str(unit.get("equipment", {}).get("armor", "")))
		if not armor.is_empty():
			armor.durability = clampi(int(unit.get("armor", 0)), 0, int(armor.max_durability))

static func validate_campaign(c: Dictionary) -> String:
	var state = c.get("equipment")
	if not state is Dictionary:
		return "装备状态缺失。"
	if int(state.get("schema", -1)) != Data.SCHEMA or not state.get("instances") is Array:
		return "装备版本或实例列表损坏。"
	if not state.get("next_instance_serial") is int or int(state.next_instance_serial) < 1:
		return "装备实例序号损坏。"
	var instances: Dictionary = {}
	var largest_serial := 0
	for raw in state.instances:
		if not raw is Dictionary:
			return "装备实例损坏。"
		var instance: Dictionary = raw
		for key in ["id", "definition_id", "acquisition", "durability", "max_durability"]:
			if not instance.has(key):
				return "装备实例字段缺失。"
		var instance_id := str(instance.id)
		var definition := Data.get_definition(str(instance.definition_id))
		if instance_id.is_empty() or instances.has(instance_id) or definition.is_empty():
			return "装备实例编号重复或定义未知。"
		if not instance_id.begins_with("equip_") or not str(instance_id.trim_prefix("equip_")).is_valid_int():
			return "装备实例编号格式损坏。"
		largest_serial = maxi(largest_serial, int(instance_id.trim_prefix("equip_")))
		if not str(instance.acquisition) in ["issued", "purchased"]:
			return "装备来源损坏。"
		var expected_max := int(definition.get("armor", 0))
		if int(instance.max_durability) != expected_max or int(instance.durability) < 0 or int(instance.durability) > expected_max:
			return "装备耐久损坏。"
		instances[instance_id] = instance
	if int(state.next_instance_serial) <= largest_serial:
		return "装备实例序号会与现有物品重复。"
	var used: Dictionary = {}
	for unit: Dictionary in c.get("roster", []):
		var loadout = unit.get("equipment")
		var visual = unit.get("visual_loadout")
		if not loadout is Dictionary or not loadout.has_all(["weapon", "armor"]):
			return "队员装备槽缺失。"
		if not visual is Dictionary or not visual.has_all(["weapon", "armor"]) or not unit.get("weapon_style") is String:
			return "队员装备表现快照缺失。"
		if str(unit.kind) == "dog" or int(unit.hp) <= 0:
			if not str(loadout.weapon).is_empty() or not str(loadout.armor).is_empty():
				return "战犬或死亡队员不能持有人工装备。"
			if not str(unit.weapon_style).is_empty() or not str(visual.weapon).is_empty() or not str(visual.armor).is_empty():
				return "无人工装备单位残留装备表现快照。"
			continue
		for slot in ["weapon", "armor"]:
			var instance_id := str(loadout.get(slot, ""))
			if instance_id.is_empty() or not instances.has(instance_id) or used.has(instance_id):
				return "队员装备缺失或同一实例被重复装备。"
			var definition := Data.get_definition(str(instances[instance_id].definition_id))
			if str(definition.slot) != slot or not str(unit.kind) in definition.allowed_kinds:
				return "队员装备与槽位或岗位不匹配。"
			used[instance_id] = true
		var weapon_definition := Data.get_definition(str(instances[str(loadout.weapon)].definition_id))
		var armor_definition := Data.get_definition(str(instances[str(loadout.armor)].definition_id))
		if str(unit.weapon_style) != str(weapon_definition.weapon_style) or int(unit.range) != int(weapon_definition.range):
			return "队员武器流派或射程与实例不一致。"
		if str(visual.weapon) != str(weapon_definition.id) or str(visual.armor) != str(armor_definition.id):
			return "队员装备表现快照与实例不一致。"
		if int(unit.max_armor) != int(instances[str(loadout.armor)].max_durability) or int(unit.armor) != int(instances[str(loadout.armor)].durability):
			return "队员护甲值与装备实例不一致。"
	return ""

static func _grant_basic_loadout(c: Dictionary, unit: Dictionary, issued: bool) -> void:
	unit.equipment = {"weapon": "", "armor": ""}
	unit.weapon_style = ""
	unit.visual_loadout = {"weapon": "", "armor": ""}
	if str(unit.get("kind", "")) == "dog":
		return
	var acquisition := "issued" if issued else "purchased"
	var weapon := _new_instance(c, Data.basic_weapon(str(unit.kind)), acquisition)
	var armor := _new_instance(c, Data.basic_armor(str(unit.kind)), acquisition, int(unit.get("armor", 0)), int(unit.get("max_armor", 0)))
	unit.equipment.weapon = str(weapon.id)
	unit.equipment.armor = str(armor.id)
	var weapon_definition := Data.get_definition(str(weapon.definition_id))
	unit.weapon_style = str(weapon_definition.weapon_style)
	unit.range = int(weapon_definition.range)
	unit.visual_loadout.weapon = str(weapon.definition_id)
	unit.visual_loadout.armor = str(armor.definition_id)

static func _new_instance(c: Dictionary, definition_id: String, acquisition: String, durability_override: int = -1, max_override: int = -1) -> Dictionary:
	var definition := Data.get_definition(definition_id)
	var serial := int(c.equipment.next_instance_serial)
	c.equipment.next_instance_serial = serial + 1
	var maximum := int(definition.get("armor", 0))
	if max_override >= 0 and str(definition.get("slot", "")) == "armor":
		maximum = max_override
	var durability := maximum if durability_override < 0 else clampi(durability_override, 0, maximum)
	var instance := {"id": "equip_%d" % serial, "definition_id": definition_id,
		"acquisition": acquisition, "durability": durability, "max_durability": maximum}
	c.equipment.instances.append(instance)
	return instance

static func _find_instance(c: Dictionary, instance_id: String) -> Dictionary:
	for instance: Dictionary in c.get("equipment", {}).get("instances", []):
		if str(instance.get("id", "")) == instance_id:
			return instance
	return {}

static func _remove_instance(c: Dictionary, instance_id: String) -> void:
	var instances: Array = c.get("equipment", {}).get("instances", [])
	for index in range(instances.size()):
		if str(instances[index].get("id", "")) == instance_id:
			instances.remove_at(index)
			return

static func _find_unit(c: Dictionary, unit_id: String) -> Dictionary:
	for unit: Dictionary in c.get("roster", []):
		if str(unit.get("id", "")) == unit_id:
			return unit
	return {}

static func _owner_map(c: Dictionary) -> Dictionary:
	var owners := {}
	for unit: Dictionary in c.get("roster", []):
		for slot in ["weapon", "armor"]:
			var instance_id := str(unit.get("equipment", {}).get(slot, ""))
			if not instance_id.is_empty():
				owners[instance_id] = str(unit.id)
	return owners

static func _equip_reason(c: Dictionary, unit: Dictionary, instance: Dictionary) -> String:
	var camp := _camp_reason(c)
	if not camp.is_empty():
		return camp
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return "请选择存活的人类队员。"
	if str(unit.get("kind", "")) == "dog":
		return "战犬依靠天然护甲，不使用人工装备。"
	var definition := Data.get_definition(str(instance.get("definition_id", "")))
	if definition.is_empty() or not str(unit.kind) in definition.allowed_kinds:
		return "这件装备不适合该岗位。"
	var owner_id := str(_owner_map(c).get(str(instance.get("id", "")), ""))
	if not owner_id.is_empty():
		return "该实例已由%s装备。" % str(_find_unit(c, owner_id).get("name", "另一名队员"))
	return ""

static func _camp_reason(c: Dictionary) -> String:
	if str(c.get("phase", "")) != "camp":
		return "只能在营地阶段交易和换装。"
	if str(c.get("world", {}).get("company_location_id", "")) != World.CAMP_ID:
		return "佣兵团必须位于灰岸营地。"
	return ""

static func _unit_summary(unit: Dictionary) -> Dictionary:
	return {"id": str(unit.get("id", "")), "name": str(unit.get("name", "")),
		"kind": str(unit.get("kind", "")), "hp": int(unit.get("hp", 0)),
		"max_hp": int(unit.get("max_hp", 0)), "attack": int(unit.get("attack", 0)),
		"accuracy": int(unit.get("accuracy", 0)), "armor": int(unit.get("armor", 0)),
		"max_armor": int(unit.get("max_armor", 0)), "range": int(unit.get("range", 0)),
		"weapon_style": str(unit.get("weapon_style", "")),
		"visual_loadout": unit.get("visual_loadout", {}).duplicate(true)}

static func _comparison(c: Dictionary, unit: Dictionary, definition: Dictionary) -> Dictionary:
	var result := {"attack": 0, "accuracy": 0, "armor": 0}
	if unit.is_empty() or str(unit.get("kind", "")) == "dog":
		return result
	var slot := str(definition.get("slot", ""))
	var old_instance := _find_instance(c, str(unit.get("equipment", {}).get(slot, "")))
	var old_definition := Data.get_definition(str(old_instance.get("definition_id", "")))
	if slot == "weapon":
		result.attack = int(definition.get("attack", 0)) - int(old_definition.get("attack", 0))
		result.accuracy = int(definition.get("accuracy", 0)) - int(old_definition.get("accuracy", 0))
	elif slot == "armor":
		result.armor = int(definition.get("armor", 0)) - int(unit.get("max_armor", 0))
	return result

static func _instance_description(instance: Dictionary, definition: Dictionary) -> String:
	var description := str(definition.get("description", ""))
	if str(definition.get("slot", "")) == "armor":
		description += " 当前耐久%d/%d。" % [int(instance.get("durability", 0)), int(instance.get("max_durability", 0))]
	return description

static func _sync_roster_armor(c: Dictionary) -> void:
	for unit: Dictionary in c.get("roster", []):
		if str(unit.get("kind", "")) == "dog" or int(unit.get("hp", 0)) <= 0:
			continue
		var armor := _find_instance(c, str(unit.get("equipment", {}).get("armor", "")))
		if not armor.is_empty():
			unit.max_armor = int(armor.max_durability)
			unit.armor = int(armor.durability)

static func _repair_targets(c: Dictionary) -> Array:
	var targets: Array = []
	var equipped: Dictionary = {}
	# Roster order gives deterministic free-repair priority.
	for unit: Dictionary in c.get("roster", []):
		if int(unit.get("hp", 0)) <= 0:
			continue
		if str(unit.get("kind", "")) == "dog":
			var dog_missing := int(unit.get("max_armor", 0)) - int(unit.get("armor", 0))
			if dog_missing > 0:
				targets.append({"type": "dog", "value": unit, "missing": dog_missing})
			continue
		var instance_id := str(unit.get("equipment", {}).get("armor", ""))
		var instance := _find_instance(c, instance_id)
		if instance.is_empty():
			continue
		equipped[instance_id] = true
		var item_missing := int(instance.max_durability) - int(instance.durability)
		if item_missing > 0:
			targets.push_front({"type": "item", "value": instance, "missing": item_missing})
	# Stored armor follows every equipped item and dog.
	for instance: Dictionary in c.get("equipment", {}).get("instances", []):
		if equipped.has(str(instance.id)):
			continue
		var definition := Data.get_definition(str(instance.definition_id))
		if str(definition.get("slot", "")) != "armor":
			continue
		var missing := int(instance.max_durability) - int(instance.durability)
		if missing > 0:
			targets.append({"type": "item", "value": instance, "missing": missing})
	return targets

static func _repair_target(target: Dictionary, amount: int) -> void:
	var value: Dictionary = target.value
	if str(target.type) == "dog":
		value.armor = mini(int(value.max_armor), int(value.armor) + amount)
	else:
		value.durability = mini(int(value.max_durability), int(value.durability) + amount)

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
