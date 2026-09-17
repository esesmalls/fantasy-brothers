extends SceneTree

const Saves = preload("res://core/save_store.gd")
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")

const SAVE_PATH := "user://qa/save_store_test/campaign.json"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_cleanup()
	_test_phase_round_trips()
	_test_mid_battle_rng_continuation()
	_test_generated_growth_continuation()
	_test_backup_rotation_and_recovery()
	_test_rejected_data_preserves_primary()
	_test_structural_validation()
	_cleanup()
	print("Save store: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var candidate: String = SAVE_PATH + str(suffix)
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)

func _save_and_load(c: Dictionary) -> Dictionary:
	var saved := Saves.save_campaign(c, SAVE_PATH)
	check(bool(saved.get("ok", false)), "valid %s phase writes to isolated QA path" % str(c.get("phase", "missing")))
	return Saves.load_campaign(SAVE_PATH)

func _same_state(a: Dictionary, b: Dictionary) -> bool:
	# Variant equality is semantic, so JSON integer/float representation does not create a false failure.
	return a == b

func _choose_first(c: Dictionary) -> void:
	var choices: Array = c.get("event", {}).get("choices", [])
	if not choices.is_empty():
		Campaign.choose_event(c, str(choices[0].id))

func _enter_battle(c: Dictionary) -> void:
	if str(c.phase) == "event":
		_choose_first(c)
	c.battle = Battle.create_battle(c.roster, int(c.seed) + int(c.expedition.index) * 7919, Campaign.battle_config(c))
	c.phase = "battle"

func _victory_battle(c: Dictionary) -> Dictionary:
	var battle := Battle.create_battle(c.roster, int(c.seed) + int(c.expedition.index) * 7919, Campaign.battle_config(c))
	for unit: Dictionary in battle.units:
		if str(unit.team) == "enemy":
			unit.hp = 0
	battle.outcome = "victory"
	return battle

func _test_phase_round_trips() -> void:
	_cleanup()
	var camp := Campaign.create_campaign("hunters", 1401)
	var loaded := _save_and_load(camp)
	check(loaded.get("ok", false) and _same_state(camp, loaded.campaign), "camp round trip preserves the complete campaign")
	Campaign.start_expedition(camp)
	loaded = _save_and_load(camp)
	check(loaded.get("ok", false) and _same_state(camp, loaded.campaign), "generated event and choices survive a round trip")
	_choose_first(camp)
	loaded = _save_and_load(camp)
	check(loaded.get("ok", false) and _same_state(camp, loaded.campaign), "selected event consequence survives a round trip")
	_enter_battle(camp)
	loaded = _save_and_load(camp)
	check(loaded.get("ok", false) and _same_state(camp, loaded.campaign), "complete mid-battle state survives a round trip")

func _test_mid_battle_rng_continuation() -> void:
	_cleanup()
	var original := Campaign.create_campaign("free", 1427)
	Campaign.start_expedition(original)
	_enter_battle(original)
	# Put an enemy in legal range so the next random roll is observable after loading.
	var actor: Dictionary = original.battle.units[0]
	var enemy: Dictionary = {}
	for unit: Dictionary in original.battle.units:
		if str(unit.team) == "enemy":
			enemy = unit
			break
	enemy.q = int(actor.q) + 1
	enemy.r = int(actor.r)
	original.battle.props = []
	var loaded := _save_and_load(original)
	check(loaded.get("ok", false), "prepared random battle state loads")
	if not loaded.get("ok", false):
		return
	var restored: Dictionary = loaded.campaign
	var target := {"q": int(enemy.q), "r": int(enemy.r)}
	var first := Battle.apply_action(original.battle, str(actor.id), "attack", target)
	var second := Battle.apply_action(restored.battle, str(actor.id), "attack", target)
	check(first.get("ok", false) and second.get("ok", false), "loaded battle accepts the same next legal action")
	check(first.events == second.events, "loaded battle consumes RNG into identical combat events")
	check(original.battle == restored.battle, "loaded battle reaches the same next full state and RNG")

func _test_generated_growth_continuation() -> void:
	_cleanup()
	var original := Campaign.create_campaign("free", 1499)
	Campaign.start_expedition(original)
	_choose_first(original)
	Campaign.resolve_battle(original, _victory_battle(original))
	check(original.phase == "growth" and original.growth_offers.size() == 3, "fixture reaches generated growth phase")
	var loaded := _save_and_load(original)
	check(loaded.get("ok", false) and loaded.campaign.growth_offers == original.growth_offers, "generated growth candidates do not reroll on load")
	if not loaded.get("ok", false) or original.growth_offers.is_empty():
		return
	var restored: Dictionary = loaded.campaign
	var offer_id := str(original.growth_offers[0].id)
	var first := Campaign.choose_growth(original, offer_id)
	var second := Campaign.choose_growth(restored, offer_id)
	check(first.get("ok", false) and second.get("ok", false), "same saved growth choice remains redeemable")
	check(original == restored, "loaded growth choice produces the same roster, resources and history")

func _test_backup_rotation_and_recovery() -> void:
	_cleanup()
	var c := Campaign.create_campaign("free", 1551)
	check(Saves.save_campaign(c, SAVE_PATH).get("ok", false), "first save succeeds")
	c.gold = 71
	check(Saves.save_campaign(c, SAVE_PATH).get("ok", false), "second save succeeds and creates backup")
	c.gold = 70
	check(Saves.save_campaign(c, SAVE_PATH).get("ok", false), "third save succeeds when a backup already exists")
	var current := Saves.load_campaign(SAVE_PATH)
	check(current.get("ok", false) and int(current.campaign.gold) == 70 and not current.get("recovered", true), "primary contains the newest verified snapshot")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_string("{corrupt primary")
	file.close()
	var recovered := Saves.load_campaign(SAVE_PATH)
	check(recovered.get("ok", false) and recovered.get("recovered", false), "corrupt primary falls back to backup")
	check(recovered.get("ok", false) and int(recovered.campaign.gold) == 71, "backup is the immediately preceding verified snapshot")

func _test_rejected_data_preserves_primary() -> void:
	_cleanup()
	var good := Campaign.create_campaign("free", 1601)
	check(Saves.save_campaign(good, SAVE_PATH).get("ok", false), "preservation fixture writes")
	var invalid := good.duplicate(true)
	invalid.rng_state = 0
	invalid.gold = 999
	var rejected := Saves.save_campaign(invalid, SAVE_PATH)
	var loaded := Saves.load_campaign(SAVE_PATH)
	check(not rejected.get("ok", false), "invalid RNG state is rejected before writing")
	check(loaded.get("ok", false) and int(loaded.campaign.gold) == int(good.gold), "rejected save leaves the prior primary intact")
	var unsafe := good.duplicate(true)
	unsafe.flags.non_json_value = Vector2(1, 2)
	check(not Saves.save_campaign(unsafe, SAVE_PATH).get("ok", false), "non-JSON campaign values are rejected")

func _test_structural_validation() -> void:
	var event_state := Campaign.create_campaign("free", 1701)
	Campaign.start_expedition(event_state)
	var duplicate_choice := event_state.duplicate(true)
	duplicate_choice.event.choices.append(duplicate_choice.event.choices[0].duplicate(true))
	check(not Saves.validate(duplicate_choice).is_empty(), "duplicate generated event choice IDs are rejected")
	var bad_offer := event_state.duplicate(true)
	_choose_first(bad_offer)
	Campaign.resolve_battle(bad_offer, _victory_battle(bad_offer))
	bad_offer.growth_offers[0].erase("id")
	check(not Saves.validate(bad_offer).is_empty(), "growth offers require stable IDs")
	var battle_state := Campaign.create_campaign("free", 1703)
	Campaign.start_expedition(battle_state)
	_enter_battle(battle_state)
	var missing_order_unit := battle_state.duplicate(true)
	missing_order_unit.battle.order[0] = "missing_unit"
	check(not Saves.validate(missing_order_unit).is_empty(), "battle order cannot reference a missing unit")
	var duplicate_order := battle_state.duplicate(true)
	duplicate_order.battle.order[1] = duplicate_order.battle.order[0]
	check(not Saves.validate(duplicate_order).is_empty(), "battle order cannot repeat a unit")
	var bad_cell := battle_state.duplicate(true)
	bad_cell.battle.cells["0,0"].field = "lava"
	check(not Saves.validate(bad_cell).is_empty(), "battle cells reject unknown reaction states")
	var bad_turn := battle_state.duplicate(true)
	bad_turn.battle.turn_index = bad_turn.battle.order.size()
	check(not Saves.validate(bad_turn).is_empty(), "battle turn index remains inside its order")
