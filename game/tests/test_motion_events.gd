extends SceneTree
## Presentation timing checks. BattleBoard may read snapshots and events, but it may
## never change rules, RNG, action history or the already-settled result.

const Battle = preload("res://tests/legacy_battle_rules.gd") # Fixed event fixtures before dynamic initiative.
const Board = preload("res://presentation/battle_board.gd")
const ReviewScene = preload("res://presentation/motion_review.tscn")
const AssetDocument = preload("res://presentation/asset_document.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	# Isolate from the user's published art. Explicit timings exercise the new contract.
	AssetDocument.storage_override = AssetDocument.project_root().path_join("builds/asset-workbench/motion-unit")
	var document := AssetDocument.new()
	document.data.actions["test-slash"] = {"id": "test-slash", "duration": 1.2, "events": [{"id": "contact", "time": 0.31}], "tracks": []}
	document.data.actions["test-bash"] = {"id": "test-bash", "duration": 0.8, "events": [{"id": "contact", "time": 0.4}], "tracks": []}
	_check(document.apply().is_empty(), "isolated authored motion fixture publishes")
	_test_catalog_timings()
	_test_shield_action_lookup_and_single_speed()
	_test_contact_snapshot_and_skip()
	_test_six_direction_attack_vectors()
	_test_modular_silhouette_selection()
	_test_review_death_stops()
	print("Motion events: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _fixture(target_hp: int = 30, target_armor: int = 0) -> Dictionary:
	var battle := Battle.create_battle([{
		"id": "crew_1", "name": "样板", "kind": "guard", "hp": 40, "max_hp": 40,
		"armor": 20, "max_armor": 20, "attack": 14, "accuracy": 100,
		"weapon_style": "guard", "presentation_sample": true,
		"visual_loadout": {"weapon": "weapon_guard_sword", "armor": "armor_mail"}, "perks": []
	}], 7711, {"id": "motion-test"})
	var actor := _unit(battle, "crew_1")
	actor.visual_actions = {"slash": "test-slash", "shield_bash": "test-bash"}
	var target := _unit(battle, "enemy_0")
	target.q = int(actor.q) + 1
	target.r = int(actor.r)
	target.hp = target_hp
	target.max_hp = maxi(target_hp, 30)
	target.armor = target_armor
	target.max_armor = maxi(target_armor, 1)
	return battle

func _new_board() -> Control:
	var board := Board.new()
	get_root().add_child(board)
	board.set_process(false)
	return board

func _test_catalog_timings() -> void:
	_check(is_equal_approx(Board.motion_duration("a", "slash"), 0.42), "template A slash duration comes from the motion catalog")
	_check(is_equal_approx(Board.motion_duration("b", "shield_bash"), 0.60), "template B shield duration comes from the motion catalog")
	_check(is_equal_approx(Board.motion_duration("c", "slash"), 0.92), "template C slash duration comes from the motion catalog")
	_check(is_equal_approx(Board.motion_contact("b"), 0.50), "template B contact fraction comes from the motion catalog")

func _test_shield_action_lookup_and_single_speed() -> void:
	var before := _fixture(40, 20)
	var settled: Dictionary = before.duplicate(true)
	var target := _unit(settled, "enemy_0")
	var result := Battle.apply_action(settled, "crew_1", "shield_bash", {"q": int(target.q), "r": int(target.r)})
	_check(bool(result.ok), "real shield bash fixture is legal")
	var rules_after := JSON.stringify(settled)
	var board := _new_board()
	board.set_motion_template("b")
	board.set_battle(before)
	board.set_battle(settled)
	board.set_animation_speed(2.0)
	board.play_events(result.events)
	board._process(0.0)
	var pose: Dictionary = board.get_motion_pose("crew_1")
	_check(str(pose.action) == "shield_bash", "attack event resolves shield bash through root action and actor")
	_check(board._pending_impacts.size() == 1 and board._pending_impacts[0].events.size() == 2, "same-root shield hit and exposed status stay grouped until contact")
	board._process(0.15)
	pose = board.get_motion_pose("crew_1")
	_check(is_equal_approx(float(board._motions.crew_1.duration), 0.8), "authored shield duration reaches real board")
	_check(is_equal_approx(float(pose.progress), 0.375), "2x speed advances once across authored duration")
	_check(JSON.stringify(settled) == rules_after, "animation playback leaves rules, RNG and action history unchanged")
	board.queue_free()

func _test_contact_snapshot_and_skip() -> void:
	var before := _fixture(3, 0)
	var settled: Dictionary = before.duplicate(true)
	var target := _unit(settled, "enemy_0")
	var result := Battle.apply_action(settled, "crew_1", "attack", {"q": int(target.q), "r": int(target.r)})
	_check(bool(result.ok) and int(_unit(settled, "enemy_0").hp) == 0, "real attack settles lethal rules immediately")
	var rules_after := JSON.stringify(settled)
	var board := _new_board()
	board.set_motion_template("a")
	board.set_battle(before)
	board.set_battle(settled)
	board.play_events(result.events)
	board._process(0.0)
	var target_id := "enemy_0"
	_check(int(board._display_units.get(target_id, {}).get("hp", 0)) == 3, "lethal target keeps its old visual snapshot before contact")
	var contact_time := 0.31
	_check(is_equal_approx(float(board._motions.crew_1.duration), 1.2), "authored slash duration overrides legacy template")
	board._process(contact_time - 0.002)
	_check(int(board._display_units.get(target_id, {}).get("hp", 0)) == 3 and str(board.get_motion_pose(target_id).action) != "death", "death does not appear one frame before contact")
	board._process(0.004)
	_check(int(board._display_units.get(target_id, {}).get("hp", 1)) == 0 and str(board.get_motion_pose(target_id).action) == "death", "hit and death feedback switch to the settled snapshot at contact")
	board.skip_animations()
	_check(not board.has_pending_animation() and board._display_units.is_empty(), "skip clears every presentation queue")
	_check(str(board.get_motion_pose(target_id).action) == "death", "skip immediately exposes the correct settled terminal pose")
	_check(JSON.stringify(settled) == rules_after, "contact playback and skip preserve the full rules snapshot")
	board.queue_free()

func _test_six_direction_attack_vectors() -> void:
	var directions := [
		{"step": Vector2i(1, 0), "name": "东"},
		{"step": Vector2i(1, -1), "name": "东北"},
		{"step": Vector2i(0, -1), "name": "西北"},
		{"step": Vector2i(-1, 0), "name": "西"},
		{"step": Vector2i(-1, 1), "name": "西南"},
		{"step": Vector2i(0, 1), "name": "东南"},
	]
	for entry: Dictionary in directions:
		var step: Vector2i = entry.step
		var before := _fixture(80, 0)
		var actor := _unit(before, "crew_1")
		var target := _unit(before, "enemy_0")
		target.q = int(actor.q) + step.x
		target.r = int(actor.r) + step.y
		var settled: Dictionary = before.duplicate(true)
		var settled_target := _unit(settled, "enemy_0")
		var result := Battle.apply_action(settled, "crew_1", "attack", {"q": int(settled_target.q), "r": int(settled_target.r)})
		var rules_after := JSON.stringify(settled)
		var board := _new_board()
		board.set_battle(before)
		board.set_battle(settled)
		board.play_events(result.get("events", []))
		board._process(0.0)
		var pose: Dictionary = board.get_motion_pose("crew_1")
		var expected := Vector2(sqrt(3.0) * (float(step.x) + float(step.y) * 0.5), 1.5 * float(step.y)).normalized()
		var actual: Vector2 = pose.get("direction", Vector2.ZERO)
		_check(bool(result.get("ok", false)) and str(pose.get("action", "")) == "slash" and actual.dot(expected) > 0.999, "real sword attack transmits the full %s hex direction to its pose" % str(entry.name))
		_check(JSON.stringify(settled) == rules_after, "%s direction playback leaves the settled rules snapshot unchanged" % str(entry.name))
		board.queue_free()

func _test_modular_silhouette_selection() -> void:
	var battle := _fixture()
	var actor := _unit(battle, "crew_1")
	var board := _new_board()
	board.set_battle(battle)
	var point: Vector2 = board._hex_center(int(actor.q), int(actor.r))
	_check(str(board._unit_hit_at(point + Vector2(-33, -13)).get("id", "")) == "crew_1", "visible modular shield belongs to its wearer when clicked")
	_check(not board._modular_arm_hit(Vector2(-42, -38)), "empty space above and outside the shield is not selectable armor")
	board.queue_free()

func _test_review_death_stops() -> void:
	var review = ReviewScene.instantiate()
	review._build_ui()
	review.reset_fixture()
	review._set_preview_action("death")
	review.preview_paused = false
	review._process(Board.motion_duration("b", "death") + 0.01)
	_check(review.preview_paused and is_equal_approx(float(review.preview_progress), 1.0) and review.pause_button.text == "重播", "death preview stops on its terminal frame instead of reviving in a loop")
	review._toggle_preview_pause()
	_check(not review.preview_paused and is_equal_approx(float(review.preview_progress), 0.0), "terminal replay control restarts death from its first frame")
	review._set_armor("armor_padded")
	_check(int(review._sample_unit().max_armor) == 10 and int(review._sample_unit().armor) == 10, "padded review resets the real battle fixture to its equipment-defined armor")
	review._set_armor("armor_mail")
	_check(int(review._sample_unit().max_armor) == 24 and int(review._sample_unit().armor) == 24, "mail review resets the real battle fixture to its equipment-defined armor")
	review._set_preview_background("white")
	_check(review.preview_background == "white" and review.actor_preview.background_mode == "white" and review.background_buttons["white"].button_pressed, "review close-up exposes a selectable white edge-check background")
	review._set_preview_background("battle")
	_check(review.preview_background == "battle" and review.actor_preview.background_mode == "battle" and review.background_buttons["battle"].button_pressed, "review close-up exposes a selectable battlefield background")
	review.free()

func _unit(battle: Dictionary, id: String) -> Dictionary:
	for unit: Dictionary in battle.get("units", []):
		if str(unit.get("id", "")) == id:
			return unit
	return {}
