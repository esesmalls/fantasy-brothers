extends RefCounted
## Small, explicit 0.1.4 equipment set. Definitions are immutable; campaign
## inventories store stable instances that refer to these IDs.

const SCHEMA := 1
const BURDEN := {"armor_padded": 6, "armor_leather": 10, "armor_brigandine": 16, "armor_mail": 24,
	"weapon_guard_sword": 10, "weapon_guard_cleaver": 15, "weapon_spear_long": 8,
	"weapon_spear_hooked": 11, "weapon_archer_bow": 5, "weapon_archer_longbow": 9,
	"weapon_skirmisher_blade": 4, "weapon_skirmisher_axe": 10, "weapon_hunter_bow": 5, "weapon_hunter_recurve": 7}
const HUMAN_KINDS := ["guard", "spear", "archer", "skirmisher", "hunter"]

const DEFINITIONS := {
	"weapon_guard_sword": {
		"id": "weapon_guard_sword", "slot": "weapon", "name": "营团剑盾",
		"description": "剑盾流派：普通攻击射程1，并提供盾击与推开。属性修正为0。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "guard", "range": 1, "attack": 0, "accuracy": 0, "price": 18, "sell_price": 9
	},
	"weapon_guard_cleaver": {
		"id": "weapon_guard_cleaver", "slot": "weapon", "name": "重刃盾",
		"description": "剑盾流派：射程1并提供盾击与推开；攻击+3，基础命中-5。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "guard", "range": 1, "attack": 3, "accuracy": -5, "price": 38, "sell_price": 19
	},
	"weapon_spear_long": {
		"id": "weapon_spear_long", "slot": "weapon", "name": "营团长枪",
		"description": "长枪流派：普通攻击射程2，可利用破绽。属性修正为0。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "spear", "range": 2, "attack": 0, "accuracy": 0, "price": 17, "sell_price": 8
	},
	"weapon_spear_hooked": {
		"id": "weapon_spear_hooked", "slot": "weapon", "name": "钩刃长枪",
		"description": "长枪流派：射程2并可利用破绽；攻击+3，基础命中-6。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "spear", "range": 2, "attack": 3, "accuracy": -6, "price": 36, "sell_price": 18
	},
	"weapon_archer_bow": {
		"id": "weapon_archer_bow", "slot": "weapon", "name": "营团短弓",
		"description": "弓流派：普通攻击射程4。属性修正为0。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "archer", "range": 4, "attack": 0, "accuracy": 0, "price": 17, "sell_price": 8
	},
	"weapon_archer_longbow": {
		"id": "weapon_archer_longbow", "slot": "weapon", "name": "硬弦长弓",
		"description": "弓流派：普通攻击射程4；攻击+3，基础命中-7。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "archer", "range": 4, "attack": 3, "accuracy": -7, "price": 40, "sell_price": 20
	},
	"weapon_skirmisher_blade": {
		"id": "weapon_skirmisher_blade", "slot": "weapon", "name": "营团短刃",
		"description": "短兵流派：普通攻击射程1。属性修正为0。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "skirmisher", "range": 1, "attack": 0, "accuracy": 0, "price": 16, "sell_price": 8
	},
	"weapon_skirmisher_axe": {
		"id": "weapon_skirmisher_axe", "slot": "weapon", "name": "缺口手斧",
		"description": "短兵流派：普通攻击射程1；攻击+3，基础命中-6。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "skirmisher", "range": 1, "attack": 3, "accuracy": -6, "price": 34, "sell_price": 17
	},
	"weapon_hunter_bow": {
		"id": "weapon_hunter_bow", "slot": "weapon", "name": "猎团弓",
		"description": "猎弓流派：普通攻击射程3。战犬指令由已学驯兽能力提供。属性修正为0。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "hunter", "range": 3, "attack": 0, "accuracy": 0, "price": 17, "sell_price": 8
	},
	"weapon_hunter_recurve": {
		"id": "weapon_hunter_recurve", "slot": "weapon", "name": "林地反曲弓",
		"description": "猎弓流派：普通攻击射程3；攻击-2，基础命中+7。不会授予战犬指令。",
		"allowed_kinds": HUMAN_KINDS, "weapon_style": "hunter", "range": 3, "attack": -2, "accuracy": 7, "price": 38, "sell_price": 19
	},
	"armor_padded": {
		"id": "armor_padded", "slot": "armor", "name": "轻型衬甲",
		"description": "10点最大护甲。便宜的轻装选择。",
		"allowed_kinds": ["guard", "spear", "archer", "skirmisher", "hunter"], "armor": 10, "price": 18, "sell_price": 9
	},
	"armor_leather": {
		"id": "armor_leather", "slot": "armor", "name": "中型皮甲",
		"description": "14点最大护甲。在成本与防护间折中。",
		"allowed_kinds": ["guard", "spear", "archer", "skirmisher", "hunter"], "armor": 14, "price": 27, "sell_price": 13
	},
	"armor_brigandine": {
		"id": "armor_brigandine", "slot": "armor", "name": "中型钉甲",
		"description": "16点最大护甲。比中型皮甲多2点防护。",
		"allowed_kinds": ["guard", "spear", "archer", "skirmisher", "hunter"], "armor": 16, "price": 34, "sell_price": 17
	},
	"armor_mail": {
		"id": "armor_mail", "slot": "armor", "name": "重型链甲",
		"description": "24点最大护甲。防护最高，也占用最多整备资金。",
		"allowed_kinds": ["guard", "spear", "archer", "skirmisher", "hunter"], "armor": 24, "price": 50, "sell_price": 25
	}
}

const SHOP_ORDER: Array[String] = [
	"weapon_guard_cleaver", "weapon_spear_hooked", "weapon_archer_longbow",
	"weapon_skirmisher_axe", "weapon_hunter_recurve",
	"armor_padded", "armor_leather", "armor_brigandine", "armor_mail"
]

const BASIC_WEAPON := {
	"guard": "weapon_guard_sword", "spear": "weapon_spear_long",
	"archer": "weapon_archer_bow", "skirmisher": "weapon_skirmisher_blade",
	"hunter": "weapon_hunter_bow"
}

const BASIC_ARMOR := {
	"guard": "armor_mail", "spear": "armor_brigandine",
	"archer": "armor_padded", "skirmisher": "armor_leather",
	"hunter": "armor_leather"
}

static func get_definition(definition_id: String) -> Dictionary:
	var result: Dictionary = DEFINITIONS.get(definition_id, {}).duplicate(true)
	if not result.is_empty():
		result.burden = int(BURDEN.get(definition_id, 0))
	return result

static func loadout_burden(loadout: Dictionary) -> int:
	return int(BURDEN.get(loadout.get("weapon", ""), 0)) + int(BURDEN.get(loadout.get("armor", ""), 0))

static func is_definition(definition_id: String) -> bool:
	return DEFINITIONS.has(definition_id)

static func basic_weapon(kind: String) -> String:
	return str(BASIC_WEAPON.get(kind, ""))

static func basic_armor(kind: String) -> String:
	return str(BASIC_ARMOR.get(kind, ""))
