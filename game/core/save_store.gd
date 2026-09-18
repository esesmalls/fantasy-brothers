extends RefCounted
## Versioned snapshots; rotate the previous verified snapshot before replacing it.

const FORMAT_VERSION = 1
const MAX_BYTES = 8 * 1024 * 1024
const MAX_JSON_DEPTH = 40
const MAX_SAFE_JSON_INT = 9007199254740991
const RNG_MAX = 2147483646
const BATTLE_RULES_VERSION = "prototype-0.1.1"
const LEGACY_BATTLE_RULES_VERSION = "prototype-0.1"
const UNIT_KINDS = ["guard", "spear", "archer", "skirmisher", "hunter", "dog", "raider"]
const PERKS = ["vigor", "precision", "breacher", "firewise", "packbond"]

static func save_campaign(c: Dictionary, path: String = "user://campaign.json") -> Dictionary:
	var problem: String = validate(c)
	if not problem.is_empty():
		return {"ok": false, "reason": "存档未写入：" + problem}
	# GDScript's dot syntax may leave StringName keys in an otherwise JSON-safe
	# Dictionary. Canonicalize them in the live state so the caller and a later
	# load observe the same key types as well as the same values.
	_canonicalize_keys(c)
	var directory: String = path.get_base_dir()
	if not directory.is_empty():
		# user:// is a Godot virtual path; the absolute API must receive its
		# globalized filesystem path on a clean machine.
		var directory_path: String = ProjectSettings.globalize_path(directory) if directory.begins_with("user://") or directory.begins_with("res://") else directory
		if DirAccess.make_dir_recursive_absolute(directory_path) != OK:
			return {"ok": false, "reason": "无法建立存档目录。"}
	var payload: String = JSON.stringify(c)
	var envelope: Dictionary = {"format": FORMAT_VERSION, "payload": payload, "sha256": payload.sha256_text()}
	var encoded: String = JSON.stringify(envelope)
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		return {"ok": false, "reason": "存档未写入：存档大小超过限制。"}
	_remove_if_present(path + ".tmp")
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return {"ok": false, "reason": "无法写入存档，请检查目录权限。"}
	file.store_string(encoded)
	file.flush()
	var write_error: Error = file.get_error()
	file.close()
	if write_error != OK or not _read(path + ".tmp").get("ok", false):
		_remove_if_present(path + ".tmp")
		return {"ok": false, "reason": "存档写入校验失败，原存档保留。"}
	if _read(path).get("ok", false):
		# Never rotate a corrupt primary over the last healthy recovery snapshot.
		var copy_error: Error = DirAccess.copy_absolute(_absolute(path), _absolute(path + ".bak"))
		if copy_error != OK or not _read(path + ".bak").get("ok", false):
			_remove_if_present(path + ".tmp")
			return {"ok": false, "reason": "无法保留备份，原存档保留。"}
	var rename_error: Error = DirAccess.rename_absolute(_absolute(path + ".tmp"), _absolute(path))
	if rename_error != OK:
		_remove_if_present(path + ".tmp")
		return {"ok": false, "reason": "无法替换存档，备份保留。"}
	return {"ok": true, "reason": "已保存"}

static func load_campaign(path: String = "user://campaign.json") -> Dictionary:
	var primary: Dictionary = _read(path)
	if primary.get("ok", false):
		primary.recovered = false
		return primary
	var backup: Dictionary = _read(path + ".bak")
	if backup.get("ok", false):
		backup.recovered = true
		backup.reason = "主存档无法读取，已恢复上一次完整备份。"
		return backup
	return {"ok": false, "reason": "没有可读取的存档。" if not FileAccess.file_exists(path) else "存档及备份无法读取；原文件已保留。"}

static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {"ok": false}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {"ok": false}
	var text: String = file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		return {"ok": false}
	var envelope = parser.data
	if not envelope is Dictionary or not _is_integer(envelope.get("format", -1), FORMAT_VERSION, FORMAT_VERSION):
		return {"ok": false}
	var payload = envelope.get("payload", null)
	if not payload is String or payload.sha256_text() != str(envelope.get("sha256", "")):
		return {"ok": false}
	var payload_parser := JSON.new()
	if payload_parser.parse(payload) != OK or not payload_parser.data is Dictionary:
		return {"ok": false}
	var data: Dictionary = payload_parser.data
	_canonicalize_numbers(data)
	if not validate(data).is_empty():
		return {"ok": false}
	var upgraded: bool = _upgrade_loaded(data)
	return {"ok": true, "campaign": data, "upgraded": upgraded, "reason": "已读取存档；旧版进度已兼容，后续行动使用 0.1.1 规则。" if upgraded else "已读取存档"}

static func _upgrade_loaded(c: Dictionary) -> bool:
	# Only upgrade after checksum and full structural validation. Never reroll
	# events or RNG, re-charge a route, or replay completed actions.
	var upgraded := false
	var expedition: Dictionary = c.expedition
	if not expedition.is_empty() and not expedition.has("route_id"):
		expedition.route_id = "road"
		expedition.route_name = "渡口旧道"
		expedition.route_food_cost = 2
		expedition.route_days = 1
		upgraded = true
	var battle: Dictionary = c.battle
	if not battle.is_empty() and str(battle.get("rules_version", "")) == LEGACY_BATTLE_RULES_VERSION:
		battle.migrated_from_rules = LEGACY_BATTLE_RULES_VERSION
		battle.rules_version = BATTLE_RULES_VERSION
		if battle.get("mission") is Dictionary:
			battle.mission.route_id = expedition.get("route_id", "road")
			battle.mission.route_name = expedition.get("route_name", "渡口旧道")
		upgraded = true
	return upgraded

static func validate(c: Dictionary) -> String:
	if not _json_safe(c):
		return "包含无法安全序列化的数据。"
	if not _is_integer(c.get("schema", -1), 1, 1):
		return "存档版本不兼容。"
	if not _is_integer(c.get("seed", null), -2147483648, 2147483647):
		return "随机种子损坏。"
	if not _is_integer(c.get("rng_state", null), 1, RNG_MAX):
		return "随机状态损坏。"
	for key in ["gold", "food", "renown"]:
		if not _is_integer(c.get(key, null), 0, MAX_SAFE_JSON_INT):
			return "资源字段损坏。"
	if not _is_integer(c.get("day", null), 1, MAX_SAFE_JSON_INT):
		return "日期字段损坏。"
	if not c.get("company_name") is String or str(c.company_name).is_empty():
		return "佣兵团名称缺失。"
	for key in ["flags", "expedition", "event", "battle", "claimed"]:
		if not c.get(key) is Dictionary:
			return "状态字段缺失。"
	for key in ["roster", "history", "growth_offers"]:
		if not c.get(key) is Array:
			return "队伍或成长字段缺失。"
	if not c.get("growth_unit_id") is String or not c.get("last_report") is String:
		return "成长或报告字段缺失。"
	if not str(c.get("origin", "")) in ["free", "hunters"] or not str(c.get("phase", "")) in ["camp", "event", "ready", "battle", "growth"]:
		return "未知的队伍或阶段。"
	if not _valid_units(c.roster, "player"):
		return "队员数据损坏。"
	for key in c.claimed:
		if not key is String or str(key).is_empty() or c.claimed[key] != true:
			return "远征领取记录损坏。"
	var phase: String = str(c.phase)
	if phase != "camp":
		var expedition_problem := _validate_expedition(c.expedition)
		if not expedition_problem.is_empty():
			return expedition_problem
	if phase in ["event", "ready", "battle"]:
		var event_problem := _validate_event(c.event, phase != "event")
		if not event_problem.is_empty():
			return event_problem
	if phase == "growth":
		if str(c.get("growth_unit_id", "")).is_empty():
			return "成长对象缺失。"
		var growth_problem := _validate_growth(c.growth_offers, str(c.expedition.get("id", "")))
		if not growth_problem.is_empty():
			return growth_problem
	elif not c.growth_offers.is_empty():
		return "非成长阶段残留未结算候选。"
	if phase == "battle":
		var battle_problem := _validate_battle(c.battle, str(c.expedition.id))
		if not battle_problem.is_empty():
			return battle_problem
	return ""

static func _validate_expedition(expedition: Dictionary) -> String:
	if not expedition.get("id") is String or str(expedition.id).is_empty() or not expedition.get("title") is String:
		return "远征编号或标题缺失。"
	for key in ["index", "difficulty", "reward", "renown_bonus"]:
		if not _is_integer(expedition.get(key, null), 0 if key != "index" else 1, MAX_SAFE_JSON_INT):
			return "远征数值损坏。"
	if int(expedition.difficulty) > 2:
		return "远征难度损坏。"
	if not expedition.get("choice") is String or not expedition.get("event_id") is String:
		return "远征选择记录缺失。"
	if not _valid_supplies(expedition.get("supplies")):
		return "远征补给损坏。"
	if not expedition.get("participant_ids") is Array or not _unique_nonempty_strings(expedition.participant_ids):
		return "远征参与者损坏。"
	var route_fields: Array = ["route_id", "route_name", "route_food_cost", "route_days"]
	var has_route := false
	for key in route_fields:
		has_route = has_route or expedition.has(key)
	if has_route:
		if not expedition.has_all(route_fields) or not expedition.route_id is String or not str(expedition.route_id) in ["road", "ridge"]:
			return "远征路线记录损坏。"
		if not expedition.route_name is String or str(expedition.route_name).is_empty():
			return "远征路线名称缺失。"
		if not _is_integer(expedition.route_food_cost, 0, MAX_SAFE_JSON_INT) or not _is_integer(expedition.route_days, 1, MAX_SAFE_JSON_INT):
			return "远征路线代价损坏。"
	return ""

static func _validate_event(event: Dictionary, require_selection: bool) -> String:
	for key in ["id", "title", "body", "participant_id", "trigger", "absence_path", "test_path"]:
		if not event.get(key) is String:
			return "事件文本或稳定编号缺失。"
	if str(event.id).is_empty() or str(event.title).is_empty():
		return "事件编号或标题缺失。"
	if not _is_integer(event.get("repeat_limit", null), 0, MAX_SAFE_JSON_INT):
		return "事件重复限制损坏。"
	var choices = event.get("choices")
	if not choices is Array or choices.is_empty():
		return "事件选项缺失。"
	var ids: Dictionary = {}
	for raw_choice in choices:
		if not raw_choice is Dictionary:
			return "事件选项损坏。"
		var choice: Dictionary = raw_choice
		for key in ["id", "title", "description"]:
			if not choice.get(key) is String or str(choice.get(key, "")).is_empty():
				return "事件选项编号或文本缺失。"
		var choice_id: String = str(choice.id)
		if ids.has(choice_id):
			return "事件选项编号重复。"
		ids[choice_id] = true
		for key in ["costs", "effects", "set_flags"]:
			if choice.has(key) and not choice[key] is Dictionary:
				return "事件选项效果损坏。"
	if require_selection:
		var selected: String = str(event.get("selected_choice", ""))
		if selected.is_empty() or not ids.has(selected):
			return "事件已进入后续阶段，但所选结果缺失。"
	return ""

static func _validate_growth(offers: Array, expedition_id: String) -> String:
	if offers.is_empty() or expedition_id.is_empty():
		return "成长选项缺失。"
	var ids: Dictionary = {}
	for raw_offer in offers:
		if not raw_offer is Dictionary:
			return "成长选项损坏。"
		var offer: Dictionary = raw_offer
		for key in ["id", "title", "description", "unit_id"]:
			if not offer.get(key) is String or str(offer.get(key, "")).is_empty():
				return "成长选项编号或文本缺失。"
		var offer_id: String = str(offer.id)
		if ids.has(offer_id) or not offer_id.begins_with(expedition_id + ":"):
			return "成长选项编号重复或不属于当前远征。"
		ids[offer_id] = true
		var perk: String = str(offer.get("perk", ""))
		var fallback: String = str(offer.get("fallback", ""))
		if (not perk.is_empty()) == (not fallback.is_empty()):
			return "成长选项效果损坏。"
		if not perk.is_empty() and not perk in PERKS:
			return "成长专长未知。"
		if not fallback.is_empty() and not fallback in ["pay", "rations", "maintenance"]:
			return "成长回退未知。"
	return ""

static func _validate_battle(b: Dictionary, expedition_id: String) -> String:
	if not _is_integer(b.get("schema", null), 1, 1) or not str(b.get("rules_version", "")) in [BATTLE_RULES_VERSION, LEGACY_BATTLE_RULES_VERSION]:
		return "战斗版本不兼容。"
	if str(b.get("id", "")) != expedition_id:
		return "战斗与远征编号不匹配。"
	for key in ["seed", "round", "turn_index", "action_seq", "width", "height"]:
		if not _is_integer(b.get(key, null), 0, MAX_SAFE_JSON_INT):
			return "战斗数值字段损坏。"
	if not _is_integer(b.get("rng_state", null), 1, RNG_MAX):
		return "战斗随机状态损坏。"
	if int(b.width) != 9 or int(b.height) != 7 or int(b.round) < 1:
		return "战场尺寸或轮次损坏。"
	if not str(b.get("outcome", "")) in ["", "victory", "defeat", "retreat"]:
		return "战斗结果未知。"
	for key in ["units", "order", "props", "log", "action_log", "initial_roster"]:
		if not b.get(key) is Array:
			return "战斗列表缺失。"
	for key in ["cells", "supplies", "mission"]:
		if not b.get(key) is Dictionary:
			return "战斗区域或任务字段缺失。"
	if not _valid_units(b.units):
		return "战斗单位损坏。"
	if b.order.size() != b.units.size() or not _unique_nonempty_strings(b.order):
		return "战斗行动顺序损坏。"
	var unit_ids: Dictionary = {}
	var occupied: Dictionary = {}
	for unit: Dictionary in b.units:
		var unit_id: String = str(unit.id)
		unit_ids[unit_id] = true
		if not _is_integer(unit.q, 0, int(b.width) - 1) or not _is_integer(unit.r, 0, int(b.height) - 1):
			return "战斗单位位置越界。"
		if int(unit.hp) > 0:
			var position := "%d,%d" % [int(unit.q), int(unit.r)]
			if occupied.has(position):
				return "存活战斗单位位置重叠。"
			occupied[position] = true
	for unit_id in b.order:
		if not unit_ids.has(str(unit_id)):
			return "行动顺序引用缺失单位。"
	if b.order.is_empty() or not _is_integer(b.turn_index, 0, b.order.size() - 1):
		return "回合指针损坏。"
	if str(b.outcome).is_empty():
		var active_id: String = str(b.order[int(b.turn_index)])
		for unit: Dictionary in b.units:
			if str(unit.id) == active_id and int(unit.hp) <= 0:
				return "未结束战斗停在死亡单位回合。"
	if b.cells.size() != int(b.width) * int(b.height):
		return "战场格子数量损坏。"
	for q in range(int(b.width)):
		for r in range(int(b.height)):
			var cell = b.cells.get("%d,%d" % [q, r])
			if not cell is Dictionary:
				return "战场格子缺失。"
			if not str(cell.get("surface", "")) in ["dry", "oil", "water"] or not str(cell.get("field", "invalid")) in ["", "fire", "steam"]:
				return "战场地表状态损坏。"
			if not _is_integer(cell.get("expires", null), 0, MAX_SAFE_JSON_INT) or not cell.get("blocked") is bool:
				return "战场格子期限或阻挡状态损坏。"
	if not _valid_props(b.props, int(b.width), int(b.height)):
		return "战场物件损坏。"
	if not _valid_supplies(b.supplies):
		return "战斗补给损坏。"
	return ""

static func _valid_units(units: Array, expected_team: String = "") -> bool:
	var ids: Dictionary = {}
	for raw_unit in units:
		if not raw_unit is Dictionary:
			return false
		var unit: Dictionary = raw_unit
		if not unit.has_all(["id", "name", "kind", "team", "hp", "max_hp", "armor", "max_armor", "ap", "max_ap", "attack", "accuracy", "range", "q", "r", "statuses", "perks"]):
			return false
		var unit_id: String = str(unit.id)
		if unit_id.is_empty() or ids.has(unit_id) or not unit.name is String:
			return false
		ids[unit_id] = true
		if not str(unit.kind) in UNIT_KINDS or not str(unit.team) in ["player", "enemy"]:
			return false
		if not expected_team.is_empty() and str(unit.team) != expected_team:
			return false
		if not _is_integer(unit.max_hp, 1, 100000) or not _is_integer(unit.hp, 0, int(unit.max_hp)):
			return false
		if not _is_integer(unit.max_armor, 0, 100000) or not _is_integer(unit.armor, 0, int(unit.max_armor)):
			return false
		if not _is_integer(unit.max_ap, 1, 1000) or not _is_integer(unit.ap, 0, int(unit.max_ap)):
			return false
		for key in ["attack", "accuracy", "range", "q", "r"]:
			if not _is_integer(unit.get(key), -100000, 100000):
				return false
		if not unit.statuses is Dictionary or not unit.perks is Array or not _unique_strings(unit.perks):
			return false
		for perk in unit.perks:
			if not str(perk) in PERKS:
				return false
	return true

static func _valid_props(props: Array, width: int, height: int) -> bool:
	var ids: Dictionary = {}
	for raw_prop in props:
		if not raw_prop is Dictionary:
			return false
		var prop: Dictionary = raw_prop
		if not prop.has_all(["id", "kind", "q", "r", "hp", "max_hp", "blocks"]):
			return false
		var prop_id: String = str(prop.id)
		if prop_id.is_empty() or ids.has(prop_id) or not str(prop.kind) in ["oil", "water", "cover", "grain"]:
			return false
		ids[prop_id] = true
		if not _is_integer(prop.q, 0, width - 1) or not _is_integer(prop.r, 0, height - 1):
			return false
		if not _is_integer(prop.max_hp, 1, 100000) or not _is_integer(prop.hp, 0, int(prop.max_hp)) or not prop.blocks is bool:
			return false
	return true

static func _valid_supplies(supplies) -> bool:
	if not supplies is Dictionary:
		return false
	for key in ["oil", "fire", "water"]:
		if not _is_integer(supplies.get(key, null), 0, MAX_SAFE_JSON_INT):
			return false
	return true

static func _unique_nonempty_strings(values: Array) -> bool:
	if values.is_empty():
		return false
	var seen: Dictionary = {}
	for value in values:
		if not value is String or str(value).is_empty() or seen.has(str(value)):
			return false
		seen[str(value)] = true
	return true

static func _unique_strings(values: Array) -> bool:
	var seen: Dictionary = {}
	for value in values:
		if not value is String or seen.has(str(value)):
			return false
		seen[str(value)] = true
	return true

static func _is_integer(value, minimum: int, maximum: int) -> bool:
	if value is int:
		return value >= minimum and value <= maximum
	if value is float:
		return is_finite(value) and floor(value) == value and value >= minimum and value <= maximum
	return false

static func _json_safe(value, depth: int = 0) -> bool:
	if depth > MAX_JSON_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_STRING, TYPE_STRING_NAME:
			return true
		TYPE_INT:
			return value >= -MAX_SAFE_JSON_INT and value <= MAX_SAFE_JSON_INT
		TYPE_FLOAT:
			return is_finite(value) and value >= -MAX_SAFE_JSON_INT and value <= MAX_SAFE_JSON_INT
		TYPE_ARRAY:
			for item in value:
				if not _json_safe(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			for key in value:
				# Dictionary property syntax in GDScript can create StringName keys;
				# JSON.stringify serializes them as their textual key.
				if not (key is String or key is StringName) or not _json_safe(value[key], depth + 1):
					return false
			return true
		_:
			return false

static func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(_absolute(path))

static func _absolute(path: String) -> String:
	return ProjectSettings.globalize_path(path) if path.begins_with("user://") or path.begins_with("res://") else path

static func _canonicalize_keys(value) -> void:
	if value is Dictionary:
		var replacements: Array = []
		for key in value:
			_canonicalize_keys(value[key])
			if key is StringName:
				replacements.append({"old": key, "new": str(key)})
		for item: Dictionary in replacements:
			if value.has(item.old):
				var child = value[item.old]
				value.erase(item.old)
				value[item.new] = child
	elif value is Array:
		for item in value:
			_canonicalize_keys(item)

static func _canonicalize_numbers(value):
	if value is Dictionary:
		for key in value:
			value[key] = _canonicalize_numbers(value[key])
		return value
	if value is Array:
		for index in range(value.size()):
			value[index] = _canonicalize_numbers(value[index])
		return value
	if value is float and is_finite(value) and floor(value) == value:
		return int(value)
	return value
