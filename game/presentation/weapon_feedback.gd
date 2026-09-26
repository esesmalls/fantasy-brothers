extends Node
## Presentation-only weapon audio. The caller supplies settled outcome and material.
## No combat method, battle state, or rule RNG is read here.

const AUDIO_ROOT := "res://assets/audio/weapon/"
const CUES := {
	"blade_prepare": "blade_prepare.ogg",
	"blade_light_release": "blade_light_release.wav",
	"blade_heavy_release": "blade_heavy_release.wav",
	"blade_light_recover": "blade_light_recover.wav",
	"spear_release": "spear_release.wav",
	"bow_prepare": "bow_prepare.wav",
	"bow_draw": "bow_draw.wav",
	"bow_release": "bow_release.wav",
	"cloth_prepare": "cloth_prepare.ogg",
	"cloth_recover": "cloth_recover.ogg",
	"metal_recover": "metal_recover.ogg",
	"flesh_light": "flesh_light.ogg",
	"flesh_heavy": "flesh_heavy.ogg",
	"armor_light": "armor_light.ogg",
	"armor_heavy": "armor_heavy.ogg",
	"shield_contact": "shield_contact.ogg",
	"miss_result": "miss_result.wav",
}
const WEAPON_TYPES := {
	"weapon_guard_sword": "light_sword", "weapon_skirmisher_blade": "light_sword",
	"weapon_guard_cleaver": "heavy_blade", "weapon_skirmisher_axe": "heavy_blade",
	"weapon_spear_long": "spear", "weapon_spear_hooked": "spear",
	"weapon_archer_bow": "bow", "weapon_archer_longbow": "bow",
	"weapon_hunter_bow": "bow", "weapon_hunter_recurve": "bow",
	"shield_bash": "shield", "shield": "shield",
}

var _voices: Array[AudioStreamPlayer] = []
var _voice_phases: Dictionary = {}
var _next_voice := 0


static func weapon_type(weapon_id: String) -> String:
	return str(WEAPON_TYPES.get(weapon_id, weapon_id if weapon_id in ["light_sword", "heavy_blade", "spear", "bow", "shield"] else "light_sword"))


## Fractions are presentation guidance for a new authored action. Existing published
## release/contact event markers remain authoritative when present.
static func action_template(weapon_id: String) -> Dictionary:
	var kind := weapon_type(weapon_id)
	var entries := {
		"light_sword": {"duration": 0.76, "prepare": 0.05, "release": 0.25, "contact": 0.43, "recover": 0.60,
			"intent": "短预备、快切入、短回收；剑尖方向先于命中反馈"},
		"heavy_blade": {"duration": 1.05, "prepare": 0.05, "release": 0.40, "contact": 0.62, "recover": 0.79,
			"intent": "明显蓄势、厚重接触、慢回收；斧刃落点可辨"},
		"spear": {"duration": 0.83, "prepare": 0.08, "release": 0.29, "contact": 0.48, "recover": 0.66,
			"intent": "沿目标方向直刺、短停顿、撤枪"},
		"bow": {"duration": 1.42, "prepare": 0.06, "release": 0.45, "contact": 0.75, "recover": 0.86,
			"intent": "搭箭拉弦并瞄准；离弦和远端接触是两个独立瞬间"},
		"shield": {"duration": 0.66, "prepare": 0.06, "release": 0.30, "contact": 0.47, "recover": 0.69,
			"intent": "盾面迎敌、格挡接触、短反冲回位"},
	}
	return entries[kind].duplicate(true)


## Derive a first-pass schema-5 action from an existing published sword/spear/bow
## action. Call only for an unedited weapon action; hand-authored published actions
## win. Base asset positions, pivots, masks, anchors, and appearance are untouched.
static func authored_action(base_action: Dictionary, weapon_id: String, kind: String) -> Dictionary:
	if base_action.is_empty(): return {}
	var weapon := "shield" if kind == "shield_bash" else weapon_type(weapon_id)
	var timing := action_template(weapon)
	var result := base_action.duplicate(true)
	var duration := float(timing.duration)
	result["id"] = ("shield_bash_" if weapon == "shield" else "attack_") + weapon_id
	result["duration"] = duration
	result["events"] = [
		{"id": "release", "time": duration * float(timing.release)},
		{"id": "contact", "time": duration * float(timing.contact)},
	]
	if weapon == "shield":
		# The shield itself presents toward the threat and rebounds. No sword track
		# is retained, so a bash never reads as an invisible sword strike.
		result.erase("legacy_action")
		result.erase("legacy_weapon")
		result["tracks"] = [
			_shield_track("x", duration, timing, [0.0, -5.0, 10.0, 12.0, 3.0, 0.0]),
			_shield_track("rotation", duration, timing, [0.0, -9.0, 16.0, 10.0, 4.0, 0.0]),
		]
		return result
	var old_duration := maxf(0.01, float(base_action.get("duration", 1.0)))
	var old_release := 0.25
	var old_contact := 0.42
	for marker: Dictionary in base_action.get("events", []):
		if str(marker.get("id", "")) == "release": old_release = float(marker.get("time", 0.0)) / old_duration
		if str(marker.get("id", "")) == "contact": old_contact = float(marker.get("time", 0.0)) / old_duration
	var old_recover := 0.64 if weapon != "bow" else 0.80
	for track: Dictionary in result.get("tracks", []):
		for key: Dictionary in track.get("keys", []):
			var old_fraction := float(key.get("time", 0.0)) / old_duration
			key["time"] = duration * _remap_phase(old_fraction, old_release, old_contact, old_recover, timing)
			if weapon == "heavy_blade":
				var property_id := str(track.get("property", ""))
				if property_id in ["x", "rotation"] and old_fraction > 0.0 and old_fraction < 0.99:
					key["value"] = float(key.get("value", 0.0)) * (1.20 if property_id == "x" else 1.16)
	var legacy: Dictionary = result.get("legacy_action", {})
	if not legacy.is_empty():
		legacy["duration"] = duration
		legacy["release"] = float(timing.release)
		legacy["contact"] = float(timing.contact)
		for key: Dictionary in legacy.get("keyframes", []):
			key["t"] = _remap_phase(float(key.get("t", 0.0)), old_release, old_contact, old_recover, timing)
	return result


static func _remap_phase(fraction: float, old_release: float, old_contact: float, old_recover: float, timing: Dictionary) -> float:
	var old_stops := [0.0, old_release, old_contact, old_recover, 1.0]
	var new_stops := [0.0, float(timing.release), float(timing.contact), float(timing.recover), 1.0]
	for index in range(4):
		if fraction <= float(old_stops[index + 1]):
			var weight := clampf(inverse_lerp(float(old_stops[index]), float(old_stops[index + 1]), fraction), 0.0, 1.0)
			return lerpf(float(new_stops[index]), float(new_stops[index + 1]), weight)
	return 1.0


static func _shield_track(property_id: String, duration: float, timing: Dictionary, values: Array[float]) -> Dictionary:
	var fractions := [0.0, float(timing.release), float(timing.contact), float(timing.contact) + 0.10, float(timing.recover), 1.0]
	var labels := ["rest", "brace", "contact", "rebound", "recover", "return"]
	var keys := []
	for index in range(values.size()):
		keys.append({"id": "shield_bash.%s.%s" % [labels[index], property_id], "interpolation": "smooth", "time": duration * fractions[index], "value": values[index]})
	return {"target": "shield", "property": property_id, "keys": keys}

static func defend_action() -> Dictionary:
	var timing := action_template("shield")
	return {"id": "defend_shield", "duration": 0.5, "events": [], "tracks": [
		_shield_track("x", 0.5, timing, [0.0, 6.0, -4.0, 1.0, 5.0, 6.0]),
		_shield_track("rotation", 0.5, timing, [0.0, -8.0, 7.0, -3.0, -5.0, -5.0])]}


static func cue_for(weapon_id: String, phase: String, outcome: String = "hit", material: String = "flesh") -> String:
	var kind := weapon_type(weapon_id)
	if phase == "contact" or phase == "result":
		if outcome == "miss": return "miss_result"
		if outcome == "block" or material == "block": return "shield_contact"
		if material == "armor": return "armor_heavy" if kind == "heavy_blade" or kind == "shield" else "armor_light"
		return "flesh_heavy" if kind == "heavy_blade" or kind == "shield" else "flesh_light"
	match phase:
		"prepare":
			if kind == "bow": return "bow_prepare"
			if kind == "spear" or kind == "shield": return "cloth_prepare"
			return "blade_prepare"
		"aim":
			return "bow_draw" if kind == "bow" else ""
		"flight":
			# Quiet recorded air movement used as arrow-flight foley.
			return "spear_release" if kind == "bow" else ""
		"release":
			match kind:
				"light_sword": return "blade_light_release"
				"heavy_blade": return "blade_heavy_release"
				"spear": return "spear_release"
				"bow": return "bow_release"
				"shield": return "cloth_prepare"
		"recover":
			return "metal_recover" if kind == "heavy_blade" or kind == "shield" else ("cloth_recover" if kind == "bow" or kind == "spear" else "blade_light_recover")
	return ""


static func cue_path(cue_id: String) -> String:
	return AUDIO_ROOT + str(CUES[cue_id]) if CUES.has(cue_id) else ""


static func should_play_phase(weapon_id: String, phase: String, speed: float) -> bool:
	if speed <= 0.001: return phase == "result"
	if speed < 1.75: return true
	# At 2× the defining release and contact still sound at their true pitch. Drop
	# only small handling cues to keep the short timeline legible.
	if phase == "recover": return false
	if phase == "prepare" and weapon_type(weapon_id) == "light_sword": return false
	return true


## Call with published action markers and already-settled event classification.
## The caller owns timing. This method never changes AudioStreamPlayer.pitch_scale.
func play_cue(weapon_id: String, phase: String, outcome: String = "hit", material: String = "flesh", speed: float = 1.0) -> String:
	if not should_play_phase(weapon_id, phase, speed): return ""
	var cue_id := cue_for(weapon_id, phase, outcome, material)
	var path := cue_path(cue_id)
	if path.is_empty(): return ""
	if not is_inside_tree(): return cue_id
	var stream := load(path) as AudioStream
	if stream == null:
		push_warning("Weapon feedback cue could not load: " + path)
		return ""
	var player := _available_voice()
	player.stop()
	player.stream = stream
	player.pitch_scale = 1.0
	player.volume_db = -6.0 if phase == "prepare" or phase == "recover" or phase == "aim" else -3.0
	if phase == "flight": player.volume_db = -20.0
	_voice_phases[player.get_instance_id()] = phase
	player.play()
	return cue_id


## During skip, discard only process cues; preserve one concise result cue.
func skip_to_result(weapon_id: String, outcome: String, material: String = "flesh") -> String:
	for player in _voices:
		player.stop()
	return play_cue(weapon_id, "result", outcome, material, 0.0)


func stop_process_sounds() -> void:
	for player in _voices:
		if str(_voice_phases.get(player.get_instance_id(), "")) != "result" and str(_voice_phases.get(player.get_instance_id(), "")) != "contact":
			player.stop()


func _available_voice() -> AudioStreamPlayer:
	for player in _voices:
		if not player.playing: return player
	if _voices.size() < 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)
		return player
	var player := _voices[_next_voice % _voices.size()]
	_next_voice += 1
	return player
