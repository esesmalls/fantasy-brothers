extends SceneTree

const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Equipment = preload("res://core/equipment_rules.gd")
const Saves = preload("res://core/save_store.gd")

const LEGACY_PATH := "res://../builds/qa/equipment-legacy-test.json"

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_initial_loadouts_and_view()
	_test_trade_and_atomic_rejections()
	_test_weapon_battle_stats_and_growth()
	_test_cross_role_weapon_rules()
	_test_armor_instances_and_repair()
	_test_battle_wear_death_recruit_and_next_trip()
	_test_legacy_phase_migrations()
	_test_legacy_camp_and_returning_migrations()
	_cleanup_legacy()
	print("Equipment rules: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _test_initial_loadouts_and_view() -> void:
	var free := Campaign.create_campaign("free", 2401)
	check(free.equipment.instances.size() == 8 and int(free.equipment.next_instance_serial) == 9, "four human starters receive eight stable equipment instances")
	var ids: Dictionary = {}
	for instance: Dictionary in free.equipment.instances:
		ids[str(instance.id)] = true
	check(ids.size() == 8 and ids.has("equip_1") and ids.has("equip_8"), "starter instance IDs are unique and reproducible")
	check(str(free.roster[0].equipment.weapon) == "equip_1" and str(free.roster[0].equipment.armor) == "equip_2", "unit slots reference inventory instances")
	check(int(free.roster[0].attack) == 12 and int(free.roster[0].accuracy) == 88 and int(free.roster[0].armor) == 24, "starter equipment maps the established guard values without rebalance")
	var view := Equipment.get_view(free, str(free.roster[0].id))
	check(view.ok and view.units.size() == 4 and int(view.selected_unit.range) == 1 and view.slots.size() == 2, "read-only view exposes unit range and two selected slots")
	check(view.inventory.size() == 8 and bool(view.inventory[0].equipped) and int(view.inventory[0].sell_price) == 0, "view identifies equipped issued gear as non-sellable")
	check(view.shop.size() == 9 and str(view.shop[0].id) == "weapon_guard_cleaver", "shop exposes five weapon styles and four armors for free human loadouts")
	var hunters := Campaign.create_campaign("hunters", 2402)
	check(str(hunters.roster[3].kind) == "dog" and str(hunters.roster[3].equipment.weapon).is_empty() and str(hunters.roster[3].equipment.armor).is_empty(), "war dog uses no artificial equipment")
	check(Equipment.validate_campaign(free).is_empty() and Equipment.validate_campaign(hunters).is_empty(), "new origin inventories satisfy equipment invariants")

func _test_trade_and_atomic_rejections() -> void:
	var c := Campaign.create_campaign("free", 2411)
	var before_invalid := JSON.stringify(c)
	check(not Equipment.buy(c, "missing_definition").ok and JSON.stringify(c) == before_invalid, "unknown purchase is rejected atomically")
	var bought := Equipment.buy(c, "weapon_guard_cleaver")
	check(bought.ok and int(c.gold) == 34 and str(bought.instance_id) == "equip_9", "purchase deducts exact funds and assigns next stable ID")
	var old_weapon := str(c.roster[0].equipment.weapon)
	var equipped := Equipment.equip(c, str(c.roster[0].id), str(bought.instance_id))
	check(equipped.ok and str(c.roster[0].equipment.weapon) == "equip_9" and _has_instance(c, old_weapon), "weapon replacement returns the old instance to inventory")
	var equipped_state := JSON.stringify(c)
	check(not Equipment.sell(c, "equip_9").ok and JSON.stringify(c) == equipped_state, "equipped item cannot be sold and rejection is atomic")
	check(not Equipment.equip(c, str(c.roster[1].id), "equip_9").ok and JSON.stringify(c) == equipped_state, "same instance cannot be equipped by a second unit")
	check(not Equipment.sell(c, old_weapon).ok and JSON.stringify(c) == equipped_state, "issued starter gear cannot be sold for recruit-loop profit")
	var armor := Equipment.buy(c, "armor_padded")
	var gold_after_buy := int(c.gold)
	check(armor.ok and Equipment.sell(c, str(armor.instance_id)).ok and int(c.gold) == gold_after_buy + 9, "unbound purchased inventory can be sold for its fixed resale value")
	var once_sold := JSON.stringify(c)
	check(not Equipment.sell(c, str(armor.instance_id)).ok and JSON.stringify(c) == once_sold, "the same stable instance cannot be sold twice")
	c.phase = "travel"
	var travel_state := JSON.stringify(c)
	check(not Equipment.buy(c, "armor_padded").ok and not Equipment.equip(c, str(c.roster[0].id), old_weapon).ok and JSON.stringify(c) == travel_state, "trade and loadout changes are blocked outside camp without partial mutation")

func _test_weapon_battle_stats_and_growth() -> void:
	var c := Campaign.create_campaign("free", 2421)
	var bought := Equipment.buy(c, "weapon_guard_cleaver")
	var base_weapon := str(c.roster[0].equipment.weapon)
	check(Equipment.equip(c, str(c.roster[0].id), str(bought.instance_id)).ok, "guard equips compatible variant")
	check(int(c.roster[0].attack) == 15 and int(c.roster[0].accuracy) == 83 and int(c.roster[0].range) == 1, "weapon tradeoff changes attack and hit while preserving role range")
	var battle := Battle.create_battle(c.roster, 2422, {})
	var guard: Dictionary = battle.units[0]
	var enemy: Dictionary = battle.units[4]
	enemy.q = int(guard.q) + 1
	enemy.r = int(guard.r)
	battle.props = []
	var plan := Battle.preview(battle, str(guard.id), "attack", {"q": int(enemy.q), "r": int(enemy.r)})
	check(plan.ok and int(plan.damage) == 15 and int(plan.chance) == 83, "battle preview consumes the equipped weapon stats used by settlement")
	# Use the real growth rule, then swap both ways to prove equipment applies a
	# delta rather than reconstructing and erasing permanent precision.
	c.phase = "growth"
	c.expedition = {"id": "growth_equipment"}
	c.growth_unit_id = str(c.roster[0].id)
	c.growth_offers = [{"id": "growth_equipment:crew_1:precision", "title": "沉着瞄准", "description": "命中+8", "perk": "precision", "unit_id": str(c.roster[0].id)}]
	check(Campaign.choose_growth(c, "growth_equipment:crew_1:precision").ok and int(c.roster[0].accuracy) == 91, "permanent precision stacks on the equipped weapon modifier")
	c.phase = "camp"
	check(Equipment.equip(c, str(c.roster[0].id), base_weapon).ok and int(c.roster[0].accuracy) == 96, "swapping to the basic weapon preserves permanent precision")
	check(Equipment.equip(c, str(c.roster[0].id), str(bought.instance_id)).ok and int(c.roster[0].accuracy) == 91, "re-equipping the variant reapplies only its own hit tradeoff")

func _test_cross_role_weapon_rules() -> void:
	var spear_user := Campaign.create_campaign("free", 2423)
	var spear_buy := Equipment.buy(spear_user, "weapon_spear_hooked")
	check(spear_buy.ok and Equipment.equip(spear_user, str(spear_user.roster[0].id), str(spear_buy.instance_id)).ok, "guard background can freely equip a spear weapon")
	check(str(spear_user.roster[0].kind) == "guard" and str(spear_user.roster[0].weapon_style) == "spear" and int(spear_user.roster[0].range) == 2, "weapon style changes without overwriting character background")
	var spear_battle := Battle.create_battle(spear_user.roster, 2424, {})
	var spear_guard: Dictionary = spear_battle.units[0]
	var spear_enemy: Dictionary = spear_battle.units[4]
	spear_enemy.q = int(spear_guard.q) + 2
	spear_enemy.r = int(spear_guard.r)
	spear_enemy.statuses.exposed = {"expires": 2}
	spear_battle.props = []
	var spear_actions := Battle.get_actions(spear_battle, str(spear_guard.id))
	check(_has_action(spear_actions, "attack") and not _has_action(spear_actions, "shield_bash") and not _has_action(spear_actions, "push"), "spear loadout removes shield actions from a guard background")
	var spear_plan := Battle.preview(spear_battle, str(spear_guard.id), "attack", {"q": int(spear_enemy.q), "r": int(spear_enemy.r)})
	check(spear_plan.ok and spear_plan.consume_exposed and int(spear_plan.chance) == 95, "cross-role spear range and exposed interaction share the real preview")
	var archer_user := Campaign.create_campaign("free", 2425)
	var bow_buy := Equipment.buy(archer_user, "weapon_archer_longbow")
	check(bow_buy.ok and Equipment.equip(archer_user, str(archer_user.roster[0].id), str(bow_buy.instance_id)).ok and int(archer_user.roster[0].range) == 4, "guard background can equip a bow and receives bow range")
	var bow_battle := Battle.create_battle(archer_user.roster, 2426, {})
	var bow_guard: Dictionary = bow_battle.units[0]
	var bow_enemy: Dictionary = bow_battle.units[4]
	bow_enemy.q = int(bow_guard.q) + 4
	bow_enemy.r = int(bow_guard.r)
	bow_battle.props = []
	check(Battle.preview(bow_battle, str(bow_guard.id), "attack", {"q": int(bow_enemy.q), "r": int(bow_enemy.r)}).ok, "bow-equipped guard attacks at four cells in actual rules")
	var shield_user := Campaign.create_campaign("free", 2427)
	var shield_buy := Equipment.buy(shield_user, "weapon_guard_cleaver")
	check(shield_buy.ok and Equipment.equip(shield_user, str(shield_user.roster[2].id), str(shield_buy.instance_id)).ok, "archer background can freely equip a shield weapon")
	var shield_battle := Battle.create_battle(shield_user.roster, 2428, {})
	var archer_with_shield: Dictionary = shield_battle.units[2]
	var shield_actions := Battle.get_actions(shield_battle, str(archer_with_shield.id))
	check(str(archer_with_shield.kind) == "archer" and str(archer_with_shield.weapon_style) == "guard" and int(archer_with_shield.range) == 1 and _has_action(shield_actions, "shield_bash") and _has_action(shield_actions, "push"), "shield weapon grants shield actions and one-cell range without changing archer background")
	var hunters := Campaign.create_campaign("hunters", 2429)
	var hunter_spear := Equipment.buy(hunters, "weapon_spear_hooked")
	Equipment.equip(hunters, str(hunters.roster[2].id), str(hunter_spear.instance_id))
	var hunter_battle := Battle.create_battle(hunters.roster, 2430, {})
	var hunter_actions := Battle.get_actions(hunter_battle, str(hunter_battle.units[2].id))
	check(_has_action(hunter_actions, "command_follow") and _has_action(hunter_actions, "command_pin") and _has_action(hunter_actions, "command_recall"), "hunter background keeps dog commands after changing weapon style")

func _test_armor_instances_and_repair() -> void:
	var c := Campaign.create_campaign("free", 2431)
	var starter_mail := str(c.roster[0].equipment.armor)
	var padded_buy := Equipment.buy(c, "armor_padded")
	check(padded_buy.ok and Equipment.equip(c, str(c.roster[0].id), str(padded_buy.instance_id)).ok and int(c.roster[0].armor) == 10, "new armor equips with its own full durability")
	c.roster[0].armor = 3
	Equipment.sync_roster_armor_to_instances(c)
	check(Equipment.equip(c, str(c.roster[0].id), starter_mail).ok and int(c.roster[0].armor) == 24, "switching away stores wear on the exact armor instance")
	check(Equipment.equip(c, str(c.roster[0].id), str(padded_buy.instance_id)).ok and int(c.roster[0].armor) == 3, "re-equipping worn armor cannot repair it for free")
	var preview := Equipment.get_repair_preview(c)
	check(int(preview.missing) == 7 and int(preview.price) == 2 and preview.description.contains("合计恢复最多6点"), "repair preview derives cost and fallback from actual instance wear")
	var gold_before := int(c.gold)
	check(Campaign.camp_action(c, "repair").ok and int(c.gold) == gold_before - 2 and int(c.roster[0].armor) == 10, "paid camp repair restores the armor instance at loss-based price")
	var hunters := Campaign.create_campaign("hunters", 2432)
	hunters.roster[0].armor = 20
	hunters.roster[3].armor = 0
	Equipment.sync_roster_armor_to_instances(hunters)
	hunters.gold = 0
	var repair_preview := Equipment.get_repair_preview(hunters)
	var day_before := int(hunters.day)
	check(int(repair_preview.missing) == 10 and int(repair_preview.price) == 3, "repair cost includes equipped armor and dog natural armor")
	check(Campaign.camp_action(hunters, "repair").ok and int(hunters.day) == day_before + 1, "zero-gold repair preserves the one-day recovery path")
	check(int(hunters.roster[0].armor) + int(hunters.roster[3].armor) == 26, "free repair restores only six points company-wide instead of once per stock item")

func _test_battle_wear_death_recruit_and_next_trip() -> void:
	var c := Campaign.create_campaign("free", 2441)
	var premium := Equipment.buy(c, "weapon_guard_cleaver")
	check(Equipment.equip(c, str(c.roster[0].id), str(premium.instance_id)).ok, "death fixture equips a purchased weapon")
	var dead_weapon := str(c.roster[0].equipment.weapon)
	var dead_armor := str(c.roster[0].equipment.armor)
	var spear_armor := str(c.roster[1].equipment.armor)
	_ready(c)
	var battle := Battle.create_battle(c.roster, 2442, Campaign.battle_config(c))
	check(Campaign.begin_battle(c, battle).ok, "equipment fixture enters a real contract battle")
	for unit: Dictionary in c.battle.units:
		if str(unit.id) == str(c.roster[0].id):
			unit.hp = 0
			unit.armor = 0
		elif str(unit.id) == str(c.roster[1].id):
			unit.armor = 5
	c.battle.outcome = "defeat"
	var result := Campaign.resolve_battle(c, c.battle)
	check(result.ok and not _has_instance(c, dead_weapon) and not _has_instance(c, dead_armor), "battle settlement loses both equipped instances with a casualty")
	check(int(_instance(c, spear_armor).durability) == 5 and int(c.roster[1].armor) == 5, "survivor battle wear is written to the same armor instance")
	check(Campaign.return_to_camp(c).ok, "defeated equipment state completes the normal return trip")
	var gold_before_recruit := int(c.gold)
	var recruit := Campaign.camp_action(c, "recruit")
	check(recruit.ok and not str(c.roster[0].equipment.weapon).is_empty() and not str(c.roster[0].equipment.armor).is_empty(), "replacement receives a fresh basic weapon and armor")
	check(int(c.gold) <= gold_before_recruit and not Equipment.sell(c, str(c.roster[0].equipment.weapon)).ok, "replacement issue cannot turn advance debt into sale profit")
	check(Campaign.start_expedition(c).ok, "re-equipped replacement can start the next trip")
	_ready(c)
	var next_battle := Battle.create_battle(c.roster, 2443, Campaign.battle_config(c))
	check(Campaign.begin_battle(c, next_battle).ok and _battle_unit(next_battle, str(c.roster[0].id)).get("equipment", {}) == c.roster[0].equipment, "travel-return-recruit loop carries stable loadout IDs into the next battle snapshot")

func _test_legacy_phase_migrations() -> void:
	_cleanup_legacy()
	var battle_campaign := Campaign.create_campaign("free", 2451)
	_ready(battle_campaign)
	var battle := Battle.create_battle(battle_campaign.roster, 2452, Campaign.battle_config(battle_campaign))
	Campaign.begin_battle(battle_campaign, battle)
	_strip_equipment(battle_campaign)
	battle_campaign.battle.rules_version = "prototype-0.1.1"
	var battle_snapshot: Dictionary = battle_campaign.battle.duplicate(true)
	var rng_before := int(battle_campaign.rng_state)
	_write_legacy(battle_campaign)
	var loaded := Saves.load_campaign(LEGACY_PATH)
	check(loaded.ok and loaded.upgraded and str(loaded.campaign.phase) == "battle", "0.1.3 battle save receives equipment migration")
	check(loaded.campaign.battle == battle_snapshot and int(loaded.campaign.rng_state) == rng_before, "legacy battle migration preserves battlefield snapshot, action log and RNG")
	check(Equipment.validate_campaign(loaded.campaign).is_empty(), "migrated battle roster receives valid stable loadout instances")
	var old_runtime: Dictionary = battle_snapshot.duplicate(true)
	var old_guard: Dictionary = old_runtime.units[0]
	var old_spear: Dictionary = old_runtime.units[1]
	var old_enemy: Dictionary = old_runtime.units[4]
	old_runtime.turn_index = 0
	old_runtime.props = []
	old_enemy.q = int(old_guard.q) + 1
	old_enemy.r = int(old_guard.r)
	check(_has_action(Battle.get_actions(old_runtime, str(old_guard.id)), "shield_bash") and _has_action(Battle.get_actions(old_runtime, str(old_guard.id)), "push"), "0.1.1 battle without weapon_style keeps guard-kind shield fallback")
	old_runtime.turn_index = 1
	old_enemy.q = int(old_spear.q) + 2
	old_enemy.r = int(old_spear.r)
	old_enemy.statuses.exposed = {"expires": 2}
	var old_spear_plan := Battle.preview(old_runtime, str(old_spear.id), "attack", {"q": int(old_enemy.q), "r": int(old_enemy.r)})
	check(old_spear_plan.ok and old_spear_plan.consume_exposed, "0.1.1 battle without weapon_style keeps spear-kind range and exposed fallback")
	var event_campaign := Campaign.create_campaign("free", 2453)
	Campaign.start_expedition(event_campaign)
	while str(event_campaign.phase) == "travel":
		Campaign.advance_travel(event_campaign)
	var saved_event: Dictionary = event_campaign.event.duplicate(true)
	var event_rng := int(event_campaign.rng_state)
	_strip_equipment(event_campaign)
	check(Saves._upgrade_loaded(event_campaign) and event_campaign.event == saved_event and int(event_campaign.rng_state) == event_rng and str(event_campaign.phase) == "event", "legacy event migration does not reroll its saved instance or choice set")
	var growth_campaign := Campaign.create_campaign("free", 2454)
	_ready(growth_campaign)
	var won := Battle.create_battle(growth_campaign.roster, 2455, Campaign.battle_config(growth_campaign))
	Campaign.begin_battle(growth_campaign, won)
	for unit: Dictionary in growth_campaign.battle.units:
		if str(unit.team) == "enemy":
			unit.hp = 0
	growth_campaign.battle.outcome = "victory"
	Campaign.resolve_battle(growth_campaign, growth_campaign.battle)
	var offers: Array = growth_campaign.growth_offers.duplicate(true)
	var growth_rng := int(growth_campaign.rng_state)
	_strip_equipment(growth_campaign)
	check(Saves._upgrade_loaded(growth_campaign) and growth_campaign.growth_offers == offers and int(growth_campaign.rng_state) == growth_rng and str(growth_campaign.phase) == "growth", "legacy growth migration preserves generated rewards and random state")

func _test_legacy_camp_and_returning_migrations() -> void:
	_cleanup_legacy()
	var camp_campaign := Campaign.create_campaign("free", 2461)
	camp_campaign.gold = 91
	camp_campaign.food = 7
	var camp_rng := int(camp_campaign.rng_state)
	var camp_location := str(camp_campaign.world.company_location_id)
	var camp_claimed: Dictionary = camp_campaign.claimed.duplicate(true)
	_strip_equipment(camp_campaign)
	_write_legacy(camp_campaign)
	var camp_loaded := Saves.load_campaign(LEGACY_PATH)
	check(camp_loaded.ok and camp_loaded.upgraded and str(camp_loaded.campaign.phase) == "camp", "0.1.3 camp save receives equipment migration")
	if camp_loaded.ok:
		var restored_camp: Dictionary = camp_loaded.campaign
		check(int(restored_camp.gold) == 91 and int(restored_camp.food) == 7 and int(restored_camp.rng_state) == camp_rng and str(restored_camp.world.company_location_id) == camp_location and restored_camp.claimed == camp_claimed, "camp migration preserves resources, RNG, location, phase and claims")
		var camp_purchase := Equipment.buy(restored_camp, "weapon_spear_hooked")
		check(camp_purchase.ok and Equipment.equip(restored_camp, str(restored_camp.roster[0].id), str(camp_purchase.instance_id)).ok and str(restored_camp.roster[0].weapon_style) == "spear", "migrated camp inventory supports real purchase and cross-role equip")
	var returning_campaign := Campaign.create_campaign("free", 2462)
	_ready(returning_campaign)
	var returning_battle := Battle.create_battle(returning_campaign.roster, 2463, Campaign.battle_config(returning_campaign))
	Campaign.begin_battle(returning_campaign, returning_battle)
	returning_campaign.battle.outcome = "defeat"
	check(Campaign.resolve_battle(returning_campaign, returning_campaign.battle).ok and str(returning_campaign.phase) == "returning", "returning legacy fixture completes one battle settlement")
	var returning_gold := int(returning_campaign.gold)
	var returning_food := int(returning_campaign.food)
	var returning_rng := int(returning_campaign.rng_state)
	var returning_location := str(returning_campaign.world.company_location_id)
	var returning_claimed: Dictionary = returning_campaign.claimed.duplicate(true)
	_strip_equipment(returning_campaign)
	_write_legacy(returning_campaign)
	var returning_loaded := Saves.load_campaign(LEGACY_PATH)
	check(returning_loaded.ok and returning_loaded.upgraded and str(returning_loaded.campaign.phase) == "returning", "0.1.3 returning save receives equipment migration")
	if returning_loaded.ok:
		var restored_returning: Dictionary = returning_loaded.campaign
		check(int(restored_returning.gold) == returning_gold and int(restored_returning.food) == returning_food and int(restored_returning.rng_state) == returning_rng and str(restored_returning.world.company_location_id) == returning_location and restored_returning.claimed == returning_claimed, "returning migration preserves resources, RNG, location, phase and claimed settlement")
		check(Campaign.return_to_camp(restored_returning).ok and str(restored_returning.phase) == "camp", "migrated returning save reaches camp through the saved return path")
		var after_return := JSON.stringify({"gold": restored_returning.gold, "food": restored_returning.food, "claimed": restored_returning.claimed})
		check(not Campaign.return_to_camp(restored_returning).ok and JSON.stringify({"gold": restored_returning.gold, "food": restored_returning.food, "claimed": restored_returning.claimed}) == after_return, "second return is rejected without repeating rewards or claims")
		var returning_purchase := Equipment.buy(restored_returning, "armor_padded")
		check(returning_purchase.ok and Equipment.equip(restored_returning, str(restored_returning.roster[0].id), str(returning_purchase.instance_id)).ok, "equipment remains usable after migrated returning save completes camp return")

func _ready(c: Dictionary) -> void:
	if str(c.phase) == "camp":
		Campaign.start_expedition(c)
	while str(c.phase) == "travel":
		Campaign.advance_travel(c)
	if str(c.phase) == "event":
		Campaign.choose_event(c, str(c.event.choices[0].id))
	while str(c.phase) == "travel":
		Campaign.advance_travel(c)

func _has_instance(c: Dictionary, instance_id: String) -> bool:
	return not _instance(c, instance_id).is_empty()

func _instance(c: Dictionary, instance_id: String) -> Dictionary:
	for instance: Dictionary in c.equipment.instances:
		if str(instance.id) == instance_id:
			return instance
	return {}

func _battle_unit(battle: Dictionary, unit_id: String) -> Dictionary:
	for unit: Dictionary in battle.units:
		if str(unit.id) == unit_id:
			return unit
	return {}

func _has_action(actions: Array, action_id: String) -> bool:
	for action: Dictionary in actions:
		if str(action.id) == action_id:
			return true
	return false

func _strip_equipment(c: Dictionary) -> void:
	c.erase("equipment")
	for unit: Dictionary in c.roster:
		unit.erase("equipment")
		unit.erase("weapon_style")
		unit.erase("visual_loadout")
	# Old 0.1.3 battle snapshots did not carry loadout references. Their removal
	# here is part of the saved fixture; migration must leave the snapshot exact.
	for unit: Dictionary in c.get("battle", {}).get("units", []):
		unit.erase("equipment")
		unit.erase("weapon_style")
		unit.erase("visual_loadout")
	for unit: Dictionary in c.get("battle", {}).get("initial_roster", []):
		unit.erase("equipment")
		unit.erase("weapon_style")
		unit.erase("visual_loadout")

func _write_legacy(c: Dictionary) -> void:
	var directory := LEGACY_PATH.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var payload := JSON.stringify(c)
	var envelope := JSON.stringify({"format": 1, "payload": payload, "sha256": payload.sha256_text()})
	var file := FileAccess.open(LEGACY_PATH, FileAccess.WRITE)
	file.store_string(envelope)
	file.close()

func _cleanup_legacy() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var path: String = LEGACY_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
