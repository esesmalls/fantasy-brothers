extends SceneTree
const Rules = preload("res://core/battle_rules.gd")
const Data = preload("res://core/tactical_data.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	terrain()
	fatigue()
	casualties()
	morale()
	deployment()
	replay_and_ai()
	full_battles()
	evacuation()
	print("Tactical expansion: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func fixture() -> Dictionary:
	var s = Rules.create_battle([
		{"id": "a", "kind": "guard", "equipment_burden": 0},
		{"id": "b", "kind": "spear", "equipment_burden": 0}], 101)
	s.props = []
	s.units = [s.units[0], s.units[1], s.units[2]]
	s.order = ["a", "b", "enemy_0"]
	s.turn_index = 0
	s.units[0].q = 2
	s.units[0].r = 2
	s.units[1].q = 1
	s.units[1].r = 3
	s.units[2].q = 6
	s.units[2].r = 3
	for c in s.cells.values():
		c.terrain = "flat"
		c.elevation = 0
		c.surface = "dry"
	return s

func terrain() -> void:
	var s = fixture()
	check(s.rules_version == "prototype-0.1.6" and s.cells["2,2"].has_all(["terrain", "elevation", "surface", "field"]), "new rules preserve layered cell schema")
	s.cells["3,2"].terrain = "mud"
	var p = Rules.preview(s, "a", "move", {"q": 3, "r": 2})
	check(p.ok and p.cost == 3 and p.fatigue_cost == 8, "mud preview includes AP and fatigue")
	Rules.apply_action(s, "a", "move", {"q": 3, "r": 2})
	check(s.units[0].ap == 3 and s.units[0].fatigue == 8, "mud resolution consumes exact preview costs")
	var climb = fixture()
	climb.cells["3,2"].terrain = "rubble"
	climb.cells["3,2"].elevation = 1
	p = Rules.preview(climb, "a", "move", {"q": 3, "r": 2})
	check(p.ok and p.cost == 4 and p.fatigue_cost == 9, "rubble ascent adds both costs")
	var detour = fixture()
	detour.cells["3,2"].terrain = "mud"
	detour.cells["3,2"].elevation = 1
	detour.cells["4,2"].terrain = "flat"
	p = Rules.preview(detour, "a", "move", {"q": 4, "r": 2})
	check(p.ok and p.cost == 6 and p.path.size() == 3, "weighted search prefers affordable three-step route over costly short route")
	var elements: Array = []
	Rules._apply_surface(climb, 3, 2, "oil", elements)
	Rules._apply_surface(climb, 3, 2, "fire", elements)
	check(climb.cells["3,2"].field == "fire" and climb.cells["3,2"].terrain == "rubble" and climb.cells["3,2"].elevation == 1, "oil fire overlays do not erase terrain or height")
	Rules._apply_surface(climb, 3, 2, "water", elements)
	check(climb.cells["3,2"].surface == "water" and climb.cells["3,2"].field == "steam" and climb.cells["3,2"].terrain == "rubble", "water reaction retains rubble")
	var high = fixture()
	high.units[2].q = 3
	high.units[2].r = 2
	high.cells["2,2"].elevation = 1
	check(Rules.preview(high, "a", "attack", {"q": 3, "r": 2}).chance == 90, "melee high ground grants ten accuracy")
	high.cells["2,2"].elevation = 0
	high.cells["3,2"].elevation = 1
	check(Rules.preview(high, "a", "attack", {"q": 3, "r": 2}).chance == 70, "melee uphill loses ten accuracy")
	high.units[0].range = 4
	high.units[0].weapon_style = "archer"
	high.units[2].q = 4
	high.cells["3,2"].elevation = 0
	high.cells["2,2"].elevation = 1
	check(Rules.preview(high, "a", "attack", {"q": 4, "r": 2}).chance == 90, "ranged high ground grants accuracy")
	high.cells["2,2"].elevation = 0
	high.cells["3,2"].elevation = 1
	check(not Rules.preview(high, "a", "attack", {"q": 4, "r": 2}).ok, "intervening raised ridge blocks low-to-low shot")
	high.cells["2,2"].elevation = 1
	high.cells["4,2"].elevation = 1
	check(Rules.preview(high, "a", "attack", {"q": 4, "r": 2}).ok, "same plateau permits elevated shot")
	var map_b = Rules.create_battle([{"id": "a"}], 1, {"map_id": "ridge_road"})
	check(map_b.map_id == "ridge_road" and map_b.cells["4,1"].elevation == 1, "second fixed battlefield has ridge topology")
	var legacy = fixture()
	legacy.rules_version = "prototype-0.1.5"
	legacy.cells["3,2"].terrain = "mud"
	legacy.cells["3,2"].elevation = 1
	check(Rules.preview(legacy, "a", "move", {"q": 3, "r": 2}).cost == 2, "legacy snapshots keep two AP movement even with unknown extra data")

func fatigue() -> void:
	var s = fixture()
	s.units[0].equipment_burden = 20
	s.units[2].q = 3
	s.units[2].r = 2
	var p = Rules.preview(s, "a", "attack", {"q": 3, "r": 2})
	check(p.fatigue_cost == 14, "equipment burden raises attack fatigue")
	s.units[0].fatigue = 90
	var before = JSON.stringify(s)
	check(not Rules.apply_action(s, "a", "attack", {"q": 3, "r": 2}).ok and JSON.stringify(s) == before, "fatigue-invalid attack is complete atomic no-op")
	check(Rules.apply_action(s, "a", "recover", {}).ok and s.units[0].fatigue == 60 and s.units[0].ap == 3, "recover spends three AP and restores thirty fatigue")
	var order = s.order.duplicate()
	Rules.apply_action(s, "a", "attack", {"q": 3, "r": 2})
	check(s.order == order, "spending fatigue never reorders current round")
	Rules._end_round(s, [])
	check(s.order.back() == "a" and s.initiative_snapshot.a == 6, "next-round order uses accumulated fatigue and burden")
	s.turn_index = s.order.find("a") - 1
	Rules.end_turn(s)
	check(s.units[0].fatigue == 59 and s.units[0].ap == 6, "turn start restores fifteen fatigue and six AP")
	var exhausted = fixture()
	exhausted.units[0].fatigue = 97
	check(not Rules.preview(exhausted, "a", "move", {"q": 3, "r": 2}).ok, "pathfinder respects remaining fatigue")
	var interrupt = fixture()
	interrupt.units[0].hp = 1
	interrupt.cells["3,2"].field = "fire"
	interrupt.cells["3,2"].expires = 2
	Rules.apply_action(interrupt, "a", "move", {"q": 4, "r": 2})
	check(interrupt.units[0].incapacitated and interrupt.units[0].ap == 4 and interrupt.units[0].fatigue == 4, "interrupted move only pays attempted step and stops")

func casualties() -> void:
	var s = fixture()
	s.action_seq = 7
	var rng_before = int(s.rng_state)
	var victim = s.units[0]
	# Suppress witnesses to demonstrate casualty sampling itself uses its own stream.
	s.units = [victim]
	var events: Array = []
	Rules._damage_unit(s, victim, 999, "enemy_0", true, events)
	check(victim.incapacitated and victim.hp == 0 and s.casualties.size() == 1, "HP zero creates one incapacitation record")
	check(s.rng_state == rng_before and s.casualty_rng_state != posmod(int(s.seed) + 7919, 2147483646) + 1, "casualty sampling does not consume attack RNG")
	check(events.back().type == "incapacitated" and s.casualties[0].source_action == 7 and s.casualties[0].status == "pending", "downed event has source root and no premature death")
	Rules._damage_unit(s, victim, 999, "enemy_0", true, events)
	check(s.casualties.size() == 1, "repeated damage cannot duplicate casualty")
	var saved = JSON.parse_string(JSON.stringify(s))
	s.outcome = "victory"
	saved.outcome = "victory"
	Rules.finalize_casualties(s)
	Rules.finalize_casualties(saved)
	check(JSON.stringify(JSON.parse_string(JSON.stringify(s.terminal_data))) == JSON.stringify(JSON.parse_string(JSON.stringify(saved.terminal_data))), "saved casualty roll reproduces terminal result")
	var frozen = JSON.stringify(s)
	Rules.finalize_casualties(s)
	check(JSON.stringify(s) == frozen, "terminal resolution is idempotent")
	for kind in ["guard", "dog"]:
		for outcome in ["victory", "defeat", "retreat"]:
			for roll in [0, 99]:
				var trial = fixture()
				trial.units[0].kind = kind
				Rules._damage_unit(trial, trial.units[0], 999, "enemy_0", true, [])
				trial.casualties[0].roll = roll
				trial.outcome = outcome
				Rules.finalize_casualties(trial)
				var expected = "survived" if outcome == "victory" and roll == 0 else "dead"
				check(trial.casualties[0].status == expected, "%s %s roll %d resolves %s" % [kind, outcome, roll, expected])
	var enemy = fixture()
	Rules._damage_unit(enemy, enemy.units[2], 999, "a", true, [])
	Rules._check_outcome(enemy)
	check(enemy.outcome == "victory" and enemy.casualties[0].status == "enemy_incapacitated", "last enemy incapacitation ends combat without inventing persistent enemy death")
	var defeat = fixture()
	Rules._damage_unit(defeat, defeat.units[0], 999, "enemy_0", true, [])
	Rules._damage_unit(defeat, defeat.units[1], 999, "enemy_0", true, [])
	Rules._check_outcome(defeat)
	check(defeat.outcome == "defeat" and defeat.casualties.size() == 2 and defeat.casualties[1].status == "dead", "last effective player down ends combat and resolves all casualties")
	var old = fixture()
	old.rules_version = "prototype-0.1.5"
	var old_events: Array = []
	Rules._damage_unit(old, old.units[0], 999, "enemy_0", true, old_events)
	check(old_events.back().type == "death" and old.casualties.is_empty(), "old ongoing battle retains immediate death semantics")

func morale() -> void:
	var s = fixture()
	s.rng_state = 69
	s.units[0].resolve = 5
	s.units[0].max_hp = 100
	s.units[0].hp = 100
	s.units[0].armor = 0
	Rules._damage_unit(s, s.units[0], 30, "enemy_0", false, [])
	check(s.units[0].morale == 2, "heavy wound can lower morale")
	Rules._damage_unit(s, s.units[0], 30, "enemy_0", false, [])
	check(s.units[0].morale == 2 and s.morale_checks.size() == 1, "same root cannot repeat a negative morale check")
	s.action_seq += 1
	Rules._morale_check(s, s.units[0], -1, "ally_incapacitated", [])
	check(s.morale_checks.size() == 2, "new root can check morale again")
	var rally = fixture()
	rally.units[1].morale = 0
	check(Rules.apply_action(rally, "a", "rally", {"q": 1, "r": 3}).ok and rally.units[1].morale == 1, "rally can recover routed ally by one level")
	check(not Rules.preview(rally, "a", "rally", {"q": 1, "r": 3}).ok, "target cannot be rallied twice in same round")
	rally.units[0].morale = 0
	check(not Rules.preview(rally, "a", "attack", {"q": 6, "r": 3}).ok and not Rules.preview(rally, "a", "rally", {"q": 2, "r": 2}).ok, "routed unit cannot attack or rally itself")
	var safe = fixture()
	safe.units[0].morale = 0
	safe.units[0].resolve = 95
	safe.rng_state = 1
	Rules._start_tactical_turn(safe, safe.units[0], [])
	check(safe.units[0].morale == 1, "safe routed actor can regain composure at turn start")
	var unsafe_state = fixture()
	unsafe_state.units[0].morale = 0
	unsafe_state.units[2].q = 3
	unsafe_state.units[2].r = 2
	var rng = int(unsafe_state.rng_state)
	Rules._start_tactical_turn(unsafe_state, unsafe_state.units[0], [])
	check(unsafe_state.units[0].morale == 0 and unsafe_state.rng_state == rng, "nearby enemy prevents free rout recovery")
	var escape = fixture()
	escape.units[0].q = 0
	var hp = int(escape.units[0].hp)
	var fled = Rules.apply_action(escape, "a", "flee", {})
	check(fled.ok and escape.units[0].escaped and escape.units[0].hp == hp and escape.casualties.is_empty(), "edge escape is survival not death")
	check(Rules._at(escape, 0, 2).is_empty() and Rules.active_unit(escape).id == "b", "escaped unit stops occupying cell and turn advances")
	escape.units[1].q = 0
	Rules.apply_action(escape, "b", "flee", {})
	check(escape.outcome == "retreat" and escape.terminal_data.escaped_ids == ["a", "b"], "all escaped players end in retreat and retain stable escaped IDs")
	var intercepted = fixture()
	intercepted.units[0].q = 0
	intercepted.units[0].r = 2
	intercepted.units[0].hp = 1
	intercepted.units[0].armor = 0
	intercepted.units[2].q = 1
	intercepted.units[2].r = 2
	intercepted.rng_state = 2
	Rules.apply_action(intercepted, "a", "flee", {})
	check(intercepted.units[0].incapacitated and not intercepted.units[0].escaped, "lethal escape reaction prevents escaped status")
	var automatic = fixture()
	automatic.units[0].morale = 0
	check(Rules.ai_step(automatic).ok and automatic.units[0].ap < 6, "player rout is processed by legal AI actions")
	var shot = fixture()
	shot.units[2].q = 3
	shot.units[2].r = 2
	shot.units[0].morale = 1
	check(Rules.preview(shot, "a", "attack", {"q": 3, "r": 2}).chance == 65, "broken morale applies public accuracy penalty")

func deployment() -> void:
	var s = fixture()
	var good = [{"unit_id": "a", "q": 0, "r": 1}, {"unit_id": "b", "q": 1, "r": 1}]
	check(Rules.validate_deployment(s, good).ok, "deployment validates complete left-side formation")
	var bad = good.duplicate(true)
	bad[1].q = 0
	check(not Rules.validate_deployment(s, bad).ok, "deployment refuses overlap")
	check(not Rules.validate_deployment(s, [good[0]]).ok, "deployment refuses missing participant")
	var started = Rules.create_battle([{"id": "a"}, {"id": "b"}], 1, {"deployment": good, "deployment_instance_id": "dep1"})
	check(started.units[0].q == 0 and started.units[0].r == 1 and started.deployment_instance_id == "dep1", "battle applies saved stable deployment")

func replay_and_ai() -> void:
	var s = fixture()
	s.units[2].q = 3
	s.units[2].r = 2
	s.units[2].hp = 1
	s.units[2].armor = 0
	s.rng_state = 1
	var copy: Dictionary = JSON.parse_string(JSON.stringify(s))
	var original = JSON.stringify(s)
	for i in range(10):
		Rules.preview(s, "a", "attack", {"q": 3, "r": 2})
	check(JSON.stringify(s) == original, "new preview does not mutate either RNG or rule state")
	var a = Rules.apply_action(s, "a", "attack", {"q": 3, "r": 2})
	var b = Rules.apply_action(copy, "a", "attack", {"q": 3, "r": 2})
	check(JSON.stringify(a.events) == JSON.stringify(b.events) and JSON.stringify(s.terminal_data) == JSON.stringify(copy.terminal_data), "new combat and casualty events reproduce after JSON round trip")
	check(s.action_log[0].has_all(["rules_version", "casualty_rng_before", "rng_before"]), "action log saves independent RNG and rule version")
	for seed_value in range(1, 21):
		var trial = fixture()
		trial.rng_state = seed_value
		trial.turn_index = 2
		trial.units[2].fatigue = 95
		trial.units[2].max_fatigue = 100
		var bounded = 0
		var valid = true
		while trial.outcome == "" and Rules.active_unit(trial).id == "enemy_0" and bounded < 12:
			var result = Rules.ai_step(trial)
			valid = valid and result.ok
			bounded += 1
		check(valid and bounded < 12 and int(trial.units[2].fatigue) <= int(trial.units[2].max_fatigue), "fatigued AI uses legal bounded turn seed " + str(seed_value))


func full_battles() -> void:
	var policy = preload("res://tests/play_policy.gd")
	for seed_value in range(1, 21):
		var roster: Array = [{"id": "a", "kind": "guard"}, {"id": "b", "kind": "spear"}, {"id": "c", "kind": "hunter"}, {"id": "d", "kind": "dog", "hunter_id": "c"}]
		var s = Rules.create_battle(roster, seed_value, {"map_id": "ridge_road" if seed_value % 2 == 0 else "granary_bank"})
		var count = 0
		var valid = true
		while s.outcome == "" and count < 600:
			var u = Rules.active_unit(s)
			if u.team == "enemy" or u.kind == "dog" or int(u.morale) == 0:
				valid = valid and Rules.ai_step(s).ok
			else:
				var command = policy.next_command(s)
				if not command.is_empty():
					valid = valid and Rules.apply_action(s, u.id, command.action, command.target).ok
				elif int(u.fatigue) >= 20 and Rules.preview(s, u.id, "recover", {}).ok:
					valid = valid and Rules.apply_action(s, u.id, "recover", {}).ok
				else:
					Rules.end_turn(s)
			for actor in s.units:
				valid = valid and int(actor.ap) >= 0 and int(actor.fatigue) >= 0 and int(actor.fatigue) <= int(actor.max_fatigue)
			count += 1
		check(valid and s.outcome != "" and count < 600 and not s.terminal_data.is_empty(), "mixed human/dog battle reaches valid terminal state seed " + str(seed_value))


func evacuation_fixture(count: int = 2) -> Dictionary:
	var roster: Array = []
	for i in range(count):
		roster.append({"id": "evac_" + str(i), "kind": "guard", "equipment_burden": 0})
	var s = Rules.create_battle(roster, 72, {"id": "evacuation_test", "contract_kind": "evacuation"})
	s.props = []
	for u in s.units:
		if u.team == "enemy":
			u.hp = 0
	for cell in s.cells.values():
		cell.terrain = "flat"
		cell.elevation = 0
	Rules._check_outcome(s)
	return s

func evacuation() -> void:
	var s = evacuation_fixture()
	check(s.objective.kind == "evacuation" and s.objective.required_count == 2 and s.objective.participant_ids == ["evac_0", "evac_1"], "evacuation saves actual deployed participants and target")
	check(s.outcome == "" and not Rules.active_unit(s).is_empty(), "defeating every enemy does not complete evacuation contract")
	s.units[0].q = int(s.width) - 1
	s.units[0].r = 2
	s.units[1].q = int(s.width) - 1
	s.units[1].r = 3
	var preview_before = JSON.stringify(s)
	check(Rules.preview(s, "evac_0", "flee", {}).summary.contains("右侧") and JSON.stringify(s) == preview_before, "exit preview identifies objective without mutating progress")
	check(Rules.apply_action(s, "evac_0", "flee", {}).ok and s.outcome == "" and s.objective.evacuated_ids == ["evac_0"], "first right exit records progress but does not win")
	check(Rules.active_unit(s).id == "evac_1", "dead enemy and exited turns skip correctly after first exit")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(s))
	Rules.apply_action(s, "evac_1", "flee", {})
	Rules.apply_action(saved, "evac_1", "flee", {})
	check(s.outcome == "victory" and s.objective.evacuated_ids == ["evac_0", "evac_1"], "second actual right exit completes objective")
	check(s.terminal_data.objective.evacuated_ids == s.objective.evacuated_ids and JSON.stringify(JSON.parse_string(JSON.stringify(s.terminal_data))) == JSON.stringify(JSON.parse_string(JSON.stringify(saved.terminal_data))), "objective completion persists and replays after load")
	var before = JSON.stringify(s)
	check(not Rules.apply_action(s, "evac_1", "flee", {}).ok and JSON.stringify(s) == before, "finished contract cannot duplicate an exit claim")
	var lone = evacuation_fixture(1)
	check(lone.objective.required_count == 1, "solo deployment only requires its sole participant")
	lone.units[0].q = int(lone.width) - 1
	Rules.apply_action(lone, "evac_0", "flee", {})
	check(lone.outcome == "victory", "solo participant can complete real evacuation")
	var wrong = evacuation_fixture()
	wrong.units[0].q = 0
	Rules.apply_action(wrong, "evac_0", "flee", {})
	check(wrong.outcome == "retreat" and wrong.objective.evacuated_ids.is_empty() and wrong.units[0].hp > 0, "wrong edge exit preserves survivor but makes two-person objective impossible")
	var loss = evacuation_fixture()
	Rules._damage_unit(loss, loss.units[0], 999, "enemy_0", true, [])
	Rules._check_outcome(loss)
	check(loss.outcome == "defeat" and loss.casualties[0].status == "dead", "downing one of two required participants immediately fails impossible objective")
	var mixed = evacuation_fixture(4)
	mixed.units[0].q = 0
	Rules.apply_action(mixed, "evac_0", "flee", {})
	check(mixed.outcome == "" and mixed.objective.evacuated_ids.is_empty(), "wrong-edge survivor does not fail objective while two others remain possible")
	Rules._damage_unit(mixed, mixed.units[1], 999, "enemy_0", true, [])
	Rules._damage_unit(mixed, mixed.units[2], 999, "enemy_0", true, [])
	Rules._check_outcome(mixed)
	check(mixed.outcome == "retreat", "other-edge survivor changes impossible objective result to retreat")
	var victory = evacuation_fixture(3)
	Rules._damage_unit(victory, victory.units[2], 999, "enemy_0", true, [])
	victory.casualties[0].roll = 0
	Rules._check_outcome(victory)
	check(victory.outcome == "", "one casualty leaves three-person deployment able to evacuate two")
	for u in victory.units:
		if u.team == "player" and u.hp > 0:
			u.q = int(victory.width) - 1
	Rules.apply_action(victory, "evac_0", "flee", {})
	Rules.apply_action(victory, "evac_1", "flee", {})
	check(victory.outcome == "victory" and victory.casualties[0].status == "survived", "evacuation victory resolves existing incapacitation survival rule")
	var walks = evacuation_fixture()
	var steps = 0
	while walks.outcome == "" and steps < 100:
		var u = Rules.active_unit(walks)
		var result = Rules._evacuation_ai(walks, u)
		if not result.ok:
			break
		steps += 1
	check(walks.outcome == "victory" and steps < 100 and walks.round > 1, "after enemies fall actual movement and multiple rounds can reach right exit")
	var dog = Rules.create_battle([{"id": "a", "kind": "hunter"}, {"id": "b", "kind": "dog", "hunter_id": "a"}], 72, {"contract_kind": "evacuation"})
	dog.props = []
	for u in dog.units:
		if u.team == "enemy":
			u.hp = 0
	dog.units[0].q = int(dog.width) - 1
	dog.turn_index = dog.order.find("a")
	Rules.apply_action(dog, "a", "flee", {})
	steps = 0
	while dog.outcome == "" and steps < 100:
		if not Rules.ai_step(dog).ok:
			break
		steps += 1
	check(dog.outcome == "victory" and dog.objective.evacuated_ids == ["a", "b"], "dog automatically reaches objective after handler leaves without requiring manual control")
	var ordinary = fixture()
	ordinary.units[2].hp = 0
	Rules._check_outcome(ordinary)
	check(ordinary.outcome == "victory" and not ordinary.has("objective"), "ordinary battle still ends immediately when enemies are defeated")
