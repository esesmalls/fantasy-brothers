extends SceneTree

const Feedback = preload("res://presentation/weapon_feedback.gd")
const AssetRuntime = preload("res://presentation/asset_runtime.gd")
var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	await process_frame
	await process_frame
	_test_templates_and_routing()
	_test_authored_action()
	_test_audio_resources_and_skip()
	await create_timer(0.25).timeout
	print("Weapon feedback: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)


func _test_templates_and_routing() -> void:
	var light := Feedback.action_template("weapon_guard_sword")
	var heavy := Feedback.action_template("weapon_skirmisher_axe")
	var spear := Feedback.action_template("weapon_spear_long")
	var bow := Feedback.action_template("weapon_archer_bow")
	var shield := Feedback.action_template("shield_bash")
	_check(float(light.contact) < float(heavy.contact) and float(light.duration) < float(heavy.duration), "heavy blade has later, weightier contact")
	_check(float(spear.release) < float(spear.contact) and float(spear.recover) > float(spear.contact), "spear thrust has a visible approach and recovery")
	_check(float(bow.release) < float(bow.contact) and Feedback.cue_for("bow", "aim") == "bow_draw", "bow aim and target contact are separate")
	_check(float(shield.recover) > float(shield.contact), "shield recoil remains after block")
	_check(Feedback.cue_for("weapon_guard_sword", "contact", "miss", "flesh") == "miss_result", "miss cannot sound like flesh damage")
	_check(Feedback.cue_for("weapon_guard_sword", "contact", "hit", "armor") == "armor_light", "armor contact selects metal")
	_check(Feedback.cue_for("weapon_skirmisher_axe", "contact", "hit", "armor") == "armor_heavy", "heavy blade selects weighty metal")
	_check(Feedback.cue_for("weapon_guard_sword", "contact", "block", "flesh") == "shield_contact", "block takes precedence over flesh")
	_check(Feedback.should_play_phase("bow", "release", 2.0) and Feedback.should_play_phase("bow", "contact", 2.0), "2x retains distinct release and result")
	_check(not Feedback.should_play_phase("light_sword", "recover", 2.0) and Feedback.should_play_phase("light_sword", "result", 0.0), "2x shortens handling; skip keeps result")


func _test_audio_resources_and_skip() -> void:
	for cue_id in Feedback.CUES:
		var path: String = Feedback.cue_path(cue_id)
		_check(ResourceLoader.exists(path) and load(path) is AudioStream, "audio resource imports: " + cue_id)
	var feedback := Feedback.new()
	get_root().add_child(feedback)
	var release_id: String = feedback.play_cue("weapon_archer_bow", "release", "hit", "flesh", 2.0)
	_check(release_id == "bow_release" and feedback._voices.size() == 1 and is_equal_approx(feedback._voices[0].pitch_scale, 1.0), "accelerated bow release uses real pitch")
	var result_id: String = feedback.skip_to_result("weapon_archer_bow", "block", "block")
	_check(result_id == "shield_contact" and feedback._voices.size() <= 8, "skip discards flight and plays one block result")
	for player in feedback._voices:
		player.stop()
		player.stream = null
	feedback.free()


func _test_authored_action() -> void:
	var actions: Dictionary = AssetRuntime.current().get("actions", {})
	_check(actions.has("sword") and actions.has("spear") and actions.has("bow"), "published source actions exist")
	if not (actions.has("sword") and actions.has("spear") and actions.has("bow")): return
	var original: String = JSON.stringify(actions.sword)
	var light: Dictionary = Feedback.authored_action(actions.sword, "weapon_guard_sword", "attack")
	var heavy: Dictionary = Feedback.authored_action(actions.sword, "weapon_skirmisher_axe", "attack")
	var spear: Dictionary = Feedback.authored_action(actions.spear, "weapon_spear_long", "attack")
	var bow: Dictionary = Feedback.authored_action(actions.bow, "weapon_archer_bow", "attack")
	var shield: Dictionary = Feedback.authored_action(actions.sword, "weapon_guard_sword", "shield_bash")
	_check(JSON.stringify(actions.sword) == original, "authoring never mutates published base action")
	_check(float(light.duration) < float(heavy.duration), "light sword faster than heavy axe")
	_check(float(heavy.events[1].time) > float(light.events[1].time), "heavy blade contacts later")
	_check(float(spear.events[0].time) < float(spear.events[1].time), "spear releases before contact")
	_check(float(bow.events[0].time) < float(bow.events[1].time), "bow release precedes arrow impact")
	_check(shield.tracks.size() == 2 and shield.tracks[0].target == "shield" and shield.tracks[1].property == "rotation", "shield bash animates shield x and rotation only")
	_check(not shield.has("legacy_action") and not shield.has("legacy_weapon"), "shield bash cannot inherit sword legacy path")
	for action: Dictionary in [light, heavy, spear, bow, shield]:
		var valid := true
		for track: Dictionary in action.get("tracks", []):
			var last := -1.0
			for key: Dictionary in track.get("keys", []):
				var moment := float(key.get("time", -1.0))
				valid = valid and moment >= last and moment <= float(action.duration)
				last = moment
		_check(valid, "derived track stays sorted and within duration: " + str(action.id))
