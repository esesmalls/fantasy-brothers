extends SceneTree
const Battle = preload("res://core/battle_rules.gd")
const Campaign = preload("res://core/campaign_rules.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	for version: String in ["prototype-0.1.6", "prototype-0.1.1"]:
		for map_id: String in ["granary_bank", "ridge_road"]:
			var b := Battle.create_battle(Campaign.create_campaign("free", 9213).roster, 9213, {"rules_version": version, "map_id": map_id})
			for unit: Dictionary in b.units:
				b.turn_index = b.order.find(unit.id)
				for ap: int in [0, 2, 4, 6]:
					unit.ap = ap
					for fatigue_remaining: int in [0, 7, 100]:
						if version == "prototype-0.1.6": unit.fatigue = maxi(0, int(unit.max_fatigue) - fatigue_remaining)
						var before := JSON.stringify(b)
						var expected: Array = []
						for q in range(int(b.width)):
							for r in range(int(b.height)):
								if Battle.preview(b, str(unit.id), "move", {"q": q, "r": r}).ok: expected.append({"q": q, "r": r})
						checks += 1
						if Battle.movement_reachable(b, str(unit.id)) != expected:
							failures.append("overlay/preview mismatch %s %s %s ap=%d fatigue=%d" % [version, map_id, unit.id, ap, fatigue_remaining])
						checks += 1
						if JSON.stringify(b) != before: failures.append("overlay changes rules state")
			b.outcome = "victory"
			checks += 1
			if not Battle.movement_reachable(b, str(b.units[0].id)).is_empty(): failures.append("terminal move overlay must be empty")
	print("Movement overlay: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
