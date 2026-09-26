extends RefCounted
# First playable values; all tactical tuning lives here, not in presentation.
const VERSION = "prototype-0.1.6"
const TERRAIN_AP = {"flat": 2, "mud": 3, "rubble": 3}
const TERRAIN_FATIGUE = {"flat": 4, "mud": 8, "rubble": 6}
const CLIMB_AP = 1
const CLIMB_FATIGUE = 3
const FATIGUE_COST = {"attack": 12, "shield_bash": 16, "push": 10, "defend": 8, "mark": 6, "oil": 10, "fire": 10, "water": 10, "rally": 10}
const TURN_RECOVERY = 15
const RECOVER_AMOUNT = 30
const MORALE_NAMES = ["溃逃", "崩溃", "动摇", "稳定", "振奋"]
const MORALE_HIT = [-20, -15, -5, 0, 5]
const MORALE_WITNESS_RANGE = 3
const HIGH_MELEE_HIT = 10
const HIGH_RANGED_HIT = 10
const SURVIVAL_CHANCE = 65

static func initialize(s: Dictionary) -> void:
	s.map_id = str(s.mission.get("map_id", "granary_bank"))
	if s.map_id not in ["granary_bank", "ridge_road"]:
		s.map_id = "granary_bank"
	s.casualty_rng_state = posmod(int(s.seed) + 7919, 2147483646) + 1
	s.casualties = []
	s.morale_checks = {}
	s.terminal_data = {}
	if str(s.mission.get("contract_kind", "")) == "evacuation":
		var participants: Array = []
		for u in s.units:
			if u.team == "player":
				participants.append(str(u.id))
		s.objective = {"kind": "evacuation", "required_count": mini(2, participants.size()),
			"participant_ids": participants, "evacuated_ids": []}
	for cell in s.cells.values():
		cell.terrain = "flat"
		cell.elevation = 0
	var mud = ["3,0", "4,0", "5,0", "6,0", "6,5", "7,5"]
	var rubble = ["7,1", "7,2", "7,3"]
	var high = ["7,1", "7,2", "7,3", "8,1", "8,2", "8,3"]
	if s.map_id == "ridge_road":
		mud = ["3,4", "3,5", "4,5"]
		rubble = ["4,0", "4,1", "4,2", "4,3", "5,3"]
		high = ["4,0", "4,1", "4,2", "5,0", "5,1", "5,2", "6,0", "6,1"]
	for key in mud:
		s.cells[key].terrain = "mud"
	for key in rubble:
		s.cells[key].terrain = "rubble"
	for key in high:
		s.cells[key].elevation = 1
	for u in s.units:
		u.equipment_burden = maxi(0, int(u.get("equipment_burden", 0)))
		u.max_fatigue = maxi(30, int(u.get("max_fatigue", 100)))
		u.fatigue = 0
		u.initiative = int(u.get("initiative", 100))
		u.resolve = clampi(int(u.get("resolve", 55)), 5, 95)
		u.morale = 3
		u.incapacitated = false
		u.escaped = false

static func step_cost(s: Dictionary, aq: int, ar: int, q: int, r: int) -> int:
	var cell: Dictionary = s.cells[str(q) + "," + str(r)]
	var from: Dictionary = s.cells[str(aq) + "," + str(ar)]
	return int(TERRAIN_AP.get(cell.get("terrain", "flat"), 2)) + (CLIMB_AP if int(cell.get("elevation", 0)) > int(from.get("elevation", 0)) else 0)

static func step_fatigue(s: Dictionary, u: Dictionary, aq: int, ar: int, q: int, r: int) -> int:
	var cell: Dictionary = s.cells[str(q) + "," + str(r)]
	var from: Dictionary = s.cells[str(aq) + "," + str(ar)]
	return int(TERRAIN_FATIGUE.get(cell.get("terrain", "flat"), 4)) + int(u.get("equipment_burden", 0)) / 10 + (CLIMB_FATIGUE if int(cell.get("elevation", 0)) > int(from.get("elevation", 0)) else 0)

static func initiative_score(u: Dictionary) -> int:
	return int(u.get("initiative", 100)) - int(u.get("equipment_burden", 0)) - int(u.get("fatigue", 0))
