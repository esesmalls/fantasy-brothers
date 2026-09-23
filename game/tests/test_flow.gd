extends SceneTree
const Campaign = preload("res://core/campaign_rules.gd")
const Company = preload("res://core/company_rules.gd")
const World = preload("res://core/world_data.gd")
const Battle = preload("res://core/battle_rules.gd")
const Saves = preload("res://core/save_store.gd")
const Policy = preload("res://tests/play_policy.gd")

const SAVE_PATH := "user://qa/flow.json"
const STARTS := [[2, 2], [2, 3], [1, 3], [1, 4]]
var failures := 0
var checks := 0
var victories := 0
var other_outcomes := 0
var retreats := 0
var completed_battles := 0
var confirmed_deaths := 0
var routed_turns := 0
var camp_recruits := 0
var camp_rests := 0

func _initialize() -> void:
	for seed_value in [1700, 1711]:
		for origin in ["free", "hunters"]:
			var c: Dictionary = Campaign.create_campaign(origin, seed_value)
			for contract_id in [World.CONTRACT_ID, World.EVACUATION_ID]:
				var label := "%d/%s/%s" % [seed_value, origin, contract_id]
				if not _prepare_departure(c, contract_id, label): break
				if not _travel_to_battle(c, label): break
				if not _run_battle(c, label): break
				if not _settle_and_return(c, label): break
	_check(completed_battles == 8, "all eight public-rule battles complete")
	_check(retreats >= 1 and routed_turns >= 1 and confirmed_deaths >= 1, "natural rout and deaths settle before the next contract")
	print("Campaign flow: %d checks; %d failures; %d victories, %d retreats, %d other outcomes; %d deaths, %d routed turns, %d recruits, %d rests across 2 seeds x 2 origins x 2 contracts" % [checks, failures, victories, retreats, other_outcomes, confirmed_deaths, routed_turns, camp_recruits, camp_rests])
	quit(0 if failures == 0 else 1)

func _prepare_departure(c: Dictionary, contract_id: String, label: String) -> bool:
	for attempt in range(12):
		if int(c.seed) == 1700 and str(c.origin) == "free" and contract_id == World.EVACUATION_ID and _living_count(c) < 4:
			if not _required(Campaign.camp_action(c, "recruit"), label + " replaces confirmed loss"): return false
			camp_recruits += 1
			continue
		var eligible: Array = []
		for member: Dictionary in c.roster:
			if int(member.hp) > 0 and int(member.get("recovery_until_day", 0)) <= int(c.day): eligible.append(member)
		if eligible.size() < 2:
			var recovering := false
			for member: Dictionary in c.roster:
				if int(member.hp) > 0 and int(member.get("recovery_until_day", 0)) > int(c.day): recovering = true
			if recovering:
				if not _required(Campaign.camp_action(c, "rest"), label + " rests recoverable members"): return false
				camp_rests += 1
				continue
			if eligible.is_empty() or _living_count(c) < 2:
				if not _required(Campaign.camp_action(c, "recruit"), label + " recruits after losses"): return false
				camp_recruits += 1
				continue
		var route_id := "road"
		for route: Dictionary in Campaign.get_routes(c):
			if route.id == "ridge" and int(c.expedition.get("index", 0)) == 1 and route.available: route_id = "ridge"
		var available := false
		for route: Dictionary in Campaign.get_routes(c):
			if route.id == route_id: available = bool(route.available)
		if not available:
			var supply := Campaign.camp_action(c, "resupply") if int(c.gold) >= 12 else Campaign.camp_action(c, "short_work")
			if not _required(supply, label + " obtains actual travel supplies"): return false
			continue
		if not _required(Company.select_deployment(c, _deployment(eligible)), label + " selects eligible deployment"): return false
		return _required(Campaign.accept_contract(c, contract_id, route_id), label + " accepts " + route_id)
	_check(false, label + " could not legally prepare departure in twelve camp actions")
	return false

func _deployment(eligible: Array) -> Array:
	var chosen: Array = []
	for member: Dictionary in eligible:
		if chosen.size() >= 4: break
		if str(member.kind) != "dog": chosen.append(member)
	for member: Dictionary in eligible:
		if chosen.size() >= 4: break
		if str(member.kind) != "dog": continue
		var owner_present := str(member.get("hunter_id", "")).is_empty()
		for chosen_member: Dictionary in chosen:
			if str(chosen_member.id) == str(member.get("hunter_id", "")): owner_present = true
		if owner_present: chosen.append(member)
	var slots: Array = []
	for i in range(chosen.size()):
		slots.append({"unit_id": str(chosen[i].id), "q": int(STARTS[i][0]), "r": int(STARTS[i][1])})
	return slots

func _travel_to_battle(c: Dictionary, label: String) -> bool:
	for leg in range(16):
		if c.phase != "travel": break
		if not _required(Campaign.advance_travel(c), label + " advances travel %d" % leg): return false
	if not _check(c.phase == "event", label + " reaches saved event"): return false
	if not _required(Campaign.choose_event(c, str(c.event.choices[0].id)), label + " chooses legal event"): return false
	for leg in range(16):
		if c.phase != "travel": break
		if not _required(Campaign.advance_travel(c), label + " reaches battlefield %d" % leg): return false
	if not _check(c.phase == "ready", label + " reaches contract battle"): return false
	var battle := Battle.create_battle(Campaign.battle_roster(c), int(c.seed) + int(c.expedition.index) * 7919, Campaign.battle_config(c))
	return _required(Campaign.begin_battle(c, battle), label + " begins deployed battle")

func _run_battle(c: Dictionary, label: String) -> bool:
	for step in range(900):
		if not str(c.battle.outcome).is_empty(): break
		var u: Dictionary = Battle.active_unit(c.battle)
		if not _check(not u.is_empty(), label + " has active unit at step %d" % step): return false
		if u.team == "player" and int(u.get("morale", 3)) == 0: routed_turns += 1
		var result: Dictionary
		if u.team == "enemy" or u.kind == "dog" or int(u.get("morale", 3)) == 0:
			result = Battle.ai_step(c.battle)
		elif int(c.seed) == 1700 and str(c.origin) == "free" and str(c.expedition.contract_kind) == "granary":
			# Legal repeated end-turns let enemies cause an actual casualty or rout.
			result = {"ok": true, "events": Battle.end_turn(c.battle)}
		else:
			var command: Dictionary = Policy.next_command(c.battle)
			result = {"ok": true, "events": Battle.end_turn(c.battle)} if command.is_empty() else Battle.apply_action(c.battle, str(u.id), str(command.action), command.target)
		if not _required(result, label + " action %d by %s" % [step, str(u.id)]): return false
		if step == 4:
			if not _required(Saves.save_campaign(c, SAVE_PATH), label + " saves active battle"): return false
			var restored := Saves.load_campaign(SAVE_PATH)
			if not _required(restored, label + " loads active battle"): return false
			c.clear()
			c.merge(restored.campaign, true)
	if not _check(not str(c.battle.outcome).is_empty(), label + " terminates within 900 actions"): return false
	completed_battles += 1
	if c.battle.outcome == "victory": victories += 1
	elif c.battle.outcome == "retreat": retreats += 1
	else: other_outcomes += 1
	return true

func _settle_and_return(c: Dictionary, label: String) -> bool:
	for record: Dictionary in c.battle.get("casualties", []):
		if record.team == "player" and record.status == "dead": confirmed_deaths += 1
	if not _required(Campaign.resolve_battle(c, c.battle), label + " resolves once"): return false
	if not _check(not Campaign.resolve_battle(c, c.battle).ok, label + " rejects duplicate settlement"): return false
	if c.phase == "growth":
		if not _required(Campaign.choose_growth(c, str(c.growth_offers[0].id)), label + " grants saved growth"): return false
	if not _required(Campaign.return_to_camp(c), label + " returns to camp"): return false
	return _check(c.phase == "camp", label + " can continue after its outcome")

func _living_count(c: Dictionary) -> int:
	var count := 0
	for member: Dictionary in c.roster:
		if int(member.hp) > 0: count += 1
	return count

func _required(result: Dictionary, label: String) -> bool:
	return _check(bool(result.get("ok", false)), label + ": " + str(result.get("reason", "")))

func _check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		failures += 1
		push_error("FLOW FAIL: " + label)
	return condition
