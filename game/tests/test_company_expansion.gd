extends SceneTree
const Campaign = preload("res://core/campaign_rules.gd")
const Company = preload("res://core/company_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const LegacyBattle = preload("res://tests/legacy_battle_rules.gd")
const World = preload("res://core/world_data.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_recruitment_and_economy()
	_test_deployment_and_contract()
	_test_quote_and_camp_cleanup()
	_test_real_source_event()
	print("Company expansion: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func _test_recruitment_and_economy() -> void:
	var c := Campaign.create_campaign("free", 901)
	var before := JSON.stringify(c)
	check(not Company.ensure(c) and JSON.stringify(c) == before, "ensure and opening the view do not reroll or mutate saved candidates")
	var view := Company.get_view(c)
	check(view.candidates.size() == 2 and int(view.candidates[0].fee) < int(view.candidates[1].fee) and int(view.candidates[0].wage) < int(view.candidates[1].wage), "ordinary and mature recruits expose price and daily cost")
	check(JSON.stringify(c) == before, "read-only company view leaves state untouched")
	var id := str(view.candidates[0].id)
	var recruit := Company.recruit(c, id)
	check(recruit.ok and c.roster.size() == 5 and str(c.roster[4].id) == str(recruit.unit_id), "candidate joins as a stable new unit")
	check(not Company.recruit(c, id).ok, "candidate cannot be recruited twice")
	check(c.roster[4].get("equipment", {}).get("weapon", "") != "", "recruit receives an owned basic weapon")
	var veteran_company := Campaign.create_campaign("free", 908)
	var veteran := Company.recruit(veteran_company, str(veteran_company.company.candidates[1].id))
	check(veteran.ok and int(veteran_company.roster[4].progression.level) == 2 and int(veteran_company.roster[4].progression.xp) == 100 and int(veteran_company.roster[4].daily_maintenance) == 4, "mature origin's starting level and ongoing cost are real")
	var day := int(c.day)
	check(Company.tick(c).ok and int(c.day) == day and int(c.company.last_maintenance_day) == day, "reopening does not charge daily upkeep")
	c.day = day + 1
	var paid := Company.tick(c)
	var once := JSON.stringify(c)
	check(paid.ok and int(paid.charged) > 0 and Company.tick(c).charged == 0 and JSON.stringify(c) == once, "daily maintenance charges exactly once")
	check(not Company.refresh(c).ok, "candidate refresh respects saved wait day")
	c.day = int(c.company.refresh_after_day)
	Company.tick(c)
	var refreshed := Company.refresh(c)
	check(refreshed.ok and str(c.company.candidates[0].id) != id, "paid timed refresh saves new unique candidate IDs")
	var work := Company.short_work(c)
	check(work.ok and c.claimed.has(str(work.instance_id)) and c.history.back().type == "short_work", "short work takes time and saves a single instance claim")
	var dead := Campaign.create_campaign("free", 902)
	for u: Dictionary in dead.roster: u.hp = 0
	dead.gold = 0; dead.food = 0
	check(Company.emergency_recruit(dead).ok and int(dead.gold) == 0 and int(dead.flags.advance_debt) > 0, "zero-resource wiped company has debt-backed emergency recruit")
	check(Company.short_work(dead).ok and int(dead.food) > 0, "zero-resource recovery can obtain food without battle XP")
	check(int(dead.gold) >= 8 and int(dead.company.maintenance_debt) == 0, "short work covers new upkeep and leaves usable cash")
	check(Company.validate(c).is_empty(), "company state remains structurally valid")

func _test_deployment_and_contract() -> void:
	var c := Campaign.create_campaign("hunters", 903)
	var reserve := Company.recruit(c, str(c.company.candidates[0].id))
	check(reserve.ok and c.roster.size() == 5, "hunter company can hire a fifth member as reserve")
	var slots := [{"unit_id": str(c.roster[0].id), "q": 0, "r": 1}, {"unit_id": str(c.roster[4].id), "q": 2, "r": 2}]
	check(Company.select_deployment(c, slots).ok, "one to four eligible people can be placed on legal left cells")
	check(not Company.select_deployment(c, [slots[0], slots[0]]).ok, "duplicate person or cell is rejected")
	var wounded: Dictionary = c.roster[4]
	wounded.recovery_until_day = int(c.day) + 2
	check(not Company.select_deployment(c, slots).ok, "serious wound blocks deployment until recovery day")
	wounded.recovery_until_day = 0
	var dog_only := [{"unit_id": str(c.roster[3].id), "q": 0, "r": 1}]
	check(not Company.select_deployment(c, dog_only).ok, "bound dog cannot depart without handler")
	check(Company.select_deployment(c, slots).ok, "eligible reserve can replace veteran")
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(c))
	check(str(serialized.company.deployment[1].unit_id) == str(slots[1].unit_id) and int(serialized.company.deployment[1].q) == 2 and str(serialized.company.candidates[0].id) == str(c.company.candidates[0].id), "save round trip preserves selected cells and recruit pool")
	check(Company.validate(serialized).is_empty(), "JSON restored company passes structural validation")
	var offers := Campaign.get_contract_offers(c, World.CAMP_ID)
	check(offers.size() == 3 and str(offers[1].kind) == "evacuation" and str(offers[2].kind) == "short_work", "offers expose distinct goals, costs and risks")
	var accepted := Campaign.accept_contract(c, World.EVACUATION_ID, "road")
	check(accepted.ok and c.expedition.participant_ids.size() == 2 and c.expedition.participant_ids[1] == str(wounded.id), "departure locks selected participants")
	check(Campaign.battle_roster(c).size() == 2 and c.expedition.deployment == slots, "battle roster excludes reserve and stores positions")
	var mission := Campaign.battle_config(c)
	var battle := Battle.create_battle(Campaign.battle_roster(c), 903, mission)
	check(str(mission.contract_kind) == "evacuation" and str(battle.get("deployment_error", "")).is_empty() and str(battle.objective.kind) == "evacuation", "battle reads saved legal deployment and evacuation objective")
	check(not Campaign.begin_battle(c, {"id": str(c.expedition.id), "deployment_error": "非法部署"}).ok, "invalid tactical deployment cannot start")
	while str(c.phase) == "travel" or str(c.phase) == "event":
		if str(c.phase) == "travel": Campaign.advance_travel(c)
		else: Campaign.choose_event(c, str(c.event.choices[0].id))
	check(Campaign.begin_battle(c, battle).ok, "validated mission starts")
	var reserve_xp := int(c.roster[1].progression.xp)
	var finished := battle.duplicate(true)
	finished.outcome = "victory"
	for unit: Dictionary in finished.units:
		if str(unit.get("team", "")) == "enemy": unit.hp = 0
	finished.objective.evacuated_ids = [str(c.roster[0].id), str(wounded.id)]
	c.battle = finished.duplicate(true)
	var settlement := Campaign.resolve_battle(c, finished)
	check(settlement.ok and int(c.roster[1].progression.xp) == reserve_xp, "settlement leaves reserve XP unchanged")
	check(str(c.get("growth_unit_id", "")) in c.expedition.participant_ids, "postbattle permanent growth selects an actual participant")
	check(not Campaign.resolve_battle(c, finished).ok, "contract instance cannot be claimed twice")

func _test_real_source_event() -> void:
	var c := Campaign.create_campaign("free", 904)
	var id := str(c.roster[0].id)
	var source := "battle_904:casualty:" + id
	c.battle = {"casualties": [{"id": source, "unit_id": id, "status": "survived", "roll": 7}]}
	Company.on_battle_settled(c, [{"unit_id": id, "casualty_id": source, "name": str(c.roster[0].name)}])
	check(str(c.company.pending_event.id) == Company.EVENT_ID and "lasting_wound" in c.roster[0].permanent_injuries and int(c.roster[0].max_fatigue) < 100, "saved severe casualty creates sourced lasting wound and finite event")
	var second_id := str(c.roster[1].id)
	var second_source := "battle_904:casualty:" + second_id
	c.battle.casualties.append({"id": second_source, "unit_id": second_id, "status": "survived", "roll": 5})
	Company.on_battle_settled(c, [{"unit_id": id, "casualty_id": source, "name": str(c.roster[0].name)}, {"unit_id": second_id, "casualty_id": second_source, "name": str(c.roster[1].name)}])
	check("lasting_wound" in c.roster[1].permanent_injuries and c.company.injury_sources.size() == 2, "all surviving casualties receive their own sourced permanent consequence")
	var second_until := int(c.roster[1].recovery_until_day)
	Company.on_battle_settled(c, [{"unit_id": second_id, "casualty_id": second_source, "name": str(c.roster[1].name)}])
	check(int(c.roster[1].recovery_until_day) == second_until, "same casualty source cannot extend recovery twice")
	var event_id := str(c.company.pending_event.instance_id)
	var absent: Dictionary = c.roster.pop_front()
	check(not Company.resolve_event(c, "review").ok and str(c.company.pending_event.instance_id) == event_id, "absent participant delays event")
	c.roster.push_front(absent)
	var resolved := Company.resolve_event(c, "rest")
	check(resolved.ok and event_id in c.company.event_claims and c.company.pending_event.is_empty(), "rest choice costs resources and claims once")
	check(not Company.resolve_event(c, "rest").ok, "claimed event cannot reward twice")
	var review := Campaign.create_campaign("free", 906)
	var review_id := str(review.roster[0].id)
	var review_source := "battle_906:casualty:" + review_id
	review.battle = {"casualties": [{"id": review_source, "unit_id": review_id, "status": "survived", "roll": 50}]}
	Company.on_battle_settled(review, [{"unit_id": review_id, "casualty_id": review_source, "name": str(review.roster[0].name)}])
	check(Company.resolve_event(review, "review").ok and str(review.roster[0].personality) == "cautious" and not "lasting_wound" in review.roster[0].get("permanent_injuries", []), "review costs money and creates cautious turn without inventing a permanent wound")
	var dead := Campaign.create_campaign("free", 907)
	var dead_id := str(dead.roster[0].id)
	var dead_source := "battle_907:casualty:" + dead_id
	dead.battle = {"casualties": [{"id": dead_source, "unit_id": dead_id, "status": "survived", "roll": 50}]}
	Company.on_battle_settled(dead, [{"unit_id": dead_id, "casualty_id": dead_source, "name": str(dead.roster[0].name)}])
	dead.roster[0].hp = 0
	var gold := int(dead.gold)
	check(Company.resolve_event(dead, "review").ok and dead.company.pending_event.is_empty() and int(dead.gold) == gold, "death path closes event without reward or fee")

func _test_quote_and_camp_cleanup() -> void:
	var c := Campaign.create_campaign("free", 909)
	c.roster[0].personality = "cautious"
	c.roster[1].permanent_injuries = ["lasting_wound"]
	c.food = 3
	var quote: Dictionary = Campaign.get_contract_offers(c, World.CAMP_ID)[1].routes[1]
	var before := JSON.stringify(c)
	check(int(quote.base_food_cost) == 3 and int(quote.extra_food_cost) == 1 and int(quote.food_cost) == 4 and not quote.available and not Campaign.accept_contract(c, World.EVACUATION_ID, "ridge").ok and JSON.stringify(c) == before, "extra ration is visible and unaffordable contract does not mutate state")
	c.food = 4
	quote = Campaign.get_contract_offers(c, World.CAMP_ID)[1].routes[1]
	var accepted := Campaign.accept_contract(c, World.EVACUATION_ID, "ridge")
	check(quote.available and accepted.ok and int(c.food) == 0 and int(c.expedition.route_food_cost) == int(quote.food_cost) and int(c.expedition.reward) == int(quote.reward) and int(c.expedition.supplies.water) == int(quote.supplies.water), "quoted ration, evacuation reward and cautious water equal accepted snapshot")
	var deaths := Campaign.create_campaign("free", 910)
	var old_id := str(deaths.roster[0].id)
	Campaign.start_expedition(deaths)
	while str(deaths.phase) == "travel" or str(deaths.phase) == "event":
		if str(deaths.phase) == "travel": Campaign.advance_travel(deaths)
		else: Campaign.choose_event(deaths, str(deaths.event.choices[0].id))
	var legacy := LegacyBattle.create_battle(Campaign.battle_roster(deaths), 910, Campaign.battle_config(deaths))
	Campaign.begin_battle(deaths, legacy)
	for unit: Dictionary in deaths.battle.units:
		if str(unit.get("id", "")) == old_id: unit.hp = 0
	deaths.battle.outcome = "defeat"
	check(Campaign.resolve_battle(deaths, deaths.battle).ok and old_id in deaths.expedition.participant_ids and not old_id in deaths.company.deployment.map(func(slot): return str(slot.unit_id)) and Company.validate(deaths).is_empty(), "battle settlement prunes dead member only from next camp deployment")
	Campaign.return_to_camp(deaths)
	var hired := Company.emergency_recruit(deaths)
	check(hired.ok and Company.validate(deaths).is_empty() and not old_id in deaths.company.deployment.map(func(slot): return str(slot.unit_id)) and Company.select_deployment(deaths, [{"unit_id": str(hired.unit_id), "q": 2, "r": 2}]).ok, "emergency replacement leaves a legal editable selection with no ghost ID")
	var direct := Campaign.create_campaign("free", 912)
	var vacated: Dictionary = direct.company.deployment[0].duplicate(true)
	direct.roster[0].hp = 0
	var direct_hire := Company.emergency_recruit(direct)
	check(direct_hire.ok and Company.validate(direct).is_empty() and direct.company.deployment.any(func(entry): return str(entry.unit_id) == str(direct_hire.unit_id) and int(entry.q) == int(vacated.q) and int(entry.r) == int(vacated.r)), "emergency hire inherits a selected casualty's original legal cell")
	var wound := Campaign.create_campaign("free", 911)
	wound.roster[0].injury = {"id": "serious_wound", "source": "battle_911:casualty:crew_1", "until_day": 2}
	wound.roster[0].recovery_until_day = 2
	wound.day = 2
	Company.tick(wound)
	check(wound.roster[0].injury.is_empty() and int(wound.roster[0].recovery_until_day) == 0, "expired temporary injury clears while permanent history remains")
	var old := Campaign.create_campaign("free", 905)
	check(Company.get_view(old).event.is_empty(), "old campaign without casualty source does not invent injury event")
