extends SceneTree

const Rules = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_origins_and_camp_recovery()
	_test_expedition_routes()
	_test_events_are_saved_and_have_safe_paths()
	_test_result_claims_casualties_and_recovery()
	_test_three_expedition_closure()
	_test_growth_offer_save_and_absence_path()
	_test_json_determinism()
	print("Campaign rules: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func choose_first(c: Dictionary) -> Dictionary:
	while str(c.get("phase", "")) == "travel":
		var advanced := Rules.advance_travel(c)
		if not advanced.get("ok", false):
			return advanced
	var choices: Array = c.event.get("choices", [])
	if choices.is_empty():
		return {"ok": false, "reason": "event has no choices"}
	var result := Rules.choose_event(c, str(choices[0].id))
	while result.get("ok", false) and str(c.get("phase", "")) == "travel":
		var advanced := Rules.advance_travel(c)
		if not advanced.get("ok", false):
			return advanced
	return result

func replace_current_event(c: Dictionary, event_id: String) -> void:
	var event := Rules._make_event(c, event_id)
	var travel: Dictionary = c.world.travel
	var instance_id := "%s:%s" % [str(c.expedition.id), event_id]
	event.event_instance_id = instance_id
	event.scope = "travel"
	event.content_version = "world-0.1"
	event.location_id = str(travel.route_path[int(travel.event_step)])
	c.event = event
	c.expedition.event_id = event_id
	travel.event_instance_id = instance_id

func battle_result(c: Dictionary, outcome: String, dead_ids: Array = [], grain_alive := true, dead_enemies := 0) -> Dictionary:
	if str(c.phase) == "ready":
		var battle := Battle.create_battle(c.roster, int(c.seed) + int(c.expedition.index) * 7919, Rules.battle_config(c))
		Rules.begin_battle(c, battle)
	for unit: Dictionary in c.battle.units:
		if str(unit.team) == "player":
			if str(unit.id) in dead_ids:
				unit.hp = 0
		elif dead_enemies > 0:
			unit.hp = 0
			dead_enemies -= 1
	for prop: Dictionary in c.battle.props:
		if str(prop.kind) == "grain":
			prop.hp = 14 if grain_alive else 0
	c.battle.outcome = outcome
	return c.battle

func resolve_victory_to_camp(c: Dictionary, grain_alive := true) -> Dictionary:
	var result := Rules.resolve_battle(c, battle_result(c, "victory", [], grain_alive))
	if c.phase == "growth" and not c.growth_offers.is_empty():
		Rules.choose_growth(c, str(c.growth_offers[0].id))
	if c.phase == "returning":
		Rules.return_to_camp(c)
	return result

func event_signature(event: Dictionary) -> String:
	var choices: Array = []
	for choice: Dictionary in event.get("choices", []):
		choices.append([
			str(choice.get("id", "")), str(choice.get("title", "")), str(choice.get("description", "")),
			int(choice.get("costs", {}).get("gold", 0)), int(choice.get("costs", {}).get("food", 0)),
			int(choice.get("effects", {}).get("gold", 0)), int(choice.get("effects", {}).get("food", 0)),
			int(choice.get("effects", {}).get("reward", 0)), int(choice.get("effects", {}).get("difficulty", 0)),
			int(choice.get("effects", {}).get("oil", 0)), int(choice.get("effects", {}).get("fire", 0)), int(choice.get("effects", {}).get("water", 0)),
			int(choice.get("effects", {}).get("renown", 0)), int(choice.get("effects", {}).get("heal", 0))
		])
	return JSON.stringify([str(event.get("id", "")), str(event.get("participant_id", "")), choices])

func state_signature(c: Dictionary) -> String:
	var roster: Array = []
	for unit: Dictionary in c.get("roster", []):
		roster.append([str(unit.id), int(unit.hp), int(unit.armor), int(unit.max_hp), int(unit.accuracy), unit.get("perks", []).duplicate()])
	return JSON.stringify([
		int(c.get("rng_state", 0)), str(c.get("phase", "")), int(c.get("gold", 0)), int(c.get("food", 0)), int(c.get("day", 0)), int(c.get("renown", 0)),
		str(c.get("expedition", {}).get("id", "")), int(c.get("expedition", {}).get("difficulty", 0)), int(c.get("expedition", {}).get("reward", 0)),
		int(c.get("expedition", {}).get("supplies", {}).get("oil", 0)), int(c.get("expedition", {}).get("supplies", {}).get("fire", 0)), int(c.get("expedition", {}).get("supplies", {}).get("water", 0)),
		event_signature(c.get("event", {})), roster
	])

func route_by_id(routes: Array, route_id: String) -> Dictionary:
	for route: Dictionary in routes:
		if str(route.get("id", "")) == route_id:
			return route
	return {}

func _test_expedition_routes() -> void:
	var preview_campaign := Rules.create_campaign("free", 31)
	var preview_before := JSON.stringify(preview_campaign)
	var routes := Rules.get_routes(preview_campaign)
	var road := route_by_id(routes, "road")
	var ridge := route_by_id(routes, "ridge")
	check(JSON.stringify(preview_campaign) == preview_before, "route preview is pure and does not advance campaign RNG or state")
	var required_fields := ["id", "name", "description", "food_cost", "days", "difficulty", "reward", "supplies", "available", "reason"]
	var complete_preview := routes.size() == 2
	for route: Dictionary in routes:
		for field: String in required_fields:
			complete_preview = complete_preview and route.has(field)
	check(complete_preview, "two route previews expose the complete stable UI contract")
	check(str(road.get("name", "")) == "渡口旧道" and bool(road.get("available", false)) and int(road.get("food_cost", 0)) == 2 and int(road.get("days", 0)) == 1 and int(road.get("difficulty", -1)) == 0 and int(road.get("reward", 0)) == 42 and int(road.get("supplies", {}).get("oil", 0)) == 1, "ferry road preserves the prior first-expedition cost, risk, reward, and supplies")
	check(bool(ridge.get("available", false)) and int(ridge.get("food_cost", 0)) == 3 and int(ridge.get("days", 0)) == 1 and int(ridge.get("difficulty", -1)) == 1 and int(ridge.get("reward", 0)) == 60 and int(ridge.get("supplies", {}).get("oil", 0)) == 2, "ridge trades one ration for higher risk, reward, and oil")
	check(not str(road.get("reason", "")).is_empty() and not str(ridge.get("reason", "")).is_empty(), "available route previews explain that departure is possible")

	var road_campaign := Rules.create_campaign("free", 32)
	var road_preview := route_by_id(Rules.get_routes(road_campaign), "road")
	var road_start := Rules.start_expedition(road_campaign)
	var road_config := Rules.battle_config(road_campaign)
	check(road_start.ok and int(road_campaign.food) == 6 and int(road_campaign.day) == 2 and str(road_campaign.expedition.route_id) == "road" and str(road_campaign.expedition.route_name) == str(road_preview.name) and int(road_campaign.expedition.route_food_cost) == int(road_preview.food_cost) and int(road_campaign.expedition.route_days) == int(road_preview.days), "default expedition remains the old road and saves its selected route")
	check(int(road_campaign.expedition.difficulty) == int(road_preview.difficulty) and int(road_campaign.expedition.reward) == int(road_preview.reward) and JSON.stringify(road_campaign.expedition.supplies) == JSON.stringify(road_preview.supplies) and str(road_config.route_id) == "road" and str(road_config.route_name) == str(road_preview.name), "road preview, expedition, and battle mission use one configuration")
	check(road_campaign.history.size() == 1 and str(road_campaign.history[0].type) == "departure" and str(road_campaign.history[0].route_id) == "road" and int(road_campaign.history[0].route_food_cost) == 2 and int(road_campaign.history[0].route_days) == 1, "departure history records route and its paid cost")
	check(choose_first(road_campaign).ok and str(Rules.battle_config(road_campaign).route_id) == "road" and resolve_victory_to_camp(road_campaign).ok, "road selection survives event choice and battle settlement")

	var ridge_campaign := Rules.create_campaign("hunters", 33)
	var ridge_preview := route_by_id(Rules.get_routes(ridge_campaign), "ridge")
	var ridge_start := Rules.start_expedition(ridge_campaign, "ridge")
	var ridge_config := Rules.battle_config(ridge_campaign)
	check(ridge_start.ok and int(ridge_campaign.food) == 5 and int(ridge_campaign.day) == 2 and str(ridge_campaign.expedition.route_id) == "ridge" and int(ridge_campaign.expedition.difficulty) == int(ridge_preview.difficulty) and int(ridge_campaign.expedition.reward) == int(ridge_preview.reward) and int(ridge_campaign.expedition.supplies.oil) == int(ridge_preview.supplies.oil) and str(ridge_config.route_id) == "ridge" and str(ridge_config.route_name) == str(ridge_preview.name), "ridge consequences reach the mission without creating a new battle or event path")

	var insufficient := Rules.create_campaign("free", 34)
	insufficient.food = 2
	var insufficient_before := JSON.stringify(insufficient)
	check(not bool(route_by_id(Rules.get_routes(insufficient), "ridge").get("available", true)) and not Rules.start_expedition(insufficient, "ridge").ok and JSON.stringify(insufficient) == insufficient_before, "unaffordable ridge is previewed and rejected without changing state or RNG")
	insufficient.food = 1
	insufficient_before = JSON.stringify(insufficient)
	check(not Rules.start_expedition(insufficient).ok and JSON.stringify(insufficient) == insufficient_before, "unaffordable road is rejected without changing state or RNG")

	var invalid := Rules.create_campaign("free", 35)
	var invalid_before := JSON.stringify(invalid)
	check(not Rules.start_expedition(invalid, "river").ok and JSON.stringify(invalid) == invalid_before, "unknown route is rejected before any campaign mutation")
	check(Rules.start_expedition(invalid).ok, "valid road starts after an unknown-route rejection")
	invalid_before = JSON.stringify(invalid)
	check(not Rules.start_expedition(invalid, "ridge").ok and JSON.stringify(invalid) == invalid_before, "repeated departure cannot replace route, event, or RNG state")

	var capped := Rules.create_campaign("free", 36)
	capped.flags.expeditions_started = 4
	var capped_road := route_by_id(Rules.get_routes(capped), "road")
	var capped_ridge := route_by_id(Rules.get_routes(capped), "ridge")
	check(int(capped_road.get("difficulty", -1)) == 2 and int(capped_ridge.get("difficulty", -1)) == 2 and "敌情已达当前区域上限" in str(capped_ridge.get("description", "")) and "补给与收益选择" in str(capped_ridge.get("description", "")), "capped ridge preview states that risk matches the road and choice is supplies for reward")

	var recovery := Rules.create_campaign("free", 37)
	recovery.flags.expeditions_started = 4
	recovery.flags.last_outcome = "defeat"
	var recovery_road := route_by_id(Rules.get_routes(recovery), "road")
	var recovery_ridge := route_by_id(Rules.get_routes(recovery), "ridge")
	check(int(recovery_road.get("difficulty", -1)) == 0 and int(recovery_ridge.get("difficulty", -1)) == 1 and "上次失利让敌情回落" in str(recovery_ridge.get("description", "")) and not "敌情已达当前区域上限" in str(recovery_ridge.get("description", "")), "failure recovery preview restores road to zero and describes the ridge's remaining added risk")

func _test_origins_and_camp_recovery() -> void:
	var free := Rules.create_campaign("free", 12)
	var hunters := Rules.create_campaign("hunters", 12)
	check(free.origin == "free" and free.roster.size() == 4 and str(free.roster[3].kind) == "skirmisher", "free company has its four distinct deployment roles")
	check(hunters.origin == "hunters" and str(hunters.roster[2].kind) == "hunter" and str(hunters.roster[3].kind) == "dog", "hunter company pays a deployment slot for its dog")
	check(str(hunters.roster[3].hunter_id) == str(hunters.roster[2].id), "hunter company binds dog to its hunter")
	free.roster[0].hp = 12
	free.roster[0].armor = 3
	var rest := Rules.camp_action(free, "rest")
	check(rest.ok and free.roster[0].hp == 30 and free.food == 6 and free.day == 2, "rationed rest has an explicit food and day cost")
	free.gold = 0
	var repair := Rules.camp_action(free, "repair")
	check(repair.ok and free.roster[0].armor == 9 and free.day == 3, "poor company can patch armor without a money soft-lock")
	free.food = 0
	var resupply := Rules.camp_action(free, "resupply")
	check(resupply.ok and free.food == 4 and free.day == 5, "poor and hungry company has a constrained work-for-food recovery path")

func _test_events_are_saved_and_have_safe_paths() -> void:
	var c := Rules.create_campaign("free", 41)
	var start := Rules.start_expedition(c)
	check(start.ok and c.phase == "travel" and str(c.event.id) == "event_bell_on_bank", "first expedition saves its stable opening event before travel")
	var saved_event := JSON.stringify(c.event)
	check(not Rules.start_expedition(c).ok and JSON.stringify(c.event) == saved_event, "reopening an unresolved expedition cannot reroll its event")
	check(Rules.advance_travel(c).ok and c.phase == "event", "travel reaches the saved opening event")
	var six_ids := ["event_bell_on_bank", "event_granary_stores", "event_hunter_tracks", "event_village_reply", "event_unposted_letter", "event_bell_at_bridge"]
	for event_id: String in six_ids:
		var event := Rules._make_event(c, event_id)
		check(str(event.id) == event_id and event.get("choices", []).size() >= 2 and not str(event.trigger).is_empty(), "%s declares stable trigger and choices" % event_id)
		check(not str(event.absence_path).is_empty() and not str(event.test_path).is_empty(), "%s declares an absence route and test path" % event_id)
	var event_choice := choose_first(c)
	check(event_choice.ok and c.phase == "ready" and str(c.event.selected_choice) == "bell_protect", "event choice is applied once and records its consequence")
	resolve_victory_to_camp(c)
	check(bool(c.flags.villagers_promised), "opening promise persists after its battle result")
	var next_start := Rules.start_expedition(c)
	check(next_start.ok and str(c.event.id) == "event_village_reply", "promise condition selects the single follow-up event")
	while c.phase == "travel":
		Rules.advance_travel(c)
	var promised_participant := str(c.event.participant_id)
	for member: Dictionary in c.roster:
		if str(member.id) == promised_participant:
			member.hp = 0
	var absent_choice := choose_first(c)
	check(absent_choice.ok and c.phase == "ready" and "缺席" in str(absent_choice.reason), "a dead event participant transfers the promise to the company")
	var c3 := Rules.create_campaign("free", 42)
	c3.flags.expeditions_started = 2
	check(Rules.start_expedition(c3).ok and str(c3.event.id) == "event_bell_at_bridge", "third expedition selects bridge closure regardless of prior cast")
	var hungry_free := Rules.create_campaign("free", 43)
	Rules.start_expedition(hungry_free)
	while hungry_free.phase == "travel":
		Rules.advance_travel(hungry_free)
	hungry_free.food = 0
	replace_current_event(hungry_free, "event_hunter_tracks")
	check(not Rules.choose_event(hungry_free, "tracks_scout").ok and Rules.choose_event(hungry_free, "tracks_salvage").ok, "non-hunter tracking preserves a free alternative when food is gone")
	var hunters := Rules.create_campaign("hunters", 44)
	Rules.start_expedition(hunters)
	while hunters.phase == "travel":
		Rules.advance_travel(hunters)
	hunters.food = 0
	replace_current_event(hunters, "event_hunter_tracks")
	var hunter_choice := Rules.choose_event(hunters, "tracks_scout")
	while hunters.phase == "travel":
		Rules.advance_travel(hunters)
	check(hunter_choice.ok and hunters.phase == "ready", "hunter tracking removes the food cost through its roster-specific method")

func _test_result_claims_casualties_and_recovery() -> void:
	var c := Rules.create_campaign("hunters", 64)
	Rules.start_expedition(c)
	choose_first(c)
	var fallen_id := str(c.roster[2].id)
	var defeat := Rules.resolve_battle(c, battle_result(c, "defeat", [fallen_id]))
	check(defeat.ok and c.phase == "returning" and int(c.roster[2].hp) == 0, "defeat carries a named casualty into the return state")
	check(c.flags.memorial.size() == 1 and str(c.flags.memorial[0].id) == fallen_id, "casualty enters memorial exactly once")
	var settled := JSON.stringify(c)
	check(not Rules.resolve_battle(c, c.battle).ok and JSON.stringify(c) == settled, "same expedition cannot claim a second settlement or reward")
	check(Rules.return_to_camp(c).ok, "defeated survivors complete the explicit return trip")
	var recruit := Rules.camp_action(c, "recruit")
	check(recruit.ok and int(c.roster[2].hp) > 0 and str(c.roster[2].kind) == "hunter", "casualty can be replaced in its original tactical slot")
	check(str(c.roster[3].hunter_id) == str(c.roster[2].id), "replacement hunter rebinds surviving dog")
	var retreat_company := Rules.create_campaign("free", 65)
	Rules.start_expedition(retreat_company)
	choose_first(retreat_company)
	retreat_company.roster[0].hp = 7
	var retreat := Rules.resolve_battle(retreat_company, battle_result(retreat_company, "retreat", [], false, 2))
	check(retreat.ok and retreat_company.phase == "returning" and int(retreat_company.roster[0].hp) == 7 and int(retreat_company.gold) == 78, "retreat preserves injuries and only pays bounded scavenged loot")
	check(Rules.return_to_camp(retreat_company).ok, "retreat can always return to camp")

func _test_three_expedition_closure() -> void:
	var c := Rules.create_campaign("free", 77)
	for index in range(3):
		check(Rules.start_expedition(c).ok, "short story expedition %d starts" % (index + 1))
		check(choose_first(c).ok, "short story expedition %d has a playable choice" % (index + 1))
		var result := resolve_victory_to_camp(c, index != 1)
		check(result.ok, "short story expedition %d resolves" % (index + 1))
	check(bool(c.flags.ending_seen) and not str(c.flags.ending_text).is_empty(), "third completed expedition produces a finite story closure")
	check(c.phase == "camp" and Rules.start_expedition(c).ok, "story closure leaves the company playable for later expeditions")

func _test_growth_offer_save_and_absence_path() -> void:
	var c := Rules.create_campaign("free", 91)
	Rules.start_expedition(c)
	choose_first(c)
	var result := Rules.resolve_battle(c, battle_result(c, "victory"))
	check(result.ok and c.phase == "growth" and c.growth_offers.size() == 3, "victory saves exactly one three-choice growth offer")
	var saved := JSON.stringify(c.growth_offers)
	check(not Rules.choose_growth(c, "not-an-offer").ok and JSON.stringify(c.growth_offers) == saved, "invalid growth choice preserves saved offer")
	var basic_present := false
	for offer: Dictionary in c.growth_offers:
		if str(offer.get("perk", "")) in ["vigor", "precision"]:
			basic_present = true
	check(basic_present, "growth candidates retain an eligible basic direction")
	var target_id := str(c.growth_unit_id)
	for member: Dictionary in c.roster:
		if str(member.id) == target_id:
			member.hp = 0
	var gold_before := int(c.gold)
	var absence := Rules.choose_growth(c, str(c.growth_offers[0].id))
	check(absence.ok and c.phase == "returning" and int(c.gold) == gold_before + 12, "missing growth recipient resolves to a finite company-wide fallback")
	check(Rules.return_to_camp(c).ok, "growth fallback still completes the return trip")

func _test_json_determinism() -> void:
	var original := Rules.create_campaign("hunters", 1234)
	Rules.start_expedition(original)
	var restored = JSON.parse_string(JSON.stringify(original))
	check(event_signature(original.event) == event_signature(restored.event), "JSON round trip preserves generated event and its participant")
	var a := choose_first(original)
	var b := choose_first(restored)
	check(a.ok and b.ok and state_signature(original) == state_signature(restored), "JSON-restored campaign applies the same event effects deterministically")
	var battle_a := battle_result(original, "victory")
	var battle_b := battle_result(restored, "victory")
	Rules.resolve_battle(original, battle_a)
	Rules.resolve_battle(restored, battle_b)
	check(JSON.stringify(original.growth_offers) == JSON.stringify(restored.growth_offers), "same JSON state produces the same saved growth candidates")
