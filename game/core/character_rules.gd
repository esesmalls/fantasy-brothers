extends RefCounted
## Character progression and effective-stat ledger. Rules write campaign state;
## presentation only consumes copies returned by get_view().

const Data = preload("res://core/character_data.gd")
const EquipmentData = preload("res://core/equipment_data.gd")

const RANGED_STYLES := ["archer", "hunter"]
const BASIC_TRAINING := {
	"basic_vitality": {"name": "体魄基础操练", "stat_id": "vitality"},
	"basic_melee": {"name": "近战基础操练", "stat_id": "melee_skill"},
	"basic_ranged": {"name": "远程基础操练", "stat_id": "ranged_skill"},
	"basic_defense": {"name": "防御基础操练", "stat_id": "defense"}
}

static func ensure_campaign(c: Dictionary) -> Dictionary:
	var changed := false
	if not c.get("character_state") is Dictionary or int(c.character_state.get("schema", -1)) != Data.SCHEMA:
		var settled_claims: Array[String] = []
		for expedition_id in c.get("claimed", {}):
			settled_claims.append("battle:%s" % str(expedition_id))
		c.character_state = {"schema": Data.SCHEMA, "rules_version": Data.RULES_VERSION, "claimed_battles": settled_claims}
		changed = true
	elif str(c.character_state.get("rules_version", "")) != Data.RULES_VERSION:
		c.character_state.rules_version = Data.RULES_VERSION
		changed = true
	if not c.character_state.get("claimed_battles") is Array:
		c.character_state.claimed_battles = []
		changed = true
	for unit: Dictionary in c.get("roster", []):
		var result := ensure_character(unit, c)
		changed = changed or bool(result.get("changed", false))
	_bind_unowned_dogs(c)
	return {"ok": true, "changed": changed}

static func ensure_character(unit: Dictionary, equipment_context: Dictionary = {}) -> Dictionary:
	if _has_ledger(unit):
		var previous := JSON.stringify(unit)
		recompute_character(unit, equipment_context)
		return {"ok": true, "changed": JSON.stringify(unit) != previous}
	var background_id := str(unit.get("background_id", Data.background_for_kind(str(unit.get("kind", "guard")))))
	var background := Data.background(background_id)
	if background.is_empty():
		background_id = Data.background_for_kind(str(unit.get("kind", "guard")))
		background = Data.background(background_id)
	var base: Dictionary = background.stats.duplicate(true)
	var weapon := _weapon_definition(unit, equipment_context)
	var weapon_accuracy := int(weapon.get("accuracy", 0))
	var perk := _perk_sources(unit)
	var natural_accuracy := int(unit.get("accuracy", base.melee_skill)) - weapon_accuracy
	var observed_defense := int(unit.get("defense", base.defense))
	var compatibility := _zero_stats()
	compatibility.vitality = int(unit.get("max_hp", base.vitality)) - int(base.vitality) - int(perk.vitality)
	compatibility.melee_skill = natural_accuracy - int(base.melee_skill) - int(perk.melee_skill)
	compatibility.ranged_skill = natural_accuracy - int(base.ranged_skill) - int(perk.ranged_skill)
	compatibility.defense = observed_defense - int(base.defense) - int(perk.defense)
	unit.background_id = background_id
	unit.background_name = str(background.name)
	unit.background_description = str(background.description)
	unit.capability_tags = background.capabilities.duplicate()
	unit.character_history = []
	unit.progression = {
		"schema": Data.SCHEMA, "level": 1, "xp": 0, "attribute_points": 0,
		"training_credits": 0 if str(unit.get("kind", "")) == "dog" else 1,
		"xp_claims": [], "training_claims": [], "stat_changes": []
	}
	unit.stat_sources = {
		"schema": Data.SCHEMA, "base": base, "growth": _zero_stats(),
		"compatibility": compatibility, "perk": perk, "equipment": _zero_stats(), "effective": _zero_stats()
	}
	unit.combat_sources = {
		"base_attack": int(unit.get("attack", Data.BASE_ATTACK.get(str(unit.get("kind", "")), 12))) - int(weapon.get("attack", 0)),
		"equipment_attack": 0, "effective_attack": int(unit.get("attack", 0))
	}
	if str(unit.get("kind", "")) == "hunter" and not "beast_handler" in unit.capability_tags:
		unit.capability_tags.append("beast_handler")
	recompute_character(unit, equipment_context)
	return {"ok": true, "changed": true}

static func recompute_campaign(c: Dictionary) -> void:
	for unit: Dictionary in c.get("roster", []):
		recompute_character(unit, c)
	_bind_unowned_dogs(c)

static func recompute_character(unit: Dictionary, equipment_context: Dictionary = {}) -> Dictionary:
	if not _has_ledger(unit):
		return ensure_character(unit, equipment_context)
	var old_max := int(unit.get("max_hp", 1))
	var old_hp := int(unit.get("hp", old_max))
	var missing_hp := maxi(0, old_max - old_hp)
	var was_dead := old_hp <= 0
	var sources: Dictionary = unit.stat_sources
	sources.perk = _perk_sources(unit)
	sources.equipment = _zero_stats()
	var weapon := _weapon_definition(unit, equipment_context)
	var style := str(weapon.get("weapon_style", unit.get("weapon_style", unit.get("kind", "guard"))))
	var accuracy_stat := "ranged_skill" if style in RANGED_STYLES else "melee_skill"
	sources.equipment[accuracy_stat] = int(weapon.get("accuracy", 0))
	var effective := _zero_stats()
	for stat_id: String in Data.STAT_ORDER:
		effective[stat_id] = int(sources.base.get(stat_id, 0)) + int(sources.growth.get(stat_id, 0)) + int(sources.compatibility.get(stat_id, 0)) + int(sources.perk.get(stat_id, 0)) + int(sources.equipment.get(stat_id, 0))
	sources.effective = effective
	unit.max_hp = maxi(1, int(effective.vitality))
	unit.hp = 0 if was_dead else clampi(int(unit.max_hp) - missing_hp, 1, int(unit.max_hp))
	unit.defense = int(effective.defense)
	unit.vitality = int(effective.vitality)
	unit.melee_skill = int(effective.melee_skill)
	unit.ranged_skill = int(effective.ranged_skill)
	unit.level = int(unit.progression.get("level", 1))
	unit.accuracy = int(effective[accuracy_stat])
	var combat: Dictionary = unit.combat_sources
	combat.equipment_attack = int(weapon.get("attack", 0))
	combat.effective_attack = int(combat.get("base_attack", unit.get("attack", 0))) + int(combat.equipment_attack)
	unit.attack = int(combat.effective_attack)
	if not weapon.is_empty():
		unit.range = int(weapon.get("range", unit.get("range", 1)))
		unit.weapon_style = style
	return {"ok": true, "effective": effective.duplicate(true)}

static func get_view(c: Dictionary, unit_id: String = "") -> Dictionary:
	var units: Array = []
	var selected: Dictionary = {}
	for unit: Dictionary in c.get("roster", []):
		var summary := {
			"id": str(unit.get("id", "")), "name": str(unit.get("name", "")), "kind": str(unit.get("kind", "")),
			"hp": int(unit.get("hp", 0)), "max_hp": int(unit.get("max_hp", 0)),
			"level": int(unit.get("progression", {}).get("level", 1)), "background_name": str(unit.get("background_name", "未知出身"))
		}
		units.append(summary)
		if str(unit.get("id", "")) == unit_id:
			selected = unit
	if selected.is_empty():
		for unit: Dictionary in c.get("roster", []):
			if int(unit.get("hp", 0)) > 0 and str(unit.get("kind", "")) != "dog":
				selected = unit
				break
	if selected.is_empty() and not c.get("roster", []).is_empty():
		selected = c.roster[0]
	var progression: Dictionary = selected.get("progression", {})
	var stats: Array = []
	for stat_id: String in Data.STAT_ORDER:
		var definition := Data.stat(stat_id)
		var upgrade_reason := _upgrade_reason(selected, stat_id, c)
		var base_value := int(selected.get("stat_sources", {}).get("base", {}).get(stat_id, 0))
		var growth_value := int(selected.get("stat_sources", {}).get("growth", {}).get(stat_id, 0))
		var equipment_value := int(selected.get("stat_sources", {}).get("equipment", {}).get(stat_id, 0))
		var compat_value := int(selected.get("stat_sources", {}).get("compatibility", {}).get(stat_id, 0))
		var perk_value := int(selected.get("stat_sources", {}).get("perk", {}).get(stat_id, 0))
		stats.append({
			"id": stat_id, "name": str(definition.name),
			"value": int(selected.get("stat_sources", {}).get("effective", {}).get(stat_id, 0)),
			"base": base_value, "growth": growth_value, "equipment": equipment_value,
			"compat": compat_value, "perk": perk_value,
			"breakdown": "基础%d + 培养%d + 装备%d + 既有能力%d + 专长%d" % [base_value, growth_value, equipment_value, compat_value, perk_value],
			"description": str(definition.description), "upgrade_amount": int(definition.upgrade_amount),
			"can_upgrade": upgrade_reason.is_empty(), "upgrade_reason": "可以投入1点属性点。" if upgrade_reason.is_empty() else upgrade_reason
		})
	var capability_names: Array[String] = []
	for capability in selected.get("capability_tags", []):
		capability_names.append(str(Data.CAPABILITY_NAMES.get(str(capability), capability)))
	return {
		"units": units, "selected_unit": selected.duplicate(true),
		"background_name": str(selected.get("background_name", "未知出身")),
		"background_description": str(selected.get("background_description", "")),
		"level": int(progression.get("level", 1)), "xp": int(progression.get("xp", 0)),
		"xp_next": Data.xp_next(int(progression.get("level", 1))),
		"attribute_points": int(progression.get("attribute_points", 0)),
		"training_credits": int(progression.get("training_credits", 0)),
		"stats": stats, "training_options": _training_options(c, selected),
		"capabilities": capability_names, "history": selected.get("character_history", []).duplicate()
	}

static func spend_attribute(c: Dictionary, unit_id: String, stat_id: String) -> Dictionary:
	var unit := _find_unit(c, unit_id)
	if unit.is_empty():
		return _fail("找不到这名队员。")
	var reason := _upgrade_reason(unit, stat_id, c)
	if not reason.is_empty():
		return _fail(reason)
	var amount := int(Data.stat(stat_id).upgrade_amount)
	unit.progression.attribute_points = int(unit.progression.attribute_points) - 1
	unit.stat_sources.growth[stat_id] = int(unit.stat_sources.growth.get(stat_id, 0)) + amount
	var change_id := "level:%s:%d" % [stat_id, unit.progression.stat_changes.size() + 1]
	unit.progression.stat_changes.append(_change(change_id, stat_id, amount, "level", "level_%d" % int(unit.progression.level), int(c.get("day", 1))))
	unit.character_history.append("第%d级：%s提高%d。" % [int(unit.progression.level), str(Data.stat(stat_id).name), amount])
	recompute_character(unit, c)
	return {"ok": true, "reason": "%s提高%d。" % [str(Data.stat(stat_id).name), amount]}

static func train(c: Dictionary, unit_id: String, training_id: String) -> Dictionary:
	var unit := _find_unit(c, unit_id)
	if unit.is_empty():
		return _fail("找不到这名队员。")
	var option := _training_option(c, unit, training_id)
	if option.is_empty():
		return _fail("未知训练项目。")
	if not bool(option.available):
		return _fail(str(option.reason))
	if training_id == "bind_dog":
		var dog := _first_living_dog(c)
		if dog.is_empty():
			return _fail("营团当前没有存活战犬。")
		_rebind_dog(c, unit, dog)
		unit.character_history.append("在营地接管了战犬%s。" % str(dog.name))
		return {"ok": true, "reason": "%s现在由%s单独指挥。" % [str(dog.name), str(unit.name)]}
	var credit_cost := int(option.credit_cost)
	var food_cost := int(option.food_cost)
	var gold_cost := int(option.gold_cost)
	# Availability above validates the full transaction before any cost changes.
	unit.progression.training_credits = int(unit.progression.training_credits) - credit_cost
	c.food = int(c.food) - food_cost
	c.gold = int(c.gold) - gold_cost
	c.day = int(c.day) + int(option.days)
	var claim_id := "training:%s:%d:%d" % [str(unit.id), int(c.day), unit.progression.training_claims.size() + 1]
	unit.progression.training_claims.append(claim_id)
	if BASIC_TRAINING.has(training_id):
		var stat_id := str(BASIC_TRAINING[training_id].stat_id)
		var amount := int(Data.stat(stat_id).training_amount)
		unit.stat_sources.growth[stat_id] = int(unit.stat_sources.growth.get(stat_id, 0)) + amount
		unit.progression.stat_changes.append(_change(claim_id, stat_id, amount, "training", training_id, int(c.day)))
		unit.character_history.append("第%d天完成%s：%s提高%d。" % [int(c.day), str(option.name), str(Data.stat(stat_id).name), amount])
		recompute_character(unit, c)
	else:
		unit.capability_tags.append("beast_handler")
		unit.character_history.append("第%d天完成驯兽入门，学会标记与战犬指挥。" % int(c.day))
		_bind_unowned_dogs(c)
	return {"ok": true, "reason": "%s完成%s。" % [str(unit.name), str(option.name)]}

static func battle_progression_problem(c: Dictionary, battle: Dictionary, outcome: String, claim_id: String) -> String:
	if claim_id.is_empty():
		return "人物成长领取编号缺失。"
	if claim_id in c.get("character_state", {}).get("claimed_battles", []):
		return "这次人物经验已经领取。"
	if not outcome in ["victory", "defeat", "retreat"]:
		return "战斗结果不能用于人物成长。"
	var results := {}
	for raw: Dictionary in battle.get("units", []):
		if str(raw.get("team", "")) == "player":
			results[str(raw.get("id", ""))] = raw
	for participant_id in c.get("expedition", {}).get("participant_ids", []):
		var unit := _find_unit(c, str(participant_id))
		if unit.is_empty() or not results.has(str(participant_id)):
			return "参战人物与战斗结果不一致。"
		if claim_id in unit.get("progression", {}).get("xp_claims", []):
			return "这次人物经验已经领取。"
	return ""

static func apply_battle_progression(c: Dictionary, battle: Dictionary, outcome: String, claim_id: String) -> Dictionary:
	var problem := battle_progression_problem(c, battle, outcome, claim_id)
	if not problem.is_empty():
		return _fail(problem)
	var results := {}
	for raw: Dictionary in battle.get("units", []):
		if str(raw.get("team", "")) == "player":
			results[str(raw.id)] = raw
	var engaged := _battle_has_player_action(c, battle)
	var awards := []
	c.character_state.claimed_battles.append(claim_id)
	for participant_id in c.expedition.participant_ids:
		var unit := _find_unit(c, str(participant_id))
		var result: Dictionary = results[str(participant_id)]
		if int(result.get("hp", 0)) <= 0:
			continue
		var amount := 100 if outcome == "victory" else (35 if engaged else 0)
		if amount <= 0:
			continue
		var old_level := int(unit.progression.level)
		unit.progression.xp = int(unit.progression.xp) + amount
		unit.progression.level = Data.level_for_xp(int(unit.progression.xp))
		unit.level = int(unit.progression.level)
		var gained_levels := int(unit.progression.level) - old_level
		var gained_points := 0
		if str(unit.get("kind", "")) != "dog":
			gained_points = gained_levels * Data.ATTRIBUTE_POINTS_PER_LEVEL
			unit.progression.attribute_points = int(unit.progression.attribute_points) + gained_points
			unit.progression.training_credits = mini(Data.TRAINING_CREDIT_CAP, int(unit.progression.training_credits) + 1)
		unit.progression.xp_claims.append(claim_id)
		var note := "%s获得%d经验" % [str(unit.name), amount]
		if gained_levels > 0:
			note += "，升至%d级" % int(unit.progression.level)
			if gained_points > 0:
				note += "并获得%d属性点" % gained_points
		unit.character_history.append(note + "。")
		awards.append({"unit_id": str(unit.id), "xp": amount, "levels": gained_levels})
	return {"ok": true, "reason": "人物经历已经结算。", "awards": awards}

static func validate_campaign(c: Dictionary, allow_legacy: bool = false) -> String:
	if not c.has("character_state"):
		return "" if allow_legacy else "人物规则状态缺失。"
	if not c.character_state is Dictionary or int(c.character_state.get("schema", -1)) != Data.SCHEMA or str(c.character_state.get("rules_version", "")) != Data.RULES_VERSION:
		return "人物规则版本损坏。"
	if not _unique_strings(c.character_state.get("claimed_battles", [])):
		return "人物成长领取记录损坏。"
	var dog_owners := {}
	for unit: Dictionary in c.get("roster", []):
		if not _has_ledger(unit):
			return "人物属性来源账本缺失。"
		var background := Data.background(str(unit.background_id))
		if background.is_empty() or str(unit.background_name) != str(background.name) or str(unit.background_description) != str(background.description):
			return "人物出身元数据损坏。"
		if not _unique_strings(unit.capability_tags) or not _unique_strings(unit.progression.xp_claims) or not _unique_strings(unit.progression.training_claims):
			return "人物能力或领取记录重复。"
		for capability in unit.capability_tags:
			if not Data.CAPABILITY_NAMES.has(str(capability)):
				return "人物能力编号未知。"
		if str(unit.kind) == "hunter" and not "beast_handler" in unit.capability_tags:
			return "旧猎人缺少驯兽能力。"
		if int(unit.progression.get("schema", -1)) != Data.SCHEMA or not unit.progression.get("stat_changes") is Array or not unit.get("character_history") is Array:
			return "人物成长结构损坏。"
		for key in ["level", "xp", "attribute_points", "training_credits"]:
			if not unit.progression.get(key) is int:
				return "人物成长数值损坏。"
		if int(unit.progression.xp) < 0 or int(unit.progression.attribute_points) < 0:
			return "人物经验或属性点不能为负。"
		var expected_level := Data.level_for_xp(int(unit.progression.xp))
		if int(unit.progression.level) != expected_level or int(unit.progression.attribute_points) < 0 or int(unit.progression.training_credits) < 0 or int(unit.progression.training_credits) > Data.TRAINING_CREDIT_CAP:
			return "人物等级、属性点或实践额度损坏。"
		if str(unit.kind) == "dog" and (int(unit.progression.attribute_points) != 0 or int(unit.progression.training_credits) != 0):
			return "战犬不能持有人类培养货币。"
		if int(unit.stat_sources.get("schema", -1)) != Data.SCHEMA:
			return "人物属性来源版本损坏。"
		for bucket in ["base", "growth", "compatibility", "perk", "equipment", "effective"]:
			if not unit.stat_sources.get(bucket) is Dictionary:
				return "人物属性来源缺失。"
		for stat_id: String in Data.STAT_ORDER:
			var total := 0
			for bucket in ["base", "growth", "compatibility", "perk", "equipment"]:
				if not unit.stat_sources[bucket].get(stat_id) is int:
					return "人物属性来源数值损坏。"
				total += int(unit.stat_sources[bucket][stat_id])
			if int(unit.stat_sources.effective.get(stat_id, -999999)) != total:
				return "人物有效属性与来源不一致。"
		if int(unit.max_hp) != int(unit.stat_sources.effective.vitality) or int(unit.get("defense", 0)) != int(unit.stat_sources.effective.defense):
			return "人物生命或防御未使用有效属性。"
		var weapon := _weapon_definition(unit, c)
		var style := str(weapon.get("weapon_style", unit.get("weapon_style", unit.kind)))
		var accuracy_stat := "ranged_skill" if style in RANGED_STYLES else "melee_skill"
		if int(unit.accuracy) != int(unit.stat_sources.effective[accuracy_stat]):
			return "人物命中未使用当前武器对应技艺。"
		if int(unit.get("vitality", -999999)) != int(unit.stat_sources.effective.vitality) or int(unit.get("melee_skill", -999999)) != int(unit.stat_sources.effective.melee_skill) or int(unit.get("ranged_skill", -999999)) != int(unit.stat_sources.effective.ranged_skill) or int(unit.get("level", 0)) != int(unit.progression.level):
			return "人物战斗快照镜像损坏。"
		if not unit.combat_sources.has_all(["base_attack", "equipment_attack", "effective_attack"]):
			return "人物攻击来源损坏。"
		for combat_key in ["base_attack", "equipment_attack", "effective_attack"]:
			if not unit.combat_sources.get(combat_key) is int:
				return "人物攻击来源数值损坏。"
		if int(unit.attack) != int(unit.combat_sources.effective_attack) or int(unit.combat_sources.effective_attack) != int(unit.combat_sources.base_attack) + int(unit.combat_sources.equipment_attack):
			return "人物攻击来源损坏。"
		var change_ids := {}
		for change in unit.progression.stat_changes:
			if not change is Dictionary or not change.has_all(["id", "stat_id", "amount", "source_type", "source_id", "day"]):
				return "人物属性变化元数据缺失。"
			if not change.amount is int or not change.day is int or str(change.id).is_empty() or change_ids.has(str(change.id)) or Data.stat(str(change.stat_id)).is_empty() or int(change.amount) <= 0 or not str(change.source_type) in ["level", "training"] or str(change.source_id).is_empty() or int(change.day) < 1:
				return "人物属性变化元数据损坏。"
			change_ids[str(change.id)] = true
		if str(unit.kind) == "dog" and int(unit.hp) > 0:
			var owner_id := str(unit.get("hunter_id", ""))
			if not owner_id.is_empty():
				if dog_owners.has(owner_id):
					return "一名驯兽者重复绑定多只战犬。"
				dog_owners[owner_id] = str(unit.id)
	for owner_id in dog_owners:
		var owner := _find_unit(c, str(owner_id))
		if owner.is_empty() or int(owner.hp) <= 0 or not "beast_handler" in owner.capability_tags or str(owner.get("beast_id", "")) != str(dog_owners[owner_id]):
			return "战犬绑定引用损坏。"
	return ""

static func _training_options(c: Dictionary, unit: Dictionary) -> Array:
	var options: Array = []
	for training_id in ["basic_vitality", "basic_melee", "basic_ranged", "basic_defense", "beast_handler", "bind_dog"]:
		options.append(_training_option(c, unit, training_id))
	return options

static func _training_option(c: Dictionary, unit: Dictionary, training_id: String) -> Dictionary:
	var option := {"id": training_id, "name": "", "description": "", "cost_text": "", "available": false, "reason": "", "food_cost": 0, "gold_cost": 0, "days": 0, "credit_cost": 0}
	if BASIC_TRAINING.has(training_id):
		var definition: Dictionary = BASIC_TRAINING[training_id]
		var stat := Data.stat(str(definition.stat_id))
		option.name = str(definition.name)
		option.description = "%s提高%d；共同上限%d。" % [str(stat.name), int(stat.training_amount), int(stat.cap)]
		option.cost_text = "1天、1粮、1实践额度"
		option.food_cost = 1
		option.days = 1
		option.credit_cost = 1
	elif training_id == "beast_handler":
		option.name = "驯兽入门"
		option.description = "后天学会猎物标记和战犬指挥；能力不生成战犬，也不复制战犬行动。"
		option.cost_text = "12金、1天、1粮、1实践额度"
		option.gold_cost = 12
		option.food_cost = 1
		option.days = 1
		option.credit_cost = 1
	elif training_id == "bind_dog":
		option.name = "接管现有战犬"
		option.description = "在营地把一只现有战犬改由此人单独指挥；原主人解除绑定。"
		option.cost_text = "免费，不耗时"
	else:
		return {}
	var reason := _training_reason(c, unit, training_id, option)
	option.available = reason.is_empty()
	option.reason = "可以训练。" if reason.is_empty() else reason
	return option

static func _training_reason(c: Dictionary, unit: Dictionary, training_id: String, option: Dictionary) -> String:
	if str(c.get("phase", "")) != "camp":
		return "必须回到营地。"
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return "只能训练存活队员。"
	if str(unit.get("kind", "")) == "dog":
		return "战犬不使用人类培养项目。"
	if training_id == "beast_handler" and "beast_handler" in unit.get("capability_tags", []):
		return "已经掌握驯兽指挥。"
	if training_id == "bind_dog":
		if not "beast_handler" in unit.get("capability_tags", []):
			return "先学习驯兽入门。"
		var dog := _first_living_dog(c)
		if dog.is_empty():
			return "营团当前没有存活战犬。"
		if str(dog.get("hunter_id", "")) == str(unit.id):
			return "这只战犬已经由此人指挥。"
		return ""
	if int(unit.progression.get("training_credits", 0)) < int(option.credit_cost):
		return "缺少实践额度；完成有效参战后可补充。"
	if int(c.get("food", 0)) < int(option.food_cost):
		return "粮食不足。"
	if int(c.get("gold", 0)) < int(option.gold_cost):
		return "资金不足，需要%d金。" % int(option.gold_cost)
	if BASIC_TRAINING.has(training_id):
		var stat_id := str(BASIC_TRAINING[training_id].stat_id)
		if _permanent_stat(unit, stat_id) + int(Data.stat(stat_id).training_amount) > int(Data.stat(stat_id).cap):
			return "已达到共同训练上限。"
	return ""

static func _upgrade_reason(unit: Dictionary, stat_id: String, c: Dictionary = {}) -> String:
	if not c.is_empty() and str(c.get("phase", "")) != "camp":
		return "必须回到营地才能分配属性点。"
	if int(unit.get("hp", 0)) <= 0:
		return "死亡人物不能消费属性点。"
	if str(unit.get("kind", "")) == "dog":
		return "战犬暂不使用人物属性点。"
	if Data.stat(stat_id).is_empty():
		return "未知属性。"
	if int(unit.get("progression", {}).get("attribute_points", 0)) <= 0:
		return "没有可用属性点。"
	if _permanent_stat(unit, stat_id) + int(Data.stat(stat_id).upgrade_amount) > int(Data.stat(stat_id).cap):
		return "已达到共同培养上限。"
	return ""

static func _perk_sources(unit: Dictionary) -> Dictionary:
	var result := _zero_stats()
	var perks: Array = unit.get("perks", [])
	if "vigor" in perks:
		result.vitality = 8
	if "precision" in perks:
		result.melee_skill = 8
		result.ranged_skill = 8
	return result

static func _weapon_definition(unit: Dictionary, context: Dictionary) -> Dictionary:
	var instance_id := str(unit.get("equipment", {}).get("weapon", ""))
	if not instance_id.is_empty():
		for instance: Dictionary in context.get("equipment", {}).get("instances", []):
			if str(instance.get("id", "")) == instance_id:
				return EquipmentData.get_definition(str(instance.get("definition_id", "")))
	var visual_id := str(unit.get("visual_loadout", {}).get("weapon", ""))
	return EquipmentData.get_definition(visual_id)

static func _battle_has_player_action(c: Dictionary, battle: Dictionary) -> bool:
	var participants: Array = c.get("expedition", {}).get("participant_ids", [])
	for entry: Dictionary in battle.get("action_log", []):
		# Orders alone are preparation: a follow/recall/pin command followed by
		# immediate retreat earns nothing. The dog's later attack is its own action.
		if str(entry.get("actor", "")) in participants and str(entry.get("action", "")) in ["attack", "shield_bash", "push", "mark", "oil", "fire", "water"]:
			return true
	return false

static func _permanent_stat(unit: Dictionary, stat_id: String) -> int:
	var sources: Dictionary = unit.get("stat_sources", {})
	return int(sources.get("base", {}).get(stat_id, 0)) + int(sources.get("growth", {}).get(stat_id, 0)) + int(sources.get("compatibility", {}).get(stat_id, 0)) + int(sources.get("perk", {}).get(stat_id, 0))

static func _bind_unowned_dogs(c: Dictionary) -> void:
	var handlers := {}
	for unit: Dictionary in c.get("roster", []):
		if int(unit.get("hp", 0)) > 0 and "beast_handler" in unit.get("capability_tags", []):
			handlers[str(unit.id)] = unit
	for dog: Dictionary in c.get("roster", []):
		if str(dog.get("kind", "")) != "dog" or int(dog.get("hp", 0)) <= 0:
			continue
		var owner_id := str(dog.get("hunter_id", ""))
		if handlers.has(owner_id):
			handlers[owner_id].beast_id = str(dog.id)
			continue
		dog.hunter_id = ""
		for handler_id in handlers:
			if str(handlers[handler_id].get("beast_id", "")).is_empty():
				_rebind_dog(c, handlers[handler_id], dog)
				break

static func _rebind_dog(c: Dictionary, handler: Dictionary, dog: Dictionary) -> void:
	for unit: Dictionary in c.get("roster", []):
		if str(unit.get("beast_id", "")) == str(dog.id):
			unit.beast_id = ""
		if str(unit.get("kind", "")) == "dog" and str(unit.get("hunter_id", "")) == str(handler.id):
			unit.hunter_id = ""
	dog.hunter_id = str(handler.id)
	handler.beast_id = str(dog.id)

static func _first_living_dog(c: Dictionary) -> Dictionary:
	for unit: Dictionary in c.get("roster", []):
		if str(unit.get("kind", "")) == "dog" and int(unit.get("hp", 0)) > 0:
			return unit
	return {}

static func _find_unit(c: Dictionary, unit_id: String) -> Dictionary:
	for unit: Dictionary in c.get("roster", []):
		if str(unit.get("id", "")) == unit_id:
			return unit
	return {}

static func _has_ledger(unit: Dictionary) -> bool:
	return unit.get("progression") is Dictionary and unit.get("stat_sources") is Dictionary and unit.get("combat_sources") is Dictionary and unit.get("capability_tags") is Array and unit.get("character_history") is Array

static func _zero_stats() -> Dictionary:
	return {"vitality": 0, "melee_skill": 0, "ranged_skill": 0, "defense": 0}

static func _change(change_id: String, stat_id: String, amount: int, source_type: String, source_id: String, day: int) -> Dictionary:
	return {"id": change_id, "stat_id": stat_id, "amount": amount, "source_type": source_type, "source_id": source_id, "day": day}

static func _unique_strings(values) -> bool:
	if not values is Array:
		return false
	var seen := {}
	for value in values:
		if not value is String or str(value).is_empty() or seen.has(str(value)):
			return false
		seen[str(value)] = true
	return true

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
