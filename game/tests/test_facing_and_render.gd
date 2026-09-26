extends SceneTree
const Runtime = preload("res://presentation/asset_runtime.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Campaign = preload("res://core/campaign_rules.gd")
const Board = preload("res://presentation/battle_board.gd")
const Battle = preload("res://core/battle_rules.gd")
const Document = preload("res://presentation/asset_document.gd")
var checks := 0
var failures: Array[String] = []
func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)
func _initialize() -> void:
	var crew: Dictionary = Campaign.create_campaign("free", 6023).roster[2]
	var enemy := crew.duplicate(true); enemy.team = "enemy"
	check(Runtime.facing_for(crew, {}) == 1, "friendly defaults right")
	check(Runtime.facing_for(enemy, {}) == -1, "enemy defaults left")
	check(Runtime.facing_for(crew, {"action": "slash", "direction": Vector2.LEFT}) == -1, "friendly attacks target to left")
	check(Runtime.facing_for(enemy, {"action": "slash", "direction": Vector2.RIGHT}) == 1, "enemy attacks target to right")
	var data := Runtime.data_for_unit(crew)
	var action := Runtime.action_for_unit(crew, "attack")
	var contact := 0.0
	for marker: Dictionary in action.events:
		if marker.id == "contact": contact = float(marker.time)
	for facing in [-1.0, 1.0]:
		for target in [Vector2(-180, -60), Vector2(210, 30), Vector2(0, -160)]:
			var arrow := Runtime.battle_arrow_pose(data, "", action, contact, target, facing)
			check(arrow.position.distance_to(target) < 0.001, "arrow tip reaches actual target at contact")
			var miss := Runtime.battle_arrow_pose(data, "", action, contact, target, facing, "miss")
			check(miss.position.distance_to(target) > 0 and miss.position.distance_to(target) < 24, "miss lands near this target, not a fixed demo point")
			check(not Runtime.battle_arrow_pose(data, "", action, contact + 0.1, target, facing).visible, "arrow removed after contact")
	var ids := Runtime.selection(data, crew)
	Visuals.draw_cache.clear()
	var before := Visuals.compiled_draws
	for i in range(20): Visuals.draw_packets(data, ids, Runtime.cached_directory)
	check(Visuals.compiled_draws == before + 1, "static actor geometry compiled once across redraws")
	var plain := data.duplicate(true)
	plain.erase("_render_cache_key")
	plain.assets.face.flip_h = false
	var normal := Visuals.draw_packets(plain, ["face"], Runtime.cached_directory, "", {}, 0, {}, true)
	plain.assets.face.flip_h = true
	var flipped := Visuals.draw_packets(plain, ["face"], Runtime.cached_directory, "", {}, 0, {}, true)
	check(normal.parts.size() == flipped.parts.size() and not normal.parts.is_empty(), "flip keeps geometry and mask count")
	if not normal.parts.is_empty():
		check(normal.parts[0].polygon == flipped.parts[0].polygon, "flip preserves calibration and grip frame")
		check(normal.parts[0].uvs != flipped.parts[0].uvs, "flip mirrors pixels")
	var state := Battle.create_battle(Campaign.create_campaign("free", 6023).roster, 6023)
	var attacker: Dictionary = state.units[2]
	var defender: Dictionary = state.units[4]
	attacker.q = 5; attacker.r = 3
	defender.q = 1; defender.r = 3
	var board := Board.new()
	root.add_child(board)
	board.set_battle(state)
	board._begin_event({"type": "attack", "actor": attacker.id, "target": defender.id})
	var pose := board.get_motion_pose(str(attacker.id))
	check(pose.direction.x < 0, "board forwards actual left-side target direction")
	check(pose.target_position == board._hex_center(1, 3) + Runtime.impact_offset(defender), "board forwards calibrated target impact anchor")
	check(Runtime.impact_offset({"kind": "dog"}) == Vector2(0, -16), "dog uses its low body anchor")
	board.skip_animations(); board.free()
	var start := Time.get_ticks_usec()
	for i in range(20): Visuals.draw_packets(data, ids, Runtime.cached_directory)
	var cached_us := Time.get_ticks_usec() - start
	start = Time.get_ticks_usec()
	for i in range(20): Visuals.draw_packets(plain, ids, Runtime.cached_directory)
	print("20 static geometry requests: cached=%dus, uncached=%dus (CPU preparation only)" % [cached_us, Time.get_ticks_usec() - start])
	var document := Document.new()
	check(document.load_project(Document.project_root().path_join("art/workbench/projects/foundation-review.asset.json")).is_empty(), "load actual review draft")
	document.replace_scene("random", 812)
	var original := Runtime.cached_data
	Runtime.cached_data = document.runtime_data()
	Runtime.identity_cache.clear()
	for member: Dictionary in Campaign.create_campaign("free", 6023).roster:
		var composed := Runtime.data_for_unit(member)
		check(Visuals.diagnostics(composed, Runtime.selection(composed, member)).is_empty(), "random assembly still supplies runtime parent context")
	Runtime.cached_data = original
	Runtime.identity_cache.clear()
	print("Facing/render: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures: printerr(failure)
	quit(0 if failures.is_empty() else 1)
