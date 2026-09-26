extends RefCounted
## Static world content for the first playable map. Campaign state stores only IDs.

const SCHEMA := 1
const CONTENT_VERSION := "world-0.1"
const CAMP_ID := "loc_greyshore_camp"
const CONTRACT_ID := "contract_rain_granary"
const EVACUATION_ID := "contract_river_evacuation"
const SHORT_WORK_ID := "contract_short_work"
const CONTRACT_IDS := [CONTRACT_ID, EVACUATION_ID, SHORT_WORK_ID]

const LOCATIONS: Array[Dictionary] = [
	{"id": CAMP_ID, "name": "灰岸营地", "description": "佣兵团休养、补给与补员的固定落脚处。", "x": 0.13, "y": 0.72, "kind": "camp"},
	{"id": "loc_ferry_crossing", "name": "泥岸渡口", "description": "旧道从渡口通往粮仓，来往货工也提供缺粮时的恢复通路。", "x": 0.31, "y": 0.52, "kind": "crossing"},
	{"id": "loc_ridge_pass", "name": "碎石山脊", "description": "险径入口；多带一份口粮，换取油料与更高报酬。", "x": 0.33, "y": 0.22, "kind": "pass"},
	{"id": "loc_hunter_edge", "name": "雾林边缘", "description": "断绳、车辙与猎犬足迹汇在林边。", "x": 0.57, "y": 0.25, "kind": "wilds"},
	{"id": "loc_granary", "name": "雨夜粮仓", "description": "当前唯一契约战场；粮袋能否保住取决于战斗结果。", "x": 0.79, "y": 0.54, "kind": "contract"},
	{"id": "loc_bridgehead", "name": "裂钟桥头", "description": "第三次远征时，裂钟的去向在这里收束。", "x": 0.56, "y": 0.76, "kind": "landmark"}
]

const EDGES: Array[Dictionary] = [
	{"from": CAMP_ID, "to": "loc_ferry_crossing"},
	{"from": CAMP_ID, "to": "loc_ridge_pass"},
	{"from": CAMP_ID, "to": "loc_hunter_edge"},
	{"from": "loc_ferry_crossing", "to": "loc_bridgehead"},
	{"from": "loc_ferry_crossing", "to": "loc_granary"},
	{"from": "loc_ridge_pass", "to": "loc_bridgehead"},
	{"from": "loc_ridge_pass", "to": "loc_hunter_edge"},
	{"from": "loc_hunter_edge", "to": "loc_granary"}
]

const ROUTE_PATHS := {
	"road": [CAMP_ID, "loc_ferry_crossing", "loc_granary"],
	"ridge": [CAMP_ID, "loc_ridge_pass", "loc_hunter_edge", "loc_granary"]
}

static func new_world() -> Dictionary:
	return {
		"schema": SCHEMA,
		"content_version": CONTENT_VERSION,
		"company_location_id": CAMP_ID,
		"discovered_location_ids": [CAMP_ID, "loc_ferry_crossing", "loc_ridge_pass"],
		"active_contract_id": "",
		"travel": {},
		"location_states": {},
		"pending_effects": [],
		"resolved_event_instance_ids": []
	}

static func has_location(location_id: String) -> bool:
	for location: Dictionary in LOCATIONS:
		if str(location.id) == location_id:
			return true
	return false

static func has_edge(from_id: String, to_id: String) -> bool:
	for edge: Dictionary in EDGES:
		if (str(edge.from) == from_id and str(edge.to) == to_id) or (str(edge.from) == to_id and str(edge.to) == from_id):
			return true
	return false

static func route_path(route_id: String) -> Array:
	return ROUTE_PATHS.get(route_id, []).duplicate()
