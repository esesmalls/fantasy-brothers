extends RefCounted
## Immutable 0.1.5 character definitions. Campaign saves keep stable IDs and
## source totals; this file only supplies definitions and shared limits.

const SCHEMA := 1
const RULES_VERSION := "character-0.1.5"
const MAX_LEVEL := 8
const XP_PER_LEVEL := 100
const ATTRIBUTE_POINTS_PER_LEVEL := 2
const TRAINING_CREDIT_CAP := 3

const STAT_ORDER: Array[String] = ["vitality", "melee_skill", "ranged_skill", "defense"]
const STAT_DEFINITIONS := {
	"vitality": {
		"id": "vitality", "name": "体魄", "description": "提高最大生命，已有伤势保留。",
		"upgrade_amount": 6, "training_amount": 2, "cap": 100
	},
	"melee_skill": {
		"id": "melee_skill", "name": "近战技艺", "description": "使用剑盾、长枪与短兵时的基础命中。",
		"upgrade_amount": 4, "training_amount": 2, "cap": 110
	},
	"ranged_skill": {
		"id": "ranged_skill", "name": "远程技艺", "description": "使用短弓、长弓与猎弓时的基础命中。",
		"upgrade_amount": 4, "training_amount": 2, "cap": 110
	},
	"defense": {
		"id": "defense", "name": "防御", "description": "直接降低敌人对该人物的最终命中率。",
		"upgrade_amount": 3, "training_amount": 1, "cap": 40
	}
}

const BACKGROUNDS := {
	"caravan_guard": {
		"id": "caravan_guard", "name": "商路护卫", "description": "早年守过商队，熟悉盾阵和近身缠斗。",
		"stats": {"vitality": 58, "melee_skill": 88, "ranged_skill": 88, "defense": 8}, "capabilities": []
	},
	"militia_spearman": {
		"id": "militia_spearman", "name": "乡镇民兵", "description": "受过长枪队列操练，习惯在阵线后方保持距离。",
		"stats": {"vitality": 48, "melee_skill": 88, "ranged_skill": 88, "defense": 5}, "capabilities": []
	},
	"village_bowyer": {
		"id": "village_bowyer", "name": "村镇弓手", "description": "靠狩猎和守望练出稳定手感，仍可转练近战。",
		"stats": {"vitality": 40, "melee_skill": 86, "ranged_skill": 86, "defense": 3}, "capabilities": []
	},
	"road_scout": {
		"id": "road_scout", "name": "道路斥候", "description": "长期走险路，擅长轻装接敌和寻找退路。",
		"stats": {"vitality": 46, "melee_skill": 88, "ranged_skill": 88, "defense": 5}, "capabilities": []
	},
	"woodland_hunter": {
		"id": "woodland_hunter", "name": "林地猎人", "description": "懂得辨认兽迹并与驯养战犬协同。",
		"stats": {"vitality": 46, "melee_skill": 88, "ranged_skill": 88, "defense": 4},
		"capabilities": ["tracking", "beast_handler"]
	},
	"warhound": {
		"id": "warhound", "name": "驯养战犬", "description": "受训的战犬；成长和装备规则与人类队员分开。",
		"stats": {"vitality": 40, "melee_skill": 90, "ranged_skill": 90, "defense": 4}, "capabilities": ["war_dog"]
	}
}

const KIND_BACKGROUNDS := {
	"guard": "caravan_guard", "spear": "militia_spearman", "archer": "village_bowyer",
	"skirmisher": "road_scout", "hunter": "woodland_hunter", "dog": "warhound"
}

const BASE_ATTACK := {"guard": 12, "spear": 15, "archer": 14, "skirmisher": 15, "hunter": 13, "dog": 12}
const CAPABILITY_NAMES := {
	"tracking": "追踪知识", "beast_handler": "驯兽指挥", "war_dog": "战犬"
}

static func background_for_kind(kind: String) -> String:
	return str(KIND_BACKGROUNDS.get(kind, "caravan_guard"))

static func background(background_id: String) -> Dictionary:
	return BACKGROUNDS.get(background_id, {})

static func stat(stat_id: String) -> Dictionary:
	return STAT_DEFINITIONS.get(stat_id, {})

static func xp_next(level: int) -> int:
	return mini(MAX_LEVEL - 1, maxi(1, level)) * XP_PER_LEVEL

static func level_for_xp(xp: int) -> int:
	return clampi(1 + int(maxi(0, xp) / XP_PER_LEVEL), 1, MAX_LEVEL)
