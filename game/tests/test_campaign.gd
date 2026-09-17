extends SceneTree

const Rules = preload("res://core/campaign_rules.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_origins_and_camp_recovery()
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
	var choices: Array = c.event.get("choices", [])
	if choices.is_empty():
		return {"ok": false, "reason": "event has no choices"}
	return Rules.choose_event(c, str(choices[0].id))

func battle_result(c: Dictionary, outcome: String, dead_ids: Array = [], grain_alive := true, dead_enemies := 0) -> Dictionary:
	var units: Array = []
	for member: Dictionary in c.roster:
		if int(member.hp) <= 0:
			continue
		var result := {"id": str(member.id), "team": "player", "hp": int(member.hp), "armor": int(member.armor)}
		if str(member.id) in dead_ids:
			result.hp = 0
		units.append(result)
	for i in range(dead_enemies):
		units.append({"id": "enemy_test_%d" % i, "team": "enemy", "hp": 0, "armor": 0})
	return {
		"id": str(c.expedition.id), "outcome": outcome, "units": units,
		"props": [{"id": "grain", "kind": "grain", "hp": 14 if grain_alive else 0}]
	}

func resolve_victory_to_camp(c: Dictionary, grain_alive := true) -> Dictionary:
	var result := Rules.resolve_battle(c, battle_result(c, "victory", [], grain_alive))
	if c.phase == "growth" and not c.growth_offers.is_empty():
		Rules.choose_growth(c, str(c.growth_offers[0].id))
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
	check(start.ok and c.phase == "event" and str(c.event.id) == "event_bell_on_bank", "first expedition has stable opening event")
	var saved_event := JSON.stringify(c.event)
	check(not Rules.start_expedition(c).ok and JSON.stringify(c.event) == saved_event, "reopening an unresolved expedition cannot reroll its event")
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
	hungry_free.food = 0
	hungry_free.event = Rules._make_event(hungry_free, "event_hunter_tracks")
	check(not Rules.choose_event(hungry_free, "tracks_scout").ok and Rules.choose_event(hungry_free, "tracks_salvage").ok, "non-hunter tracking preserves a free alternative when food is gone")
	var hunters := Rules.create_campaign("hunters", 44)
	Rules.start_expedition(hunters)
	hunters.food = 0
	hunters.event = Rules._make_event(hunters, "event_hunter_tracks")
	check(Rules.choose_event(hunters, "tracks_scout").ok and hunters.phase == "ready", "hunter tracking removes the food cost through its roster-specific method")

func _test_result_claims_casualties_and_recovery() -> void:
	var c := Rules.create_campaign("hunters", 64)
	Rules.start_expedition(c)
	choose_first(c)
	var fallen_id := str(c.roster[2].id)
	var defeat := Rules.resolve_battle(c, battle_result(c, "defeat", [fallen_id]))
	check(defeat.ok and c.phase == "camp" and int(c.roster[2].hp) == 0, "defeat carries a named casualty into campaign state")
	check(c.flags.memorial.size() == 1 and str(c.flags.memorial[0].id) == fallen_id, "casualty enters memorial exactly once")
	var settled := JSON.stringify(c)
	check(not Rules.resolve_battle(c, c.battle).ok and JSON.stringify(c) == settled, "same expedition cannot claim a second settlement or reward")
	var recruit := Rules.camp_action(c, "recruit")
	check(recruit.ok and int(c.roster[2].hp) > 0 and str(c.roster[2].kind) == "hunter", "casualty can be replaced in its original tactical slot")
	check(str(c.roster[3].hunter_id) == str(c.roster[2].id), "replacement hunter rebinds surviving dog")
	var retreat_company := Rules.create_campaign("free", 65)
	Rules.start_expedition(retreat_company)
	choose_first(retreat_company)
	retreat_company.roster[0].hp = 7
	var retreat := Rules.resolve_battle(retreat_company, battle_result(retreat_company, "retreat", [], false, 2))
	check(retreat.ok and retreat_company.phase == "camp" and int(retreat_company.roster[0].hp) == 7 and int(retreat_company.gold) == 78, "retreat preserves injuries and only pays bounded scavenged loot")

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
	check(absence.ok and c.phase == "camp" and int(c.gold) == gold_before + 12, "missing growth recipient resolves to a finite company-wide fallback")

func _test_json_determinism() -> void:
	var original := Rules.create_campaign("hunters", 1234)
	Rules.start_expedition(original)
	var restored = JSON.parse_string(JSON.stringify(original))
	check(event_signature(original.event) == event_signature(restored.event), "JSON round trip preserves generated event and its participant")
	var choice_id := str(original.event.choices[0].id)
	var a := Rules.choose_event(original, choice_id)
	var b := Rules.choose_event(restored, choice_id)
	check(a.ok and b.ok and state_signature(original) == state_signature(restored), "JSON-restored campaign applies the same event effects deterministically")
	var battle_a := battle_result(original, "victory")
	var battle_b := battle_result(restored, "victory")
	Rules.resolve_battle(original, battle_a)
	Rules.resolve_battle(restored, battle_b)
	check(JSON.stringify(original.growth_offers) == JSON.stringify(restored.growth_offers), "same JSON state produces the same saved growth candidates")
