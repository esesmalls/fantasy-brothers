extends RefCounted
# Pure, JSON-compatible rules. Presentation never changes these results.
const Appearance = preload("res://core/appearance_rules.gd")
const EquipmentData = preload("res://core/equipment_data.gd")
const Tactical = preload("res://core/tactical_data.gd")
const RULES_VERSION = Tactical.VERSION
const DIRECTIONS = [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]]
const FIRE_DAMAGE = 10

static func create_battle(roster: Array, seed: int, mission: Dictionary = {}) -> Dictionary:
	var s = {"schema": 1, "rules_version": str(mission.get("rules_version", RULES_VERSION)), "seed": seed, "rng_state": posmod(seed, 2147483646) + 1,
		"id": str(mission.get("id", "battle_" + str(seed))), "width": 9, "height": 7, "round": 1,
		"units": [], "cells": {}, "props": [], "order": [], "turn_index": 0, "outcome": "",
		"log": [], "action_log": [], "initial_roster": roster.duplicate(true), "supplies": {"oil": 2, "fire": 3, "water": 3}, "action_seq": 0, "mission": mission.duplicate(true)}
	for key in mission.get("supplies", {}):
		s.supplies[key] = int(mission.supplies[key])
	for q in range(9):
		for r in range(7):
			s.cells[_key(q, r)] = {"surface": "dry", "field": "", "expires": 0, "blocked": false}
	var starts = [[2, 2], [2, 3], [1, 3], [1, 4]]
	for raw in roster:
		if int(raw.get("hp", 1)) <= 0 or s.units.size() >= 4:
			continue
		var u = _unit(raw, "player")
		var p = starts[s.units.size()]
		u.q = p[0]
		u.r = p[1]
		s.units.append(u)
	var handlers: Dictionary = {}
	for u in s.units:
		if _has_capability(u, "beast_handler"):
			handlers[str(u.id)] = u
	for u in s.units:
		if u.kind == "dog":
			var owner_id := str(u.get("hunter_id", ""))
			if not handlers.has(owner_id):
				owner_id = ""
				for handler_id in handlers:
					if str(handlers[handler_id].get("beast_id", "")) == str(u.id):
						owner_id = str(handler_id)
						break
				if owner_id.is_empty():
					for handler_id in handlers:
						var already_used := false
						for other in s.units:
							if other != u and str(other.get("kind", "")) == "dog" and str(other.get("hunter_id", "")) == str(handler_id):
								already_used = true
						if not already_used:
							owner_id = str(handler_id)
							break
			u.hunter_id = owner_id
			u.command = "follow"
			u.command_target = ""
	var difficulty = clampi(int(mission.get("difficulty", 0)), 0, 2)
	var enemies = [[5, 2, "raider"], [6, 4, "raider"], [5, 5, "archer"]]
	if difficulty >= 2:
		enemies.append([7, 1, "raider"])
	for i in range(enemies.size()):
		var p = enemies[i]
		var e = _unit({"id": "enemy_" + str(i), "name": "劫掠者" if p[2] == "raider" else "劫匪弓手",
			"kind": p[2], "max_hp": 26 + difficulty * 5, "hp": 26 + difficulty * 5,
			"max_armor": 4 + difficulty * 3, "armor": 4 + difficulty * 3,
			"attack": 9 + difficulty * 2, "accuracy": 70 + difficulty * 3}, "enemy")
		e.q = p[0]
		e.r = p[1]
		s.units.append(e)
	s.cells[_key(4, 1)].surface = "oil"
	s.cells[_key(4, 5)].surface = "water"
	s.props = [
		{"id": "oil_jar", "kind": "oil", "q": 4, "r": 2, "hp": 6, "max_hp": 6, "blocks": true},
		{"id": "water_barrel", "kind": "water", "q": 3, "r": 4, "hp": 6, "max_hp": 6, "blocks": true},
		{"id": "wood_cover", "kind": "cover", "q": 4, "r": 3, "hp": 16, "max_hp": 16, "blocks": true},
		{"id": "grain", "kind": "grain", "q": 6, "r": 2, "hp": 14, "max_hp": 14, "blocks": true}]
	if _expanded(s):
		for u in s.units:
			Appearance.ensure_unit(u)
			if u.team == "enemy" and u.kind == "raider":
				u.visual_loadout = {"weapon": "weapon_skirmisher_axe", "armor": "armor_leather"}
			if not u.has("equipment_burden"):
				u.equipment_burden = EquipmentData.loadout_burden(u.visual_loadout)
			if not u.has("max_fatigue"):
				u.max_fatigue = maxi(30, 80 + int(u.max_hp) / 2 - int(u.equipment_burden))
		Tactical.initialize(s)
		_apply_deployment(s)
	for u in s.units:
		s.order.append(u.id)
	if _expanded(s):
		_sort_order(s)
	_check_outcome(s)
	return s

static func _unit(raw: Dictionary, team: String) -> Dictionary:
	var u = raw.duplicate(true)
	var kind = str(u.get("kind", "guard"))
	u.id = str(u.get("id", team + "_" + kind))
	u.name = str(u.get("name", kind))
	u.kind = kind
	u.weapon_style = str(u.get("weapon_style", _default_weapon_style(kind)))
	if not u.get("visual_loadout") is Dictionary:
		u.visual_loadout = _default_visual_loadout(kind, u.weapon_style)
	else:
		u.visual_loadout = u.visual_loadout.duplicate(true)
	u.team = team
	u.max_hp = int(u.get("max_hp", 28 if kind == "dog" else 38))
	u.hp = int(u.get("hp", u.max_hp))
	u.max_armor = int(u.get("max_armor", 4 if kind == "dog" else 14))
	u.armor = int(u.get("armor", u.max_armor))
	u.attack = int(u.get("attack", 10 if kind == "dog" else 14))
	u.accuracy = int(u.get("accuracy", 80))
	u.defense = int(u.get("defense", 0))
	u.melee_skill = int(u.get("melee_skill", u.accuracy))
	u.ranged_skill = int(u.get("ranged_skill", u.accuracy))
	u.level = int(u.get("level", 1))
	u.background_name = str(u.get("background_name", ""))
	if u.get("capability_tags") is Array:
		u.capability_tags = u.capability_tags.duplicate()
	else:
		u.capability_tags = ["beast_handler"] if kind == "hunter" else []
	u.range = int(u.get("range", _style_range(str(u.weapon_style))))
	u.max_ap = 6
	u.ap = 6
	u.statuses = {}
	u.perks = u.get("perks", []).duplicate()
	u.hazard_round = -1
	return u

static func active_unit(s: Dictionary) -> Dictionary:
	if s.outcome != "" or s.order.is_empty():
		return {}
	return _find_unit(s, str(s.order[int(s.turn_index)]))

static func get_actions(s: Dictionary, unit_id: String) -> Array:
	var u = _find_unit(s, unit_id)
	if u.is_empty() or not _available(s, u):
		return []
	var style := _weapon_style(u)
	var attack_name: String = str({"guard": "剑击", "spear": "长枪刺击", "archer": "射击", "hunter": "猎弓射击", "skirmisher": "短兵攻击"}.get(style, "攻击"))
	var actions = [
		_act("move", "移动", 2, 3, "每格2行动点；离开敌方控制区可能遭反击。", "cell"),
		_act("attack", attack_name, 3, int(u.range), "消耗破绽获得25命中。" if style == "spear" else "攻击敌人或破坏物件。", "enemy_or_prop"),
		_act("defend", "戒备", 2, 0, "至自身下回合开始，敌人命中率降低20。", "self")]
	if style == "guard":
		actions.append(_act("shield_bash", "盾击", 3, 1, "造成6伤害并制造破绽，长枪可利用。", "enemy"))
		actions.append(_act("push", "推开", 2, 1, "确定推动1格；不触发脱离反击，危险地表仍生效。", "enemy"))
	if _has_capability(u, "beast_handler"):
		actions.append(_act("mark", "猎物标记", 2, 4, "驯兽者对标记目标+15命中；羁绊战犬伤害提高。", "enemy"))
		actions.append(_act("command_follow", "战犬跟随", 1, 0, "战犬自身回合跟随主人，攻击邻近敌人。", "self"))
		actions.append(_act("command_pin", "战犬牵制", 1, 6, "指定敌人，战犬自身回合接近并攻击。", "enemy"))
		actions.append(_act("command_recall", "战犬撤回", 1, 0, "战犬自身回合撤向主人，停止攻击。", "self"))
	if u.kind != "dog":
		actions.append(_act("oil", "抛洒油瓶", 3, 3, "中心与相邻格铺油，消耗1油瓶。", "cell"))
		actions.append(_act("fire", "投掷火种", 3, 3, "直击6；点燃目标及相邻油格，水格产生蒸汽。", "cell"))
		actions.append(_act("water", "泼水", 3, 3, "中心与相邻格浇水；灭火形成遮挡远程的蒸汽。", "cell"))
	if _expanded(s):
		actions[0].description = "平地2、泥地/碎石3行动点；上坡+1。装备负担提高疲劳。"
		actions.append(_act("recover", "恢复", 3, 0, "恢复30疲劳；消耗3行动点。", "self"))
		actions.append(_act("flee", "撤离战场", 2, 0, "须从右侧边缘撤出才计契约目标；其他边撤出为放弃目标。" if _evacuation(s) else "在地图边缘撤离；不视为死亡，脱离近敌会遭反击。", "self"))
		if int(u.get("morale", 3)) == 0:
			return actions.filter(func(a): return a.id in ["move", "recover", "flee"])
		if u.kind != "dog":
			actions.append(_act("rally", "鼓舞", 3, 2, "友军士气提升一级，最高稳定；每目标每轮一次。", "ally"))
	return actions

static func _act(id: String, title: String, cost: int, reach: int, description: String, target: String) -> Dictionary:
	return {"id": id, "name": title, "cost": cost, "range": reach, "description": description, "target": target}

static func action_overlay(s: Dictionary, unit_id: String, action_id: String) -> Dictionary:
	# This is presentation data only. Target legality still comes exclusively from preview().
	var result = {"range_cells": [], "blocked_cells": [], "valid_targets": []}
	var u = _find_unit(s, unit_id)
	if u.is_empty() or not _available(s, u):
		return result
	var action = {}
	for candidate in get_actions(s, unit_id):
		if candidate.id == action_id:
			action = candidate
			break
	if action.is_empty() or action_id == "move" or action.target == "self":
		return result
	var reach = int(action.range)
	for q in range(int(s.width)):
		for r in range(int(s.height)):
			var dist = _distance(int(u.q), int(u.r), q, r)
			if dist > reach or (dist == 0 and action.target not in ["cell", "ally"]):
				continue
			var cell = {"q": q, "r": r}
			if not _action_line_clear(s, u, action_id, q, r, dist):
				result.blocked_cells.append(cell)
				continue
			result.range_cells.append(cell)
			if preview(s, unit_id, action_id, cell).ok:
				result.valid_targets.append(cell)
	return result

static func preview(s: Dictionary, unit_id: String, action_id: String, target: Dictionary) -> Dictionary:
	# apply_action consumes this same validated, calculated plan.
	var p = {"ok": false, "reason": "", "summary": "", "chance": 100, "damage": 0, "cost": 0, "path": [], "affected": []}
	var u = _find_unit(s, unit_id)
	if s.outcome != "" or u.is_empty() or not _available(s, u):
		return _invalid(p, "战斗已结束或单位不可行动。")
	if active_unit(s).get("id", "") != unit_id:
		return _invalid(p, "尚未轮到该单位。")
	var action = {}
	for a in get_actions(s, unit_id):
		if a.id == action_id:
			action = a
			break
	if action.is_empty():
		return _invalid(p, "该单位没有此技能。")
	var q = int(target.get("q", u.q))
	var r = int(target.get("r", u.r))
	if action.target == "self":
		q = int(u.q)
		r = int(u.r)
	if not _inside(s, q, r):
		return _invalid(p, "目标在战场外。")
	p.q = q
	p.r = r
	p.cost = int(action.cost)
	p.affected = [{"q": q, "r": r}]
	var dist = _distance(int(u.q), int(u.r), q, r)
	var victim = _at(s, q, r)
	var prop = _prop_at(s, q, r)
	if action_id == "move":
		if dist == 0:
			return _invalid(p, "已在此格。")
		p.path = _path(s, u, q, r, int(u.ap) if _expanded(s) else int(u.ap) / 2)
		if p.path.is_empty():
			return _invalid(p, "无法到达：行动点不足、被占用或有障碍。")
		p.cost = _route_cost(s, u, p.path) if _expanded(s) else p.path.size() * 2
		p.summary = "移动%d格，消耗%d行动点。" % [p.path.size(), p.cost]
		var pq = int(u.q)
		var pr = int(u.r)
		for step in p.path:
			if not _disengagers(s, u, pq, pr, int(step.q), int(step.r)).is_empty():
				p.summary += " 警告：脱离控制区可能遭反击。"
				break
			pq = int(step.q)
			pr = int(step.r)
		for step in p.path:
			if s.cells[_key(int(step.q), int(step.r))].field == "fire":
				p.summary += " 路经火区：每轮至多受到%d点生命伤害。" % _fire_amount(u)
				break
	elif action_id == "rally":
		if victim.is_empty() or victim.team != u.team or dist > 2:
			return _invalid(p, "鼓舞需要两格内可行动的友军。")
		if int(victim.get("morale", 3)) >= 3 or int(victim.get("rallied_round", -1)) == int(s.round):
			return _invalid(p, "目标已稳定或本轮已受鼓舞。")
		p.target_id = victim.id
		p.summary = "士气提升一级（最高稳定）；每目标每轮一次。"
	elif action_id == "flee":
		if not _edge(s, u):
			return _invalid(p, "须先移动至地图边缘。")
		p.summary = "撤离战场；相邻敌人各可反击一次，撤出者不会计为死亡。"
		if _evacuation(s) and u.team == "player":
			p.summary += " 从右侧成功撤出将推进目标。" if int(u.q) == int(s.width) - 1 else " 此边不计目标，可能导致契约失败。"
	elif action_id == "recover":
		if int(u.get("fatigue", 0)) == 0:
			return _invalid(p, "无需恢复疲劳。")
		p.summary = "恢复%d疲劳。" % mini(Tactical.RECOVER_AMOUNT, int(u.fatigue))
	elif action_id in ["attack", "shield_bash", "push", "mark", "command_pin"]:
		if dist > int(action.range) or dist == 0:
			return _invalid(p, "目标超出距离。")
		if victim.is_empty() and (action_id != "attack" or prop.is_empty()):
			return _invalid(p, "请选择敌人。")
		if not victim.is_empty() and victim.team == u.team:
			return _invalid(p, "不能攻击友军。")
		if not _action_line_clear(s, u, action_id, q, r, dist):
			return _invalid(p, "掩体或蒸汽遮挡视线。")
		if action_id.begins_with("command") and _dog_for(s, unit_id).is_empty():
			return _invalid(p, "没有存活且可接受指令的战犬。")
		p.target_id = victim.get("id", prop.get("id", ""))
		p.is_prop = victim.is_empty()
		if action_id == "push":
			var destination = _push_destination(u, victim)
			if not _walkable(s, int(destination.q), int(destination.r)):
				return _invalid(p, "推动方向被占用或到达边界。")
			p.destination = destination
			p.affected.append(destination)
			p.summary = "推动1格，不触发脱离反击；目的地火区仍造成伤害。"
		elif action_id == "mark":
			p.summary = "标记目标至第%d轮末；猎人对其+15命中。" % (int(s.round) + 1)
		elif action_id == "command_pin":
			p.summary = "战犬在自身回合牵制此目标；不刷新战犬行动点。"
		else:
			p.chance = _hit_chance(s, u, victim, action_id) if not victim.is_empty() else 100
			p.damage = _attack_damage(s, u, victim, action_id)
			p.consume_exposed = action_id == "attack" and _weapon_style(u) == "spear" and not victim.is_empty() and victim.statuses.has("exposed")
			p.summary = "命中%d%%；命中时%d伤害（护甲先吸收）。" % [p.chance, p.damage]
			if p.consume_exposed:
				p.summary += " 消耗破绽+25命中，未命中也消耗。"
			if action_id == "shield_bash":
				p.summary += " 命中施加破绽。"
			if not prop.is_empty():
				p.summary += " 破坏油罐铺油、水桶浇水、木掩体打开道路；粮食损毁影响结算。"
	elif action_id in ["oil", "fire", "water"]:
		if dist > int(action.range):
			return _invalid(p, "超出投掷距离。")
		if int(s.supplies.get(action_id, 0)) <= 0:
			return _invalid(p, "此类补给已用尽。")
		if not _action_line_clear(s, u, action_id, q, r, dist):
			return _invalid(p, "掩体或蒸汽挡住投掷路线。")
		p.affected = _area(s, q, r)
		p.damage = 6 if action_id == "fire" else 0
		p.summary = action.description + " 波及敌我，区域期限为第%d轮末。" % (int(s.round) + 1)
		if action_id == "fire":
			p.summary += " 火区接触每单位每轮至多10生命伤害，忽略护甲。"
	elif action_id.begins_with("command"):
		if _dog_for(s, unit_id).is_empty():
			return _invalid(p, "没有存活且可接受指令的战犬。")
		p.summary = action.description
	else:
		p.summary = action.description
	if int(u.ap) < int(p.cost):
		return _invalid(p, "行动点不足。")
	if _expanded(s):
		p.fatigue_cost = _plan_fatigue(s, u, action_id, p)
		if int(u.fatigue) + int(p.fatigue_cost) > int(u.max_fatigue):
			return _invalid(p, "疲劳容量不足；可先恢复或等待下回合。")
		p.summary += " 疲劳+%d（当前%d/%d）。" % [p.fatigue_cost, u.fatigue, u.max_fatigue]
	p.ok = true
	return p

static func _invalid(p: Dictionary, reason: String) -> Dictionary:
	p.reason = reason
	p.summary = reason
	return p

static func apply_action(s: Dictionary, unit_id: String, action_id: String, target: Dictionary) -> Dictionary:
	var p = preview(s, unit_id, action_id, target)
	if not p.ok:
		return {"ok": false, "reason": p.reason, "events": []}
	var events: Array = []
	var u = _find_unit(s, unit_id)
	_record_action(s, unit_id, action_id, target)
	var root_id = int(s.action_seq)
	if action_id == "move":
		var reacted = {}
		for step in p.path:
			if int(u.hp) <= 0:
				break
			u.ap = int(u.ap) - (Tactical.step_cost(s, int(u.q), int(u.r), int(step.q), int(step.r)) if _expanded(s) else 2)
			if _expanded(s):
				u.fatigue += Tactical.step_fatigue(s, u, int(u.q), int(u.r), int(step.q), int(step.r))
			for enemy in _disengagers(s, u, int(u.q), int(u.r), int(step.q), int(step.r)):
				if reacted.has(enemy.id):
					continue
				reacted[enemy.id] = true
				_strike(s, enemy, u, _hit_chance(s, enemy, u, "attack"), int(enemy.attack), "反击", events)
				if int(u.hp) <= 0:
					break
			if int(u.hp) <= 0:
				break
			_move_unit(s, u, int(step.q), int(step.r), events)
			# Fire can kill after entering a path tile. Never continue moving or
			# charging AP once the mover is dead.
			if int(u.hp) <= 0:
				break
	else:
		u.ap = int(u.ap) - int(p.cost)
		if _expanded(s):
			u.fatigue += int(p.fatigue_cost)
		var victim = _find_unit(s, str(p.get("target_id", "")))
		if action_id in ["attack", "shield_bash"]:
			if p.get("consume_exposed", false):
				victim.statuses.erase("exposed")
			if p.get("is_prop", false):
				var prop = _find_prop(s, str(p.target_id))
				_damage_prop(s, prop, int(p.damage), unit_id, events)
			else:
				var hit = _strike(s, u, victim, int(p.chance), int(p.damage), "盾击" if action_id == "shield_bash" else "攻击", events)
				if hit and action_id == "shield_bash" and int(victim.hp) > 0:
					victim.statuses.exposed = {"expires": int(s.round) + 1, "source": unit_id, "root_action": root_id}
					_emit(s, events, "status", unit_id, victim.id, int(victim.q), int(victim.r), victim.name + "露出破绽", 0)
		elif action_id == "push":
			_move_unit(s, victim, int(p.destination.q), int(p.destination.r), events)
			_emit(s, events, "status", unit_id, victim.id, int(victim.q), int(victim.r), "推开：强制位移不触发反击", 0)
		elif action_id == "mark":
			victim.statuses.marked = {"expires": int(s.round) + 1, "source": unit_id, "root_action": root_id}
			_emit(s, events, "status", unit_id, victim.id, int(victim.q), int(victim.r), "猎物已标记", 0)
		elif action_id == "recover":
			u.fatigue = maxi(0, int(u.fatigue) - Tactical.RECOVER_AMOUNT)
			_emit(s, events, "status", unit_id, unit_id, int(u.q), int(u.r), u.name + "调整呼吸", 0)
		elif action_id == "rally":
			victim.morale = mini(3, int(victim.morale) + 1)
			victim.rallied_round = int(s.round)
			_emit(s, events, "morale", unit_id, victim.id, int(victim.q), int(victim.r), victim.name + "受到鼓舞", 1)
		elif action_id == "flee":
			for enemy in s.units:
				if _available(s, enemy) and enemy.team != u.team and int(enemy.range) <= 2 and int(enemy.get("morale", 3)) > 0 and _distance(int(u.q), int(u.r), int(enemy.q), int(enemy.r)) == 1 and int(u.hp) > 0:
					_strike(s, enemy, u, _hit_chance(s, enemy, u, "attack"), int(enemy.attack), "撤离反击", events)
			if int(u.hp) > 0:
				u.escaped = true
				if _evacuation(s) and u.team == "player" and int(u.q) == int(s.width) - 1 and str(u.id) in s.objective.participant_ids and str(u.id) not in s.objective.evacuated_ids:
					s.objective.evacuated_ids.append(str(u.id))
					_emit(s, events, "objective", unit_id, unit_id, int(u.q), int(u.r), "右侧撤离进度：%d/%d" % [s.objective.evacuated_ids.size(), int(s.objective.required_count)], 1)
				_emit(s, events, "escape", unit_id, unit_id, int(u.q), int(u.r), u.name + "撤出战场", 0)
		elif action_id == "defend":
			u.statuses.defending = {"source": unit_id}
			_emit(s, events, "status", unit_id, unit_id, int(u.q), int(u.r), u.name + "进入戒备", 0)
		elif action_id.begins_with("command"):
			var dog = _dog_for(s, unit_id)
			dog.command = action_id.trim_prefix("command_")
			dog.command_target = str(p.get("target_id", ""))
			_emit(s, events, "status", unit_id, dog.id, int(dog.q), int(dog.r), "战犬指令已更新，下个自身回合执行", 0)
		elif action_id in ["oil", "fire", "water"]:
			s.supplies[action_id] = int(s.supplies[action_id]) - 1
			if action_id == "fire":
				var direct = _at(s, int(p.q), int(p.r))
				if not direct.is_empty():
					_damage_unit(s, direct, 6, unit_id, false, events)
				var prop = _prop_at(s, int(p.q), int(p.r))
				if not prop.is_empty():
					_damage_prop(s, prop, 6, unit_id, events)
			for tile in p.affected:
				_apply_surface(s, int(tile.q), int(tile.r), action_id, events)
	_check_outcome(s)
	if s.outcome == "" and not _available(s, u):
		# A mover can die to a reaction before entering the next tile or to fire
		# after entering it. Advance through any further turn-start deaths now so
		# no dead unit remains the active actor, and keep all events in this action.
		events.append_array(end_turn(s))
	elif s.outcome != "":
		_emit(s, events, "status", "", "", -1, -1, "敌人被击退。" if s.outcome == "victory" else "佣兵团失去战斗能力。", 0)
	return {"ok": true, "reason": "", "events": events}

static func _strike(s: Dictionary, attacker: Dictionary, victim: Dictionary, chance: int, damage: int, label: String, events: Array) -> bool:
	_emit(s, events, "attack", attacker.id, victim.id, int(victim.q), int(victim.r), attacker.name + label, 0)
	var roll := _random(s, 100)
	var hit = roll < chance
	if hit:
		_damage_unit(s, victim, damage, attacker.id, false, events)
	else:
		_emit(s, events, "miss", attacker.id, victim.id, int(victim.q), int(victim.r), "未命中", 0)
		if _expanded(s) and victim.statuses.has("defending") and _weapon_style(victim) == "guard":
			var unguarded := victim.duplicate(true)
			unguarded.statuses.erase("defending")
			var undefended_chance := _hit_chance(s, attacker, unguarded, "shield_bash" if label == "盾击" else "attack")
			if roll < undefended_chance:
				events.back().outcome = "block"
				events.back().text = "盾牌格挡"
	return hit

static func _damage_unit(s: Dictionary, u: Dictionary, amount: int, actor: String, bypass: bool, events: Array) -> void:
	if int(u.hp) <= 0:
		return
	var absorbed = 0 if bypass else mini(int(u.armor), amount)
	u.armor = int(u.armor) - absorbed
	var loss = amount - absorbed
	u.hp = maxi(0, int(u.hp) - loss)
	_emit(s, events, "hit", actor, u.id, int(u.q), int(u.r), "%s：护甲-%d，生命-%d" % [u.name, absorbed, loss], amount)
	if _expanded(s):
		events.back().armor_damage = absorbed
		events.back().hp_damage = loss
		if int(u.hp) == 0:
			_incapacitate(s, u, actor, events)
		elif loss >= maxi(1, ceili(float(u.max_hp) * 0.25)):
			_morale_check(s, u, -1, "heavy_hit", events)
	elif int(u.hp) == 0:
		_emit(s, events, "death", actor, u.id, int(u.q), int(u.r), u.name + "倒下", 0)

static func _damage_prop(s: Dictionary, p: Dictionary, amount: int, actor: String, events: Array) -> void:
	if p.is_empty() or int(p.hp) <= 0:
		return
	p.hp = maxi(0, int(p.hp) - amount)
	_emit(s, events, "hit", actor, p.id, int(p.q), int(p.r), "物件受损", amount)
	if int(p.hp) > 0:
		return
	p.blocks = false
	_emit(s, events, "status", actor, p.id, int(p.q), int(p.r), "物件已破坏：" + str(p.kind), 0)
	if p.kind in ["oil", "water"]:
		for tile in _area(s, int(p.q), int(p.r)):
			_apply_surface(s, int(tile.q), int(tile.r), str(p.kind), events)

static func _apply_surface(s: Dictionary, q: int, r: int, element: String, events: Array) -> void:
	var cell = s.cells[_key(q, r)]
	if cell.blocked:
		return
	if element == "oil":
		if cell.field == "fire":
			cell.surface = "dry"
			_emit(s, events, "status", "", "", q, r, "油被火区消耗", 0)
		else:
			cell.surface = "oil"
			_emit(s, events, "status", "", "", q, r, "油地表", 0)
	elif element == "water":
		cell.surface = "water"
		if cell.field in ["fire", "steam"]:
			cell.field = "steam"
			cell.expires = maxi(int(cell.expires), int(s.round) + 1)
		_emit(s, events, "water", "", "", q, r, "蒸汽遮蔽" if cell.field == "steam" else "水地表", 0)
	elif element == "fire":
		if cell.surface == "water":
			cell.field = "steam"
			cell.expires = maxi(int(cell.expires), int(s.round) + 1)
		elif cell.surface == "oil" or cell.field == "fire":
			cell.surface = "dry"
			cell.field = "fire"
			cell.expires = maxi(int(cell.expires), int(s.round) + 1)
		_emit(s, events, "fire", "", "", q, r, "火区" if cell.field == "fire" else ("蒸汽" if cell.field == "steam" else "火星"), 0)
		if cell.field == "fire":
			var u = _at(s, q, r)
			if not u.is_empty():
				_hazard(s, u, events)
			var p = _prop_at(s, q, r)
			if not p.is_empty() and int(p.get("hazard_round", -1)) != int(s.round):
				p.hazard_round = int(s.round)
				_damage_prop(s, p, FIRE_DAMAGE, "", events)

static func _fire_amount(u: Dictionary) -> int:
	return FIRE_DAMAGE / 2 if u.perks.has("firewise") else FIRE_DAMAGE

static func _hazard(s: Dictionary, u: Dictionary, events: Array) -> void:
	if int(u.hp) <= 0:
		return
	var c = s.cells[_key(int(u.q), int(u.r))]
	if c.field == "fire" and int(u.get("hazard_round", -1)) != int(s.round):
		u.hazard_round = int(s.round)
		_damage_unit(s, u, _fire_amount(u), "", true, events)

static func _move_unit(s: Dictionary, u: Dictionary, q: int, r: int, events: Array) -> void:
	var old_q = int(u.q)
	var old_r = int(u.r)
	u.q = q
	u.r = r
	_emit(s, events, "move", u.id, "", q, r, u.name + "移动", 0)
	events.back().from_q = old_q
	events.back().from_r = old_r
	_hazard(s, u, events)

static func end_turn(s: Dictionary) -> Array:
	var events: Array = []
	if s.outcome != "":
		return events
	var current = active_unit(s)
	_record_action(s, str(current.get("id", "")), "end_turn", {})
	if not current.is_empty() and int(current.hp) > 0:
		current.ap = 0
	for _attempt in range(s.order.size() * 3 + 1):
		s.turn_index = int(s.turn_index) + 1
		if int(s.turn_index) >= s.order.size():
			_end_round(s, events)
			s.turn_index = 0
		_check_outcome(s)
		if s.outcome != "":
			break
		var u = _find_unit(s, str(s.order[int(s.turn_index)]))
		if not u.is_empty() and _available(s, u):
			u.ap = 6
			if _expanded(s):
				_start_tactical_turn(s, u, events)
			u.statuses.erase("defending")
			_hazard(s, u, events)
			_check_outcome(s)
			if int(u.hp) > 0 or s.outcome != "":
				break
	if s.outcome != "":
		_emit(s, events, "status", "", "", -1, -1, "敌人被击退。" if s.outcome == "victory" else "佣兵团失去战斗能力。", 0)
	return events

static func _end_round(s: Dictionary, events: Array) -> void:
	for c in s.cells.values():
		if c.field != "" and int(c.expires) <= int(s.round):
			c.field = ""
			c.expires = 0
	for u in s.units:
		for status in u.statuses.keys():
			if u.statuses[status].has("expires") and int(u.statuses[status].expires) <= int(s.round):
				u.statuses.erase(status)
	if _expanded(s):
		_sort_order(s)
	s.round = int(s.round) + 1
	_emit(s, events, "round", "", "", -1, -1, "第%d轮" % int(s.round), 0)
	# Objects also take fire damage once per global round.
	for prop in s.props:
		if int(prop.hp) > 0 and s.cells[_key(int(prop.q), int(prop.r))].field == "fire":
			if int(prop.get("hazard_round", -1)) != int(s.round):
				prop.hazard_round = int(s.round)
				_damage_prop(s, prop, FIRE_DAMAGE, "", events)

static func ai_step(s: Dictionary) -> Dictionary:
	var u = active_unit(s)
	if u.is_empty():
		return {"ok": false, "reason": "战斗已结束", "events": []}
	if _expanded(s) and int(u.get("morale", 3)) == 0:
		return _flee_ai(s, u)
	if u.team == "player" and u.kind != "dog":
		return {"ok": false, "reason": "等待玩家", "events": []}
	if _expanded(s) and int(u.get("fatigue", 0)) >= int(u.get("max_fatigue", 100)) - 20 and preview(s, u.id, "recover", {}).ok:
		return apply_action(s, u.id, "recover", {})
	var enemies: Array = []
	for candidate in s.units:
		if _available(s, candidate) and candidate.team != u.team:
			enemies.append(candidate)
	if _evacuation(s) and u.team == "player" and u.kind == "dog":
		var owner = _find_unit(s, str(u.get("hunter_id", "")))
		if enemies.is_empty() or owner.is_empty() or not _available(s, owner):
			return _evacuation_ai(s, u)
	var command = str(u.get("command", "pin"))
	var hunter = _find_unit(s, str(u.get("hunter_id", "")))
	var anchor = {}
	if u.kind == "dog" and command in ["follow", "recall"] and not hunter.is_empty() and _available(s, hunter):
		anchor = hunter
	var commanded_target = {}
	if u.kind == "dog" and command == "pin":
		var requested = _find_unit(s, str(u.get("command_target", "")))
		if not requested.is_empty() and _available(s, requested) and requested.team != u.team:
			commanded_target = requested
	# Recall always suppresses attacks. Pin focuses the living ordered target instead of
	# opportunistically switching to a lower-health enemy.
	if not enemies.is_empty() and not (u.kind == "dog" and command == "recall"):
		var best_attack = {}
		var best_score = -100000.0
		for enemy in enemies:
			if u.kind == "dog" and command == "follow" and _distance(int(u.q), int(u.r), int(enemy.q), int(enemy.r)) > 1:
				continue
			if not commanded_target.is_empty() and enemy.id != commanded_target.id:
				continue
			var p = preview(s, u.id, "attack", {"q": enemy.q, "r": enemy.r})
			if p.ok:
				var score = float(p.chance) * float(p.damage) / 100.0 + (10.0 if int(enemy.hp) <= int(p.damage) else 0.0)
				if enemy.id == u.get("command_target", ""):
					score += 8.0
				if score > best_score:
					best_score = score
					best_attack = {"q": enemy.q, "r": enemy.r}
		if not best_attack.is_empty():
			return apply_action(s, u.id, "attack", best_attack)
	if int(u.ap) >= 2:
		var target = anchor
		if target.is_empty() and not commanded_target.is_empty():
			target = commanded_target
		if target.is_empty() and not (u.kind == "dog" and command == "recall"):
			var nearest = 10000
			for enemy in enemies:
				var distance = _distance(int(u.q), int(u.r), int(enemy.q), int(enemy.r))
				if enemy.id == u.get("command_target", ""):
					target = enemy
					break
				if distance < nearest:
					nearest = distance
					target = enemy
		if not target.is_empty():
			var old_distance = _distance(int(u.q), int(u.r), int(target.q), int(target.r))
			if not anchor.is_empty() and old_distance <= 1:
				return {"ok": true, "reason": "", "events": end_turn(s)}
			var chosen = {}
			var old_hazard = 12.0 if s.cells[_key(int(u.q), int(u.r))].field == "fire" else 0.0
			var score_best = -float(old_distance) * 3.0 - old_hazard
			for direction in DIRECTIONS:
				var q = int(u.q) + int(direction[0])
				var r = int(u.r) + int(direction[1])
				var p = preview(s, u.id, "move", {"q": q, "r": r})
				if not p.ok:
					continue
				var score = -float(_distance(q, r, int(target.q), int(target.r))) * 3.0
				if s.cells[_key(q, r)].field == "fire":
					score -= 12.0
				if _expanded(s):
					score -= (int(p.cost) - 2) * 1.5 + int(p.fatigue_cost) * 0.08
				score -= _disengagers(s, u, int(u.q), int(u.r), q, r).size() * 7.0
				if score > score_best:
					score_best = score
					chosen = {"q": q, "r": r}
			# A target can be nominally in range while a cover object or steam
			# blocks the attack line. Search a route around the obstacle even
			# when distance alone would not have triggered the old detour.
			if chosen.is_empty():
				chosen = _detour_step(s, u, target)
			if not chosen.is_empty():
				return apply_action(s, u.id, "move", chosen)
	if _expanded(s) and int(u.get("morale", 3)) < 3 and preview(s, u.id, "rally", {"q": u.q, "r": u.r}).ok:
		return apply_action(s, u.id, "rally", {"q": u.q, "r": u.r})
	if _expanded(s) and int(u.get("fatigue", 0)) >= 20 and preview(s, u.id, "recover", {}).ok:
		return apply_action(s, u.id, "recover", {})
	if int(u.ap) >= 2 and not u.statuses.has("defending") and preview(s, u.id, "defend", {}).ok:
		return apply_action(s, u.id, "defend", {})
	return {"ok": true, "reason": "", "events": end_turn(s)}

static func retreat(s: Dictionary) -> void:
	if s.outcome == "":
		s.outcome = "retreat"
		_record_action(s, "", "retreat", {})
		finalize_casualties(s)
		s.log.append("撤退：幸存者与已发生损失进入结算。")
		while s.log.size() > 80:
			s.log.pop_front()

static func _detour_step(s: Dictionary, u: Dictionary, target: Dictionary) -> Dictionary:
	var best = {}
	var best_cost = 100000.0
	for d in DIRECTIONS:
		var q = int(target.q) + int(d[0])
		var r = int(target.r) + int(d[1])
		var route = _path(s, u, q, r, 63)
		if route.is_empty():
			continue
		var cost = float(_route_cost(s, u, route)) if _expanded(s) else float(route.size()) * 2.0
		var previous_q = int(u.q)
		var previous_r = int(u.r)
		for tile in route:
			if s.cells[_key(int(tile.q), int(tile.r))].field == "fire":
				cost += 20.0
			cost += _disengagers(s, u, previous_q, previous_r, int(tile.q), int(tile.r)).size() * 7.0
			previous_q = int(tile.q)
			previous_r = int(tile.r)
		if cost < best_cost:
			var landing = _first_route_landing(s, u, route)
			if not landing.is_empty():
				best_cost = cost
				best = landing
	return best

static func _first_route_landing(s: Dictionary, u: Dictionary, route: Array) -> Dictionary:
	# An AI unit may cross one or more allies in one action, but it must end on
	# the first empty tile that fits its remaining AP.
	if _expanded(s):
		for tile in route:
			if _walkable(s, int(tile.q), int(tile.r)):
				return tile if preview(s, u.id, "move", tile).ok else {}
		return {}
	var steps = mini(route.size(), int(u.ap) / 2)
	for i in range(steps):
		var tile = route[i]
		if _walkable(s, int(tile.q), int(tile.r)):
			return tile
	return {}

static func _record_action(s: Dictionary, actor: String, action: String, target: Dictionary) -> void:
	s.action_seq = int(s.action_seq) + 1
	if not s.has("action_log"):
		s.action_log = []
	s.action_log.append({"id": int(s.action_seq), "round": int(s.round), "actor": actor,
		"action": action, "target": target.duplicate(true), "rng_before": int(s.rng_state)})
	if _expanded(s):
		s.action_log.back().casualty_rng_before = int(s.casualty_rng_state)
		s.action_log.back().rules_version = str(s.rules_version)

static func _hit_chance(s: Dictionary, u: Dictionary, v: Dictionary, action: String) -> int:
	var chance = int(u.accuracy) - int(v.get("defense", 0))
	if v.statuses.has("defending"):
		chance -= 20
	if action == "attack" and _weapon_style(u) == "spear" and v.statuses.has("exposed"):
		chance += 25
	if _has_capability(u, "beast_handler") and v.statuses.has("marked"):
		chance += 15
	if _expanded(s):
		var height = _elevation(s, int(u.q), int(u.r)) - _elevation(s, int(v.q), int(v.r))
		if int(u.range) > 2:
			chance += Tactical.HIGH_RANGED_HIT if height > 0 else 0
		else:
			chance += height * Tactical.HIGH_MELEE_HIT
		chance += int(Tactical.MORALE_HIT[clampi(int(u.get("morale", 3)), 0, 4)])
	return clampi(chance, 5, 95)

static func _attack_damage(s: Dictionary, u: Dictionary, v: Dictionary, action: String) -> int:
	var damage = 6 if action == "shield_bash" else int(u.attack)
	if u.perks.has("breacher"):
		if action == "shield_bash":
			damage += 4
		elif _weapon_style(u) == "spear" and not v.is_empty() and v.statuses.has("exposed"):
			damage += 6
	if u.kind == "dog" and not v.is_empty() and v.statuses.has("marked"):
		var hunter = _find_unit(s, str(u.get("hunter_id", "")))
		if u.perks.has("packbond") or (not hunter.is_empty() and hunter.perks.has("packbond")):
			damage += 6
	return damage

static func _path(s: Dictionary, u: Dictionary, q: int, r: int, budget: int) -> Array:
	if _expanded(s):
		return _weighted_path(s, u, q, r, budget)
	# Landing requires an empty cell. Traversal additionally permits living
	# allies (including dogs), while enemies and props remain hard blockers.
	if not _walkable(s, q, r):
		return []
	var start = _key(int(u.q), int(u.r))
	var frontier = [{"q": int(u.q), "r": int(u.r)}]
	var came = {start: ""}
	var costs = {start: 0}
	while not frontier.is_empty():
		var here = frontier.pop_front()
		var hkey = _key(int(here.q), int(here.r))
		if int(costs[hkey]) >= budget:
			continue
		for d in DIRECTIONS:
			var nq = int(here.q) + int(d[0])
			var nr = int(here.r) + int(d[1])
			var nk = _key(nq, nr)
			if came.has(nk) or not _traversable(s, u, nq, nr):
				continue
			came[nk] = hkey
			costs[nk] = int(costs[hkey]) + 1
			if nq == q and nr == r:
				var result: Array = []
				var cursor = nk
				while cursor != start:
					var bits = cursor.split(",")
					result.push_front({"q": int(bits[0]), "r": int(bits[1])})
					cursor = came[cursor]
				return result
			frontier.append({"q": nq, "r": nr})
	return []

static func _action_line_clear(s: Dictionary, u: Dictionary, action_id: String, q: int, r: int, dist: int) -> bool:
	if action_id in ["attack", "shield_bash", "push", "mark", "command_pin"]:
		if dist <= 1 and int(u.range) <= 2:
			return true
		return _line_clear(s, int(u.q), int(u.r), q, r, int(u.range) > 2 or action_id == "mark")
	if action_id in ["oil", "fire", "water"]:
		return dist <= 1 or _line_clear(s, int(u.q), int(u.r), q, r, true)
	return true

static func _line_clear(s: Dictionary, aq: int, ar: int, bq: int, br: int, ranged: bool) -> bool:
	var distance = _distance(aq, ar, bq, br)
	for i in range(distance + 1):
		var t = float(i) / maxi(1, distance)
		var pos = _hex_round(lerpf(float(aq), float(bq), t), lerpf(float(ar), float(br), t))
		var c = s.cells.get(_key(int(pos.q), int(pos.r)), {})
		if ranged and c.get("field", "") == "steam":
			return false
		if i > 0 and i < distance and not c.is_empty():
			if _expanded(s):
				var ray_height = lerpf(float(_elevation(s, aq, ar)), float(_elevation(s, bq, br)), t) + 0.5
				if float(c.get("elevation", 0)) > ray_height:
					return false
			if c.blocked or not _prop_at(s, int(pos.q), int(pos.r)).is_empty():
				return false
	return true

static func _hex_round(q: float, r: float) -> Dictionary:
	var x = roundi(q)
	var z = roundi(r)
	var y = roundi(-q - r)
	var dx = absf(float(x) - q)
	var dz = absf(float(z) - r)
	var dy = absf(float(y) + q + r)
	if dx > dy and dx > dz:
		x = -y - z
	elif dz > dy:
		z = -x - y
	return {"q": x, "r": z}

static func _push_destination(u: Dictionary, v: Dictionary) -> Dictionary:
	return {"q": int(v.q) + int(v.q) - int(u.q), "r": int(v.r) + int(v.r) - int(u.r)}

static func _disengagers(s: Dictionary, u: Dictionary, aq: int, ar: int, bq: int, br: int) -> Array:
	var result: Array = []
	for enemy in s.units:
		if _available(s, enemy) and enemy.team != u.team and int(enemy.range) <= 2 and (not _expanded(s) or int(enemy.get("morale", 3)) > 0):
			if _distance(aq, ar, int(enemy.q), int(enemy.r)) == 1 and _distance(bq, br, int(enemy.q), int(enemy.r)) > 1:
				result.append(enemy)
	return result

static func _walkable(s: Dictionary, q: int, r: int) -> bool:
	if not _inside(s, q, r) or s.cells[_key(q, r)].blocked:
		return false
	return _at(s, q, r).is_empty() and _prop_at(s, q, r).is_empty()

static func _traversable(s: Dictionary, u: Dictionary, q: int, r: int) -> bool:
	if not _inside(s, q, r) or s.cells[_key(q, r)].blocked or not _prop_at(s, q, r).is_empty():
		return false
	var occupant = _at(s, q, r)
	return occupant.is_empty() or occupant.team == u.team

static func _inside(s: Dictionary, q: int, r: int) -> bool:
	return q >= 0 and r >= 0 and q < int(s.width) and r < int(s.height)

static func _at(s: Dictionary, q: int, r: int) -> Dictionary:
	for u in s.units:
		if _available(s, u) and int(u.q) == q and int(u.r) == r:
			return u
	return {}

static func _prop_at(s: Dictionary, q: int, r: int) -> Dictionary:
	for p in s.props:
		if int(p.hp) > 0 and int(p.q) == q and int(p.r) == r:
			return p
	return {}

static func _find_unit(s: Dictionary, id: String) -> Dictionary:
	for u in s.units:
		if u.id == id:
			return u
	return {}

static func _find_prop(s: Dictionary, id: String) -> Dictionary:
	for p in s.props:
		if p.id == id:
			return p
	return {}

static func _dog_for(s: Dictionary, id: String) -> Dictionary:
	for u in s.units:
		if u.kind == "dog" and _available(s, u) and u.get("hunter_id", "") == id:
			return u
	return {}

static func _has_capability(unit: Dictionary, capability_id: String) -> bool:
	# Old battle snapshots intentionally lack capability metadata and retain the
	# 0.1.4 hunter fallback until that already-started battle ends.
	if unit.get("capability_tags") is Array:
		return capability_id in unit.capability_tags
	return capability_id == "beast_handler" and str(unit.get("kind", "")) == "hunter"

static func _area(s: Dictionary, q: int, r: int) -> Array:
	var area = [{"q": q, "r": r}]
	for d in DIRECTIONS:
		var nq = q + int(d[0])
		var nr = r + int(d[1])
		if _inside(s, nq, nr):
			area.append({"q": nq, "r": nr})
	return area

static func _distance(aq: int, ar: int, bq: int, br: int) -> int:
	return maxi(absi(aq - bq), maxi(absi(ar - br), absi(aq + ar - bq - br)))

static func _key(q: int, r: int) -> String:
	return str(q) + "," + str(r)

static func _weapon_style(u: Dictionary) -> String:
	# Saved 0.1.3 battles intentionally remain untouched and use their original
	# kind as the weapon fallback for the rest of that in-progress battle.
	return str(u.get("weapon_style", _default_weapon_style(str(u.get("kind", "")))))

static func _default_weapon_style(kind: String) -> String:
	if kind == "raider":
		return "skirmisher"
	if kind == "dog":
		return ""
	return kind

static func _style_range(style: String) -> int:
	return int({"guard": 1, "spear": 2, "archer": 4, "skirmisher": 1, "hunter": 3}.get(style, 1))

static func _default_visual_loadout(kind: String, style: String) -> Dictionary:
	var weapons := {"guard": "weapon_guard_sword", "spear": "weapon_spear_long",
		"archer": "weapon_archer_bow", "skirmisher": "weapon_skirmisher_blade",
		"hunter": "weapon_hunter_bow"}
	var armors := {"guard": "armor_mail", "spear": "armor_brigandine",
		"archer": "armor_padded", "skirmisher": "armor_leather", "hunter": "armor_leather"}
	return {"weapon": str(weapons.get(style, "")), "armor": str(armors.get(kind, ""))}

static func _random(s: Dictionary, upper: int) -> int:
	s.rng_state = (int(s.rng_state) * 48271) % 2147483647
	return int(s.rng_state) % upper

static func _check_outcome(s: Dictionary) -> void:
	if s.outcome != "":
		return
	var players = 0
	var enemies = 0
	for u in s.units:
		if _available(s, u):
			if u.team == "player":
				players += 1
			else:
				enemies += 1
	if _evacuation(s):
		var required = int(s.objective.required_count)
		var achieved = s.objective.evacuated_ids.size()
		var possible = achieved
		var wrong_exit = false
		for u in s.units:
			if u.team != "player" or str(u.id) not in s.objective.participant_ids:
				continue
			if _available(s, u):
				possible += 1
			elif bool(u.get("escaped", false)) and str(u.id) not in s.objective.evacuated_ids:
				wrong_exit = true
		if required > 0 and achieved >= required:
			s.outcome = "victory"
		elif possible < required or required == 0:
			s.outcome = "retreat" if wrong_exit else "defeat"
		if s.outcome != "":
			finalize_casualties(s)
		return
	if players == 0:
		s.outcome = "defeat"
		if _expanded(s):
			for u in s.units:
				if u.team == "player" and int(u.hp) > 0 and bool(u.get("escaped", false)):
					s.outcome = "retreat"
					break
	elif enemies == 0:
		s.outcome = "victory"
	if s.outcome != "":
		finalize_casualties(s)

static func _emit(s: Dictionary, events: Array, type: String, actor: String, target: String, q: int, r: int, message: String, amount: int) -> void:
	events.append({"type": type, "actor": actor, "target": target, "q": q, "r": r, "text": message, "amount": amount, "root_action": int(s.action_seq)})
	s.log.append(message)
	while s.log.size() > 80:
		s.log.pop_front()


static func _expanded(s: Dictionary) -> bool:
	return str(s.get("rules_version", "")) == RULES_VERSION

static func _available(s: Dictionary, u: Dictionary) -> bool:
	return int(u.hp) > 0 and (not _expanded(s) or not bool(u.get("escaped", false)))

static func _elevation(s: Dictionary, q: int, r: int) -> int:
	return int(s.cells.get(_key(q, r), {}).get("elevation", 0))

static func _edge(s: Dictionary, u: Dictionary) -> bool:
	return int(u.q) == 0 or int(u.r) == 0 or int(u.q) == int(s.width) - 1 or int(u.r) == int(s.height) - 1

static func _route_cost(s: Dictionary, u: Dictionary, route: Array) -> int:
	var result = 0
	var q = int(u.q)
	var r = int(u.r)
	for step in route:
		result += Tactical.step_cost(s, q, r, int(step.q), int(step.r))
		q = int(step.q)
		r = int(step.r)
	return result

static func _plan_fatigue(s: Dictionary, u: Dictionary, action_id: String, plan: Dictionary) -> int:
	if action_id == "move":
		var result = 0
		var q = int(u.q)
		var r = int(u.r)
		for step in plan.path:
			result += Tactical.step_fatigue(s, u, q, r, int(step.q), int(step.r))
			q = int(step.q)
			r = int(step.r)
		return result
	var base = int(Tactical.FATIGUE_COST.get(action_id, 0))
	return base + int(u.get("equipment_burden", 0)) / 10 if base > 0 else 0

static func _weighted_path(s: Dictionary, u: Dictionary, q: int, r: int, budget: int) -> Array:
	if not _walkable(s, q, r):
		return []
	return _weighted_routes(s, u, budget, Vector2i(q, r)).get(_key(q, r), [])

static func movement_reachable(s: Dictionary, unit_id: String) -> Array:
	# One shared path search for the move overlay instead of one per board cell.
	# Hover previews and settlement still use the very same AP/fatigue search.
	var result: Array = []
	var u = _find_unit(s, unit_id)
	if s.outcome != "" or u.is_empty() or not _available(s, u) or active_unit(s).get("id", "") != unit_id:
		return result
	var routes = _weighted_routes(s, u, int(u.ap)) if _expanded(s) else {}
	for q in range(int(s.width)):
		for r in range(int(s.height)):
			if (_expanded(s) and routes.has(_key(q, r))) or (not _expanded(s) and preview(s, unit_id, "move", {"q": q, "r": r}).ok):
				result.append({"q": q, "r": r})
	return result

static func _weighted_routes(s: Dictionary, u: Dictionary, budget: int, target: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	# Pareto labels keep an AP-cheap but exhausting route from hiding a legal detour.
	var routes: Dictionary = {}
	var frontier: Array = [{"q": int(u.q), "r": int(u.r), "ap": 0, "fatigue": 0, "path": []}]
	var labels: Dictionary = {_key(int(u.q), int(u.r)): [{"ap": 0, "fatigue": 0}]}
	var remaining = int(u.get("max_fatigue", 100)) - int(u.get("fatigue", 0))
	while not frontier.is_empty():
		frontier.sort_custom(func(a, b): return int(a.ap) < int(b.ap) if int(a.ap) != int(b.ap) else int(a.fatigue) < int(b.fatigue))
		var here: Dictionary = frontier.pop_front()
		var here_key = _key(int(here.q), int(here.r))
		if int(here.q) == target.x and int(here.r) == target.y:
			return {here_key: here.path}
		if target.x < 0 and not here.path.is_empty() and not routes.has(here_key) and _walkable(s, int(here.q), int(here.r)):
			routes[here_key] = here.path
		for d in DIRECTIONS:
			var nq = int(here.q) + int(d[0])
			var nr = int(here.r) + int(d[1])
			if not _traversable(s, u, nq, nr):
				continue
			var ap = int(here.ap) + Tactical.step_cost(s, int(here.q), int(here.r), nq, nr)
			var fatigue = int(here.fatigue) + Tactical.step_fatigue(s, u, int(here.q), int(here.r), nq, nr)
			if ap > budget or (budget <= int(u.ap) and fatigue > remaining):
				continue
			var key = _key(nq, nr)
			var dominated = false
			for label in labels.get(key, []):
				if int(label.ap) <= ap and int(label.fatigue) <= fatigue:
					dominated = true
					break
			if dominated:
				continue
			if not labels.has(key):
				labels[key] = []
			labels[key].append({"ap": ap, "fatigue": fatigue})
			var path: Array = here.path.duplicate()
			path.append({"q": nq, "r": nr})
			frontier.append({"q": nq, "r": nr, "ap": ap, "fatigue": fatigue, "path": path})
	return routes

static func _sort_order(s: Dictionary) -> void:
	# Sort only at battle creation / round boundary; no mid-round extra turns.
	s.order.sort_custom(func(a, b):
		var au = _find_unit(s, str(a))
		var bu = _find_unit(s, str(b))
		var av = Tactical.initiative_score(au)
		var bv = Tactical.initiative_score(bu)
		return av > bv if av != bv else str(a) < str(b))
	s.initiative_snapshot = {}
	for id in s.order:
		s.initiative_snapshot[str(id)] = Tactical.initiative_score(_find_unit(s, str(id)))

static func _start_tactical_turn(s: Dictionary, u: Dictionary, events: Array) -> void:
	u.fatigue = maxi(0, int(u.get("fatigue", 0)) - Tactical.TURN_RECOVERY)
	if int(u.get("morale", 3)) == 0:
		var safe = true
		for enemy in s.units:
			if _available(s, enemy) and enemy.team != u.team and _distance(int(u.q), int(u.r), int(enemy.q), int(enemy.r)) <= 2:
				safe = false
		if safe:
			_morale_check(s, u, 1, "safe_recovery", events)

static func _morale_check(s: Dictionary, u: Dictionary, direction: int, reason: String, events: Array) -> void:
	if not _available(s, u):
		return
	var key = "%d:%s:%d" % [int(s.action_seq), str(u.id), direction]
	if s.morale_checks.has(key):
		return
	var before = int(u.get("morale", 3))
	var threshold = clampi(int(u.get("resolve", 55)) + (before - 3) * 5, 5, 95)
	var roll = _random(s, 100)
	var changed = roll >= threshold if direction < 0 else roll < threshold
	u.morale = clampi(before + (direction if changed else 0), 0, 4)
	s.morale_checks[key] = {"unit_id": str(u.id), "root_action": int(s.action_seq), "reason": reason, "roll": roll, "threshold": threshold, "before": before, "after": int(u.morale)}
	if before != int(u.morale):
		var cause := str({"heavy_hit": "遭受重创", "ally_incapacitated": "附近同伴倒下", "enemy_incapacitated": "击倒附近敌人", "safe_recovery": "安全处重整"}.get(reason, reason))
		_emit(s, events, "morale", "", u.id, int(u.q), int(u.r), u.name + "：" + str(Tactical.MORALE_NAMES[int(u.morale)]) + "（" + cause + "）", direction)
		events.back().reason = reason

static func _incapacitate(s: Dictionary, u: Dictionary, actor: String, events: Array) -> void:
	if bool(u.get("incapacitated", false)):
		return
	u.incapacitated = true
	var before = int(s.casualty_rng_state)
	s.casualty_rng_state = (before * 48271) % 2147483647
	var casualty = {"id": "%s:casualty:%s" % [str(s.id), str(u.id)], "battle_id": str(s.id),
		"unit_id": str(u.id), "team": str(u.team), "kind": str(u.kind), "source_action": int(s.action_seq),
		"source_actor": actor, "rng_before": before, "roll": int(s.casualty_rng_state) % 100, "status": "pending", "round": int(s.round)}
	s.casualties.append(casualty)
	u.casualty_id = casualty.id
	_emit(s, events, "incapacitated", actor, u.id, int(u.q), int(u.r), u.name + "失去战斗能力（战后清点伤亡）", 0)
	var observers: Array = s.units.duplicate()
	observers.sort_custom(func(a, b): return str(a.id) < str(b.id))
	for observer in observers:
		if not _available(s, observer):
			continue
		if _distance(int(observer.q), int(observer.r), int(u.q), int(u.r)) > Tactical.MORALE_WITNESS_RANGE:
			continue
		if observer.team == u.team:
			_morale_check(s, observer, -1, "ally_incapacitated", events)
		elif observer.team != u.team:
			_morale_check(s, observer, 1, "enemy_incapacitated", events)

static func finalize_casualties(s: Dictionary) -> Dictionary:
	if not _expanded(s) or str(s.outcome).is_empty():
		return {}
	if not s.get("terminal_data", {}).is_empty():
		return s.terminal_data
	for casualty in s.get("casualties", []):
		if str(casualty.status) != "pending":
			continue
		casualty.outcome = str(s.outcome)
		casualty.survival_chance = Tactical.SURVIVAL_CHANCE if s.outcome == "victory" else 0
		if casualty.team != "player":
			casualty.status = "enemy_incapacitated"
		else:
			casualty.status = "survived" if int(casualty.roll) < int(casualty.survival_chance) else "dead"
		var casualty_unit := _find_unit(s, str(casualty.unit_id))
		if not casualty_unit.is_empty(): casualty_unit.casualty_status = str(casualty.status)
	var escaped: Array = []
	for u in s.units:
		if bool(u.get("escaped", false)):
			escaped.append(str(u.id))
	s.terminal_data = {"battle_id": str(s.id), "rules_version": str(s.rules_version), "outcome": str(s.outcome),
		"casualties": s.casualties.duplicate(true), "escaped_ids": escaped, "final_action": int(s.action_seq)}
	if _evacuation(s):
		s.terminal_data.objective = s.objective.duplicate(true)
	return s.terminal_data

static func _flee_ai(s: Dictionary, u: Dictionary) -> Dictionary:
	if preview(s, u.id, "flee", {}).ok:
		return apply_action(s, u.id, "flee", {})
	var best: Dictionary = {}
	var best_score = -100000.0
	for q in range(int(s.width)):
		for r in range(int(s.height)):
			var p = preview(s, u.id, "move", {"q": q, "r": r})
			if not p.ok:
				continue
			var edge_distance = mini(mini(q, r), mini(int(s.width) - 1 - q, int(s.height) - 1 - r))
			var score = -float(edge_distance) * 12.0 - int(p.cost) - int(p.fatigue_cost) * 0.1
			var pq = int(u.q)
			var pr = int(u.r)
			for tile in p.path:
				score -= _disengagers(s, u, pq, pr, int(tile.q), int(tile.r)).size() * 10.0
				if s.cells[_key(int(tile.q), int(tile.r))].field == "fire":
					score -= 30.0
				pq = int(tile.q)
				pr = int(tile.r)
			if score > best_score:
				best_score = score
				best = {"q": q, "r": r}
	if not best.is_empty():
		return apply_action(s, u.id, "move", best)
	if preview(s, u.id, "recover", {}).ok:
		return apply_action(s, u.id, "recover", {})
	return {"ok": true, "reason": "", "events": end_turn(s)}

static func validate_deployment(s: Dictionary, deployment: Array) -> Dictionary:
	var ids: Dictionary = {}
	var occupied: Dictionary = {}
	for slot in deployment:
		if not slot is Dictionary:
			return {"ok": false, "reason": "部署格式无效。"}
		var id = str(slot.get("unit_id", ""))
		var u = _find_unit(s, id)
		var q = int(slot.get("q", -1))
		var r = int(slot.get("r", -1))
		if u.is_empty() or u.team != "player" or ids.has(id) or q < 0 or q > 2 or r < 0 or r >= int(s.height):
			return {"ok": false, "reason": "部署需为本次队员、唯一ID及左侧三列合法格。"}
		var key = _key(q, r)
		if occupied.has(key) or s.cells[key].blocked or not _prop_at(s, q, r).is_empty():
			return {"ok": false, "reason": "部署格重叠或被阻挡。"}
		ids[id] = true
		occupied[key] = true
	for u in s.units:
		if u.team == "player" and not ids.has(str(u.id)):
			return {"ok": false, "reason": "部署须包含全部出战队员。"}
	return {"ok": true, "reason": ""}

static func _apply_deployment(s: Dictionary) -> void:
	if not s.mission.get("deployment", []) is Array or s.mission.get("deployment", []).is_empty():
		return
	var validation = validate_deployment(s, s.mission.deployment)
	if not validation.ok:
		s.deployment_error = validation.reason
		return
	for slot in s.mission.deployment:
		var u = _find_unit(s, str(slot.unit_id))
		u.q = int(slot.q)
		u.r = int(slot.r)
	s.deployment_instance_id = str(s.mission.get("deployment_instance_id", ""))


static func _evacuation(s: Dictionary) -> bool:
	return _expanded(s) and str(s.get("objective", {}).get("kind", "")) == "evacuation"

static func _evacuation_ai(s: Dictionary, u: Dictionary) -> Dictionary:
	# Dogs cannot be manually selected; once their handler leaves or combat clears,
	# they use the same costs and exit action to finish this existing objective.
	if int(u.q) == int(s.width) - 1 and preview(s, u.id, "flee", {}).ok:
		return apply_action(s, u.id, "flee", {})
	var chosen: Dictionary = {}
	var best = 100000.0
	for r in range(int(s.height)):
		var route = _path(s, u, int(s.width) - 1, r, int(s.width) * int(s.height) * 4)
		if route.is_empty():
			continue
		var landing = _first_route_landing(s, u, route)
		if landing.is_empty():
			continue
		var score = float(_route_cost(s, u, route))
		var q0 = int(u.q)
		var r0 = int(u.r)
		for tile in route:
			if s.cells[_key(int(tile.q), int(tile.r))].field == "fire":
				score += 20.0
			score += _disengagers(s, u, q0, r0, int(tile.q), int(tile.r)).size() * 7.0
			q0 = int(tile.q)
			r0 = int(tile.r)
		if score < best:
			best = score
			chosen = landing
	if not chosen.is_empty():
		return apply_action(s, u.id, "move", chosen)
	if preview(s, u.id, "recover", {}).ok:
		return apply_action(s, u.id, "recover", {})
	return {"ok": true, "reason": "", "events": end_turn(s)}
