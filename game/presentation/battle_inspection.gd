extends RefCounted
const EquipmentData = preload("res://core/equipment_data.gd")
# Read-only presentation projection of battle state. It never previews or settles actions.

const KIND_NAMES := {
	"guard": "盾卫", "spear": "长枪手", "archer": "弓手", "skirmisher": "游击兵",
	"hunter": "猎人", "dog": "战犬", "raider": "劫掠者"
}
const PERK_INFO := {
	"vigor": ["坚韧", "最大生命与当前生命提高 8。"],
	"precision": ["沉着瞄准", "基础命中提高 8。"],
	"breacher": ["破阵协同", "盾击伤害 +4；长枪利用破绽时伤害 +6。"],
	"firewise": ["识火", "火区伤害减半；火区仍会直接伤害生命。"],
	"packbond": ["同猎", "战犬攻击已标记目标时伤害 +6。"]
}
const PROP_NAMES := {"oil": "油罐", "water": "水桶", "cover": "木掩体", "grain": "粮仓"}

static func inspect_cell(battle: Dictionary, q: int, r: int, preferred_unit_id: String = "") -> Dictionary:
	if not _inside(battle, q, r):
		return {}
	var cell: Dictionary = battle.get("cells", {}).get(_key(q, r), {})
	if cell.is_empty():
		return {}
	var units: Array = _units_at(battle, q, r)
	var unit: Dictionary = _preferred_unit(units, preferred_unit_id)
	if unit.is_empty():
		unit = _primary_unit(units)
	var props: Array = _props_at(battle, q, r)
	var prop: Dictionary = _primary_prop(props)
	var result := {
		"title": "格位 (%d, %d)" % [q, r],
		"subtitle": "战场格位",
		"lines": [] as Array[String],
		"glyph": "地",
		"team": "neutral"
	}
	if not unit.is_empty():
		_fill_unit(result, battle, unit)
	elif not prop.is_empty():
		_fill_prop(result, prop)
	_append_other_occupants(result.lines, battle, units, unit, props, prop)
	_append_cell(result.lines, battle, cell, unit)
	if unit.is_empty() and prop.is_empty():
		result.lines.push_front("坐标：q %d / r %d" % [q, r])
	return result

static func _fill_unit(result: Dictionary, battle: Dictionary, unit: Dictionary) -> void:
	var dead := int(unit.get("hp", 0)) <= 0
	var role := str(KIND_NAMES.get(str(unit.get("kind", "")), str(unit.get("kind", "未知岗位"))))
	var side := "我方" if str(unit.get("team", "")) == "player" else "敌方"
	result.title = str(unit.get("name", "未命名单位"))
	result.subtitle = "%s · %s%s" % [side, role, " · 已倒下" if dead else ""]
	result.glyph = "†" if dead else ("犬" if str(unit.get("kind", "")) == "dog" else ("我" if str(unit.get("team", "")) == "player" else "敌"))
	result.team = str(unit.get("team", "neutral"))
	var lines: Array[String] = result.lines
	lines.append("生命：%d / %d%s" % [int(unit.get("hp", 0)), int(unit.get("max_hp", 0)), "（死亡）" if dead else ""])
	lines.append("护甲：%d / %d" % [int(unit.get("armor", 0)), int(unit.get("max_armor", 0))])
	if dead:
		lines.append("行动点：—（已倒下，不会再行动）")
	else:
		lines.append("行动点：%d / %d" % [int(unit.get("ap", 0)), int(unit.get("max_ap", 0))])
	lines.append("攻击：%d · 基础命中：%d%% · 射程：%d 格" % [int(unit.get("attack", 0)), int(unit.get("accuracy", 0)), int(unit.get("range", 0))])
	var loadout: Dictionary = unit.get("visual_loadout", {})
	for slot: String in ["weapon", "armor"]:
		var item: Dictionary = EquipmentData.get_definition(str(loadout.get(slot, "")))
		if not item.is_empty():
			lines.append(("手持：" if slot == "weapon" else "穿戴：") + str(item.name))
	lines.append(_turn_line(battle, unit))
	_append_statuses(lines, battle, unit)
	_append_perks(lines, unit)
	if str(unit.get("kind", "")) == "dog":
		_append_dog(lines, battle, unit)
	if dead:
		lines.append("倒下的身影留在战场上。")
	elif int(unit.get("hp", 0)) * 3 <= maxi(1, int(unit.get("max_hp", 1))):
		lines.append("伤势沉重。")

static func _fill_prop(result: Dictionary, prop: Dictionary) -> void:
	var kind := str(prop.get("kind", "unknown"))
	var destroyed := int(prop.get("hp", 0)) <= 0
	result.title = ("已毁的" if destroyed else "") + str(PROP_NAMES.get(kind, kind))
	result.subtitle = "战场物件 · %s" % ("已毁坏" if destroyed else "可破坏")
	result.glyph = "残" if destroyed else "物"
	result.team = "neutral"
	var lines: Array[String] = result.lines
	lines.append("类型：%s" % str(PROP_NAMES.get(kind, kind)))
	lines.append("耐久：%d / %d" % [int(prop.get("hp", 0)), int(prop.get("max_hp", 0))])
	var blocks := not destroyed and bool(prop.get("blocks", false))
	lines.append("阻挡：%s" % ("是" if blocks else "否"))
	lines.append(_prop_outcome(kind))

static func _append_other_occupants(lines: Array[String], battle: Dictionary, units: Array, primary_unit: Dictionary, props: Array, primary_prop: Dictionary) -> void:
	for unit in units:
		if unit == primary_unit:
			continue
		var state := "已倒下" if int(unit.get("hp", 0)) <= 0 else ("我方" if str(unit.get("team", "")) == "player" else "敌方")
		lines.append("同格单位：%s（%s，%s）" % [str(unit.get("name", unit.get("id", "未知"))), str(KIND_NAMES.get(str(unit.get("kind", "")), unit.get("kind", "未知"))), state])
	for prop in props:
		if prop == primary_prop:
			continue
		lines.append("同格物件：%s（耐久 %d / %d）" % [str(PROP_NAMES.get(str(prop.get("kind", "")), prop.get("kind", "未知"))), int(prop.get("hp", 0)), int(prop.get("max_hp", 0))])
	if not primary_unit.is_empty() and not primary_prop.is_empty():
		lines.append("同格物件：%s（耐久 %d / %d；%s）" % [str(PROP_NAMES.get(str(primary_prop.get("kind", "")), primary_prop.get("kind", "未知"))), int(primary_prop.get("hp", 0)), int(primary_prop.get("max_hp", 0)), _prop_outcome(str(primary_prop.get("kind", "")))])

static func _append_cell(lines: Array[String], battle: Dictionary, cell: Dictionary, unit: Dictionary) -> void:
	if bool(cell.get("blocked", false)):
		lines.append("地形：不可通行")
	var surface := str(cell.get("surface", "dry"))
	lines.append("地表：%s" % ({"dry": "干燥", "oil": "油地", "water": "积水"}.get(surface, surface)))
	var field := str(cell.get("field", ""))
	if field == "fire":
		lines.append("区域：火区（每轮至多一次，直接伤害生命并忽略护甲）")
		if not unit.is_empty() and unit.get("perks", []).has("firewise"):
			lines.append("识火：该单位的火区伤害减半。")
	elif field == "steam":
		lines.append("区域：蒸汽（遮挡远程视线）")
	elif not field.is_empty():
		lines.append("区域：%s" % field)
	if not field.is_empty() and int(cell.get("expires", 0)) > 0:
		lines.append("区域期限：第 %d 轮末（当前第 %d 轮）" % [int(cell.get("expires", 0)), int(battle.get("round", 0))])
	if field in ["fire", "steam"]:
		lines.append("热浪逼人。" if field == "fire" else "视野被白雾吞没。")

static func _append_statuses(lines: Array[String], battle: Dictionary, unit: Dictionary) -> void:
	var statuses: Dictionary = unit.get("statuses", {})
	for status_name in ["defending", "exposed", "marked", "pinned"]:
		if not statuses.has(status_name):
			continue
		var data: Dictionary = statuses[status_name] if statuses[status_name] is Dictionary else {}
		var source := _source_name(battle, str(data.get("source", "")))
		var text := ""
		match status_name:
			"defending": text = "戒备：敌人对其命中 -20，至该单位下回合开始"
			"exposed": text = "破绽：长枪攻击可消耗，获得 +25 命中"
			"marked": text = "标记：猎人对其 +15 命中；同猎战犬可获得伤害加成"
			"pinned": text = "牵制标记"
		if int(data.get("expires", 0)) > 0:
			text += "；第 %d 轮末到期" % int(data.expires)
		if not source.is_empty():
			text += "；来源：" + source
		lines.append(text)
	for status_name in statuses:
		if str(status_name) in ["defending", "exposed", "marked", "pinned"]:
			continue
		lines.append("状态：%s%s" % [str(status_name), _generic_status_suffix(battle, statuses[status_name])])

static func _append_perks(lines: Array[String], unit: Dictionary) -> void:
	var perks: Array = unit.get("perks", [])
	if perks.is_empty():
		lines.append("专长：无")
		return
	for perk in perks:
		var info: Array = PERK_INFO.get(str(perk), [str(perk), "效果未记录。"])
		lines.append("专长「%s」：%s" % [str(info[0]), str(info[1])])

static func _append_dog(lines: Array[String], battle: Dictionary, dog: Dictionary) -> void:
	var command := str(dog.get("command", "follow"))
	var command_text: String = str({"follow": "跟随主人并攻击邻近敌人", "pin": "牵制指定目标", "recall": "撤回主人身边并停止攻击"}.get(command, command))
	lines.append("战犬指令：%s（在自身回合执行）" % command_text)
	var hunter := _source_name(battle, str(dog.get("hunter_id", "")))
	lines.append("绑定猎人：%s" % (hunter if not hunter.is_empty() else "无或已无法识别"))
	if command == "pin":
		var target := _source_name(battle, str(dog.get("command_target", "")))
		lines.append("牵制目标：%s" % (target if not target.is_empty() else "无有效目标"))

static func _turn_line(battle: Dictionary, unit: Dictionary) -> String:
	if int(unit.get("hp", 0)) <= 0:
		return "行动顺序：已倒下，不进入后续行动"
	if not str(battle.get("outcome", "")).is_empty():
		return "行动顺序：战斗已经结束"
	var order: Array = battle.get("order", [])
	if order.is_empty() or not str(unit.get("id", "")) in order:
		return "行动顺序：未列入当前顺序"
	var start := clampi(int(battle.get("turn_index", 0)), 0, order.size() - 1)
	if str(order[start]) == str(unit.get("id", "")):
		return "行动顺序：当前行动者"
	var current := _find_unit(battle, str(order[start]))
	var living_before := 1 if not current.is_empty() and int(current.get("hp", 0)) > 0 else 0
	for offset in range(1, order.size() + 1):
		var candidate_id := str(order[(start + offset) % order.size()])
		if candidate_id == str(unit.get("id", "")):
			return "行动顺序：此前还有 %d 名单位行动" % living_before
		var candidate := _find_unit(battle, candidate_id)
		if not candidate.is_empty() and int(candidate.get("hp", 0)) > 0:
			living_before += 1
	return "行动顺序：未列入当前顺序"

static func _prop_outcome(kind: String) -> String:
	match kind:
		"oil": return "毁坏结果：中心与相邻可用格铺油；遇火会被消耗并形成火区。"
		"water": return "毁坏结果：中心与相邻可用格积水；可灭火并形成蒸汽。"
		"cover": return "毁坏结果：取消阻挡，打开通路与射线。"
		"grain": return "毁坏结果：失去胜利后的 2 份口粮与 10 金额外谢礼。"
		_: return "毁坏结果：未记录。"

static func _generic_status_suffix(battle: Dictionary, raw: Variant) -> String:
	if not raw is Dictionary:
		return ""
	var data: Dictionary = raw
	var suffix := ""
	if int(data.get("expires", 0)) > 0:
		suffix += "；第 %d 轮末到期" % int(data.expires)
	var source := _source_name(battle, str(data.get("source", "")))
	if not source.is_empty():
		suffix += "；来源：" + source
	return suffix

static func _source_name(battle: Dictionary, id: String) -> String:
	if id.is_empty():
		return ""
	var unit := _find_unit(battle, id)
	if not unit.is_empty():
		return str(unit.get("name", id))
	for prop in battle.get("props", []):
		if str(prop.get("id", "")) == id:
			return str(PROP_NAMES.get(str(prop.get("kind", "")), id))
	return id

static func _preferred_unit(units: Array, preferred_id: String) -> Dictionary:
	if preferred_id.is_empty():
		return {}
	for unit in units:
		if str(unit.get("id", "")) == preferred_id:
			return unit
	return {}

static func _primary_unit(units: Array) -> Dictionary:
	for unit in units:
		if int(unit.get("hp", 0)) > 0:
			return unit
	return units[0] if not units.is_empty() else {}

static func _primary_prop(props: Array) -> Dictionary:
	for prop in props:
		if int(prop.get("hp", 0)) > 0:
			return prop
	return props[0] if not props.is_empty() else {}

static func _units_at(battle: Dictionary, q: int, r: int) -> Array:
	var found: Array = []
	for unit in battle.get("units", []):
		if int(unit.get("q", -1)) == q and int(unit.get("r", -1)) == r:
			found.append(unit)
	return found

static func _props_at(battle: Dictionary, q: int, r: int) -> Array:
	var found: Array = []
	for prop in battle.get("props", []):
		if int(prop.get("q", -1)) == q and int(prop.get("r", -1)) == r:
			found.append(prop)
	return found

static func _find_unit(battle: Dictionary, id: String) -> Dictionary:
	for unit in battle.get("units", []):
		if str(unit.get("id", "")) == id:
			return unit
	return {}

static func _inside(battle: Dictionary, q: int, r: int) -> bool:
	return q >= 0 and r >= 0 and q < int(battle.get("width", 0)) and r < int(battle.get("height", 0))

static func _key(q: int, r: int) -> String:
	return "%d,%d" % [q, r]
