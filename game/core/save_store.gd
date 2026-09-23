extends RefCounted
## Versioned snapshots; rotate the previous verified snapshot before replacing it.

const World = preload("res://core/world_data.gd")
const Equipment = preload("res://core/equipment_rules.gd")
const Character = preload("res://core/character_rules.gd")
const Appearance = preload("res://core/appearance_rules.gd")
const Company = preload("res://core/company_rules.gd")

const FORMAT_VERSION = 1
const MAX_BYTES = 8 * 1024 * 1024
const MAX_JSON_DEPTH = 40
const MAX_SAFE_JSON_INT = 9007199254740991
const RNG_MAX = 2147483646
const BATTLE_RULES_VERSION = "prototype-0.1.6"
const CHARACTER_BATTLE_RULES_VERSION = "prototype-0.1.5"
const PREVIOUS_BATTLE_RULES_VERSION = "prototype-0.1.4"
const LEGACY_BATTLE_RULES_VERSION = "prototype-0.1.1"
const ORIGINAL_BATTLE_RULES_VERSION = "prototype-0.1"
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
	if not validate(data, true).is_empty():
		return {"ok": false}
	var upgraded: bool = _upgrade_loaded(data)
	if not validate(data).is_empty():
		return {"ok": false}
	return {"ok": true, "campaign": data, "upgraded": upgraded, "reason": "已读取存档；保留进行中的旧战斗，后续新战斗使用0.1.6战术规则。" if upgraded else "已读取存档"}

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
	if not expedition.is_empty():
		if not expedition.has("contract_id"):
			expedition.contract_id = World.CONTRACT_ID
			expedition.travel_id = str(expedition.id)
			expedition.location_id = "loc_granary"
			upgraded = true
	# In-progress battles are immutable versioned snapshots. Character migration
	# only touches the campaign roster; battle RNG, units and logs remain byte-for-byte.
	var battle: Dictionary = c.battle
	if not battle.is_empty() and str(battle.get("rules_version", "")) == ORIGINAL_BATTLE_RULES_VERSION:
		battle.migrated_from_rules = ORIGINAL_BATTLE_RULES_VERSION
		# The historical migration only adds route compatibility. It must not
		# advertise 0.1.5 character metadata that the frozen battle never stored.
		battle.rules_version = PREVIOUS_BATTLE_RULES_VERSION
		if battle.get("mission") is Dictionary:
			battle.mission.route_id = expedition.get("route_id", "road")
			battle.mission.route_name = expedition.get("route_name", "渡口旧道")
		upgraded = true
	if not c.has("world"):
		c.world = World.new_world()
		_upgrade_world_for_legacy_phase(c)
		upgraded = true
	if Equipment.migrate_legacy(c):
		upgraded = true
	var character_upgrade := Character.ensure_campaign(c)
	upgraded = upgraded or bool(character_upgrade.get("changed", false))
	if Company.ensure(c):
		upgraded = true
	return upgraded

static func _upgrade_world_for_legacy_phase(c: Dictionary) -> void:
	var phase: String = str(c.phase)
	if phase == "camp" or c.expedition.is_empty():
		return
	var expedition: Dictionary = c.expedition
	var route_id: String = str(expedition.get("route_id", "road"))
	var path: Array = World.route_path(route_id)
	var event_id: String = str(expedition.get("event_id", c.event.get("id", "")))
	var event_instance_id := "%s:%s" % [str(expedition.id), event_id]
	var event_step: int = 1
	if event_id == "event_granary_stores":
		event_step = path.size() - 1
	elif event_id == "event_bell_at_bridge":
		if route_id == "road":
			path = [World.CAMP_ID, "loc_ferry_crossing", "loc_bridgehead", "loc_ferry_crossing", "loc_granary"]
		else:
			path = [World.CAMP_ID, "loc_ridge_pass", "loc_bridgehead", "loc_ridge_pass", "loc_hunter_edge", "loc_granary"]
		event_step = 2
	var step: int = event_step if phase == "event" else path.size() - 1
	var status: String = phase
	if phase == "growth" or phase == "returning":
		status = "returning"
	c.world.active_contract_id = World.CONTRACT_ID
	c.world.travel = {
		"id": str(expedition.id), "contract_id": World.CONTRACT_ID,
		"origin_id": World.CAMP_ID, "destination_id": "loc_granary",
		"route_id": route_id, "route_path": path,
		"edge_ids": _edge_ids(path), "current_edge_index": step,
		"food_cost": int(expedition.get("route_food_cost", 2)),
		"days": int(expedition.get("route_days", 1)),
		"event_instance_id": event_instance_id, "event_step": event_step,
		"status": status
	}
	c.world.company_location_id = str(path[step])
	for i in range(step + 1):
		if not str(path[i]) in c.world.discovered_location_ids:
			c.world.discovered_location_ids.append(str(path[i]))
	if not c.event.is_empty():
		c.event.event_instance_id = event_instance_id
		c.event.scope = "travel"
		c.event.content_version = World.CONTENT_VERSION
		c.event.location_id = str(path[event_step])
		if phase == "event":
			# Old event saves had already paid their route and opened the choice.
			# Preserve their direct event -> ready continuation without replaying travel.
			c.event.legacy_direct_ready = true
	if phase in ["ready", "battle", "growth", "returning"]:
		c.world.resolved_event_instance_ids.append(event_instance_id)

static func _edge_ids(path: Array) -> Array:
	var ids: Array = []
	for i in range(path.size() - 1):
		ids.append("%s>%s" % [str(path[i]), str(path[i + 1])])
	return ids

static func validate(c: Dictionary, allow_legacy_equipment: bool = false) -> String:
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
	var legacy_world: bool = not c.has("world")
	if not legacy_world and not c.get("world") is Dictionary:
		return "世界状态缺失。"
	if not str(c.get("origin", "")) in ["free", "hunters"] or not str(c.get("phase", "")) in ["camp", "travel", "event", "ready", "battle", "growth", "returning"]:
		return "未知的队伍或阶段。"
	if legacy_world and str(c.phase) in ["travel", "returning"]:
		return "旧版存档包含未知阶段。"
	if not _valid_units(c.roster, "player"):
		return "队员数据损坏。"
	if not c.has("equipment"):
		if not allow_legacy_equipment:
			return "装备状态缺失。"
	else:
		var equipment_problem := Equipment.validate_campaign(c)
		if not equipment_problem.is_empty():
			return equipment_problem
	var character_problem := Character.validate_campaign(c, allow_legacy_equipment)
	if not character_problem.is_empty():
		return character_problem
	var company_problem := Company.validate(c, allow_legacy_equipment)
	if not company_problem.is_empty():
		return company_problem
	for key in c.claimed:
		if not key is String or str(key).is_empty() or c.claimed[key] != true:
			return "远征领取记录损坏。"
	var phase: String = str(c.phase)
	if phase != "camp":
		var expedition_problem := _validate_expedition(c.expedition)
		if not expedition_problem.is_empty():
			return expedition_problem
	if phase in ["travel", "event", "ready", "battle"]:
		var event_problem := _validate_event(c.event, phase in ["ready", "battle"])
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
	if not legacy_world:
		var world_problem := _validate_world(c)
		if not world_problem.is_empty():
			return world_problem
	return ""

static func _validate_world(c: Dictionary) -> String:
	var world: Dictionary = c.world
	if not _is_integer(world.get("schema", null), World.SCHEMA, World.SCHEMA) or str(world.get("content_version", "")) != World.CONTENT_VERSION:
		return "世界存档版本不兼容。"
	for key in ["company_location_id", "active_contract_id"]:
		if not world.get(key) is String:
			return "世界位置或契约字段损坏。"
	for key in ["travel", "location_states"]:
		if not world.get(key) is Dictionary:
			return "世界旅行或地点状态缺失。"
	for key in ["discovered_location_ids", "pending_effects", "resolved_event_instance_ids"]:
		if not world.get(key) is Array:
			return "世界列表状态缺失。"
	if not World.has_location(str(world.company_location_id)):
		return "公司所在地点未知。"
	if not _unique_nonempty_strings(world.discovered_location_ids) or not str(world.company_location_id) in world.discovered_location_ids:
		return "地点发现记录损坏。"
	for location_id in world.discovered_location_ids:
		if not World.has_location(str(location_id)):
			return "地点发现记录引用未知地点。"
	if not world.pending_effects.is_empty():
		return "当前版本不接受未知的延迟世界效果。"
	if not _unique_strings(world.resolved_event_instance_ids):
		return "事件实例结算记录损坏。"
	for event_instance_id in world.resolved_event_instance_ids:
		if str(event_instance_id).is_empty():
			return "事件实例结算记录损坏。"
	for location_id in world.location_states:
		var state = world.location_states[location_id]
		if not location_id is String or not World.has_location(str(location_id)) or not state is Dictionary:
			return "地点状态引用损坏。"
		if not state.get("flags") is Dictionary or not _is_integer(state.get("last_visit_day", null), 1, MAX_SAFE_JSON_INT):
			return "地点状态内容损坏。"
	var phase: String = str(c.phase)
	var travel: Dictionary = world.travel
	if phase == "camp":
		if str(world.company_location_id) != World.CAMP_ID or not str(world.active_contract_id).is_empty() or not travel.is_empty():
			return "营地阶段残留未完成旅行。"
		return ""
	var contract_id := str(world.active_contract_id)
	if travel.is_empty() or not contract_id in [World.CONTRACT_ID, World.EVACUATION_ID]:
		return "当前阶段缺少活动契约旅行。"
	var required := ["id", "contract_id", "origin_id", "destination_id", "route_id", "route_path", "edge_ids", "current_edge_index", "food_cost", "days", "event_instance_id", "event_step", "status"]
	if not travel.has_all(required):
		return "旅行字段缺失。"
	var expedition_id: String = str(c.expedition.get("id", ""))
	if str(travel.id) != expedition_id or str(travel.contract_id) != contract_id or str(c.expedition.get("travel_id", "")) != expedition_id or str(c.expedition.get("contract_id", "")) != contract_id:
		return "旅行、契约与远征编号不一致。"
	if str(travel.origin_id) != World.CAMP_ID or str(travel.destination_id) != "loc_granary" or not str(travel.route_id) in ["road", "ridge"]:
		return "旅行端点或路线损坏。"
	if str(c.expedition.get("route_id", "")) != str(travel.route_id) or str(c.expedition.get("location_id", "")) != "loc_granary":
		return "远征路线或目标地点不一致。"
	if not travel.route_path is Array or travel.route_path.size() < 2 or not _unique_path_locations_are_known(travel.route_path):
		return "旅行路径损坏。"
	if str(travel.route_path[0]) != World.CAMP_ID or str(travel.route_path[-1]) != "loc_granary":
		return "旅行路径端点损坏。"
	if not travel.edge_ids is Array or travel.edge_ids.size() != travel.route_path.size() - 1:
		return "旅行边记录损坏。"
	for i in range(travel.route_path.size() - 1):
		var from_id := str(travel.route_path[i])
		var to_id := str(travel.route_path[i + 1])
		if not World.has_edge(from_id, to_id) or str(travel.edge_ids[i]) != "%s>%s" % [from_id, to_id]:
			return "旅行路径包含未知连线。"
	var expected_path: Array = World.route_path(str(travel.route_id))
	var expected_event_step: int = 1 if expected_path.size() > 2 else expected_path.size() - 1
	if str(c.expedition.get("event_id", "")) == "event_granary_stores":
		expected_event_step = expected_path.size() - 1
	elif str(c.expedition.get("event_id", "")) == "event_bell_at_bridge":
		expected_path = [World.CAMP_ID, "loc_ferry_crossing", "loc_bridgehead", "loc_ferry_crossing", "loc_granary"] if str(travel.route_id) == "road" else [World.CAMP_ID, "loc_ridge_pass", "loc_bridgehead", "loc_ridge_pass", "loc_hunter_edge", "loc_granary"]
		expected_event_step = 2
	if travel.route_path != expected_path or int(travel.event_step) != expected_event_step:
		return "旅行路径与已保存事件不一致。"
	if not _is_integer(travel.current_edge_index, 0, travel.route_path.size() - 1) or not _is_integer(travel.event_step, 1, travel.route_path.size() - 1):
		return "旅行推进索引损坏。"
	if not _is_integer(travel.food_cost, 0, MAX_SAFE_JSON_INT) or not _is_integer(travel.days, 1, MAX_SAFE_JSON_INT):
		return "旅行代价损坏。"
	if str(world.company_location_id) != str(travel.route_path[int(travel.current_edge_index)]):
		return "公司位置与旅行索引不一致。"
	if not travel.event_instance_id is String or str(travel.event_instance_id) != "%s:%s" % [expedition_id, str(c.expedition.event_id)]:
		return "旅行事件实例编号不一致。"
	if not c.event.is_empty():
		if str(c.event.get("event_instance_id", "")) != str(travel.event_instance_id) or str(c.event.get("scope", "")) != "travel" or str(c.event.get("content_version", "")) != World.CONTENT_VERSION:
			return "事件实例元数据损坏。"
		if str(c.event.get("location_id", "")) != str(travel.route_path[int(travel.event_step)]):
			return "事件地点与旅行路径不一致。"
	elif phase in ["travel", "event", "ready", "battle"]:
		return "活动旅行缺少已保存事件。"
	var expected_status: String = str({"travel": "traveling", "event": "event", "ready": "ready", "battle": "battle", "growth": "returning", "returning": "returning"}.get(phase, ""))
	if str(travel.status) != expected_status:
		return "旅行状态与战役阶段不一致。"
	var resolved: bool = str(travel.event_instance_id) in world.resolved_event_instance_ids
	var step: int = int(travel.current_edge_index)
	var event_step: int = int(travel.event_step)
	if phase == "event" and (resolved or step != event_step):
		return "事件阶段与旅行节点不一致。"
	if phase == "travel" and ((step < event_step and resolved) or (step >= event_step and not resolved)):
		return "旅行进度与事件解决记录不一致。"
	if phase in ["ready", "battle", "growth", "returning"] and (not resolved or step != travel.route_path.size() - 1):
		return "后续阶段缺少事件解决记录。"
	if resolved and not c.event.is_empty():
		var selected_problem: String = _validate_event(c.event, true)
		if not selected_problem.is_empty():
			return selected_problem
	if phase in ["travel", "event", "ready", "battle"] and c.claimed.has(expedition_id):
		return "未结算契约错误标记为已领取。"
	if phase in ["growth", "returning"] and not c.claimed.has(expedition_id):
		return "返营阶段缺少唯一结算记录。"
	return ""

static func _unique_path_locations_are_known(path: Array) -> bool:
	# Repeated locations are intentional on the bridge detour; every entry must
	# still be a stable known location ID.
	for location_id in path:
		if not location_id is String or not World.has_location(str(location_id)):
			return false
	return true

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
	if not _is_integer(b.get("schema", null), 1, 1) or not str(b.get("rules_version", "")) in [BATTLE_RULES_VERSION, CHARACTER_BATTLE_RULES_VERSION, PREVIOUS_BATTLE_RULES_VERSION, LEGACY_BATTLE_RULES_VERSION, ORIGINAL_BATTLE_RULES_VERSION]:
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
	if str(b.rules_version) in [BATTLE_RULES_VERSION, CHARACTER_BATTLE_RULES_VERSION]:
		for unit: Dictionary in b.units:
			if not unit.has_all(["defense", "melee_skill", "ranged_skill", "level", "background_name", "capability_tags"]):
				return "新版战斗缺少人物属性快照。"
			if not unit.capability_tags is Array or not _unique_strings(unit.capability_tags):
				return "新版战斗能力快照损坏。"
			for key in ["defense", "melee_skill", "ranged_skill"]:
				if not _is_integer(unit.get(key, null), -100000, 100000):
					return "新版战斗人物属性快照损坏。"
			if not _is_integer(unit.get("level", null), 1, 1000) or not unit.background_name is String:
				return "新版战斗人物元数据损坏。"
	if b.order.size() != b.units.size() or not _unique_nonempty_strings(b.order):
		return "战斗行动顺序损坏。"
	var unit_ids: Dictionary = {}
	var occupied: Dictionary = {}
	for unit: Dictionary in b.units:
		var unit_id: String = str(unit.id)
		unit_ids[unit_id] = true
		if not _is_integer(unit.q, 0, int(b.width) - 1) or not _is_integer(unit.r, 0, int(b.height) - 1):
			return "战斗单位位置越界。"
		if int(unit.hp) > 0 and not bool(unit.get("escaped", false)):
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
	if str(b.rules_version) == BATTLE_RULES_VERSION:
		return _validate_tactical(b)
	return ""

static func _validate_tactical(b: Dictionary) -> String:
	if not _is_integer(b.get("casualty_rng_state"), 1, RNG_MAX) or not b.get("casualties") is Array:
		return "伤亡随机记录损坏。"
	for cell: Dictionary in b.cells.values():
		if cell.get("terrain", "") not in ["flat", "mud", "rubble"] or not _is_integer(cell.get("elevation"), 0, 1):
			return "地形或高度损坏。"
	var units := {}
	for unit: Dictionary in b.units:
		units[str(unit.id)] = unit
		if not _is_integer(unit.get("max_fatigue"), 1, 100000) or not _is_integer(unit.get("fatigue"), 0, int(unit.max_fatigue)):
			return "疲劳状态损坏。"
		if not _is_integer(unit.get("morale"), 0, 4) or not _is_integer(unit.get("resolve"), 0, 100):
			return "士气状态损坏。"
		if not unit.get("incapacitated") is bool or not unit.get("escaped") is bool:
			return "作战资格状态损坏。"
		if bool(unit.incapacitated) != (int(unit.hp) <= 0) or (bool(unit.escaped) and bool(unit.incapacitated)):
			return "伤亡和撤离状态矛盾。"
	var seen := {}
	if b.get("mission", {}).get("contract_kind", "") == "evacuation":
		var objective = b.get("objective")
		if not objective is Dictionary or objective.get("kind", "") != "evacuation" or not objective.get("participant_ids") is Array or not objective.get("evacuated_ids") is Array:
			return "撤离目标缺失。"
		if not _unique_nonempty_strings(objective.participant_ids) or not _unique_strings(objective.evacuated_ids) or not _is_integer(objective.get("required_count"), 1, 2):
			return "撤离目标计数损坏。"
		var actual: Array = []
		for unit: Dictionary in b.units:
			if unit.team == "player": actual.append(str(unit.id))
		if actual.size() != objective.participant_ids.size() or int(objective.required_count) != mini(2, actual.size()):
			return "撤离目标与出战名单不符。"
		for id in objective.participant_ids:
			if str(id) not in actual: return "撤离目标引用未知队员。"
		for id in objective.evacuated_ids:
			if str(id) not in actual or not units[str(id)].get("escaped", false) or int(units[str(id)].q) != int(b.width) - 1:
				return "撤离进度没有真实出口记录。"
	for record in b.casualties:
		if not record is Dictionary or not units.has(str(record.get("unit_id", ""))) or seen.has(str(record.get("unit_id", ""))):
			return "伤亡人物记录损坏。"
		seen[str(record.unit_id)] = true
		if str(record.get("id", "")).is_empty() or str(record.get("battle_id", "")) != str(b.id) or not _is_integer(record.get("roll"), 0, 99):
			return "伤亡判定损坏。"
		if record.get("status", "") not in ["pending", "survived", "dead", "enemy_incapacitated"]:
			return "伤亡结果损坏。"
		if not str(b.outcome).is_empty() and record.status == "pending":
			return "终局伤亡未结算。"
	return ""

static func _valid_units(units: Array, expected_team: String = "") -> bool:
	var ids: Dictionary = {}
	for raw_unit in units:
		if not raw_unit is Dictionary:
			return false
		var unit: Dictionary = raw_unit
		if not Appearance.validate(unit).is_empty():
			return false
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
