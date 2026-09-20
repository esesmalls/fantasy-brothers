extends SceneTree
## Deterministic capture of the actual review renderer. No repainting or generated imagery.

const REVIEW_SCENE := preload("res://presentation/hand_style_review.tscn")

var _failures: Array[String] = []

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := ProjectSettings.globalize_path("res://../builds/hand-style-review")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = ProjectSettings.globalize_path(argument.get_slice("=", 1))
	DirAccess.make_dir_recursive_absolute(output)
	if DisplayServer.get_name() == "headless":
		printerr("HAND STYLE REVIEW FAIL: headless模式无法生成评审截图")
		quit(1)
		return
	root.content_scale_size = Vector2i(1440, 900)
	root.size = Vector2i(1440, 900)
	var review = REVIEW_SCENE.instantiate()
	root.add_child(review)
	await process_frame
	await process_frame
	var setup_errors: Array[String] = review.preflight_errors()
	if not setup_errors.is_empty():
		for setup_error in setup_errors:
			printerr("HAND STYLE REVIEW FAIL: " + setup_error)
		quit(1)
		return
	var sound_failures: Array[String] = review.export_preview_sounds("res://../art/validation/2026-09-20-hand-comparison/previews")
	for failed_path in sound_failures:
		_failures.append("无法保存预览声音：" + failed_path)
	review.reset_review()
	review.play_action("slash")
	review._process(0.71)
	var committed_damage := int(review.get_review_state().armor_damage)
	review._on_slider_changed(0.20)
	review._on_slider_changed(0.80)
	review._on_slider_changed(0.20)
	review._on_slider_changed(0.80)
	if committed_damage != 6 or int(review.get_review_state().armor_damage) != committed_damage:
		_failures.append("拖动时间轴重复结算了同一次普通攻击的护甲损伤")
	review.reset_review()

	review.set_fixed_frame("idle", 0.22, 0)
	await _save_frame(output.path_join("hand-style-static-1440x900.png"))
	for action in ["slash", "shield_bash"]:
		for index in range(9):
			var progress := float(index) / 8.0
			var damage := (6 if action == "slash" else 3) if progress >= 0.48 else 0
			review.set_fixed_frame(action, progress, damage)
			await _save_frame(output.path_join("hand-style-%s-%02d.png" % [action, index]))

	review.set_fixed_frame("idle", 0.22, 9)
	root.content_scale_size = Vector2i(1180, 740)
	root.size = Vector2i(1180, 740)
	await process_frame
	await process_frame
	await _save_frame(output.path_join("hand-style-small-1180x740.png"))

	review.set_capture_strip_mode(true)
	root.content_scale_size = Vector2i(1120, 440)
	root.size = Vector2i(1120, 440)
	await process_frame
	await process_frame
	for action in ["slash", "shield_bash"]:
		for index in range(16):
			var progress := float(index) / 15.0
			var damage := (6 if action == "slash" else 3) if progress >= 0.48 else 0
			review.set_fixed_frame(action, progress, damage)
			await _save_frame(output.path_join("strip-%s-%02d.png" % [action, index]))

	if _failures.is_empty():
		print("Hand style review capture: static, 18 full UI action frames, 1180x740 small view, and 32 no-UI strip frames saved to " + output)
	else:
		for failure in _failures:
			printerr("HAND STYLE REVIEW FAIL: " + failure)
	quit(0 if _failures.is_empty() else 1)

func _save_frame(path: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(path)
	if error != OK:
		_failures.append("无法保存截图：" + path)
