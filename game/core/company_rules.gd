extends RefCounted
## Small, saved company economy. Numbers are prototype playtest values.
const Equipment = preload("res://core/equipment_rules.gd")
const Character = preload("res://core/character_rules.gd")
const MAX_LIVING := 8
const EVENT_ID := "evt_camp_rescue_reckoning_v1"
const ROLES := ["guard", "spear", "archer", "skirmisher", "hunter"]
const ROLE_NAMES := {"guard": "盾卫", "spear": "枪兵", "archer": "弓手", "skirmisher": "游击兵", "hunter": "猎人", "dog": "猎犬"}
const STARTS := [[2, 2], [2, 3], [1, 3], [1, 4]]

static func ensure(c: Dictionary) -> bool:
	if c.has("company"):
		return false
	var company := {"schema": 1, "candidate_serial": 1, "candidates": [], "refresh_after_day": int(c.get("day", 1)) + 3,
		"last_maintenance_day": int(c.get("day", 1)), "maintenance_debt": 0,
		"deployment": [], "pending_event": {}, "event_claims": [], "injury_sources": []}
	c.company = company
	_seed_candidates(c)
	var n := 0
	for u: Dictionary in c.get("roster", []):
		if int(u.get("hp", 0)) <= 0 or n >= 4: continue
		company.deployment.append({"unit_id": str(u.id), "q": int(STARTS[n][0]), "r": int(STARTS[n][1])})
		n += 1
	return true

static func get_view(c: Dictionary) -> Dictionary:
	var company: Dictionary = c.get("company", {})
	if company.is_empty(): return {"ok": false, "reason": "经营记录尚未迁移。"}
	var candidates := []
	for raw: Dictionary in company.get("candidates", []):
		var item := raw.duplicate(true)
		item.available = str(c.get("phase", "")) == "camp" and int(c.get("gold", 0)) >= int(raw.price) and _living_count(c) < MAX_LIVING
		item.fee = int(raw.price)
		item.wage = int(raw.daily_maintenance)
		item.description = "%s；%s；%s" % [str(raw.starting_equipment), str(raw.training_gap), "成熟出身省训练时间" if str(raw.background) == "veteran" else "普通出身培养上限相同"]
		item.reason = "可签约" if item.available else "资金不足、名册已满或不在营地"
		candidates.append(item)
	var daily := maintenance_due(c)
	var event: Dictionary = company.get("pending_event", {})
	return {"ok": true, "reason": "", "candidates": candidates, "roster": c.get("roster", []).duplicate(true), "deployment": company.get("deployment", []).duplicate(true),
		"living_count": _living_count(c), "roster_limit": MAX_LIVING,
		"maintenance": {"daily_cost": daily, "debt": int(company.get("maintenance_debt", 0)),
			"last_day": int(company.get("last_maintenance_day", c.day)), "next_day": int(company.get("last_maintenance_day", c.day)) + 1},
		"maintenance_per_day": daily, "maintenance_debt": int(company.get("maintenance_debt", 0)),
		"next_maintenance_day": int(company.get("last_maintenance_day", c.day)) + 1,
		"refresh_cost": 8, "refresh_days": 2, "refresh_after_day": int(company.get("refresh_after_day", 0)),
		"short_work": {"days": 2, "net_gold": 8, "food": 2, "battle_xp": 0, "risk": "低：占用两天、维护费从工钱中扣；储备充足时不可接"},
		"pending_event": event.duplicate(true), "event": _event_view(event)}

static func validate(c: Dictionary, allow_legacy: bool = false) -> String:
	if not c.has("company"):
		return "" if allow_legacy else "经营记录缺失。"
	var x = c.company
	if not x is Dictionary or not x.has_all(["schema", "candidate_serial", "candidates", "refresh_after_day", "last_maintenance_day", "maintenance_debt", "deployment", "pending_event", "event_claims", "injury_sources"]):
		return "经营记录结构损坏。"
	for key in ["schema", "candidate_serial", "refresh_after_day", "last_maintenance_day", "maintenance_debt"]:
		if not _integer(x[key]): return "经营记录整数损坏。"
	if int(x.schema) != 1 or not x.candidates is Array or not x.deployment is Array or not x.event_claims is Array or not x.injury_sources is Array or not x.pending_event is Dictionary:
		return "经营记录结构损坏。"
	if int(x.candidate_serial) < 1 or int(x.refresh_after_day) < 1 or int(x.last_maintenance_day) < 1 or int(x.last_maintenance_day) > int(c.get("day", 1)) or int(x.maintenance_debt) < 0:
		return "经营记录数值损坏。"
	if _living_count(c) > MAX_LIVING: return "名册超过八名存活成员。"
	var seen := {}
	for candidate in x.candidates:
		if not candidate is Dictionary or not candidate.has_all(["id", "name", "kind", "background", "price", "daily_maintenance"]): return "招聘候选损坏。"
		var id := str(candidate.id)
		if id.is_empty() or seen.has(id) or not _integer(candidate.price) or not _integer(candidate.daily_maintenance) or int(candidate.price) < 0 or int(candidate.daily_maintenance) < 0: return "招聘候选重复或数值损坏。"
		seen[id] = true
	seen = {}
	var occupied := {}
	for slot in x.deployment:
		if not slot is Dictionary or not slot.has_all(["unit_id", "q", "r"]): return "部署记录损坏。"
		var id := str(slot.unit_id)
		if not slot.unit_id is String or not _integer(slot.q) or not _integer(slot.r): return "部署记录类型损坏。"
		var key := "%d,%d" % [int(slot.q), int(slot.r)]
		if id.is_empty() or seen.has(id) or occupied.has(key) or _find(c, id).is_empty() or int(slot.q) < 0 or int(slot.q) > 2 or int(slot.r) < 0 or int(slot.r) > 6: return "部署记录损坏。"
		seen[id] = true; occupied[key] = true
	if x.deployment.size() > 4: return "部署人数超过四人。"
	seen = {}
	for claim in x.event_claims:
		if not claim is String or str(claim).is_empty() or seen.has(str(claim)): return "人物事件领取编号损坏。"
		seen[str(claim)] = true
	seen = {}
	for source in x.injury_sources:
		if not source is String or str(source).is_empty() or seen.has(str(source)): return "伤残来源编号损坏。"
		seen[str(source)] = true
	if not x.pending_event.is_empty():
		if not x.pending_event.has_all(["id", "instance_id", "participant_id", "source", "trigger", "absence_path", "repeat_limit", "test_path", "choices"]): return "人物事件结构损坏。"
		if str(x.pending_event.id) != EVENT_ID or str(x.pending_event.instance_id).is_empty() or str(x.pending_event.instance_id) in x.event_claims: return "人物事件编号损坏。"
	return ""

static func _integer(value) -> bool:
	return value is int or (value is float and is_finite(value) and floor(value) == value)

static func _event_view(event: Dictionary) -> Dictionary:
	if event.is_empty(): return {}
	var out := event.duplicate(true)
	out.title = "重伤归来"
	out.text = "战后重伤幸存。选择恢复时间与物资，或花时间复盘并改变行事方式。"
	return out

static func maintenance_due(c: Dictionary) -> int:
	var total := 0
	for unit: Dictionary in c.get("roster", []):
		if int(unit.get("hp", 0)) > 0:
			total += int(unit.get("daily_maintenance", 1 if str(unit.get("kind", "")) == "dog" else 2))
	return total

static func tick(c: Dictionary) -> Dictionary:
	var company: Dictionary = c.get("company", {})
	if company.is_empty(): return _fail("经营记录尚未迁移。")
	var through := int(c.get("day", 1))
	for unit: Dictionary in c.get("roster", []):
		var until_day := int(unit.get("recovery_until_day", 0))
		if until_day > 0 and until_day <= through:
			unit.recovery_until_day = 0
			if unit.get("injury", {}) is Dictionary and int(unit.get("injury", {}).get("until_day", 0)) <= through:
				unit.injury = {}
	var last := int(company.get("last_maintenance_day", through))
	if through <= last: return {"ok": true, "reason": "本日维护已结算。", "charged": 0}
	var due := (through - last) * maintenance_due(c)
	var paid := mini(maxi(0, int(c.get("gold", 0))), due)
	c.gold = int(c.gold) - paid
	company.maintenance_debt = int(company.get("maintenance_debt", 0)) + due - paid
	company.last_maintenance_day = through
	return {"ok": true, "reason": "经过%d天，维护费%d金；支付%d金，欠款%d金。" % [through - last, due, paid, int(company.maintenance_debt)], "charged": due, "paid": paid}

static func recruit(c: Dictionary, candidate_id: String) -> Dictionary:
	if str(c.get("phase", "")) != "camp": return _fail("须在营地招募。")
	if _living_count(c) >= MAX_LIVING: return _fail("名册最多八名存活成员。")
	var company: Dictionary = c.get("company", {})
	var candidate := {}
	for raw: Dictionary in company.get("candidates", []):
		if str(raw.get("id", "")) == candidate_id: candidate = raw; break
	if candidate.is_empty(): return _fail("候选人已离开或编号无效。")
	if int(c.get("gold", 0)) < int(candidate.price): return _fail("签约资金不足。")
	c.gold = int(c.gold) - int(candidate.price)
	var unit := _make_unit(c, candidate)
	c.roster.append(unit)
	Equipment.grant_recruit_loadout(c, unit)
	Character.ensure_character(unit, c)
	if str(candidate.background) == "veteran":
		unit.progression.xp = 100
		unit.progression.level = 2
		unit.level = 2
	Character.ensure_campaign(c)
	company.candidates.erase(candidate)
	return {"ok": true, "reason": "%s入团：签约%d金，每日维护%d金；基本装备随人配发且不可出售。" % [str(unit.name), int(candidate.price), int(candidate.daily_maintenance)], "unit_id": str(unit.id)}

static func emergency_recruit(c: Dictionary) -> Dictionary:
	if str(c.get("phase", "")) != "camp": return _fail("须在营地补员。")
	if _living_count(c) >= MAX_LIVING: return _fail("名册已满。")
	var slot := -1
	for i in range(c.roster.size()):
		if int(c.roster[i].get("hp", 0)) <= 0: slot = i; break
	var vacant_position := {}
	if slot >= 0:
		for position: Dictionary in c.company.get("deployment", []):
			if str(position.get("unit_id", "")) == str(c.roster[slot].id):
				vacant_position = {"q": int(position.q), "r": int(position.r)}
				break
	prune_deployment(c)
	var kind := "guard"
	if slot >= 0: kind = str(c.roster[slot].kind)
	if kind not in ROLES and kind != "dog": kind = "guard"
	var price := 18 if kind == "dog" else 28
	var paid := mini(int(c.gold), price)
	var debt := price - paid
	c.gold = int(c.gold) - paid
	c.flags.advance_debt = int(c.flags.get("advance_debt", 0)) + debt
	var candidate := {"kind": kind, "name": "急募%s" % str(ROLE_NAMES.get(kind, "佣兵")), "background": "ordinary", "daily_maintenance": 1 if kind == "dog" else 2}
	var unit := _make_unit(c, candidate)
	if slot < 0:
		c.roster.append(unit)
	else:
		c.roster[slot] = unit
	# Reuse a former cell if this dead member was selected. A wiped company
	# receives one legal starting cell; other replacement choices stay editable.
	if c.company.deployment.size() < 4 and not vacant_position.is_empty():
		c.company.deployment.append({"unit_id": str(unit.id), "q": int(vacant_position.q), "r": int(vacant_position.r)})
	elif c.company.deployment.is_empty():
		for position: Array in STARTS:
			var occupied := false
			for entry: Dictionary in c.company.deployment:
				if int(entry.q) == int(position[0]) and int(entry.r) == int(position[1]): occupied = true
			if not occupied:
				c.company.deployment.append({"unit_id": str(unit.id), "q": int(position[0]), "r": int(position[1])})
				break
	Equipment.grant_recruit_loadout(c, unit)
	Character.ensure_character(unit, c)
	Character.ensure_campaign(c)
	c.day = int(c.day) + 1
	tick(c)
	return {"ok": true, "reason": "急募补员花费%d金、预支%d金，耗时一天；配发物品不可出售。" % [paid, debt], "unit_id": str(unit.id)}

static func refresh(c: Dictionary) -> Dictionary:
	if str(c.get("phase", "")) != "camp": return _fail("须在营地等待新候选。")
	var company: Dictionary = c.get("company", {})
	if int(c.day) < int(company.get("refresh_after_day", 0)): return _fail("尚未到公开的候选刷新日。")
	if int(c.gold) < 8: return _fail("寻找候选需要8金。")
	c.gold = int(c.gold) - 8
	c.day = int(c.day) + 2
	tick(c)
	company.candidates = []
	_seed_candidates(c)
	company.refresh_after_day = int(c.day) + 3
	return {"ok": true, "reason": "支付8金、等候两天，新候选已确定并保存。"}

static func short_work(c: Dictionary) -> Dictionary:
	if str(c.get("phase", "")) != "camp": return _fail("须在营地接短工。")
	if int(c.get("gold", 0)) >= 24 and int(c.get("food", 0)) >= 6: return _fail("储备足够，渡口把短工机会留给缺粮缺钱的队伍。")
	var instance_id := "work_%d_%d" % [int(c.get("seed", 0)), int(c.day)]
	if c.get("claimed", {}).has(instance_id): return _fail("这份短工已经结清。")
	var gross := maintenance_due(c) * 2 + 12
	c.day = int(c.day) + 2
	var maintenance := tick(c)
	var debt := int(c.company.get("maintenance_debt", 0))
	var repayment := mini(gross - 8, debt)
	c.company.maintenance_debt = debt - repayment
	c.gold = int(c.gold) + gross - repayment
	c.food = mini(12, int(c.food) + 2)
	c.claimed[instance_id] = true
	c.history.append({"type": "short_work", "id": instance_id, "day": int(c.day), "gold": gross - repayment})
	return {"ok": true, "reason": "短工两天：工钱%d金、2粮，不发战斗经验；维护%d金，偿还欠款%d金，至少留8金作恢复储备。" % [gross, int(maintenance.get("charged", 0)), repayment], "instance_id": instance_id}

static func select_deployment(c: Dictionary, slots: Array) -> Dictionary:
	if str(c.get("phase", "")) != "camp": return _fail("出征名单只能在营地更改。")
	var problem := deployment_problem(c, slots)
	if not problem.is_empty(): return _fail(problem)
	c.company.deployment = slots.duplicate(true)
	return {"ok": true, "reason": "出征名单与左三列位置已保存。"}

static func deployment_problem(c: Dictionary, slots: Array) -> String:
	if slots.is_empty() or slots.size() > 4: return "选择一至四名成员。"
	var ids := {}; var cells := {}
	for raw in slots:
		if not raw is Dictionary: return "部署格式无效。"
		var id := str(raw.get("unit_id", ""))
		var q := int(raw.get("q", -1)); var r := int(raw.get("r", -1))
		var key := "%d,%d" % [q, r]
		var unit := _find(c, id)
		if unit.is_empty() or int(unit.get("hp", 0)) <= 0 or int(unit.get("recovery_until_day", 0)) > int(c.day): return "死亡或重伤未休完的成员不能出战。"
		if ids.has(id) or cells.has(key) or q < 0 or q > 2 or r < 0 or r > 6: return "部署须是左三列无障碍、不重叠的格子。"
		ids[id] = true; cells[key] = true
	for raw in slots:
		var unit := _find(c, str(raw.unit_id))
		if str(unit.get("kind", "")) == "dog" and not str(unit.get("hunter_id", "")).is_empty() and not ids.has(str(unit.hunter_id)):
			return "战犬主人缺席；须带上主人，或先在营地重新绑定驯兽者。"
	return ""

static func prune_deployment(c: Dictionary) -> void:
	if not c.get("company", {}) is Dictionary: return
	var kept := []
	for slot: Dictionary in c.company.get("deployment", []):
		var unit := _find(c, str(slot.get("unit_id", "")))
		if not unit.is_empty() and int(unit.get("hp", 0)) > 0: kept.append(slot)
	c.company.deployment = kept

static func departure_deployment(c: Dictionary) -> Dictionary:
	var selected: Array = c.get("company", {}).get("deployment", [])
	var result := select_deployment(c, selected)
	if not result.ok: return result
	return {"ok": true, "reason": "", "slots": selected.duplicate(true)}

static func on_battle_settled(c: Dictionary, survivors: Array) -> void:
	if survivors.is_empty() or not c.get("company", {}) is Dictionary: return
	for survivor: Dictionary in survivors:
		var source := str(survivor.get("casualty_id", ""))
		if source.is_empty(): continue
		var id := "%s:%s" % [EVENT_ID, source]
		if source in c.company.injury_sources: continue
		var record := {}
		for casualty: Dictionary in c.get("battle", {}).get("casualties", []):
			if str(casualty.get("id", "")) == source: record = casualty; break
		if record.is_empty(): continue
		var unit := _find(c, str(survivor.unit_id))
		if unit.is_empty(): continue
		c.company.injury_sources.append(source)
		# The saved casualty roll supplies the severity; no settlement reroll.
		if int(record.get("roll", 100)) < 20:
			unit.permanent_injuries = unit.get("permanent_injuries", [])
			if not "lasting_wound" in unit.permanent_injuries: unit.permanent_injuries.append("lasting_wound")
			unit.permanent_injury_description = "长期旧伤：战斗疲劳上限 -8；山脊路多备1粮。本次重伤休养再延1天。"
			unit.recovery_until_day = int(unit.get("recovery_until_day", c.day)) + 1
			if unit.get("injury", {}) is Dictionary and not unit.get("injury", {}).is_empty(): unit.injury.until_day = int(unit.recovery_until_day)
			Character.recompute_character(unit, c)
			unit.get("character_history", []).append("%s重伤后留下长期旧伤：疲劳上限-8，山脊路多备1粮。" % source)
		if not c.company.get("pending_event", {}).is_empty() or id in c.company.event_claims: continue
		c.company.pending_event = {"id": EVENT_ID, "instance_id": id, "participant_id": str(unit.id), "source": source,
			"trigger": "返营且真实伤亡记录为重伤幸存", "absence_path": "缺席延后；死亡则关闭且无奖励", "repeat_limit": 1,
			"test_path": "新战斗胜利、倒地幸存、返营，选休养/复盘；读档重复尝试；死亡/缺席", "choices": [
				{"id": "rest", "title": "专心休养", "description": "耗一天及一粮，恢复12生命；不改变性格。"},
			{"id": "review", "title": "返营复盘", "description": "耗一天与4金，形成谨慎性格；山脊路多带一粮，出征多备一份水。"}]}

static func resolve_event(c: Dictionary, choice_id: String) -> Dictionary:
	if str(c.get("phase", "")) != "camp": return _fail("须返营再处理此事。")
	var event: Dictionary = c.get("company", {}).get("pending_event", {})
	if event.is_empty(): return _fail("没有待处理的重伤事件。")
	var id := str(event.instance_id)
	if id in c.company.event_claims: return _fail("这次事件已处理。")
	var unit := _find(c, str(event.participant_id))
	if unit.is_empty(): return _fail("队员暂时缺席，事件延后。")
	if int(unit.get("hp", 0)) <= 0:
		c.company.event_claims.append(id); c.company.pending_event = {}
		return {"ok": true, "reason": "当事人已逝，团员留下简短记录；无资源或性格奖励。"}
	if choice_id == "rest":
		if int(c.food) < 1: return _fail("休养需要一粮。")
		c.food = int(c.food) - 1
		unit.hp = mini(int(unit.max_hp), int(unit.hp) + 12)
	elif choice_id == "review":
		if int(c.gold) < 4: return _fail("复盘需要4金。")
		c.gold = int(c.gold) - 4
		unit.personality = "cautious"
	else: return _fail("未知事件选项。")
	c.day = int(c.day) + 1
	tick(c)
	c.company.event_claims.append(id)
	c.company.pending_event = {}
	c.history.append({"type": "company_event", "id": EVENT_ID, "instance_id": id, "choice": choice_id, "day": int(c.day)})
	return {"ok": true, "reason": "重伤经历已记录，后果保存。"}

static func _seed_candidates(c: Dictionary) -> void:
	for index in range(2):
		var serial := int(c.company.candidate_serial)
		c.company.candidate_serial = serial + 1
		var role: String = str(ROLES[posmod(int(c.get("seed", 0)) + serial + index, ROLES.size())])
		var mature := index == 1
		c.company.candidates.append({"id": "candidate_%d_%d" % [int(c.seed), serial], "name": ("熟练" if mature else "普通") + str(ROLE_NAMES.get(role, "佣兵")) + "·" + str(serial),
			"kind": role, "background": "veteran" if mature else "ordinary", "price": 46 if mature else 18,
			"daily_maintenance": 4 if mature else 2,
			"starting_level": 2 if mature else 1, "starting_equipment": "基本配发，不可出售",
			"training_gap": "即刻具备较高属性，仍用共同训练上限" if mature else "需出征积累实践额度"})

static func _make_unit(c: Dictionary, candidate: Dictionary) -> Dictionary:
	var serial := int(c.flags.get("next_crew_id", 5))
	c.flags.next_crew_id = serial + 1
	var kind := str(candidate.kind)
	var stats := {"guard": [58, 24, 12, 88, 1], "spear": [48, 16, 15, 88, 2], "archer": [40, 10, 14, 86, 4],
		"skirmisher": [46, 14, 15, 88, 1], "hunter": [46, 14, 13, 88, 3], "dog": [40, 6, 12, 90, 1]}
	var v: Array = stats.get(kind, stats.guard)
	var mature := str(candidate.get("background", "")) == "veteran"
	return {"id": "crew_%d" % serial, "name": str(candidate.name), "kind": kind, "team": "player", "q": 1, "r": 1,
		"hp": int(v[0]) + (6 if mature else 0), "max_hp": int(v[0]) + (6 if mature else 0), "armor": int(v[1]), "max_armor": int(v[1]),
		"ap": 6, "max_ap": 6, "attack": int(v[2]), "accuracy": int(v[3]) + (4 if mature else 0), "range": int(v[4]),
		"statuses": {}, "perks": [], "daily_maintenance": int(candidate.daily_maintenance), "background_tier": str(candidate.background)}

static func _living_count(c: Dictionary) -> int:
	var count := 0
	for u: Dictionary in c.get("roster", []):
		if int(u.get("hp", 0)) > 0: count += 1
	return count

static func _find(c: Dictionary, id: String) -> Dictionary:
	for u: Dictionary in c.get("roster", []):
		if str(u.get("id", "")) == id: return u
	return {}

static func _fail(reason: String) -> Dictionary:
	return {"ok": false, "reason": reason}
