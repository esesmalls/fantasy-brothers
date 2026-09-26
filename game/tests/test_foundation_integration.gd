extends SceneTree
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Appearance = preload("res://core/appearance_rules.gd")
const Saves = preload("res://core/save_store.gd")
const Equipment = preload("res://core/equipment_rules.gd")
const Runtime = preload("res://presentation/asset_runtime.gd")
var checks := 0
var failures: Array[String] = []

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func ready_campaign(seed_value: int) -> Dictionary:
	var c := Campaign.create_campaign("free", seed_value)
	Campaign.start_expedition(c)
	while c.phase == "travel": Campaign.advance_travel(c)
	if c.phase == "event": Campaign.choose_event(c, str(c.event.choices[0].id))
	while c.phase == "travel": Campaign.advance_travel(c)
	var b := Battle.create_battle(c.roster, seed_value, Campaign.battle_config(c))
	check(Campaign.begin_battle(c, b).ok, "new tactical battle enters campaign")
	return c

func _initialize() -> void:
	feedback_classification()
	var c := ready_campaign(6023)
	var before := JSON.stringify(c.roster[0].appearance)
	var rng_before := int(c.rng_state)
	Appearance.ensure_unit(c.roster[0])
	check(before == JSON.stringify(c.roster[0].appearance) and rng_before == int(c.rng_state), "identity is stable without consuming randomness")
	c.gold = 100
	var item := Equipment.buy(c, "weapon_skirmisher_axe") # Outside camp must refuse without identity edits.
	check(not item.ok and before == JSON.stringify(c.roster[0].appearance), "rejected swap never mutates identity")
	check(Saves.validate(c).is_empty(), "new tactical state validates: " + Saves.validate(c))
	var saved := Saves.save_campaign(c, "user://foundation-integration.json")
	check(saved.ok, "tactical save writes")
	var loaded := Saves.load_campaign("user://foundation-integration.json")
	check(loaded.get("ok", false) and loaded.get("campaign", {}).get("battle", {}) == c.battle, "load keeps fatigue morale terrain and identity")
	var invalid := c.duplicate(true)
	invalid.battle.units[0].morale = 9
	check(not Saves.validate(invalid).is_empty(), "invalid morale rejected")
	invalid = c.duplicate(true)
	invalid.battle.cells["0,0"].elevation = 5
	check(not Saves.validate(invalid).is_empty(), "unsupported elevation rejected")
	var b: Dictionary = c.battle
	var events: Array = []
	Battle._damage_unit(b, b.units[0], 1000, "enemy_0", true, events)
	# Fix the saved draw for the two deterministic settlement branches.
	b.casualties[0].roll = 0
	for unit: Dictionary in b.units:
		if unit.team == "enemy": Battle._damage_unit(b, unit, 1000, "crew_2", true, events)
	Battle._check_outcome(b)
	check(b.outcome == "victory" and b.casualties[0].status == "survived", "terminal outcome resolves saved casualty")
	check(Saves.validate(c).is_empty(), "terminal casualty snapshot validates: " + Saves.validate(c))
	var equipment_before: Dictionary = c.roster[0].equipment.duplicate(true)
	var result := Campaign.resolve_battle(c, c.battle)
	check(result.ok and int(c.roster[0].hp) > 0, "incapacitated victor survives settlement")
	check(c.roster[0].equipment == equipment_before and int(c.roster[0].progression.xp) > 0, "survivor keeps gear and earned experience")
	check(int(c.roster[0].get("recovery_until_day", 0)) > int(c.day), "survivor owes recovery time")
	var settled := JSON.stringify(c)
	check(not Campaign.resolve_battle(c, b).ok and JSON.stringify(c) == settled, "duplicate settlement gives no extra rewards")
	var dead := ready_campaign(6024)
	events = []
	Battle._damage_unit(dead.battle, dead.battle.units[0], 1000, "enemy_0", true, events)
	dead.battle.casualties[0].roll = 99
	for unit: Dictionary in dead.battle.units:
		if unit.team == "enemy": Battle._damage_unit(dead.battle, unit, 1000, "crew_2", true, events)
	Battle._check_outcome(dead.battle)
	check(Campaign.resolve_battle(dead, dead.battle).ok and int(dead.roster[0].hp) == 0, "unlucky casualty remains dead")
	check(dead.roster[0].equipment.is_empty() or str(dead.roster[0].equipment.get("weapon", "")).is_empty(), "confirmed death loses carried equipment")
	print("Foundation integration: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func feedback_classification() -> void:
	var s := Battle.create_battle([{"id": "guard", "kind": "guard"}], 10)
	var target: Dictionary = s.units[0]
	var attacker: Dictionary = s.units[1]
	target.statuses.defending = 1
	target.defense = 0
	attacker.accuracy = 80
	attacker.morale = 3
	s.cells["%d,%d" % [attacker.q, attacker.r]].elevation = 0
	s.cells["%d,%d" % [target.q, target.r]].elevation = 0
	for seed_value in range(1, 100):
		var roll := int((seed_value * 48271) % 2147483647) % 100
		if roll >= 60 and roll < 80:
			s.rng_state = seed_value
			break
	var expected_rng := (int(s.rng_state) * 48271) % 2147483647
	var hp_before := int(target.hp)
	var events: Array = []
	check(not Battle._strike(s, attacker, target, 60, 12, "攻击", events), "defending shield rejects the same miss roll")
	check(events.back().get("outcome", "") == "block" and int(target.hp) == hp_before, "block feedback reflects defense prevention without extra damage")
	check(int(s.rng_state) == expected_rng, "classifying block consumes no second random draw")
	var distant := Battle.create_battle([{"id": "near", "kind": "guard"}, {"id": "far", "kind": "archer"}], 2)
	distant.units[0].q = 0; distant.units[0].r = 0
	distant.units[1].q = 0; distant.units[1].r = 6
	Battle._damage_unit(distant, distant.units[0], 999, "enemy_0", true, [])
	check(not distant.morale_checks.has("0:far:-1"), "distant ally does not witness local incapacitation")
