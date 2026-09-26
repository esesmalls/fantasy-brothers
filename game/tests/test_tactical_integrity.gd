extends SceneTree

const Battle = preload("res://core/battle_rules.gd")
const Campaign = preload("res://core/campaign_rules.gd")
const Saves = preload("res://core/save_store.gd")
const World = preload("res://core/world_data.gd")

const SAVE_PATH := "user://qa/tactical_integrity/campaign.json"
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_cleanup()
	_test_casualty_save_and_settlement()
	_test_escaped_member_save_and_settlement()
	_test_corrupt_tactical_snapshot_rejected()
	_test_evacuation_progress_resume()
	_test_legacy_snapshot_ignores_tactical_fields()
	_cleanup()
	print("Tactical integrity: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)

func _cleanup() -> void:
	for suffix in ["", ".tmp", ".bak", ".bak.tmp"]:
		var path: String = SAVE_PATH + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _ready_campaign(seed_value: int, evacuation: bool = false) -> Dictionary:
	var c := Campaign.create_campaign("free", seed_value)
	var started: Dictionary = Campaign.accept_contract(c, World.EVACUATION_ID, "road") if evacuation else Campaign.start_expedition(c)
	check(started.ok, "contract starts for tactical integration")
	while c.phase == "travel": Campaign.advance_travel(c)
	if c.phase == "event": Campaign.choose_event(c, str(c.event.choices[0].id))
	while c.phase == "travel": Campaign.advance_travel(c)
	check(c.phase == "ready", "contract reaches ready phase")
	var battle := Battle.create_battle(Campaign.battle_roster(c), seed_value, Campaign.battle_config(c))
	check(Campaign.begin_battle(c, battle).ok, "tactical battle enters campaign")
	return c

func _loaded() -> Dictionary:
	var result := Saves.load_campaign(SAVE_PATH)
	check(result.ok, "saved tactical campaign loads")
	return result.get("campaign", {})

func _finish_victory(b: Dictionary) -> void:
	var events: Array = []
	for unit: Dictionary in b.units:
		if unit.team == "enemy" and unit.hp > 0:
			Battle._damage_unit(b, unit, 1000, "crew_2", true, events)
	Battle._check_outcome(b)

func _test_casualty_save_and_settlement() -> void:
	_cleanup()
	var c := _ready_campaign(7101)
	var b: Dictionary = c.battle
	var casualty_id := str(b.units[0].id)
	var before_equipment: Dictionary = c.roster[0].equipment.duplicate(true)
	Battle._damage_unit(b, b.units[0], 1000, "enemy_0", true, [])
	check(b.casualties.size() == 1 and b.casualties[0].status == "pending", "midbattle casualty remains pending")
	check(Saves.save_campaign(c, SAVE_PATH).ok, "pending casualty snapshot saves")
	var resumed := _loaded()
	check(resumed.battle.casualties == b.casualties and resumed.battle.casualty_rng_state == b.casualty_rng_state, "load preserves casualty draw and RNG state")
	resumed.battle.casualties[0].roll = 0
	_finish_victory(resumed.battle)
	check(resumed.battle.outcome == "victory" and resumed.battle.casualties[0].status == "survived", "victory resolves saved casualty as survivor")
	var result := Campaign.resolve_battle(resumed, resumed.battle)
	var member := _find(resumed.roster, casualty_id)
	check(result.ok and member.hp > 0 and member.equipment == before_equipment and int(member.progression.xp) > 0, "saved survivor keeps equipment and receives XP")
	check(int(member.get("recovery_until_day", 0)) > int(resumed.day), "saved survivor receives recovery time")
	var settled := JSON.stringify(resumed)
	check(not Campaign.resolve_battle(resumed, resumed.battle).ok and JSON.stringify(resumed) == settled, "repeated settlement does not grant rewards or XP again")

func _test_escaped_member_save_and_settlement() -> void:
	_cleanup()
	var c := _ready_campaign(7102)
	var b: Dictionary = c.battle
	var member_id := str(b.units[0].id)
	var before_equipment: Dictionary = c.roster[0].equipment.duplicate(true)
	b.units[0].q = 0
	b.units[0].r = 2
	b.turn_index = b.order.find(member_id)
	var escape_result := Battle.apply_action(b, member_id, "flee", {})
	check(escape_result.ok and b.units[0].escaped and b.units[0].hp > 0, "edge escape removes living member from battle: " + str(escape_result.get("reason", "")))
	check(Saves.save_campaign(c, SAVE_PATH).ok, "escaped member state saves")
	var resumed := _loaded()
	_finish_victory(resumed.battle)
	var member_casualty := false
	for record: Dictionary in resumed.battle.casualties:
		if str(record.unit_id) == member_id: member_casualty = true
	check(resumed.battle.terminal_data.escaped_ids.has(member_id) and not member_casualty, "escape remains separate from casualty after load")
	var result := Campaign.resolve_battle(resumed, resumed.battle)
	var member := _find(resumed.roster, member_id)
	check(result.ok and member.hp > 0 and member.equipment == before_equipment, "escaped member is alive and keeps equipment after settlement")

func _test_corrupt_tactical_snapshot_rejected() -> void:
	var c := _ready_campaign(7103, true)
	check(Saves._validate_battle(c.battle, str(c.expedition.id)).is_empty(), "baseline evacuation battle structure validates: " + Saves._validate_battle(c.battle, str(c.expedition.id)))
	var broken := c.duplicate(true)
	broken.battle.units[0].fatigue = int(broken.battle.units[0].max_fatigue) + 1
	check(not Saves._validate_battle(broken.battle, str(c.expedition.id)).is_empty(), "out-of-range fatigue snapshot rejected")
	broken = c.duplicate(true)
	broken.battle.objective.erase("participant_ids")
	check(not Saves._validate_battle(broken.battle, str(c.expedition.id)).is_empty(), "missing evacuation participants rejected before load")
	broken = c.duplicate(true)
	broken.battle.objective.required_count = 9
	check(not Saves._validate_battle(broken.battle, str(c.expedition.id)).is_empty(), "impossible evacuation threshold rejected before load")
	broken = c.duplicate(true)
	broken.battle.casualties.append({"id": "forged", "battle_id": str(broken.battle.id), "unit_id": "missing", "roll": 0, "status": "pending"})
	check(not Saves._validate_battle(broken.battle, str(c.expedition.id)).is_empty(), "casualty referring to missing unit rejected")

func _test_evacuation_progress_resume() -> void:
	_cleanup()
	var c := _ready_campaign(7104, true)
	var b: Dictionary = c.battle
	check(Saves.validate(c).is_empty(), "new evacuation battle is valid for saving: " + Saves.validate(c))
	var first_id := str(b.objective.participant_ids[0])
	var second_id := str(b.objective.participant_ids[1])
	var first := _find(b.units, first_id)
	var second := _find(b.units, second_id)
	first.q = int(b.width) - 1
	first.r = 0
	second.q = int(b.width) - 1
	second.r = 4
	b.turn_index = b.order.find(first_id)
	check(Battle.apply_action(b, first_id, "flee", {}).ok and b.outcome == "", "first right exit records partial objective")
	var save_result := Saves.save_campaign(c, SAVE_PATH)
	check(save_result.ok, "partial evacuation objective saves: " + str(save_result.get("reason", "")))
	var resumed := _loaded()
	if resumed.is_empty(): return
	check(resumed.battle.objective.evacuated_ids == [first_id] and resumed.battle.objective.required_count == 2, "load keeps exact evacuation progress and threshold")
	resumed.battle.turn_index = resumed.battle.order.find(second_id)
	check(Battle.apply_action(resumed.battle, second_id, "flee", {}).ok and resumed.battle.outcome == "victory", "second exit completes loaded objective")
	check(resumed.battle.terminal_data.objective.evacuated_ids == [first_id, second_id], "terminal objective records both distinct exits")

func _test_legacy_snapshot_ignores_tactical_fields() -> void:
	var base := Battle.create_battle([{"id": "legacy", "kind": "guard"}], 7105)
	base.rules_version = "prototype-0.1.5"
	base.props = []
	base.units[1].q = 3
	base.units[1].r = 2
	base.turn_index = base.order.find("legacy")
	var extra := base.duplicate(true)
	extra.units[0].morale = 0
	extra.units[0].fatigue = extra.units[0].max_fatigue
	extra.cells["3,2"].terrain = "mud"
	extra.cells["3,2"].elevation = 1
	var target := {"q": 3, "r": 2}
	var standard_preview := Battle.preview(base, "legacy", "attack", target)
	var extra_preview := Battle.preview(extra, "legacy", "attack", target)
	check(standard_preview == extra_preview, "legacy attack preview ignores new morale fatigue and height")
	check(Battle.apply_action(base, "legacy", "attack", target).ok and Battle.apply_action(extra, "legacy", "attack", target).ok, "legacy attack remains legal with tactical fields present")
	check(base.units[1].hp == extra.units[1].hp and base.rng_state == extra.rng_state, "legacy resolution is unchanged by tactical extras")

func _find(units: Array, unit_id: String) -> Dictionary:
	for unit: Dictionary in units:
		if str(unit.id) == unit_id:
			return unit
	return {}
