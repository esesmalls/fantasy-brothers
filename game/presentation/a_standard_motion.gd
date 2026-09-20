extends RefCounted
## Read-only seconds-based motion profiles. Contact compression, an actual fixed
## hold, rebound and recovery are separate. This clock never settles damage.

const PROFILES := {
	"sword": [0.84, 0.24, 0.38, 0.025, 0.100, 0.055, 0.09],
	"cleaver": [1.08, 0.33, 0.50, 0.030, 0.145, 0.085, 0.15],
	"knife": [0.62, 0.15, 0.26, 0.020, 0.060, 0.045, 0.06],
	"axe": [1.00, 0.31, 0.47, 0.030, 0.130, 0.075, 0.17],
	"spear": [0.82, 0.25, 0.40, 0.025, 0.090, 0.065, 0.08],
	"hook": [0.93, 0.27, 0.43, 0.030, 0.115, 0.085, 0.11],
	"bow": [0.98, 0.31, 0.66, 0.015, 0.055, 0.055, 0.03],
	"longbow": [1.12, 0.39, 0.77, 0.020, 0.070, 0.060, 0.04],
	"hunter_bow": [0.91, 0.28, 0.61, 0.015, 0.050, 0.050, 0.03],
	"recurve": [0.87, 0.26, 0.58, 0.015, 0.045, 0.045, 0.03],
	"shield_bash": [0.78, 0.22, 0.36, 0.035, 0.110, 0.065, 0.12],
	"bite": [0.68, 0.17, 0.29, 0.025, 0.085, 0.065, 0.12]
}
const FAMILIES := {
	"weapon_guard_sword": "sword", "weapon_guard_cleaver": "cleaver",
	"weapon_spear_long": "spear", "weapon_spear_hooked": "hook",
	"weapon_archer_bow": "bow", "weapon_archer_longbow": "longbow",
	"weapon_skirmisher_blade": "knife", "weapon_skirmisher_axe": "axe",
	"weapon_hunter_bow": "hunter_bow", "weapon_hunter_recurve": "recurve"
}

static func family(weapon: String) -> String:
	return str(FAMILIES.get(weapon, "sword"))

static func is_bow(value: String) -> bool:
	return value in ["bow", "longbow", "hunter_bow", "recurve"]

static func timing(weapon: String, action: String = "attack") -> Dictionary:
	var kind := family(weapon)
	if action in ["shield_bash", "push", "bite"]:
		kind = "shield_bash" if action == "push" else action
	var values: Array = PROFILES[kind]
	var duration := float(values[0])
	if action in ["idle", "move", "hit", "defend", "downed", "death", "mark", "command"]:
		duration = float({"idle":1.6, "move":0.4, "hit":0.40, "defend":0.45, "downed":0.72, "death":0.72, "mark":0.55, "command":0.55}[action])
	var contact := float(values[2])
	var brake_end := contact + float(values[3])
	var hold_end := brake_end + float(values[4])
	return {"family":kind, "duration":duration, "wind_end":float(values[1]),
		"contact":contact, "brake_end":brake_end, "hold_end":hold_end,
		"rebound_end":hold_end + float(values[5]), "recoil":float(values[6]),
		"release":contact - 0.18 if is_bow(kind) else contact}

static func sample(weapon: String, action: String, progress: float, outcome: String = "hit") -> Dictionary:
	var data := timing(weapon, action)
	var t := clampf(progress, 0.0, 1.0) * float(data.duration)
	var result := {"phase":"待机", "wind":0.0, "drive":0.0, "resistance":0.0,
		"recoil":0.0, "holding":false, "seconds":t, "time":data,
		"weapon_front":action in ["attack", "slash", "thrust", "shoot", "shield_bash", "push", "bite"]}
	if not bool(result.weapon_front):
		return result
	if t < float(data.wind_end):
		result.phase = "预备"
		result.wind = smoothstep(0.0, float(data.wind_end), t)
	elif t < float(data.contact):
		result.phase = "出手"
		result.drive = smoothstep(float(data.wind_end), float(data.contact), t)
		result.wind = 1.0 - float(result.drive)
	elif outcome == "miss":
		result.phase = "落空回收"
		result.drive = 1.0 - smoothstep(float(data.contact), float(data.duration), t)
	elif t < float(data.brake_end):
		result.phase = "碰撞减速"
		result.drive = 1.0
		result.resistance = smoothstep(float(data.contact), float(data.brake_end), t)
	elif t < float(data.hold_end):
		result.phase = "命中停顿"
		result.drive = 1.0
		result.resistance = 1.0
		result.holding = true
	elif t < float(data.rebound_end):
		result.phase = "受阻回弹"
		var rebound := smoothstep(float(data.hold_end), float(data.rebound_end), t)
		result.drive = 1.0 - rebound * 0.18
		result.resistance = 1.0 - rebound
		result.recoil = rebound * float(data.recoil) * (1.7 if outcome == "block" else 1.0)
	else:
		result.phase = "收回"
		var recovery := smoothstep(float(data.rebound_end), float(data.duration), t)
		result.drive = 0.82 * (1.0 - recovery)
		result.recoil = float(data.recoil) * (1.0 - recovery)
	return result

static func target_response(weapon: String, action: String, progress: float, outcome: String = "hit") -> float:
	if outcome == "miss" or action not in ["attack", "slash", "thrust", "shoot", "shield_bash", "push", "bite"]:
		return 0.0
	var motion := sample(weapon, action, progress, outcome)
	var data: Dictionary = motion.time
	var t := float(motion.seconds)
	if t < float(data.contact):
		return 0.0
	if t < float(data.brake_end):
		return smoothstep(float(data.contact), float(data.brake_end), t)
	if t < float(data.hold_end):
		return 1.0
	return 1.0 - smoothstep(float(data.hold_end), float(data.duration), t)
