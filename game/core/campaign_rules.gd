extends RefCounted
## Original prototype campaign rules. All state is JSON-safe and owned by callers.
## These values are playtest hypotheses, not the final economy or progression.

const World = preload("res://core/world_data.gd")
const Equipment = preload("res://core/equipment_rules.gd")
const Character = preload("res://core/character_rules.gd")

const PERK_INFO = {
	"vigor": {"title": "坚韧", "description": "最大生命与当前生命永久 +8。"},
	"precision": {"title": "沉着瞄准", "description": "命中永久 +8；最终命中仍受战斗上限约束。"},
	"breacher": {"title": "破阵协同", "description": "盾击伤害 +4；长枪利用破绽时伤害 +6。"},
	"firewise": {"title": "识火", "description": "火区伤害减半；仍需付出绕行或灭火的代价。"},
	"packbond": {"title": "同猎", "description": "战犬攻击已被标记的目标时伤害 +6。"}
}
const ORIGIN_KINDS = {
	"free": ["guard", "spear", "archer", "skirmisher"],
	"hunters": ["guard", "spear", "hunter", "dog"]
}
const FIRST_NAMES = ["艾妲", "罗温", "米芮", "塔洛"]
const KIND_NAMES = {
	"guard": "盾卫", "spear": "枪兵", "archer": "弓手",
	"skirmisher": "游击兵", "hunter": "猎人", "dog": "猎犬"
}
const ROUTE_ORDER: Array[String] = ["road", "ridge"]
# Original route text and numbers for the prototype. They deliberately reuse the
# same mission and event pool so route choice tests preparation, not map content.
const ROUTE_DETAILS = {
	"road": {
		"name": "渡口旧道",
		"description": "沿着渡口旧道赶往粮仓。路程稳妥，保留既有的补给与风险。",
		"food_cost": 2, "days": 1, "difficulty_offset": 0, "reward_bonus": 0,
		"supplies": {"oil": 1, "fire": 2, "water": 2}
	},
	"ridge": {
		"name": "山脊险径",
		"description": "翻过碎石山脊赶往粮仓。多带粮食换取油料和更高报酬，但敌人的装备与战力更强。",
		"food_cost": 3, "days": 1, "difficulty_offset": 1, "reward_bonus": 18,
		"supplies": {"oil": 2, "fire": 2, "water": 2}
	}
}

static func create_campaign(origin: String, seed_value: int) -> Dictionary:
	var actual_origin: String = origin if ORIGIN_KINDS.has(origin) else "free"
	var state_seed: int = posmod(seed_value, 2147483646) + 1
	var c: Dictionary = {
		"schema": 1, "seed": seed_value, "rng_state": state_seed,
		"company_name": "灰岸自由团" if actual_origin == "free" else "雾林猎团",
		"origin": actual_origin, "gold": 72, "food": 8, "day": 1, "renown": 0,
		"roster": [], "flags": {
			"next_crew_id": 5, "expeditions_started": 0, "victories": 0,
			"grain_saved": 0, "grain_lost": 0, "advance_debt": 0,
			"memorial": [], "ending_seen": false
		},
		"history": [], "phase": "camp", "expedition": {}, "event": {},
		"growth_offers": [], "growth_unit_id": "", "last_report": "",
		"battle": {}, "claimed": {}, "world": World.new_world()
	}
	var kinds: Array = ORIGIN_KINDS[actual_origin]
	for i in range(4):
		var unit_name: String = FIRST_NAMES[i]
		if str(kinds[i]) == "hunter":
			unit_name = "榛木"
		elif str(kinds[i]) == "dog":
			unit_name = "灰牙"
		c.roster.append(_new_unit(str(kinds[i]), "crew_%d" % (i + 1), unit_name, i))
	Equipment.initialize_new_campaign(c)
	Character.ensure_campaign(c)
	return c

static func camp_action(c: Dictionary, action: String) -> Dictionary:
	if str(c.get("phase", "")) != "camp":
		return _fail("先完成当前远征与成长选择，再进行营地整备。")
	var living: Array = _living(c)
	match action:
		"rest":
			var hurt: bool = false
			for unit: Dictionary in living:
				if int(unit.hp) < int(unit.max_hp):
					hurt = true
			if not hurt:
				return _fail("存活队员没有需要休养的伤势；死亡队员需要补员。")
			var has_rations: bool = int(c.food) >= 2
			var recovery: int = 18 if has_rations else 8
			if has_rations:
				c.food = int(c.food) - 2
			c.day = int(c.day) + 1
			for unit: Dictionary in living:
				unit.hp = mini(int(unit.max_hp), int(unit.hp) + recovery)
			return _camp_ok(c, "休养一天：每名存活队员恢复 %d 生命，消耗 %d 粮食。%s" % [
				recovery, 2 if has_rations else 0,
				"" if has_rations else "缺粮时只能靠野营缓慢恢复。"])
		"resupply":
			if int(c.food) >= 12:
				return _fail("行囊已有 12 份粮食，无需继续囤积。")
			if int(c.gold) >= 12:
				c.gold = int(c.gold) - 12
				var added: int = mini(6, 12 - int(c.food))
				c.food = int(c.food) + added
				return _camp_ok(c, "花费 12 金，购入 %d 份粮食。" % added)
			if int(c.food) < 2:
				c.food = int(c.food) + 4
				c.day = int(c.day) + 2
				return _camp_ok(c, "缺粮又缺钱：队伍帮渡口搬货两天，换来 4 份粮食。可继续远征。")
			return _fail("补给需要 12 金；粮食少于 2 且资金不足时，可在渡口做短工换粮。")
		"repair":
			# Roster armor remains a battle-facing mirror; persist any current wear
			# before pricing repairs across equipped and stored armor instances.
			Equipment.sync_roster_armor_to_instances(c)
			var repair := Equipment.repair_all(c)
			if not repair.ok:
				return repair
			return _camp_ok(c, str(repair.reason))
		"recruit":
			var slot: int = -1
			for i in range(c.roster.size()):
				if int(c.roster[i].hp) <= 0:
					slot = i
					break
			if slot < 0 and c.roster.size() < 4:
				slot = c.roster.size()
			if slot < 0:
				return _fail("四个出战位均有存活队员；本原型暂不扩充编制。")
			var kind: String = str(ORIGIN_KINDS[str(c.origin)][slot])
			var price: int = 18 if kind == "dog" else 28
			var paid: int = mini(int(c.gold), price)
			var advance: int = price - paid
			c.gold = int(c.gold) - paid
			c.flags.advance_debt = int(c.flags.get("advance_debt", 0)) + advance
			var serial: int = int(c.flags.get("next_crew_id", 5))
			c.flags.next_crew_id = serial + 1
			var recruit_name: String = "%s·%d" % [str(KIND_NAMES[kind]), serial]
			var recruit: Dictionary = _new_unit(kind, "crew_%d" % serial, recruit_name, slot)
			if slot == c.roster.size():
				c.roster.append(recruit)
			else:
				_record_memorial(c, c.roster[slot])
				Equipment.discard_unit_loadout(c, c.roster[slot])
				c.roster[slot] = recruit
			Equipment.grant_recruit_loadout(c, recruit)
			Character.ensure_character(recruit, c)
			c.day = int(c.day) + 1
			Character.ensure_campaign(c)
			var advance_note: String = ""
			if advance > 0:
				advance_note = " 其中 %d 金为预支签约款，之后每次战利品最多扣三分之一偿还。" % advance
			return _camp_ok(c, "%s加入，补上原有出战位，支付 %d 金，经过一天。%s" % [recruit_name, paid, advance_note])
		_:
			return _fail("未知营地操作。")

static func get_routes(c: Dictionary) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	for route_id: String in ROUTE_ORDER:
		var details: Dictionary = ROUTE_DETAILS[route_id]
		var unavailable_reason: String = _route_unavailable_reason(c, details)
		routes.append({
			"id": route_id, "name": str(details.name), "description": _route_description(c, route_id, details),
			"food_cost": int(details.food_cost), "days": int(details.days),
			"difficulty": _route_difficulty(c, int(details.difficulty_offset)),
			"reward": _route_reward(c, int(details.reward_bonus)),
			"supplies": details.supplies.duplicate(true),
			"available": unavailable_reason.is_empty(),
			"reason": "补给充足，可以从这里出发。" if unavailable_reason.is_empty() else unavailable_reason
		})
	return routes

static func get_world_view(c: Dictionary) -> Dictionary:
	var world: Dictionary = c.get("world", {})
	var travel: Dictionary = world.get("travel", {})
	var discovered: Array = world.get("discovered_location_ids", [])
	var locations: Array = []
	for raw_location: Dictionary in World.LOCATIONS:
		var location: Dictionary = raw_location.duplicate(true)
		location.discovered = str(location.id) in discovered
		locations.append(location)
	var path: Array = travel.get("route_path", []).duplicate()
	var step: int = int(travel.get("current_edge_index", 0))
	var next_location_id: String = ""
	if step + 1 < path.size():
		next_location_id = str(path[step + 1])
	return {
		"locations": locations,
		"edges": World.EDGES.duplicate(true),
		"location_id": str(world.get("company_location_id", World.CAMP_ID)),
		"route_path": path,
		"visited_ids": path.slice(0, mini(step + 1, path.size())),
		"travel_status": str(travel.get("status", "idle")),
		"step": step,
		"total_steps": maxi(0, path.size() - 1),
		"next_location_id": next_location_id,
		"report": str(c.get("last_report", ""))
	}

static func get_contract_offers(c: Dictionary, location_id: String) -> Array[Dictionary]:
	var reason: String = ""
	if location_id != World.CAMP_ID:
		reason = "雨夜粮仓契约目前只在灰岸营地接取。"
	elif str(c.get("phase", "")) != "camp" or str(c.get("world", {}).get("company_location_id", "")) != World.CAMP_ID:
		reason = "先完成当前旅行、战斗与返营。"
	elif not str(c.get("world", {}).get("active_contract_id", "")).is_empty():
		reason = "已有尚未返营的契约。"
	return [{
		"id": World.CONTRACT_ID,
		"title": "雨夜粮仓",
		"description": "前往边境粮仓，击退劫掠者并尽量保住粮袋。",
		"location_id": World.CAMP_ID,
		"destination_id": "loc_granary",
		"routes": get_routes(c),
		"available": reason.is_empty(),
		"reason": "可以选择路线并接约。" if reason.is_empty() else reason
	}]

static func accept_contract(c: Dictionary, contract_id: String, route_id: String) -> Dictionary:
	if contract_id != World.CONTRACT_ID:
		return _fail("未知契约。")
	var world: Dictionary = c.get("world", {})
	if world.is_empty() or str(world.get("company_location_id", "")) != World.CAMP_ID:
		return _fail("佣兵团必须在灰岸营地接取契约。")
	if not str(world.get("active_contract_id", "")).is_empty() or not world.get("travel", {}).is_empty():
		return _fail("已有尚未返营的契约。")
	var route: Dictionary = _route_by_id(c, route_id)
	if route.is_empty():
		return _fail("未知远征路线。")
	if not bool(route.available):
		return _fail(str(route.reason))
	# All validation is complete before food, day, flags, or RNG state can change.
	c.food = int(c.food) - int(route.food_cost)
	c.day = int(c.day) + int(route.days)
	var index: int = int(c.flags.get("expeditions_started", 0)) + 1
	c.flags.expeditions_started = index
	var participants: Array = []
	for unit: Dictionary in _living(c):
		participants.append(str(unit.id))
	var expedition_id := "exp_%d_%d" % [int(c.seed), index]
	c.expedition = {
		"id": expedition_id, "index": index,
		"title": "雨夜粮仓", "difficulty": int(route.difficulty),
		"supplies": route.supplies.duplicate(true),
		"reward": int(route.reward), "renown_bonus": 0,
		"route_id": str(route.id), "route_name": str(route.name),
		"route_food_cost": int(route.food_cost), "route_days": int(route.days),
		"choice": "", "participant_ids": participants, "event_id": "",
		"contract_id": contract_id, "travel_id": expedition_id,
		"location_id": "loc_granary"
	}
	c.growth_offers = []
	c.growth_unit_id = ""
	c.battle = {}
	var event_id: String = _select_event(c, index)
	var route_path: Array = World.route_path(route_id)
	var event_step: int = 1 if route_path.size() > 2 else maxi(0, route_path.size() - 1)
	if event_id == "event_granary_stores":
		event_step = route_path.size() - 1
	elif event_id == "event_bell_at_bridge":
		if route_id == "road":
			route_path = [World.CAMP_ID, "loc_ferry_crossing", "loc_bridgehead", "loc_ferry_crossing", "loc_granary"]
		else:
			route_path = [World.CAMP_ID, "loc_ridge_pass", "loc_bridgehead", "loc_ridge_pass", "loc_hunter_edge", "loc_granary"]
		event_step = 2
	var event_location_id: String = str(route_path[event_step])
	c.event = _make_event(c, event_id)
	c.event.event_instance_id = "%s:%s" % [expedition_id, event_id]
	c.event.scope = "travel"
	c.event.content_version = World.CONTENT_VERSION
	c.event.location_id = event_location_id
	c.expedition.event_id = event_id
	world.active_contract_id = contract_id
	world.travel = {
		"id": expedition_id, "contract_id": contract_id,
		"origin_id": World.CAMP_ID, "destination_id": "loc_granary",
		"route_id": str(route.id), "route_path": route_path,
		"edge_ids": _edge_ids(route_path), "current_edge_index": 0,
		"food_cost": int(route.food_cost), "days": int(route.days),
		"event_instance_id": str(c.event.event_instance_id),
		"event_step": event_step, "status": "traveling"
	}
	c.phase = "travel"
	c.history.append({
		"type": "departure", "id": str(c.expedition.id), "route_id": str(route.id),
		"route_name": str(route.name), "route_food_cost": int(route.food_cost),
		"route_days": int(route.days), "day": int(c.day)
	})
	c.last_report = "经「%s」出征，消耗 %d 份粮食、%d 天。眼前的选择将改变本次战斗准备与之后的回报。" % [
		str(route.name), int(route.food_cost), int(route.days)]
	return {"ok": true, "reason": c.last_report, "event": c.event, "world": get_world_view(c)}

static func start_expedition(c: Dictionary, route_id: String = "road") -> Dictionary:
	return accept_contract(c, World.CONTRACT_ID, route_id)

static func advance_travel(c: Dictionary) -> Dictionary:
	if str(c.get("phase", "")) != "travel":
		return _fail("当前没有可以推进的旅行。")
	var world: Dictionary = c.get("world", {})
	var travel: Dictionary = world.get("travel", {})
	var path: Array = travel.get("route_path", [])
	var step: int = int(travel.get("current_edge_index", -1))
	if path.size() < 2 or step < 0 or step >= path.size() - 1 or str(travel.get("status", "")) != "traveling":
		return _fail("旅行记录损坏或已经结束。")
	var next_step := step + 1
	var location_id := str(path[next_step])
	travel.current_edge_index = next_step
	world.company_location_id = location_id
	_discover(world, location_id)
	_touch_location(world, location_id, int(c.day))
	if next_step == int(travel.get("event_step", -1)) and not str(travel.event_instance_id) in world.resolved_event_instance_ids:
		c.phase = "event"
		travel.status = "event"
		c.last_report = "旅队抵达%s，一件已确定的旅途事件等待处理。" % _location_name(location_id)
	elif next_step == path.size() - 1:
		c.phase = "ready"
		travel.status = "ready"
		c.last_report = "佣兵团抵达雨夜粮仓，可以进入战斗。"
	else:
		c.last_report = "旅队抵达%s，下一段行程仍按已支付路线推进。" % _location_name(location_id)
	return {"ok": true, "reason": c.last_report, "world": get_world_view(c)}

static func _edge_ids(path: Array) -> Array:
	var ids: Array = []
	for i in range(path.size() - 1):
		ids.append("%s>%s" % [str(path[i]), str(path[i + 1])])
	return ids

static func _discover(world: Dictionary, location_id: String) -> void:
	if not location_id in world.discovered_location_ids:
		world.discovered_location_ids.append(location_id)

static func _touch_location(world: Dictionary, location_id: String, day: int) -> void:
	if not world.location_states.has(location_id):
		world.location_states[location_id] = {"flags": {}, "last_visit_day": day}
	else:
		world.location_states[location_id].last_visit_day = day

static func _location_name(location_id: String) -> String:
	for location: Dictionary in World.LOCATIONS:
		if str(location.id) == location_id:
			return str(location.name)
	return location_id

static func _route_by_id(c: Dictionary, route_id: String) -> Dictionary:
	for route: Dictionary in get_routes(c):
		if str(route.get("id", "")) == route_id:
			return route
	return {}

static func _route_unavailable_reason(c: Dictionary, details: Dictionary) -> String:
	if str(c.get("phase", "")) != "camp":
		return "远征已生成，不能重新抽选事件。"
	if _living(c).is_empty():
		return "没有存活队员。请先补员；资金不足时可预支签约款。"
	var food_cost: int = int(details.get("food_cost", 0))
	if int(c.get("food", 0)) < food_cost:
		return "出征需要 %d 份粮食。营地补给在缺钱缺粮时提供短工恢复通路。" % food_cost
	return ""

static func _route_description(c: Dictionary, route_id: String, details: Dictionary) -> String:
	if route_id != "ridge":
		return str(details.description)
	if _route_base_difficulty(c) >= 2 and not _is_failure_recovery(c):
		return "敌情已达当前区域上限，与渡口旧道相同；多消耗 1 粮，获得额外 18 金和 1 油。这是补给与收益选择。"
	if _is_failure_recovery(c):
		return "上次失利让敌情回落。山脊险径仍比渡口旧道高一档；多消耗 1 粮，获得额外 18 金和 1 油。"
	return str(details.description)

static func _is_failure_recovery(c: Dictionary) -> bool:
	return str(c.get("flags", {}).get("last_outcome", "")) in ["defeat", "retreat"]

static func _route_base_difficulty(c: Dictionary) -> int:
	var index: int = int(c.get("flags", {}).get("expeditions_started", 0)) + 1
	var difficulty: int = clampi(int((index - 1) / 2), 0, 2)
	if _is_failure_recovery(c):
		return 0
	return difficulty

static func _route_difficulty(c: Dictionary, difficulty_offset: int) -> int:
	return clampi(_route_base_difficulty(c) + difficulty_offset, 0, 2)

static func _route_reward(c: Dictionary, reward_bonus: int) -> int:
	var index: int = int(c.get("flags", {}).get("expeditions_started", 0)) + 1
	return 36 + mini(index, 3) * 6 + reward_bonus

static func choose_event(c: Dictionary, choice_id: String) -> Dictionary:
	if str(c.get("phase", "")) != "event":
		return _fail("当前没有等待选择的事件。")
	var world: Dictionary = c.get("world", {})
	var travel: Dictionary = world.get("travel", {})
	var event_instance_id: String = str(c.get("event", {}).get("event_instance_id", ""))
	if not travel.is_empty():
		if event_instance_id.is_empty() or event_instance_id != str(travel.get("event_instance_id", "")):
			return _fail("事件实例与当前旅行不匹配。")
		if event_instance_id in world.get("resolved_event_instance_ids", []):
			return _fail("这个旅途事件已经处理。")
	var chosen: Dictionary = {}
	for choice: Dictionary in c.event.get("choices", []):
		if str(choice.id) == choice_id:
			chosen = choice
			break
	if chosen.is_empty():
		return _fail("这个事件没有此选项。")
	var costs: Dictionary = chosen.get("costs", {})
	if int(c.gold) < int(costs.get("gold", 0)) or int(c.food) < int(costs.get("food", 0)):
		return _fail("资源不足，无法兑现这个选项。另一个选项始终无需支出。")
	c.gold = int(c.gold) - int(costs.get("gold", 0))
	c.food = int(c.food) - int(costs.get("food", 0))
	var effects: Dictionary = chosen.get("effects", {})
	c.gold = maxi(0, int(c.gold) + int(effects.get("gold", 0)))
	c.food = maxi(0, int(c.food) + int(effects.get("food", 0)))
	c.expedition.reward = maxi(0, int(c.expedition.reward) + int(effects.get("reward", 0)))
	c.expedition.difficulty = clampi(int(c.expedition.difficulty) + int(effects.get("difficulty", 0)), 0, 2)
	c.expedition.renown_bonus = int(c.expedition.renown_bonus) + int(effects.get("renown", 0))
	for supply_name in ["oil", "fire", "water"]:
		c.expedition.supplies[supply_name] = maxi(0, int(c.expedition.supplies[supply_name]) + int(effects.get(supply_name, 0)))
	var missing_note: String = ""
	var participant_id: String = str(c.event.get("participant_id", ""))
	if not participant_id.is_empty() and _find_living(c, participant_id).is_empty():
		missing_note = "\n原先参与的队员已经缺席，承诺由全团接手，不阻断远征。"
	var heal: int = int(effects.get("heal", 0))
	if heal > 0:
		for unit: Dictionary in _living(c):
			unit.hp = mini(int(unit.max_hp), int(unit.hp) + heal)
	for flag_key in chosen.get("set_flags", {}):
		c.flags[flag_key] = chosen.set_flags[flag_key]
	c.expedition.choice = choice_id
	c.event.selected_choice = choice_id
	c.history.append({
		"type": "event", "id": str(c.event.id), "choice": choice_id,
		"expedition_id": str(c.expedition.id), "day": int(c.day)
	})
	if bool(c.event.get("legacy_direct_ready", false)):
		world.resolved_event_instance_ids.append(event_instance_id)
		c.phase = "ready"
		travel.status = "ready"
		travel.current_edge_index = travel.get("route_path", []).size() - 1
		world.company_location_id = "loc_granary"
		_discover(world, "loc_granary")
	elif not travel.is_empty():
		world.resolved_event_instance_ids.append(event_instance_id)
		var step: int = int(travel.get("current_edge_index", 0))
		var path: Array = travel.get("route_path", [])
		if step == path.size() - 1:
			c.phase = "ready"
			travel.status = "ready"
		else:
			c.phase = "travel"
			travel.status = "traveling"
	else:
		c.phase = "ready"
	c.last_report = str(chosen.description) + missing_note
	return {"ok": true, "reason": c.last_report, "report": c.last_report}

static func battle_config(c: Dictionary) -> Dictionary:
	if c.get("expedition", {}).is_empty():
		return {}
	return {
		"id": str(c.expedition.id), "title": str(c.expedition.title),
		"difficulty": int(c.expedition.difficulty),
		"supplies": c.expedition.supplies.duplicate(true),
		"route_id": str(c.expedition.get("route_id", "road")),
		"route_name": str(c.expedition.get("route_name", "渡口旧道")),
		"event_id": str(c.expedition.get("event_id", "")),
		"choice": str(c.expedition.get("choice", "")),
		"contract_id": str(c.expedition.get("contract_id", World.CONTRACT_ID)),
		"travel_id": str(c.expedition.get("travel_id", c.expedition.id)),
		"location_id": str(c.expedition.get("location_id", "loc_granary"))
	}

static func begin_battle(c: Dictionary, battle: Dictionary) -> Dictionary:
	if str(c.get("phase", "")) != "ready":
		return _fail("当前阶段不能进入战斗。")
	var expedition_id: String = str(c.get("expedition", {}).get("id", ""))
	if expedition_id.is_empty() or str(battle.get("id", "")) != expedition_id:
		return _fail("战斗与当前契约不匹配。")
	var travel: Dictionary = c.get("world", {}).get("travel", {})
	if not travel.is_empty() and str(travel.get("status", "")) != "ready":
		return _fail("旅队尚未抵达契约战场。")
	c.battle = battle.duplicate(true)
	c.phase = "battle"
	if not travel.is_empty():
		travel.status = "battle"
	return {"ok": true, "reason": "进入雨夜粮仓战斗。"}

static func resolve_battle(c: Dictionary, battle: Dictionary) -> Dictionary:
	var expedition: Dictionary = c.get("expedition", {})
	var expedition_id: String = str(expedition.get("id", ""))
	if expedition_id.is_empty() or str(battle.get("id", "")) != expedition_id:
		return _fail("战斗与当前远征不匹配，未进行结算。")
	if str(c.get("phase", "")) != "battle":
		return _fail("当前阶段不能结算战斗。")
	if c.get("battle", {}).is_empty() or battle != c.battle:
		return _fail("提交的战斗结果不是当前已登记的战斗状态。")
	if c.get("claimed", {}).has(expedition_id):
		return _fail("这次远征已经结算，不能重复领取奖励。")
	var outcome: String = str(battle.get("outcome", ""))
	if not outcome in ["victory", "defeat", "retreat"]:
		return _fail("战斗尚未结束。")
	var player_units: Dictionary = {}
	for unit: Dictionary in battle.get("units", []):
		if str(unit.get("team", "")) == "player":
			if player_units.has(str(unit.id)):
				return _fail("战斗中存在重复队员 ID，未进行结算。")
			player_units[str(unit.id)] = unit
	for unit: Dictionary in _living(c):
		if not player_units.has(str(unit.id)):
			return _fail("战斗缺少出征队员的结果，未进行结算。")
	var equipment_problem := Equipment.battle_result_problem(c, battle)
	if not equipment_problem.is_empty():
		return _fail(equipment_problem)
	var progression_claim_id := "battle:%s" % expedition_id
	var progression_problem := Character.battle_progression_problem(c, battle, outcome, progression_claim_id)
	if not progression_problem.is_empty():
		return _fail(progression_problem)
	# All validation precedes mutation. The claim guards both money and progression.
	var equipment_settlement := Equipment.apply_battle_result(c, battle)
	var progression_settlement := Character.apply_battle_progression(c, battle, outcome, progression_claim_id)
	c.claimed[expedition_id] = true
	var casualties: Array = []
	for unit: Dictionary in c.roster:
		if player_units.has(str(unit.id)) and int(unit.hp) > 0:
			var result: Dictionary = player_units[str(unit.id)]
			unit.hp = clampi(int(result.get("hp", 0)), 0, int(unit.max_hp))
			unit.armor = clampi(int(result.get("armor", 0)), 0, int(unit.max_armor))
			if int(unit.hp) <= 0:
				casualties.append(str(unit.name))
				_record_memorial(c, unit)
	var grain_survives: bool = false
	for prop: Dictionary in battle.get("props", []):
		if str(prop.get("kind", "")) == "grain" and int(prop.get("hp", 0)) > 0:
			grain_survives = true
	var earned: int = 0
	var grain_food: int = 0
	var narrative: String = ""
	if outcome == "victory":
		earned = int(expedition.reward)
		c.flags.victories = int(c.flags.get("victories", 0)) + 1
		c.renown = int(c.renown) + 1 + int(expedition.get("renown_bonus", 0))
		if grain_survives:
			c.flags.grain_saved = int(c.flags.get("grain_saved", 0)) + 1
			grain_food = 2
			earned += 10
			narrative = "粮仓保住了。村民从抢救出的粮袋里拨出 2 份口粮，并追加 10 金谢礼。"
		else:
			c.flags.grain_lost = int(c.flags.get("grain_lost", 0)) + 1
			narrative = "敌人被击退，粮仓却毁了。契约照付，但村民再也拿不出额外的粮食与谢礼。"
	elif outcome == "retreat":
		var defeated_enemies: int = 0
		for unit: Dictionary in battle.get("units", []):
			if str(unit.get("team", "")) == "enemy" and int(unit.get("hp", 0)) <= 0:
				defeated_enemies += 1
		if not _living(c).is_empty():
			earned = mini(12, defeated_enemies * 3)
		c.flags.grain_lost = int(c.flags.get("grain_lost", 0)) + 1
		narrative = "你们离开了粮仓。未完成契约不发报酬，幸存者仅带回已击败敌人的少量随身物资。"
	else:
		c.flags.grain_lost = int(c.flags.get("grain_lost", 0)) + 1
		narrative = "远征失败，契约没有报酬。名册上的死者不会复活；这面旗帜仍可通过预支签约款招募继承者。"
	var debt: int = int(c.flags.get("advance_debt", 0))
	var repayment: int = mini(debt, int(earned / 3))
	c.flags.advance_debt = debt - repayment
	c.gold = int(c.gold) + earned - repayment
	c.food = int(c.food) + grain_food
	c.day = int(c.day) + 1
	c.flags.last_outcome = outcome
	c.history.append({
		"type": "result", "id": expedition_id, "outcome": outcome,
		"grain_saved": grain_survives and outcome == "victory",
		"gold": earned - repayment, "deaths": casualties.duplicate(), "day": int(c.day)
	})
	c.battle = battle.duplicate(true)
	var world: Dictionary = c.get("world", {})
	var travel: Dictionary = world.get("travel", {})
	if not travel.is_empty():
		travel.status = "returning"
		var granary_state: Dictionary = world.location_states.get("loc_granary", {"flags": {}, "last_visit_day": int(c.day)})
		granary_state.flags.last_outcome = outcome
		granary_state.flags.grain_saved = grain_survives and outcome == "victory"
		granary_state.last_visit_day = int(c.day)
		world.location_states["loc_granary"] = granary_state
	var report: String = "%s\n实收 %d 金；粮食 +%d；当前 %d 金、%d 份粮食。" % [
		narrative, earned - repayment, grain_food, int(c.gold), int(c.food)]
	if repayment > 0:
		report += "\n已偿还预支签约款 %d 金，尚欠 %d 金。" % [repayment, int(c.flags.advance_debt)]
	if casualties.is_empty():
		report += "\n无人阵亡。伤势和护甲损耗会保留，返营后可休养和修补。"
	else:
		report += "\n阵亡：" + "、".join(casualties) + "。他们的经历留在名册中，原位可补员。阵亡时随身武器与护甲遗失。"
		if not equipment_settlement.get("lost", []).is_empty():
			report += " 遗失：" + "、".join(equipment_settlement.lost) + "。"
	var xp_notes: Array[String] = []
	for award: Dictionary in progression_settlement.get("awards", []):
		var recipient := _find_living(c, str(award.unit_id))
		xp_notes.append("%s +%d经验" % [str(recipient.get("name", award.unit_id)), int(award.xp)])
	if not xp_notes.is_empty():
		report += "\n人物成长：" + "、".join(xp_notes) + "。"
	elif outcome != "victory":
		report += "\n本次撤离前没有有效行动，不发人物经验。"
	if int(expedition.index) >= 3 and not bool(c.flags.get("ending_seen", false)):
		c.flags.ending_seen = true
		c.flags.ending_text = _ending(c)
		report += "\n\n【短篇收束】\n" + str(c.flags.ending_text) + "\n你可以继续经营佣兵团，经历尚未遇到的事件与构筑。"
	c.growth_offers = []
	c.growth_unit_id = ""
	c.phase = "returning"
	if outcome == "victory" and not _living(c).is_empty():
		_generate_growth(c)
		if not c.growth_offers.is_empty():
			c.phase = "growth"
			report += "\n一名幸存队员从远征中获得成长机会，请选择一次。"
	c.last_report = report
	return {"ok": true, "reason": report, "report": report}

static func choose_growth(c: Dictionary, offer_id: String) -> Dictionary:
	if str(c.get("phase", "")) != "growth":
		return _fail("当前没有未兑现的成长机会。")
	var offer: Dictionary = {}
	for candidate: Dictionary in c.get("growth_offers", []):
		if str(candidate.id) == offer_id:
			offer = candidate
			break
	if offer.is_empty():
		return _fail("这个成长选项不属于当前保存的候选。")
	var unit: Dictionary = _find_living(c, str(c.get("growth_unit_id", "")))
	var perk: String = str(offer.get("perk", ""))
	var effect_note: String = ""
	if not perk.is_empty():
		if unit.is_empty():
			# A missing character must not strand a campaign in the growth phase.
			c.gold = int(c.gold) + 12
			effect_note = "原定成长队员已经缺席。导师退回 12 金训练费，全团带着这份经验继续前行。"
		else:
			# Saved candidates are promises from their generating rules version. Do
			# not re-run current eligibility and invalidate an old breacher offer.
			if perk in unit.perks or not PERK_INFO.has(perk):
				return _fail("该专长已经学习或候选数据损坏，未消耗成长机会。")
			unit.perks.append(perk)
			Character.recompute_character(unit, c)
			effect_note = "%s学会「%s」：%s" % [str(unit.name), str(offer.title), str(offer.description)]
	else:
		match str(offer.get("fallback", "")):
			"pay":
				c.gold = int(c.gold) + 12
				effect_note = "没有适配的新专长，改为留下 12 金军饷储备。"
			"rations":
				c.food = int(c.food) + 3
				effect_note = "没有适配的新专长，改为准备 3 份远征口粮。"
			"maintenance":
				for survivor: Dictionary in _living(c):
					survivor.hp = mini(int(survivor.max_hp), int(survivor.hp) + 10)
					survivor.armor = mini(int(survivor.max_armor), int(survivor.armor) + 6)
				Equipment.sync_roster_armor_to_instances(c)
				effect_note = "改为战地整备：存活队员恢复 10 生命、6 护甲。"
			_:
				return _fail("成长候选损坏，未进行任何结算。")
	c.history.append({
		"type": "growth", "id": offer_id, "unit_id": str(c.growth_unit_id),
		"perk": perk, "expedition_id": str(c.expedition.id)
	})
	c.growth_offers = []
	c.growth_unit_id = ""
	c.phase = "returning"
	c.last_report = str(c.last_report) + "\n\n" + effect_note
	return {"ok": true, "reason": effect_note, "report": effect_note}

static func return_to_camp(c: Dictionary) -> Dictionary:
	if str(c.get("phase", "")) != "returning":
		return _fail("当前没有等待完成的返营行程。")
	var world: Dictionary = c.get("world", {})
	var travel: Dictionary = world.get("travel", {})
	if world.is_empty() or travel.is_empty() or str(travel.get("status", "")) != "returning":
		return _fail("返营记录缺失。")
	var expedition_id: String = str(c.get("expedition", {}).get("id", ""))
	if expedition_id.is_empty() or not c.get("claimed", {}).has(expedition_id):
		return _fail("契约尚未完成一次性结算。")
	world.company_location_id = World.CAMP_ID
	_discover(world, World.CAMP_ID)
	_touch_location(world, World.CAMP_ID, int(c.day))
	travel.status = "completed"
	world.active_contract_id = ""
	world.travel = {}
	c.phase = "camp"
	c.last_report = str(c.last_report) + "\n\n佣兵团已经返回灰岸营地；回程已计入本次结算，不额外消耗天数或口粮。伤势、护甲与阵亡记录全部保留。"
	c.history.append({"type": "return", "id": expedition_id, "location_id": World.CAMP_ID, "day": int(c.day)})
	return {"ok": true, "reason": "已返回灰岸营地。", "report": c.last_report, "world": get_world_view(c)}

static func _new_unit(kind: String, id: String, unit_name: String, slot: int) -> Dictionary:
	var stats: Dictionary = {
		"guard": [58, 24, 12, 88, 1],
		"spear": [48, 16, 15, 88, 2],
		"archer": [40, 10, 14, 86, 4],
		"skirmisher": [46, 14, 15, 88, 1],
		"hunter": [46, 14, 13, 88, 3],
		"dog": [40, 6, 12, 90, 1]
	}
	var values: Array = stats[kind]
	return {
		"id": id, "name": unit_name, "kind": kind, "team": "player",
		"q": 1, "r": slot + 1, "hp": values[0], "max_hp": values[0],
		"armor": values[1], "max_armor": values[1], "ap": 6, "max_ap": 6,
		"attack": values[2], "accuracy": values[3], "range": values[4],
		"statuses": {}, "perks": []
	}

static func _select_event(c: Dictionary, index: int) -> String:
	if index == 1:
		return "event_bell_on_bank"
	if index == 3 and _event_count(c, "event_bell_at_bridge") == 0:
		return "event_bell_at_bridge"
	if bool(c.flags.get("villagers_promised", false)) and _event_count(c, "event_village_reply") == 0:
		return "event_village_reply"
	var pool: Array = []
	var last_event: String = ""
	for entry: Dictionary in c.history:
		if str(entry.get("type", "")) == "event":
			last_event = str(entry.id)
	# Eligibility before weighting. Required free choices survive an empty purse.
	var candidates: Array = ["event_granary_stores", "event_hunter_tracks", "event_unposted_letter"]
	for candidate in candidates:
		if str(candidate) == "event_unposted_letter" and _living(c).is_empty():
			continue
		if str(candidate) == last_event:
			continue
		var weight: int = 3 if _event_count(c, str(candidate)) == 0 else 1
		for unused in range(weight):
			pool.append(candidate)
	if pool.is_empty():
		return "event_granary_stores"
	return str(pool[_random_index(c, pool.size())])

static func _make_event(c: Dictionary, event_id: String) -> Dictionary:
	var participant: Dictionary = _story_participant(c)
	var participant_name: String = str(participant.get("name", "旗帜的继承者"))
	var event: Dictionary = {
		"id": event_id, "title": "", "body": "", "choices": [],
		"participant_id": str(participant.get("id", "")),
		"repeat_limit": 0, "trigger": "远征启程，存在存活队员",
		"absence_path": "由全团接手承诺；不依赖单一人物存活。",
		"test_path": "start_expedition → choose_event → resolve_battle"
	}
	match event_id:
		"event_bell_on_bank":
			event.title = "泥岸的钟声"
			event.body = "渡口的旧钟被布包住，钟身裂口像一道未愈的伤。%s看见几个村民站在雨里：粮仓今晚会遭抢，他们愿意把最后两桶水交给肯留下的人。雇主却只关心钟能否按时过桥。" % participant_name
			event.repeat_limit = 1
			event.trigger = "第一次远征；全团承接村民或雇主的约定"
			event.choices = [
				_choice("bell_protect", "先护住粮仓", "本次多带 2 份水、契约赏金少 8 金；村民记下承诺，未来会回信。", {}, {"water": 2, "reward": -8}, {"villagers_promised": true}),
				_choice("bell_contract", "按雇主的备战安排", "拿到 1 份油、1 份火；本次契约赏金多 6 金，村民不再许诺后援。", {}, {"oil": 1, "fire": 1, "reward": 6}, {"bell_contract": true})
			]
		"event_granary_stores":
			event.title = "雨棚下的旧桶"
			event.body = "粮仓侧门堆着一辆坏车。守仓人只肯让你们带走一种存货：干燥的灯油能封住窄道，井水则能扑灭乱窜的火舌。拿走之后，村民自己能用的就少了。"
			event.trigger = "非首程与第三程锚点；与上次事件不同，可重复"
			event.choices = [
				_choice("stores_oil", "借走灯油和火绒", "本次油 +2、火 +1、水 -1；油火封路更容易，但灭火余量下降。", {}, {"oil": 2, "fire": 1, "water": -1}),
				_choice("stores_water", "留下油，带足井水", "本次水 +3、油 -1；可以反复灭火造汽，但不能主动铺油。", {}, {"water": 3, "oil": -1})
			]
		"event_hunter_tracks":
			var has_hunter: bool = _has_kind(c, "hunter")
			event.title = "断绳旁的足迹"
			event.body = "%s在林边找到一根断绳和新鲜脚印。%s敌人的搬运队刚经过这里，绕行能避开一名警戒者，直接搜查则能找到被抛弃的油壶。" % [
				participant_name, "猎人认出了猎犬的爪印。" if has_hunter else "队里没有猎人，大家只能沿着车辙慢慢辨认。"]
			event.trigger = "非锚点；有猎人时追踪免费，无猎人也有非阻断路径"
			event.choices = [
				_choice("tracks_scout", "跟着踪迹绕行", "本次难度降低一级（最低为入门）；%s" % ("猎人带路，无需额外粮食。" if has_hunter else "绕路消耗 1 份粮食。"),
					{} if has_hunter else {"food": 1}, {"difficulty": -1}),
				_choice("tracks_salvage", "搜查被丢下的货物", "本次多带 1 份油，并立即得到 6 金；敌方警戒保持原样。", {}, {"oil": 1, "gold": 6})
			]
		"event_village_reply":
			event.title = "旧约的回信"
			event.body = "曾在泥岸求援的村民追上车队。他们没有忘记你们的答复。%s接过一张被雨泡软的纸：『当初答应过帮你们。粮和水不能都运过来，请留一样。』即使当初接话的人已经阵亡，约定也仍属于这面旗帜。" % participant_name
			event.repeat_limit = 1
			event.trigger = "选择护仓后，下一次非第三程锚点；只出现一次"
			event.choices = [
				_choice("reply_rations", "让他们送来口粮", "立即获得 4 份粮食；本次水不增加。之后这笔旧约就此兑现。", {}, {"food": 4}, {"villagers_repaid": true}),
				_choice("reply_water", "请他们接应水桶", "本次多带 2 份水，胜利声望额外 +1；不获得粮食。旧约就此兑现。", {}, {"water": 2, "renown": 1}, {"villagers_repaid": true})
			]
		"event_unposted_letter":
			event.title = "没有寄出的信"
			event.body = "%s把一封写了一半的信放在营火旁。信里没写战绩，只写了谁替谁挡过一击。队伍可以分出粮食一起照顾伤者，也可以把剩余补给用于一次更凶险、报酬更高的护送。" % participant_name
			event.trigger = "非锚点；至少一个存活人物；参与者缺席时由全团代为处理"
			event.choices = [
				_choice("letter_share", "大家分一顿热饭", "消耗 1 份粮食，每名存活队员恢复 10 生命；本次契约赏金少 4 金。", {"food": 1}, {"heal": 10, "reward": -4}),
				_choice("letter_risk", "接下更危险的路段", "本次难度提高一级（最高二级），契约赏金多 14 金。无需立即支出。", {}, {"difficulty": 1, "reward": 14})
			]
		"event_bell_at_bridge":
			event.title = "雾中的回钟"
			event.body = "第三次走到桥前，裂钟终于露出原样。%s听见村民说：钟不是护身符，只是让散落的人知道，还有人在这里守着。把它留给村庄，雇主会扣钱；随车带走，则能换来一批点火物资。" % participant_name
			event.repeat_limit = 1
			event.trigger = "第三次远征；不要求任何指定人物或前次胜利"
			event.choices = [
				_choice("bridge_keep", "把钟留在村庄", "本次多带 2 份水，胜利声望额外 +2；契约赏金少 12 金。", {}, {"water": 2, "renown": 2, "reward": -12}, {"bell_left": true}),
				_choice("bridge_deliver", "兑现最初的护送契约", "本次火 +2、油 +1，契约赏金多 10 金；村庄只能另找集结的信号。", {}, {"fire": 2, "oil": 1, "reward": 10}, {"bell_delivered": true})
			]
	return event

static func _choice(id: String, title: String, description: String, costs: Dictionary, effects: Dictionary, set_flags: Dictionary = {}) -> Dictionary:
	return {"id": id, "title": title, "description": description, "costs": costs, "effects": effects, "set_flags": set_flags}

static func _generate_growth(c: Dictionary) -> void:
	var eligible_units: Array = []
	var largest_pool: int = -1
	# Give a three-way permanent choice while any living role has that many options.
	for unit: Dictionary in _living(c):
		var count: int = _eligible_perks(unit).size()
		if count > largest_pool:
			largest_pool = count
			eligible_units = [unit]
		elif count == largest_pool:
			eligible_units.append(unit)
	if eligible_units.is_empty():
		return
	var unit: Dictionary = eligible_units[_random_index(c, eligible_units.size())]
	c.growth_unit_id = str(unit.id)
	var available: Array = _eligible_perks(unit)
	var selected: Array = []
	var basics: Array = []
	for perk in ["vigor", "precision"]:
		if perk in available:
			basics.append(perk)
	if not basics.is_empty():
		var basic: String = str(basics[_random_index(c, basics.size())])
		selected.append(basic)
		available.erase(basic)
	var synergies: Array = []
	for perk in available:
		if str(perk) in ["breacher", "packbond"]:
			synergies.append(perk)
	if not synergies.is_empty() and selected.size() < 3:
		var synergy: String = str(synergies[_random_index(c, synergies.size())])
		selected.append(synergy)
		available.erase(synergy)
	while selected.size() < 3 and not available.is_empty():
		var perk: String = str(available[_random_index(c, available.size())])
		selected.append(perk)
		available.erase(perk)
	c.growth_offers = []
	for perk in selected:
		var details: Dictionary = PERK_INFO[str(perk)]
		c.growth_offers.append({
			"id": "%s:%s:%s" % [str(c.expedition.id), str(unit.id), str(perk)],
			"title": str(details.title), "description": str(details.description),
			"perk": str(perk), "unit_id": str(unit.id)
		})
	var fallbacks: Array = [
		{"fallback": "pay", "title": "军饷储备", "description": "合法新专长不足：改为获得 12 金，不重复学习已有专长。"},
		{"fallback": "rations", "title": "行囊补给", "description": "合法新专长不足：改为获得 3 份粮食。"},
		{"fallback": "maintenance", "title": "战地整备", "description": "合法新专长不足：存活队员恢复 10 生命、6 护甲。"}
	]
	var fallback_index: int = 0
	while c.growth_offers.size() < 3:
		var fallback: Dictionary = fallbacks[fallback_index].duplicate(true)
		fallback.id = "%s:%s:%s" % [str(c.expedition.id), str(unit.id), str(fallback.fallback)]
		fallback.unit_id = str(unit.id)
		c.growth_offers.append(fallback)
		fallback_index += 1

static func _eligible_perks(unit: Dictionary) -> Array:
	var pool: Array = ["vigor", "precision", "firewise"]
	if str(unit.kind) != "dog":
		pool.append("breacher")
	# Dogs retain their original bond growth, while trained human handlers may
	# now learn the same synergy without a lifetime background restriction.
	pool.append("packbond")
	var result: Array = []
	for perk in pool:
		if not perk in unit.get("perks", []):
			result.append(perk)
	return result

static func _ending(c: Dictionary) -> String:
	var victories: int = int(c.flags.get("victories", 0))
	var saved: int = int(c.flags.get("grain_saved", 0))
	var ending: String = ""
	if victories >= 2 and saved >= 2:
		ending = "桥两端重新点起灯。人们记住了你们保下的粮车，也愿意为下一份契约作保。这支佣兵团暂时有了一个可以回来的地方。"
	elif victories >= 1:
		ending = "桥还在，粮车却少了。幸存者提起你们时，既记得伸出的手，也记得没能救下的东西。佣兵团带着一份不完整的名声继续上路。"
	else:
		ending = "粮道失守，原来的队伍没能完成托付。裂钟的故事传给后来举旗的人：失败留下名字与债务，也留下下一次改变结局的机会。"
	if bool(c.flags.get("bell_left", false)):
		ending += " 裂钟留在了村里，每次敲响都提醒着这份守望。"
	elif bool(c.flags.get("bell_delivered", false)):
		ending += " 雇主收走了裂钟，村民从此用桥头的火光彼此报信。"
	return ending

static func _story_participant(c: Dictionary) -> Dictionary:
	for unit: Dictionary in _living(c):
		if str(unit.kind) != "dog":
			return unit
	var living: Array = _living(c)
	return living[0] if not living.is_empty() else {}

static func _living(c: Dictionary) -> Array:
	var result: Array = []
	for unit: Dictionary in c.get("roster", []):
		if int(unit.get("hp", 0)) > 0:
			result.append(unit)
	return result

static func _find_living(c: Dictionary, unit_id: String) -> Dictionary:
	for unit: Dictionary in _living(c):
		if str(unit.id) == unit_id:
			return unit
	return {}

static func _has_kind(c: Dictionary, kind: String) -> bool:
	for unit: Dictionary in _living(c):
		if str(unit.kind) == kind:
			return true
	return false

static func _bind_hunter(c: Dictionary) -> void:
	var hunter_id: String = ""
	for unit: Dictionary in _living(c):
		if str(unit.kind) == "hunter":
			hunter_id = str(unit.id)
	for unit: Dictionary in c.roster:
		if str(unit.kind) == "dog":
			unit.hunter_id = hunter_id

static func _record_memorial(c: Dictionary, unit: Dictionary) -> void:
	for entry: Dictionary in c.flags.get("memorial", []):
		if str(entry.id) == str(unit.id):
			return
	c.flags.memorial.append({
		"id": str(unit.id), "name": str(unit.name), "kind": str(unit.kind),
		"perks": unit.get("perks", []).duplicate(), "day": int(c.day)
	})

static func _event_count(c: Dictionary, event_id: String) -> int:
	var count: int = 0
	for entry: Dictionary in c.get("history", []):
		if str(entry.get("type", "")) == "event" and str(entry.get("id", "")) == event_id:
			count += 1
	return count

static func _random_index(c: Dictionary, size: int) -> int:
	c.rng_state = (int(c.rng_state) * 48271) % 2147483647
	return int(c.rng_state) % maxi(size, 1)

static func _camp_ok(c: Dictionary, message: String) -> Dictionary:
	c.last_report = message
	return {"ok": true, "reason": message}

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "reason": message}
