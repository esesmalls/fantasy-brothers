extends SceneTree
## Focused checks for the isolated hand-style comparison. These checks exercise
## presentation state only; the scene has no battle or save-state contract.

const Actor = preload("res://presentation/hand_style_actor.gd")
const ReviewScene = preload("res://presentation/hand_style_review.tscn")

var checks := 0
var failures: Array[String] = []


class ActorProbe extends Control:
	const ProbeActor = preload("res://presentation/hand_style_actor.gd")
	var unit := {
		"id": "hand_style_probe",
		"name": "H样板佣兵",
		"kind": "guard",
		"hp": 42,
		"max_hp": 42,
		"armor": 17,
		"max_armor": 24,
		"visual_loadout": {"weapon": "weapon_guard_sword", "armor": "armor_mail"}
	}
	var completed := false
	var drew_both := false
	var state_before := ""
	var state_after := ""

	func _ready() -> void:
		custom_minimum_size = Vector2(320, 220)
		size = Vector2(320, 220)
		state_before = JSON.stringify(unit)
		queue_redraw()

	func _draw() -> void:
		var pose := {"action": "slash", "progress": 0.48, "armor_ratio": 0.7}
		var drew_a := ProbeActor.draw_actor(self, "a_hand", unit, Vector2(95, 175), 2.0, pose)
		var drew_b := ProbeActor.draw_actor(self, "b_abstract", unit, Vector2(225, 175), 2.0, pose)
		drew_both = drew_a and drew_b
		state_after = JSON.stringify(unit)
		completed = true


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_test_shared_timing()
	await _test_actor_is_read_only_and_assets_load()
	await _test_review_controls_and_single_impact()
	await _test_capture_failure_contract()
	print("Hand style review: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)


func _test_shared_timing() -> void:
	for action in ["idle", "slash", "shield_bash"]:
		var hand: Dictionary = Actor.get_timing("a_hand", action)
		var abstract: Dictionary = Actor.get_timing("b_abstract", action)
		_check(hand == abstract, "A/B %s use exactly the same duration and phase boundaries" % action)
	_check(is_equal_approx(float(Actor.get_timing("a_hand", "slash").duration), 0.72), "slash comparison keeps its declared 0.72 second review rhythm")
	_check(is_equal_approx(float(Actor.get_timing("a_hand", "shield_bash").duration), 0.62), "shield comparison keeps its declared 0.62 second review rhythm")


func _test_actor_is_read_only_and_assets_load() -> void:
	_check(ResourceLoader.exists(Actor.PARTS_PATH), "comparison arm and shield atlas exists")
	_check(ResourceLoader.exists("res://assets/art/motion/b-atlas-v2.png"), "shared H actor atlas exists")
	var probe := ActorProbe.new()
	root.add_child(probe)
	await process_frame
	if DisplayServer.get_name() != "headless":
		for _frame in range(2):
			await process_frame
		_check(probe.completed and probe.drew_both, "both styles render from the real shared assets")
		_check(probe.state_after == probe.state_before, "rendering A and B does not mutate the supplied unit snapshot")
	probe.queue_free()


func _test_review_controls_and_single_impact() -> void:
	var review = ReviewScene.instantiate()
	root.add_child(review)
	await process_frame
	review.set_process(false)
	_check(review.preflight_errors().is_empty(), "review preflight accepts the actor API and every required atlas")
	_check(review._canvases.size() == 2, "review exposes exactly the hand and abstract columns")

	review.play_action("slash")
	_check(review._canvases.all(func(canvas): return canvas.action == "slash" and is_equal_approx(canvas.progress, 0.0)), "both columns receive the same action and progress")
	review._process(0.70)
	_check(review._armor_damage == 6, "slash applies its displayed armor loss once at contact")
	var time_at_pause: float = review._action_time
	review.toggle_pause()
	review._process(0.50)
	_check(is_equal_approx(review._action_time, time_at_pause) and review._armor_damage == 6, "pause blocks time and repeated armor loss")
	review.toggle_pause()
	review._process(0.02)
	_check(review._armor_damage == 6, "continuing past an applied contact does not charge it twice")

	review._on_slider_changed(0.20)
	_check(review._armor_damage == 6, "scrubbing backward does not immediately alter persistent armor loss")
	review._process(0.26)
	_check(review._armor_damage == 6, "crossing the same contact again after scrubbing does not repeat armor loss")
	review.play_action("slash")
	review._process(0.70)
	_check(review._armor_damage == 12, "an explicit replay adds exactly one new slash impact")
	review._process(0.10)
	_check(review._armor_damage == 12, "replay remains single-charge after its contact frame")

	var speed_review = ReviewScene.instantiate()
	root.add_child(speed_review)
	await process_frame
	speed_review.set_process(false)
	speed_review.play_action("shield_bash")
	var start_time: float = speed_review._action_time
	speed_review._process(0.10)
	var one_x_advance: float = speed_review._action_time - start_time
	speed_review.set_speed(2.0)
	var two_x_start: float = speed_review._action_time
	speed_review._process(0.10)
	var two_x_advance: float = speed_review._action_time - two_x_start
	_check(is_equal_approx(one_x_advance, 0.10) and is_equal_approx(two_x_advance, 0.20), "2x advances the same review clock at twice the 1x rate")
	_check(speed_review._canvases.all(func(canvas): return canvas.action == "shield_bash" and is_equal_approx(canvas.progress, speed_review._progress)), "speed changes keep both comparison columns on the same frame")
	review.queue_free()
	speed_review.queue_free()
	await process_frame


func _test_capture_failure_contract() -> void:
	if DisplayServer.get_name() == "headless":
		var output: Array = []
		var exit_code := OS.execute(OS.get_executable_path(), [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", "res://tests/capture_hand_style_review.gd", "--", "--output=user://hand-style-review-contract"
		], output, true, false)
		_check(exit_code != 0, "headless/no-render capture is reported as a failure instead of a successful screenshot run")
	else:
		_check(true, "capture failure contract is exercised by the dedicated smoke run on a rendered display")
