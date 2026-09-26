extends SceneTree

const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://tests/legacy_battle_rules.gd")
const Saves = preload("res://core/save_store.gd")
const World = preload("res://core/world_data.gd")

const SAVE_PATH := "user://qa/world_test/campaign.json"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_cleanup()
	_test_world_content_and_route_costs()
	_test_bridge_detour_persistence()
	_test_three_outcomes_and_return()
	_test_atomic_rejections()
	_test_world_phase_round_trips()
	_test_legacy_phase_upgrades()
	_cleanup()
	print("World rules: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var path: String = SAVE_PATH + str(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func _snapshot(c: Dictionary) -> String:
	return JSON.stringify(c)

func _advance_to_event(c: Dictionary) -> bool:
	while str(c.get("phase", "")) == "travel":
		if not Campaign.advance_travel(c).get("ok", false):
			return false
	return str(c.get("phase", "")) == "event"

func _choose_and_advance_to_ready(c: Dictionary) -> bool:
	if str(c.get("phase", "")) == "travel" and not _advance_to_event(c):
		return false
	var choices: Array = c.get("event", {}).get("choices", [])
	if choices.is_empty() or not Campaign.choose_event(c, str(choices[0].id)).get("ok", false):
		return false
	while str(c.get("phase", "")) == "travel":
		if not Campaign.advance_travel(c).get("ok", false):
			return false
	return str(c.get("phase", "")) == "ready"

func _battle_result(c: Dictionary, outcome: String, kill_all := false, dead_enemies := 0) -> Dictionary:
	if str(c.phase) == "ready":
		Campaign.begin_battle(c, _actual_battle(c))
	for unit: Dictionary in c.battle.units:
		if str(unit.team) == "player" and kill_all:
			unit.hp = 0
		elif str(unit.team) == "enemy" and dead_enemies > 0:
			unit.hp = 0
			dead_enemies -= 1
	for prop: Dictionary in c.battle.props:
		if str(prop.kind) == "grain":
			prop.hp = 12 if outcome == "victory" else 0
	c.battle.outcome = outcome
	return c.battle

func _actual_battle(c: Dictionary) -> Dictionary:
	return Battle.create_battle(c.roster, int(c.seed) + int(c.expedition.index) * 7919, Campaign.battle_config(c))

func _finish_growth(c: Dictionary) -> bool:
	if str(c.phase) == "growth":
		return not c.growth_offers.is_empty() and Campaign.choose_growth(c, str(c.growth_offers[0].id)).get("ok", false)
	return str(c.phase) == "returning"

func _round_trip(c: Dictionary, label: String) -> Dictionary:
	_cleanup()
	var saved := Saves.save_campaign(c, SAVE_PATH)
	check(saved.get("ok", false), label + " can save")
	var loaded := Saves.load_campaign(SAVE_PATH)
	check(loaded.get("ok", false), label + " can load")
	if loaded.get("ok", false):
		check(loaded.campaign == c, label + " preserves exact state")
		return loaded.campaign
	return {}

func _test_world_content_and_route_costs() -> void:
	check(World.LOCATIONS.size() == 6 and World.EDGES.size() == 8, "world exposes the six designed locations and eight undirected edges")
	check(World.has_location(World.CAMP_ID) and World.has_location("loc_granary") and World.has_edge("loc_ferry_crossing", "loc_granary"), "stable location and edge lookup covers camp and contract destination")
	for origin in ["free", "hunters"]:
		for route_id in ["road", "ridge"]:
			var c := Campaign.create_campaign(origin, 2100 + checks)
			var before_view := _snapshot(c)
			var world_view := Campaign.get_world_view(c)
			var offers := Campaign.get_contract_offers(c, World.CAMP_ID)
			check(_snapshot(c) == before_view and world_view.locations.size() == 6 and offers.size() == 3, "%s/%s world and three contract previews are pure" % [origin, route_id])
			var expected_food := 2 if route_id == "road" else 3
			var start_food := int(c.food)
			var start_day := int(c.day)
			check(Campaign.accept_contract(c, World.CONTRACT_ID, route_id).get("ok", false), "%s/%s accepts the fixed contract" % [origin, route_id])
			check(int(c.food) == start_food - expected_food and int(c.day) == start_day + 1 and c.phase == "travel", "%s/%s charges food and day exactly once" % [origin, route_id])
			var paid_state := [int(c.food), int(c.day)]
			check(_choose_and_advance_to_ready(c), "%s/%s reaches its saved event and destination" % [origin, route_id])
			check([int(c.food), int(c.day)] == paid_state and str(c.world.company_location_id) == "loc_granary", "%s/%s node travel never charges the aggregate route again" % [origin, route_id])
			check("loc_granary" in c.world.discovered_location_ids and str(c.world.travel.route_id) == route_id, "%s/%s saves discovery and selected route" % [origin, route_id])

func _test_bridge_detour_persistence() -> void:
	var c := Campaign.create_campaign("free", 2151)
	c.flags.expeditions_started = 2
	check(Campaign.start_expedition(c, "ridge").get("ok", false) and str(c.event.id) == "event_bell_at_bridge", "third contract fixes the bridge event before travel")
	var expected_path := [World.CAMP_ID, "loc_ridge_pass", "loc_bridgehead", "loc_ridge_pass", "loc_hunter_edge", "loc_granary"]
	check(c.world.travel.route_path == expected_path and int(c.world.travel.event_step) == 2, "third ridge contract saves its bridge detour and event step")
	c = _round_trip(c, "bridge detour travel")
	check(not c.is_empty() and c.world.travel.route_path == expected_path and int(c.world.travel.event_step) == 2, "bridge detour and event step survive reload")
	check(Campaign.advance_travel(c).get("ok", false) and Campaign.advance_travel(c).get("ok", false) and c.phase == "event" and str(c.world.company_location_id) == "loc_bridgehead", "saved bridge detour reaches the bridgehead event")

func _test_three_outcomes_and_return() -> void:
	for outcome in ["victory", "retreat", "defeat"]:
		var c := Campaign.create_campaign("hunters" if outcome == "defeat" else "free", 2200 + checks)
		check(Campaign.start_expedition(c, "road").get("ok", false) and _choose_and_advance_to_ready(c), outcome + " fixture reaches battle readiness")
		var before_result_day := int(c.day)
		var result := _battle_result(c, outcome, outcome == "defeat", 2)
		check(Campaign.resolve_battle(c, result).get("ok", false), outcome + " settles once")
		check(c.claimed.has(str(c.expedition.id)) and int(c.day) == before_result_day + 1 and str(c.world.travel.status) == "returning", outcome + " records the unique claim and one result day")
		check(_finish_growth(c), outcome + " has a finite post-result growth path")
		var resources_before_return := [int(c.gold), int(c.food), int(c.day)]
		check(Campaign.return_to_camp(c).get("ok", false), outcome + " returns to camp")
		check([int(c.gold), int(c.food), int(c.day)] == resources_before_return and c.phase == "camp" and c.world.travel.is_empty(), outcome + " return adds no reward, food cost, or day")
		check(str(c.world.location_states.get("loc_granary", {}).get("flags", {}).get("last_outcome", "")) == outcome, outcome + " persists its location consequence")
		if outcome == "defeat":
			c.gold = 0
			c.food = 0
			check(Campaign.camp_action(c, "recruit").get("ok", false), "all-dead defeat can use advance-backed recruitment")
			check(Campaign.camp_action(c, "resupply").get("ok", false), "zero-money zero-food defeat can recover rations")

func _test_atomic_rejections() -> void:
	var c := Campaign.create_campaign("free", 2301)
	var before := _snapshot(c)
	check(not Campaign.accept_contract(c, "unknown", "road").get("ok", false) and _snapshot(c) == before, "unknown contract rejection is atomic")
	check(not Campaign.accept_contract(c, World.CONTRACT_ID, "unknown").get("ok", false) and _snapshot(c) == before, "unknown route rejection is atomic")
	c.food = 1
	before = _snapshot(c)
	check(not Campaign.accept_contract(c, World.CONTRACT_ID, "road").get("ok", false) and _snapshot(c) == before, "unaffordable contract rejection is atomic")
	c.food = 8
	check(Campaign.start_expedition(c).get("ok", false), "atomic fixture starts")
	before = _snapshot(c)
	check(not Campaign.start_expedition(c).get("ok", false) and _snapshot(c) == before, "duplicate acceptance cannot reroll or recharge")
	check(_advance_to_event(c), "atomic fixture reaches event")
	before = _snapshot(c)
	check(not Campaign.choose_event(c, "missing_choice").get("ok", false) and _snapshot(c) == before, "unknown event choice rejection is atomic")
	var choice_id := str(c.event.choices[0].id)
	check(Campaign.choose_event(c, choice_id).get("ok", false), "valid event choice resolves once")
	before = _snapshot(c)
	check(not Campaign.choose_event(c, choice_id).get("ok", false) and _snapshot(c) == before, "duplicate event resolution is atomic")
	while c.phase == "travel":
		Campaign.advance_travel(c)
	before = _snapshot(c)
	var skipped_battle := _actual_battle(c)
	skipped_battle.outcome = "victory"
	check(not Campaign.resolve_battle(c, skipped_battle).get("ok", false) and _snapshot(c) == before, "ready phase cannot settle a fabricated completed battle")
	var wrong_battle := _actual_battle(c)
	wrong_battle.id = "wrong"
	check(not Campaign.begin_battle(c, wrong_battle).get("ok", false) and _snapshot(c) == before, "mismatched battle rejection is atomic")
	var battle := _actual_battle(c)
	check(Campaign.begin_battle(c, battle).get("ok", false), "valid battle begins once")
	before = _snapshot(c)
	check(not Campaign.begin_battle(c, battle).get("ok", false) and _snapshot(c) == before, "duplicate battle begin is atomic")
	var foreign_result: Dictionary = c.battle.duplicate(true)
	foreign_result.outcome = "retreat"
	check(not Campaign.resolve_battle(c, foreign_result).get("ok", false) and _snapshot(c) == before, "unregistered battle result rejection is atomic")
	var result := _battle_result(c, "retreat")
	check(Campaign.resolve_battle(c, result).get("ok", false), "valid result settles once")
	before = _snapshot(c)
	check(not Campaign.resolve_battle(c, result).get("ok", false) and _snapshot(c) == before, "duplicate claim rejection is atomic")
	check(Campaign.return_to_camp(c).get("ok", false), "settled contract returns once")
	before = _snapshot(c)
	check(not Campaign.return_to_camp(c).get("ok", false) and _snapshot(c) == before, "duplicate return rejection is atomic")

func _test_world_phase_round_trips() -> void:
	var c := Campaign.create_campaign("free", 2401)
	c = _round_trip(c, "camp phase")
	Campaign.start_expedition(c, "ridge")
	c = _round_trip(c, "pre-event travel phase")
	while c.phase == "travel":
		Campaign.advance_travel(c)
	c = _round_trip(c, "event phase")
	Campaign.choose_event(c, str(c.event.choices[0].id))
	if c.phase == "travel":
		c = _round_trip(c, "post-event travel phase")
	while c.phase == "travel":
		Campaign.advance_travel(c)
	c = _round_trip(c, "ready phase")
	Campaign.begin_battle(c, _actual_battle(c))
	c = _round_trip(c, "battle phase")
	Campaign.resolve_battle(c, _battle_result(c, "victory"))
	check(c.phase == "growth", "victory fixture reaches growth phase")
	c = _round_trip(c, "growth phase")
	Campaign.choose_growth(c, str(c.growth_offers[0].id))
	c = _round_trip(c, "returning phase")
	check(Campaign.return_to_camp(c).get("ok", false), "loaded returning phase remains completable")

func _legacy_copy(c: Dictionary) -> Dictionary:
	var legacy := c.duplicate(true)
	legacy.erase("world")
	for key in ["contract_id", "travel_id", "location_id"]:
		legacy.get("expedition", {}).erase(key)
	for key in ["event_instance_id", "scope", "content_version", "location_id", "legacy_direct_ready"]:
		legacy.get("event", {}).erase(key)
	return legacy

func _load_legacy(c: Dictionary, label: String) -> Dictionary:
	_cleanup()
	var legacy := _legacy_copy(c)
	var resource_signature := [legacy.gold, legacy.food, legacy.day, legacy.rng_state]
	check(Saves.save_campaign(legacy, SAVE_PATH).get("ok", false), label + " legacy structure validates before migration")
	var loaded := Saves.load_campaign(SAVE_PATH)
	check(loaded.get("ok", false) and loaded.get("upgraded", false), label + " legacy structure upgrades")
	if loaded.get("ok", false):
		check([loaded.campaign.gold, loaded.campaign.food, loaded.campaign.day, loaded.campaign.rng_state] == resource_signature, label + " migration does not recharge or reroll")
		check(Saves.validate(loaded.campaign).is_empty(), label + " upgraded world is cross-field valid")
		return loaded.campaign
	return {}

func _test_legacy_phase_upgrades() -> void:
	var camp := Campaign.create_campaign("free", 2501)
	var upgraded_camp := _load_legacy(camp, "camp phase")
	check(not upgraded_camp.is_empty() and upgraded_camp.phase == "camp" and upgraded_camp.world.travel.is_empty(), "legacy camp stays at camp")

	var event_state := Campaign.create_campaign("free", 2502)
	Campaign.start_expedition(event_state)
	_advance_to_event(event_state)
	var upgraded_event := _load_legacy(event_state, "event phase")
	check(not upgraded_event.is_empty() and upgraded_event.phase == "event", "legacy unresolved event stays open")
	if not upgraded_event.is_empty():
		check(Campaign.choose_event(upgraded_event, str(upgraded_event.event.choices[0].id)).get("ok", false) and upgraded_event.phase == "ready", "legacy event keeps its direct event-to-ready continuation")

	var ready_state := Campaign.create_campaign("free", 2503)
	Campaign.start_expedition(ready_state)
	_choose_and_advance_to_ready(ready_state)
	var upgraded_ready := _load_legacy(ready_state, "ready phase")
	check(not upgraded_ready.is_empty() and upgraded_ready.phase == "ready", "legacy ready phase stays ready")

	var battle_state := ready_state.duplicate(true)
	Campaign.begin_battle(battle_state, _actual_battle(battle_state))
	var upgraded_battle := _load_legacy(battle_state, "battle phase")
	check(not upgraded_battle.is_empty() and upgraded_battle.phase == "battle" and not upgraded_battle.battle.is_empty(), "legacy battle phase preserves the full battle")

	var growth_state := ready_state.duplicate(true)
	Campaign.resolve_battle(growth_state, _battle_result(growth_state, "victory"))
	var offers_before: Array = growth_state.growth_offers.duplicate(true)
	var upgraded_growth := _load_legacy(growth_state, "growth phase")
	check(not upgraded_growth.is_empty() and upgraded_growth.phase == "growth" and upgraded_growth.growth_offers == offers_before, "legacy growth phase preserves generated candidates")
