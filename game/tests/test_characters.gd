extends SceneTree

const Character = preload("res://core/character_rules.gd")
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://tests/legacy_battle_rules.gd") # Fixed pre-tactical progression fixtures.
const Equipment = preload("res://core/equipment_rules.gd")
const Saves = preload("res://core/save_store.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_sources_swaps_and_split_accuracy()
	_test_defense_changes_real_resolution()
	_test_progression_claims_and_level_range()
	_test_training_costs_and_shared_eligibility()
	_test_late_handler_and_unique_binding()
	_test_legacy_migration_and_saved_growth()
	print("Character rules: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _test_sources_swaps_and_split_accuracy() -> void:
	var c := Campaign.create_campaign("free", 5101)
	c.gold = 200
	var unit: Dictionary = c.roster[0]
	var original_max := int(unit.max_hp)
	unit.hp -= 11
	unit.progression.attribute_points = 3
	var hp_result := Character.spend_attribute(c, str(unit.id), "vitality")
	check(hp_result.ok and int(unit.max_hp) == original_max + 6 and int(unit.max_hp) - int(unit.hp) == 11, "vitality growth preserves the existing HP loss instead of refilling")
	var melee_result := Character.spend_attribute(c, str(unit.id), "melee_skill")
	check(melee_result.ok and int(unit.melee_skill) == 92 and int(unit.ranged_skill) == 88, "melee and ranged skill grow independently")
	var longbow := Equipment.buy(c, "weapon_archer_longbow")
	check(longbow.ok and Equipment.equip(c, str(unit.id), str(longbow.instance_id)).ok, "human can equip the ranged test weapon")
	check(int(unit.accuracy) == 81 and int(unit.stat_sources.equipment.ranged_skill) == -7 and int(unit.stat_sources.equipment.melee_skill) == 0, "ranged weapon modifier applies only to ranged skill")
	var hooked := Equipment.buy(c, "weapon_spear_hooked")
	Equipment.equip(c, str(unit.id), str(hooked.instance_id))
	check(int(unit.accuracy) == 86 and int(unit.stat_sources.equipment.melee_skill) == -6 and int(unit.stat_sources.equipment.ranged_skill) == 0, "melee weapon uses grown melee skill and its own modifier")
	for _i in range(4):
		Equipment.equip(c, str(unit.id), str(longbow.instance_id))
		Equipment.equip(c, str(unit.id), str(hooked.instance_id))
	check(int(unit.accuracy) == 86 and int(unit.attack) == 15 and int(unit.max_hp) == original_max + 6, "repeated equipment swaps recompute once without stat drift")
	var view := Character.get_view(c, str(unit.id))
	check(view.stats.size() == 4 and view.stats[0].has_all(["base", "growth", "equipment", "compat", "perk", "breakdown"]), "character view exposes a complete auditable source breakdown")
	check(int(view.xp) == 0 and int(view.xp_next) == 100 and str(view.background_name) == "商路护卫", "view exposes cumulative XP threshold and descriptive background")

func _test_defense_changes_real_resolution() -> void:
	var high := Battle.create_battle([{"id": "a", "kind": "guard", "accuracy": 90}], 5102, {"id": "defense_high"})
	var low := high.duplicate(true)
	high.units[0].q = 2; high.units[0].r = 2; high.units[1].q = 3; high.units[1].r = 2
	low.units[0].q = 2; low.units[0].r = 2; low.units[1].q = 3; low.units[1].r = 2
	high.units[1].defense = 20; high.units[1].armor = 0; low.units[1].armor = 0; low.units[1].defense = 0
	high.props = []; low.props = []
	var preview_high := Battle.preview(high, "a", "attack", {"q": 3, "r": 2})
	var preview_low := Battle.preview(low, "a", "attack", {"q": 3, "r": 2})
	check(int(preview_high.chance) == 70 and int(preview_low.chance) == 90, "defense lowers the shared attack preview chance")
	# First roll from RNG state 9 is 39; choose a state whose next roll lies in [70, 90).
	var chosen_state := 1
	for candidate in range(1, 500):
		var roll := int((candidate * 48271) % 2147483647) % 100
		if roll >= 70 and roll < 90:
			chosen_state = candidate
			break
	high.rng_state = chosen_state; low.rng_state = chosen_state
	var high_hp := int(high.units[1].hp)
	var low_hp := int(low.units[1].hp)
	Battle.apply_action(high, "a", "attack", {"q": 3, "r": 2})
	Battle.apply_action(low, "a", "attack", {"q": 3, "r": 2})
	check(int(high.units[1].hp) == high_hp and int(low.units[1].hp) < low_hp, "defense affects actual resolution through the same hit calculation")

func _test_progression_claims_and_level_range() -> void:
	var c := Campaign.create_campaign("free", 5103)
	for expedition_index in range(7):
		_ready_for_battle(c)
		var battle := Battle.create_battle(c.roster, 5200 + expedition_index, Campaign.battle_config(c))
		Campaign.begin_battle(c, battle)
		for raw: Dictionary in c.battle.units:
			if str(raw.team) == "enemy": raw.hp = 0
		c.battle.outcome = "victory"
		check(Campaign.resolve_battle(c, c.battle).ok, "victory %d settles once" % (expedition_index + 1))
		if c.phase == "growth": Campaign.choose_growth(c, str(c.growth_offers[0].id))
		Campaign.return_to_camp(c)
	var veteran: Dictionary = c.roster[0]
	check(int(veteran.progression.level) == 8 and int(veteran.progression.xp) == 700 and int(Character.get_view(c, str(veteran.id)).xp_next) == 700, "seven victories verify cumulative progression from level 1 through 8")
	check(int(veteran.progression.attribute_points) == 14 and int(veteran.progression.training_credits) == 3, "each level grants two points and effective battles replenish only bounded practice credit")

	var dead_case := Campaign.create_campaign("free", 5301)
	_ready_for_battle(dead_case)
	var dead_battle := Battle.create_battle(dead_case.roster, 5302, Campaign.battle_config(dead_case))
	Campaign.begin_battle(dead_case, dead_battle)
	var dead_id := str(dead_case.roster[0].id)
	for raw: Dictionary in dead_case.battle.units:
		if str(raw.id) == dead_id or str(raw.team) == "enemy": raw.hp = 0
	dead_case.battle.outcome = "victory"
	Campaign.resolve_battle(dead_case, dead_case.battle)
	check(int(dead_case.roster[0].progression.xp) == 0 and int(dead_case.roster[1].progression.xp) == 100, "dead participant receives no XP while every surviving victor receives 100")
	var settled := JSON.stringify(dead_case)
	check(not Campaign.resolve_battle(dead_case, dead_case.battle).ok and JSON.stringify(dead_case) == settled, "duplicate battle settlement cannot mutate XP or resources")
	var dog_case := Campaign.create_campaign("hunters", 5300)
	_ready_for_battle(dog_case)
	var dog_battle := Battle.create_battle(dog_case.roster, 5300, Campaign.battle_config(dog_case))
	Campaign.begin_battle(dog_case, dog_battle)
	for raw: Dictionary in dog_case.battle.units:
		if str(raw.team) == "enemy": raw.hp = 0
	dog_case.battle.outcome = "victory"
	Campaign.resolve_battle(dog_case, dog_case.battle)
	check(int(dog_case.roster[3].progression.xp) == 100 and int(dog_case.roster[3].progression.level) == 2 and int(dog_case.roster[3].progression.attribute_points) == 0 and int(dog_case.roster[3].progression.training_credits) == 0, "war dog keeps XP and level history without receiving unusable human currencies")

	var engaged := Campaign.create_campaign("free", 5303)
	_ready_for_battle(engaged)
	var engaged_battle := Battle.create_battle(engaged.roster, 5304, Campaign.battle_config(engaged))
	Campaign.begin_battle(engaged, engaged_battle)
	engaged.battle.action_log.append({"id": 1, "round": 1, "actor": str(engaged.roster[0].id), "action": "attack", "target": {}, "rng_before": int(engaged.battle.rng_state)})
	engaged.battle.action_seq = 1; engaged.battle.outcome = "retreat"
	Campaign.resolve_battle(engaged, engaged.battle)
	check(int(engaged.roster[0].progression.xp) == 35 and int(engaged.roster[3].progression.xp) == 35, "engaged retreat grants bounded shared experience to surviving participants")

	var fled := Campaign.create_campaign("free", 5305)
	_ready_for_battle(fled)
	var fled_battle := Battle.create_battle(fled.roster, 5306, Campaign.battle_config(fled))
	Campaign.begin_battle(fled, fled_battle)
	Battle.retreat(fled.battle)
	Campaign.resolve_battle(fled, fled.battle)
	check(int(fled.roster[0].progression.xp) == 0 and int(fled.roster[0].progression.training_credits) == 1, "immediate flight without a player action grants neither XP nor practice credit")
	var ordered := Campaign.create_campaign("hunters", 5309)
	_ready_for_battle(ordered)
	var ordered_battle := Battle.create_battle(ordered.roster, 5310, Campaign.battle_config(ordered))
	Campaign.begin_battle(ordered, ordered_battle)
	ordered.battle.action_log.append({"id": 1, "round": 1, "actor": str(ordered.roster[2].id), "action": "command_follow", "target": {}, "rng_before": int(ordered.battle.rng_state)})
	ordered.battle.action_seq = 1; ordered.battle.outcome = "retreat"
	Campaign.resolve_battle(ordered, ordered.battle)
	check(int(ordered.roster[2].progression.xp) == 0, "issuing a no-target dog order and fleeing does not count as effective participation")
	var wandered := Campaign.create_campaign("free", 5307)
	_ready_for_battle(wandered)
	var wandered_battle := Battle.create_battle(wandered.roster, 5308, Campaign.battle_config(wandered))
	Campaign.begin_battle(wandered, wandered_battle)
	wandered.battle.action_log.append({"id": 1, "round": 1, "actor": str(wandered.roster[0].id), "action": "move", "target": {"q": 1, "r": 1}, "rng_before": int(wandered.battle.rng_state)})
	wandered.battle.action_seq = 1; wandered.battle.outcome = "retreat"
	Campaign.resolve_battle(wandered, wandered.battle)
	check(int(wandered.roster[0].progression.xp) == 0, "pure movement before retreat cannot farm engagement XP")

func _test_training_costs_and_shared_eligibility() -> void:
	var c := Campaign.create_campaign("free", 5401)
	c.food = 20
	for unit: Dictionary in c.roster:
		if str(unit.kind) == "dog": continue
		var before_day := int(c.day)
		var before_food := int(c.food)
		var before_value := int(unit.vitality)
		var result := Character.train(c, str(unit.id), "basic_vitality")
		check(result.ok and int(c.day) == before_day + 1 and int(c.food) == before_food - 1 and int(unit.vitality) == before_value + 2, "%s shares the same paid vitality training" % str(unit.kind))
	var no_food := Campaign.create_campaign("free", 5402)
	no_food.food = 0
	var unchanged := JSON.stringify(no_food)
	check(not Character.train(no_food, str(no_food.roster[0].id), "basic_melee").ok and JSON.stringify(no_food) == unchanged, "insufficient food rejects training without any mutation")
	var no_money := Campaign.create_campaign("free", 5403)
	no_money.gold = 0
	unchanged = JSON.stringify(no_money)
	check(not Character.train(no_money, str(no_money.roster[0].id), "beast_handler").ok and JSON.stringify(no_money) == unchanged, "insufficient money rejects specialist training without mutation")
	var dead := Campaign.create_campaign("free", 5404)
	dead.roster[0].hp = 0
	unchanged = JSON.stringify(dead)
	check(not Character.train(dead, str(dead.roster[0].id), "basic_defense").ok and JSON.stringify(dead) == unchanged, "dead characters cannot train and pay no costs")
	var away := Campaign.create_campaign("free", 5405)
	away.roster[0].progression.attribute_points = 1
	Campaign.start_expedition(away)
	unchanged = JSON.stringify(away)
	check(not Character.spend_attribute(away, str(away.roster[0].id), "melee_skill").ok and JSON.stringify(away) == unchanged, "attribute points are camp-only and reject without mutation")
	unchanged = JSON.stringify(away)
	check(not Character.train(away, str(away.roster[0].id), "basic_ranged").ok and JSON.stringify(away) == unchanged, "training is camp-only and rejects before mutation")

	var cap_test := Campaign.create_campaign("free", 5410)
	cap_test.gold = 200; cap_test.food = 20
	var cap_unit: Dictionary = cap_test.roster[0]
	cap_unit.stat_sources.growth.melee_skill = 20
	cap_unit.progression.attribute_points = 1
	Character.recompute_character(cap_unit, cap_test)
	var penalty_weapon := Equipment.buy(cap_test, "weapon_guard_cleaver")
	Equipment.equip(cap_test, str(cap_unit.id), str(penalty_weapon.instance_id))
	unchanged = JSON.stringify(cap_test)
	check(not Character.spend_attribute(cap_test, str(cap_unit.id), "melee_skill").ok and JSON.stringify(cap_test) == unchanged, "negative equipment cannot create room above the permanent stat cap")
	cap_unit.stat_sources.growth.ranged_skill = 20
	Character.recompute_character(cap_unit, cap_test)
	var bonus_weapon := Equipment.buy(cap_test, "weapon_hunter_recurve")
	Equipment.equip(cap_test, str(cap_unit.id), str(bonus_weapon.instance_id))
	check(Character.train(cap_test, str(cap_unit.id), "basic_ranged").ok and int(cap_unit.ranged_skill) == 117, "positive equipment does not block training permanent skill from 108 to its 110 cap")

func _test_late_handler_and_unique_binding() -> void:
	var c := Campaign.create_campaign("hunters", 5501)
	var original_handler: Dictionary = c.roster[2]
	var learner: Dictionary = c.roster[0]
	var dog: Dictionary = c.roster[3]
	check("beast_handler" in original_handler.capability_tags and str(dog.hunter_id) == str(original_handler.id), "old hunter background migrates to explicit beast-handler capability and binding")
	c.gold = 50; c.food = 10
	var learned := Character.train(c, str(learner.id), "beast_handler")
	check(learned.ok and "beast_handler" in learner.capability_tags and str(dog.hunter_id) == str(original_handler.id), "another background can visibly learn handler capability without cloning the dog")
	var bound := Character.train(c, str(learner.id), "bind_dog")
	check(bound.ok and str(dog.hunter_id) == str(learner.id) and str(learner.beast_id) == str(dog.id) and str(original_handler.get("beast_id", "")).is_empty(), "free camp binding transfers the one existing dog to one trained handler")
	var battle := Battle.create_battle(c.roster, 5502, {"id": "late_handler"})
	var actions := Battle.get_actions(battle, str(learner.id))
	check(_has_action(actions, "mark") and _has_action(actions, "command_pin") and str(battle.units[3].hunter_id) == str(learner.id), "late-trained handler receives real mark and command actions in a new battle")
	var dog_count := 0
	for raw: Dictionary in battle.units:
		if str(raw.kind) == "dog": dog_count += 1
	check(dog_count == 1, "learning and binding never generates or duplicates a war dog")

func _test_legacy_migration_and_saved_growth() -> void:
	var dog_candidate := Campaign.create_campaign("hunters", 5599)
	check("packbond" in Campaign._eligible_perks(dog_candidate.roster[3]) and "packbond" in Campaign._eligible_perks(dog_candidate.roster[0]), "both war dogs and human handler candidates retain access to packbond")
	var phases := ["camp", "event", "battle", "growth", "returning"]
	for phase_name: String in phases:
		var c := _campaign_at_phase(phase_name, 5600 + phases.find(phase_name))
		var battle_before := JSON.stringify(c.battle)
		var rng_before := int(c.rng_state)
		var offers_before := JSON.stringify(c.growth_offers)
		_strip_character_state(c)
		var old_max := int(c.roster[0].max_hp)
		var old_accuracy := int(c.roster[0].accuracy)
		var old_armor := int(c.roster[0].armor)
		var migrated := Saves._upgrade_loaded(c)
		check(migrated and int(c.roster[0].max_hp) == old_max and int(c.roster[0].accuracy) == old_accuracy and int(c.roster[0].armor) == old_armor, "%s legacy character migration preserves effective stats and armor wear" % phase_name)
		check(int(c.rng_state) == rng_before and JSON.stringify(c.growth_offers) == offers_before, "%s migration preserves campaign RNG and saved growth candidates" % phase_name)
		if phase_name == "battle":
			check(JSON.stringify(c.battle) == battle_before, "active 0.1.4 battle snapshot, RNG and logs remain byte-identical")
		check(Character.validate_campaign(c).is_empty(), "%s migration produces strict valid character metadata" % phase_name)

	var legacy := Campaign.create_campaign("free", 5701)
	var guard: Dictionary = legacy.roster[0]
	var weapon := Equipment.buy(legacy, "weapon_archer_longbow")
	Equipment.equip(legacy, str(guard.id), str(weapon.instance_id))
	guard.perks = ["vigor", "precision"]
	guard.max_hp += 8; guard.hp += 8; guard.accuracy += 8
	var expected_max := int(guard.max_hp)
	var expected_accuracy := int(guard.accuracy)
	_strip_character_state(legacy)
	Saves._upgrade_loaded(legacy)
	check(int(guard.max_hp) == expected_max and int(guard.accuracy) == expected_accuracy and int(guard.stat_sources.perk.vitality) == 8 and int(guard.stat_sources.perk.ranged_skill) == 8, "legacy vigor and precision become explicit sources exactly once")
	var stable := JSON.stringify(legacy)
	Character.ensure_campaign(legacy)
	check(JSON.stringify(legacy) == stable, "repeated migration and recomputation are idempotent")

	var growth := _campaign_at_phase("growth", 5702)
	var target_id := str(growth.growth_unit_id)
	growth.growth_offers = [{"id": "%s:%s:breacher" % [str(growth.expedition.id), target_id], "title": "破阵协同", "description": "旧候选", "perk": "breacher", "unit_id": target_id}]
	_strip_character_state(growth)
	Saves._upgrade_loaded(growth)
	check(Campaign.choose_growth(growth, str(growth.growth_offers[0].id)).ok and "breacher" in _unit(growth, target_id).perks, "saved old breacher offer remains redeemable regardless of original human kind")

	var invalid := Campaign.create_campaign("free", 5703)
	invalid.roster[0].progression.xp = -1
	check(not Saves.validate(invalid).is_empty(), "strict save validation rejects negative character XP")
	invalid = Campaign.create_campaign("free", 5704)
	invalid.roster[0].progression.attribute_points = 0.5
	check(not Saves.validate(invalid).is_empty(), "strict save validation rejects non-integer character progression")

	var original_battle := _campaign_at_phase("battle", 5705)
	_strip_character_state(original_battle)
	original_battle.battle.rules_version = "prototype-0.1"
	for raw: Dictionary in original_battle.battle.units:
		for key in ["defense", "melee_skill", "ranged_skill", "level", "background_name", "capability_tags"]:
			raw.erase(key)
	var old_rng := int(original_battle.battle.rng_state)
	var old_units := JSON.stringify(original_battle.battle.units)
	var old_log := JSON.stringify(original_battle.battle.log)
	var old_actions := JSON.stringify(original_battle.battle.action_log)
	check(Saves._upgrade_loaded(original_battle) and str(original_battle.battle.rules_version) == "prototype-0.1.4" and str(original_battle.battle.migrated_from_rules) == "prototype-0.1", "prototype-0.1 battle migrates only to the 0.1.4-compatible snapshot version")
	check(int(original_battle.battle.rng_state) == old_rng and JSON.stringify(original_battle.battle.units) == old_units and JSON.stringify(original_battle.battle.log) == old_log and JSON.stringify(original_battle.battle.action_log) == old_actions, "prototype-0.1 compatibility migration preserves frozen battle RNG, units and logs")
	check(Saves.validate(original_battle).is_empty(), "prototype-0.1 compatibility migration validates without invented 0.1.5 unit metadata")

func _ready_for_battle(c: Dictionary) -> void:
	Campaign.start_expedition(c)
	while str(c.phase) == "travel": Campaign.advance_travel(c)
	if str(c.phase) == "event": Campaign.choose_event(c, str(c.event.choices[0].id))
	while str(c.phase) == "travel": Campaign.advance_travel(c)

func _campaign_at_phase(phase_name: String, seed_value: int) -> Dictionary:
	var c := Campaign.create_campaign("free", seed_value)
	if phase_name == "camp": return c
	Campaign.start_expedition(c)
	while str(c.phase) == "travel": Campaign.advance_travel(c)
	if phase_name == "event": return c
	Campaign.choose_event(c, str(c.event.choices[0].id))
	while str(c.phase) == "travel": Campaign.advance_travel(c)
	var battle := Battle.create_battle(c.roster, seed_value + 100, Campaign.battle_config(c))
	Campaign.begin_battle(c, battle)
	# QA fixture models an already-started 0.1.4 battle.
	c.battle.rules_version = "prototype-0.1.4"
	if phase_name == "battle": return c
	for raw: Dictionary in c.battle.units:
		if str(raw.team) == "enemy": raw.hp = 0
	c.battle.outcome = "victory"
	Campaign.resolve_battle(c, c.battle)
	if phase_name == "growth": return c
	if c.phase == "growth": Campaign.choose_growth(c, str(c.growth_offers[0].id))
	return c

func _strip_character_state(c: Dictionary) -> void:
	c.erase("character_state")
	for unit: Dictionary in c.roster:
		for key in ["background_id", "background_name", "background_description", "capability_tags", "character_history", "progression", "stat_sources", "combat_sources", "beast_id", "defense", "melee_skill", "ranged_skill", "level"]:
			unit.erase(key)

func _unit(c: Dictionary, unit_id: String) -> Dictionary:
	for unit: Dictionary in c.roster:
		if str(unit.id) == unit_id: return unit
	return {}

func _has_action(actions: Array, action_id: String) -> bool:
	for action: Dictionary in actions:
		if str(action.id) == action_id: return true
	return false
