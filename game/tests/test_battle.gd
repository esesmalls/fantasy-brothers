extends SceneTree
const Rules = preload("res://core/battle_rules.gd")
var checks = 0
var failures: Array = []

func _initialize() -> void:
	_test_schema_events_and_atomicity()
	_test_preview_and_costs()
	_test_combo_and_miss()
	_test_surfaces_and_props()
	_test_fire_lifetime()
	_test_status_lifetime_and_hazard_defeat()
	_test_zoc_and_push()
	_test_dog_command()
	_test_dog_command_focus()
	_test_save_replay()
	_test_ai_and_outcomes()
	print("Battle rules: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func fixture() -> Dictionary:
	var s = Rules.create_battle([
		{"id": "g", "name": "盾兵", "kind": "guard"},
		{"id": "p", "name": "枪兵", "kind": "spear"}], 101, {"id": "fixture"})
	s.props = []
	var enemy = s.units[2]
	s.units = [s.units[0], s.units[1], enemy]
	s.order = ["g", "p", enemy.id]
	s.units[0].q = 2
	s.units[0].r = 2
	s.units[1].q = 2
	s.units[1].r = 3
	enemy.q = 3
	enemy.r = 2
	enemy.max_hp = 100
	enemy.hp = 100
	enemy.armor = 0
	for cell in s.cells.values():
		cell.surface = "dry"
	return s

func _test_schema_events_and_atomicity() -> void:
	var s = Rules.create_battle([{"id": "g", "kind": "guard"}], 17, {"id": "schema", "supplies": {"oil": 1}})
	for field in ["schema", "rules_version", "seed", "rng_state", "id", "width", "height", "round", "units", "cells", "props", "order", "turn_index", "outcome", "log", "supplies", "action_seq"]:
		check(s.has(field), "battle state exposes contract field " + field)
	var original = JSON.stringify(s)
	var invalid = Rules.apply_action(s, "g", "fire", {"q": 99, "r": 99})
	check(not invalid.ok and JSON.stringify(s) == original, "invalid tool action is a complete atomic no-op")
	var before_rng = int(s.rng_state)
	var oil = Rules.apply_action(s, "g", "oil", {"q": 2, "r": 2})
	check(oil.ok and s.supplies.oil == 0, "oil tool pays one supply and AP through shared plan")
	check(not oil.events.is_empty(), "oil surface changes produce presentation events")
	var event_shape = true
	for event in oil.events:
		for field in ["type", "actor", "target", "q", "r", "text", "amount"]:
			if not event.has(field):
				event_shape = false
	check(event_shape, "rule events expose the stable presentation shape")
	check(s.action_seq == 1 and s.action_log.back().rng_before == before_rng, "successful action records root id and pre-action RNG")
	check(JSON.parse_string(JSON.stringify(s)) != null, "battle state remains JSON serializable after surface events")

func _test_preview_and_costs() -> void:
	var s = fixture()
	var original = JSON.stringify(s)
	var p = Rules.preview(s, "g", "attack", {"q": 3, "r": 2})
	check(p.ok and p.cost == 3 and p.chance == 80, "attack preview reports same cost and probability")
	check(JSON.stringify(s) == original, "preview does not mutate state or RNG")
	var bad = Rules.apply_action(s, "g", "move", {"q": 3, "r": 2})
	check(not bad.ok and JSON.stringify(s) == original, "occupied move is atomic no-op")
	check(not Rules.preview(s, "p", "attack", {"q": 3, "r": 2}).ok, "inactive unit cannot act")
	var move = Rules.apply_action(s, "g", "move", {"q": 1, "r": 2})
	check(move.ok and s.units[0].ap == 4, "single move costs 2 AP")
	check(Rules.active_unit(s).id == "g", "action does not silently skip remaining AP")
	Rules.end_turn(s)
	check(Rules.active_unit(s).id == "p" and s.units[1].ap == 6, "explicit turn end advances")

func _test_combo_and_miss() -> void:
	var s = fixture()
	s.rng_state = 1
	var bash = Rules.apply_action(s, "g", "shield_bash", {"q": 3, "r": 2})
	check(bash.ok and s.units[2].statuses.has("exposed"), "shield hit applies exposed")
	s.turn_index = 1
	var p = Rules.preview(s, "p", "attack", {"q": 3, "r": 2})
	check(p.ok and p.chance == 95 and p.consume_exposed, "spear computes exposed bonus before consuming")
	s.rng_state = 69
	var hp = s.units[2].hp
	Rules.apply_action(s, "p", "attack", {"q": 3, "r": 2})
	check(not s.units[2].statuses.has("exposed") and s.units[2].hp == hp, "miss still consumes exposed exactly once")
	s.units[1].perks = ["breacher"]
	s.units[2].statuses.exposed = {"expires": 2, "source": "g"}
	var upgraded = Rules.preview(s, "p", "attack", {"q": 3, "r": 2})
	check(upgraded.damage == s.units[1].attack + 6, "breacher bonus shares attack plan")

func _test_surfaces_and_props() -> void:
	var s = Rules.create_battle([{"id": "g", "kind": "guard"}], 20, {})
	var result = Rules.apply_action(s, "g", "fire", {"q": 4, "r": 2})
	check(result.ok and s.props[0].hp == 0, "fire direct hit destroys oil jar")
	check(s.cells["4,2"].field == "fire" and s.cells["4,2"].surface == "dry", "destroyed oil jar lays oil before single ignition pass")
	check(s.units[1].hp == s.units[1].max_hp - 10, "fire spread harms enemy at adjacent oil")
	check(s.supplies.fire == 2, "tool deducts one supply")
	var f = fixture()
	f.cells["3,2"].surface = "oil"
	Rules.apply_action(f, "g", "fire", {"q": 3, "r": 2})
	var hp_after = f.units[2].hp
	var events: Array = []
	Rules._hazard(f, f.units[2], events)
	check(f.units[2].hp == hp_after, "same-round fire hazard cannot double tick")
	var water = Rules.apply_action(f, "g", "water", {"q": 3, "r": 2})
	check(water.ok and f.cells["3,2"].field == "steam" and f.cells["3,2"].surface == "water", "water extinguishes fire into steam")
	check(f.units[2].hp == hp_after, "water does not undo damage")
	f.units[1].kind = "archer"
	f.units[1].range = 4
	f.turn_index = 1
	check(not Rules.preview(f, "p", "attack", {"q": 3, "r": 2}).ok, "steam target blocks ranged aim")
	var guard_hp = f.units[0].hp
	f.cells["2,2"].field = "fire"
	f.units[0].perks = ["firewise"]
	Rules._hazard(f, f.units[0], events)
	check(f.units[0].hp == guard_hp - 5, "firewise halves armor-bypassing fire damage")

func _test_fire_lifetime() -> void:
	var s = fixture()
	var events: Array = []
	s.cells["7,6"].surface = "oil"
	Rules._apply_surface(s, 7, 6, "fire", events)
	check(s.cells["7,6"].expires == 2, "round N hazard expires at N+1 round end")
	Rules._end_round(s, events)
	check(s.round == 2 and s.cells["7,6"].field == "fire", "hazard survives following round start")
	Rules._end_round(s, events)
	check(s.round == 3 and s.cells["7,6"].field == "", "hazard expires after full following round")
	s.cells["7,6"].surface = "water"
	Rules._apply_surface(s, 7, 6, "fire", events)
	check(s.cells["7,6"].field == "steam" and s.cells["7,6"].surface == "water", "fire on water directly creates steam")
	var barrel = Rules.create_battle([{"id": "g", "kind": "guard"}], 21, {})
	var broken = Rules.apply_action(barrel, "g", "fire", {"q": 3, "r": 4})
	check(broken.ok and barrel.props[1].hp == 0, "fire direct hit can break the water barrel")
	check(barrel.cells["3,4"].surface == "water" and barrel.cells["3,4"].field == "steam", "broken water barrel spreads before the action's single fire reaction")

func _test_status_lifetime_and_hazard_defeat() -> void:
	var s = fixture()
	s.rng_state = 1
	Rules.apply_action(s, "g", "shield_bash", {"q": 3, "r": 2})
	var events: Array = []
	Rules._end_round(s, events)
	check(s.round == 2 and s.units[2].statuses.has("exposed"), "round-N exposed remains through the following round")
	Rules._end_round(s, events)
	check(s.round == 3 and not s.units[2].statuses.has("exposed"), "exposed expires at the following round end")
	var hazard = Rules.create_battle([{"id": "solo", "kind": "guard"}], 23, {})
	hazard.units[0].hp = 5
	hazard.cells["2,2"].field = "fire"
	hazard.cells["2,2"].expires = 2
	hazard.turn_index = hazard.order.size() - 1
	var end_events = Rules.end_turn(hazard)
	var announced = false
	for event in end_events:
		if event.type == "status" and event.text == "佣兵团失去战斗能力。":
			announced = true
	check(hazard.outcome == "defeat" and hazard.units[0].hp == 0, "turn-start fire can immediately resolve defeat")
	check(announced, "hazard-caused outcome is present in the returned event stream")

func _test_zoc_and_push() -> void:
	var s = fixture()
	s.rng_state = 1
	s.units[2].accuracy = 95
	var result = Rules.apply_action(s, "g", "move", {"q": 1, "r": 2})
	var attack_count = 0
	for event in result.events:
		if event.type == "attack" and event.actor == s.units[2].id:
			attack_count += 1
	check(attack_count == 1, "voluntary disengage triggers exactly one enemy reaction")
	var f = fixture()
	f.cells["4,2"].field = "fire"
	f.cells["4,2"].expires = 2
	var hp = f.units[2].hp
	var pushed = Rules.apply_action(f, "g", "push", {"q": 3, "r": 2})
	check(pushed.ok and f.units[2].q == 4 and f.units[2].hp == hp - 10, "push enters fire and applies hazard")
	var no_reaction = true
	for event in pushed.events:
		if event.type == "attack":
			no_reaction = false
	check(no_reaction, "forced movement never triggers opportunity strike")
	var b = fixture()
	b.cells["4,2"].blocked = true
	var original = JSON.stringify(b)
	check(not Rules.apply_action(b, "g", "push", {"q": 3, "r": 2}).ok and JSON.stringify(b) == original, "blocked push spends no AP and cannot overlap")

func _test_dog_command() -> void:
	var s = Rules.create_battle([
		{"id": "h", "kind": "hunter", "perks": ["packbond"]},
		{"id": "d", "kind": "dog"},
		{"id": "g", "kind": "guard"},
		{"id": "p", "kind": "spear"},
		{"id": "extra", "kind": "guard"}], 13, {})
	var players = 0
	for u in s.units:
		if u.team == "player":
			players += 1
	check(players == 4, "dog occupies one of four deployment slots")
	check(s.units[1].hunter_id == "h", "dog is linked to living hunter")
	s.units[4].q = 3
	s.units[4].r = 3
	s.units[1].ap = 2
	var command = Rules.apply_action(s, "h", "command_pin", {"q": 3, "r": 3})
	check(command.ok and s.units[0].ap == 5 and s.units[1].ap == 2, "issuing command costs hunter AP and never refreshes dog AP")
	Rules.end_turn(s)
	check(Rules.active_unit(s).id == "d" and s.units[1].ap == 6, "dog receives AP only on own normal turn")
	s.units[4].statuses.marked = {"expires": 2, "source": "h"}
	var plan = Rules.preview(s, "d", "attack", {"q": 3, "r": 3})
	check(plan.ok and plan.damage == s.units[1].attack + 6, "packbond dog consumes marked opportunity")
	var before = s.units[1].ap
	var acted = Rules.ai_step(s)
	check(acted.ok and s.units[1].ap < before, "commanded dog acts via same AP rules")

func _test_dog_command_focus() -> void:
	var s = Rules.create_battle([
		{"id": "h", "kind": "hunter"},
		{"id": "d", "kind": "dog"}], 29, {})
	var dog = s.units[1]
	var ordered = s.units[2]
	var tempting = s.units[3]
	dog.q = 2
	dog.r = 2
	ordered.q = 3
	ordered.r = 2
	tempting.q = 2
	tempting.r = 3
	tempting.hp = 1
	dog.command = "pin"
	dog.command_target = ordered.id
	s.turn_index = 1
	s.rng_state = 1
	var result = Rules.ai_step(s)
	var attacked_target = ""
	for event in result.events:
		if event.type == "attack":
			attacked_target = str(event.target)
	check(attacked_target == ordered.id, "pin command keeps the dog focused on its living ordered target")
	var recall = Rules.create_battle([
		{"id": "h", "kind": "hunter"},
		{"id": "d", "kind": "dog"}], 31, {})
	recall.units[0].hp = 0
	recall.units[1].q = 2
	recall.units[1].r = 2
	recall.units[2].q = 5
	recall.units[2].r = 2
	recall.units[1].command = "recall"
	recall.turn_index = 1
	var old_q = int(recall.units[1].q)
	var old_r = int(recall.units[1].r)
	var recalled = Rules.ai_step(recall)
	var attacked = false
	for event in recalled.events:
		if event.type == "attack":
			attacked = true
	check(recalled.ok and not attacked, "recall suppresses dog attacks even if the hunter has fallen")
	check(recall.units[1].q == old_q and recall.units[1].r == old_r, "recall never turns into pursuit when the hunter has fallen")

func _test_save_replay() -> void:
	var s = fixture()
	var restored = JSON.parse_string(JSON.stringify(s))
	var a = Rules.apply_action(s, "g", "shield_bash", {"q": 3, "r": 2})
	var b = Rules.apply_action(restored, "g", "shield_bash", {"q": 3, "r": 2})
	check(JSON.stringify(a.events) == JSON.stringify(b.events), "JSON restored seed produces identical combat events")
	check(JSON.stringify(JSON.parse_string(JSON.stringify(s))) == JSON.stringify(JSON.parse_string(JSON.stringify(restored))), "JSON restored next full state matches")
	check(s.rules_version == "prototype-0.1" and s.action_seq == 1, "rule version and root action are saved")
	var preview_copy = JSON.stringify(s)
	for _i in range(30):
		Rules.preview(s, "g", "move", {"q": 0, "r": 1})
	check(JSON.stringify(s) == preview_copy, "repeated previews never advance randomness")

func _test_ai_and_outcomes() -> void:
	var s = fixture()
	s.turn_index = 2
	var ap = s.units[2].ap
	var ai = Rules.ai_step(s)
	check(ai.ok and s.units[2].ap < ap, "enemy uses legal shared actions")
	var f = fixture()
	f.units[2].hp = 1
	f.rng_state = 1
	Rules.apply_action(f, "g", "attack", {"q": 3, "r": 2})
	check(f.outcome == "victory" and Rules.active_unit(f).is_empty(), "last enemy death immediately resolves victory")
	var r = fixture()
	var hp = r.units[0].hp
	Rules.retreat(r)
	check(r.outcome == "retreat" and r.units[0].hp == hp, "retreat preserves real survivor damage")
	check(not Rules.apply_action(r, "g", "defend", {}).ok, "finished battle refuses extra actions")
	for seed_value in range(1, 21):
		var trial = fixture()
		trial.rng_state = seed_value
		trial.turn_index = 2
		var bounded = 0
		while trial.turn_index == 2 and trial.outcome == "" and bounded < 12:
			Rules.ai_step(trial)
			bounded += 1
		check(bounded < 12, "AI turn terminates seed " + str(seed_value))
