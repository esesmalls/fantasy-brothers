extends Node
const Document = preload("res://presentation/asset_document.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
var checks := []
var output := ""

func check(ok: bool, name: String) -> void:
	checks.append({"name": name, "ok": ok})
	if not ok: push_error(name)

func frame() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))

func find_button(node: Node, name: String) -> Button:
	if node is Button and node.text == name: return node
	for child in node.get_children():
		var button := find_button(child, name)
		if button != null: return button
	return null

func argument(prefix: String, fallback: String) -> String:
	for item in OS.get_cmdline_user_args():
		if item.begins_with(prefix): return item.trim_prefix(prefix)
	return fallback

func run(ui: Control) -> void:
	output = argument("--asset-review-output=", Document.project_root().path_join("builds/asset-workbench/review-qa"))
	DirAccess.make_dir_recursive_absolute(output)
	var source := argument("--asset-review-project=", Document.project_root().path_join("art/workbench/projects/foundation-ready.asset.json"))
	check(DisplayServer.get_name() != "headless", "actual Windows display")
	check(ui.open_project(source), "open foundation without writing original")
	check(ui.doc.validate({}, false).is_empty(), "source project valid")
	get_window().size = Vector2i(1440, 900)
	for scale in [1.25, 1.5]:
		ui.set_ui_scale(scale, false)
		await frame()
		check(is_equal_approx(get_window().content_scale_factor, scale), "manual UI scale " + str(scale))
		check(ui.canvas.size.x >= 300, "usable canvas at UI scale " + str(scale))
		check(ui.left_scroll.get_v_scroll_bar() != null and ui.right_panel.get_v_scroll_bar() != null, "scrollable panels at UI scale " + str(scale))
		var visible := get_viewport().get_visible_rect().size
		check(ui.right_panel.get_global_rect().end.x <= visible.x + 1, "inspector inside viewport at UI scale " + str(scale))
		check(ui.canvas.get_global_rect().end.x <= visible.x + 1, "canvas inside viewport at UI scale " + str(scale))
		await capture("scale-" + str(roundi(scale * 100)))
	ui.set_ui_scale(2.5, false)
	await frame()
	var main_scroll := ui.left_scroll.get_parent().get_parent() as ScrollContainer
	check(main_scroll != null and main_scroll.get_h_scroll_bar().max_value > main_scroll.get_h_scroll_bar().page, "250% retains horizontal access on a smaller window")
	ui.set_ui_scale(1.25, false)
	await frame()
	ui.select(["axe_02"])
	var done := find_button(ui.inspector, "已处理") as CheckBox
	var flagged := find_button(ui.inspector, "存疑 · 稍后复看") as CheckBox
	check(done != null and flagged != null, "review controls visible")
	if done != null: done.button_pressed = true
	await frame()
	flagged = find_button(ui.inspector, "存疑 · 稍后复看") as CheckBox
	if flagged != null: flagged.button_pressed = true
	await frame()
	check(ui.doc.review_state("axe_02").handled and ui.doc.review_state("axe_02").flagged, "both marks can coexist")
	ui.review_filter.select(2)
	ui.refresh_library()
	var found := false
	for i in range(ui.library.item_count):
		if ui.library.get_item_metadata(i) == "axe_02": found = ui.library.get_item_text(i).contains("存疑")
	check(found, "flagged category and name label")
	ui.review_filter.select(0)
	ui.refresh_library()
	await capture("review-flags")
	ui.select(["face"])
	var original_face_position: Array = ui.doc.asset("face_01").position.duplicate()
	var shifted_face_position := [float(original_face_position[0]) + 5.0, float(original_face_position[1]) + 3.0]
	ui.doc.set_value("face_01", "position", shifted_face_position)
	var align := find_button(ui, "快速对齐…")
	check(align != null, "quick alignment entry exists")
	if align != null: align.pressed.emit()
	await frame()
	check(ui.alignment_dialog != null and ui.alignment_dialog.visible, "alignment dialog visible in exported window")
	check(ui.alignment_rows.has("face_01") and not ui.alignment_rows.has("hair_01"), "alignment shows only same concrete type")
	ui.alignment_rows.face_01.select(0)
	var only_one := find_button(ui.alignment_dialog, "只选高亮一件")
	check(only_one != null, "single target control exists")
	if only_one != null: only_one.pressed.emit()
	check(ui.alignment_rows.face_01.is_checked(0) and not ui.alignment_rows.face_02.is_checked(0), "single target control isolates highlighted component")
	check(ui.alignment_plan_data.changes.size() >= 1, "alignment previews a changed face")
	await capture("alignment-preview")
	var expected_face := Visuals.quad(ui.doc.asset("face"), Visuals.world_transform(ui.doc.data, "face"))
	ui.alignment_dialog.confirmed.emit(); ui.alignment_dialog.hide()
	await frame()
	var aligned_face := Visuals.quad(ui.doc.asset("face_01"), Visuals.world_transform(ui.doc.data, "face_01"))
	check(ui.doc.asset("face_01").position != shifted_face_position and ((aligned_face[0] + aligned_face[2]) * 0.5).is_equal_approx((expected_face[0] + expected_face[2]) * 0.5), "alignment writes face to draft")
	check(not ui.doc.review_state("face_01").handled, "alignment does not mark asset processed")
	ui.doc.undo(); ui.refresh()
	check(ui.doc.asset("face_01").position == shifted_face_position, "alignment undoes in one step")
	ui.doc.set_value("face_01", "position", original_face_position)
	var scene_before_combo: Array = ui.doc.data.editor.scene.duplicate()
	for id in ["face", "face_01"]:
		if id not in ui.doc.data.editor.scene: ui.doc.data.editor.scene.append(id)
	ui.select(["face"]); ui.open_alignment_dialog()
	ui.alignment_source_mode.select(1); ui._alignment_rebuild_sources()
	check(not ui.alignment_sources.has("face") and ui.alignment_dialog.get_ok_button().disabled, "combination requires a choice for duplicate concrete type")
	var face_picker: OptionButton
	for row in ui.alignment_sources_box.get_children():
		if row is HBoxContainer and row.get_child_count() > 1 and row.get_child(0).text.contains("[face]"): face_picker = row.get_child(1)
	check(face_picker != null, "duplicate type has source selector")
	if face_picker != null:
		for index in range(1, face_picker.item_count):
			if face_picker.get_item_text(index).ends_with("[face]"):
				face_picker.select(index); face_picker.item_selected.emit(index); break
	check(ui.alignment_sources.get("face", "") == "face" and ui.alignment_rows.has("face_01"), "combination choice maps same type candidates")
	await capture("alignment-combination")
	ui.alignment_dialog.hide(); ui.doc.data.editor.scene = scene_before_combo
	ui.set_ui_scale(2.5, false)
	ui.select(["face"]); ui.open_alignment_dialog(); await frame()
	check(ui.alignment_dialog.visible, "alignment popup opens at 250 percent UI scale")
	await capture("alignment-250")
	ui.alignment_dialog.hide(); ui.set_ui_scale(1.25, false)
	await frame()
	ui.select(["mail"]); ui.open_alignment_dialog(); await frame()
	check(ui.alignment_rows.has("outer_03") and ui.alignment_rows.size() == 4, "hardened leather appears among four outer armor targets")
	check(ui.alignment_dialog.get_ok_button().disabled and ui.alignment_summary.text.contains("蓝框参数已与来源一致"), "unchanged armor box explains disabled apply button")
	await capture("alignment-unchanged-armor")
	ui.alignment_rows.outer_03.select(0)
	var armor_only := find_button(ui.alignment_dialog, "只选高亮一件")
	if armor_only != null: armor_only.pressed.emit()
	await frame()
	var armor_preview: Variant = ui.alignment_preview
	check(armor_preview.editable and armor_preview.screen_target_quad.size() == 4, "single armor target enables direct preview editing")
	var armor_original: Dictionary = ui.doc.asset("outer_03").duplicate(true)
	if armor_preview.screen_target_quad.size() == 4:
		var box: PackedVector2Array = armor_preview.screen_target_quad
		var from := (box[0] + box[2]) * 0.5
		var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = from
		armor_preview._gui_input(press)
		var motion := InputEventMouseMotion.new(); motion.position = from + Vector2(20, -10)
		armor_preview._gui_input(motion)
		var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.position = motion.position
		armor_preview._gui_input(release)
		await frame()
		check(ui.alignment_plan_data.changes.size() == 1 and not ui.alignment_dialog.get_ok_button().disabled, "dragging blue box creates an applicable draft change")
		check(ui.doc.asset("outer_03") == armor_original, "preview drag does not modify draft before confirmation")
		var resized_before := Visuals.quad(Visuals.resolve(ui.alignment_plan_data.trial, "outer_03"), Visuals.world_transform(ui.alignment_plan_data.trial, "outer_03"))
		box = armor_preview.screen_target_quad
		var box_center := (box[0] + box[2]) * 0.5
		press = InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_LEFT; press.pressed = true; press.position = box[2]
		armor_preview._gui_input(press)
		motion = InputEventMouseMotion.new(); motion.position = box_center + (box[2] - box_center) * 1.2
		armor_preview._gui_input(motion)
		release = InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_LEFT; release.position = motion.position
		armor_preview._gui_input(release)
		await frame()
		var resized_after := Visuals.quad(Visuals.resolve(ui.alignment_plan_data.trial, "outer_03"), Visuals.world_transform(ui.alignment_plan_data.trial, "outer_03"))
		check((resized_after[1] - resized_after[0]).length() > (resized_before[1] - resized_before[0]).length() * 1.1, "dragging corner handle enlarges target proportionally")
		await capture("alignment-manual-armor")
	var reset_manual := find_button(ui.alignment_dialog, "重置预览手调")
	if reset_manual != null: reset_manual.pressed.emit()
	check(ui.alignment_plan_data.changes.is_empty() and ui.alignment_dialog.get_ok_button().disabled, "reset preview returns to unchanged source box")
	ui.alignment_dialog.hide()
	if OS.get_cmdline_user_args().has("--alignment-only"):
		var focused_failures := checks.filter(func(item): return not item.ok)
		Document.atomic_json(output.path_join("report.json"), {"display": DisplayServer.get_name(), "checks": checks.size(), "failures": focused_failures, "source": source, "screenshots": ["scale-125.png", "scale-150.png", "alignment-preview.png", "alignment-combination.png", "alignment-250.png", "alignment-unchanged-armor.png", "alignment-manual-armor.png"]})
		print(JSON.stringify({"checks": checks.size(), "failures": focused_failures.size(), "output": output}))
		get_tree().quit(0 if focused_failures.is_empty() else 1)
		return
	var initial: Array = ui.doc.data.editor.scene.duplicate()
	var pending := find_button(ui, "装入待处理／存疑")
	check(pending != null, "batch review button exists")
	if pending != null: pending.pressed.emit()
	await frame()
	check(ui.doc.data.editor.scene != initial, "one click batch changes scene")
	check(ui.doc.validate({}, false).is_empty(), "batch composition valid")
	await capture("pending-composition")
	var first: Array = ui.doc.data.editor.scene.duplicate()
	var random := find_button(ui, "随机装配")
	check(random != null, "random composition button exists")
	if random != null: random.pressed.emit()
	await frame()
	check(ui.doc.data.editor.scene != first, "one click random changes scene")
	check(ui.doc.validate({}, false).is_empty(), "random composition valid")
	await capture("random-composition")
	ui.select(["axe_01"])
	var flip := find_button(ui.inspector, "水平翻转（仅图像，不移动锚点）") as CheckBox
	check(flip != null, "horizontal flip control visible")
	var original_flip: bool = bool(ui.doc.asset("axe_01").get("flip_h", false))
	if flip != null: flip.button_pressed = not flip.button_pressed
	await frame()
	check(bool(ui.doc.asset("axe_01").get("flip_h", false)) != original_flip, "horizontal flip edits asset")
	var saved := output.path_join("review-smoke.asset.json")
	if FileAccess.file_exists(saved): DirAccess.remove_absolute(saved)
	check(ui.doc.save_project(saved).is_empty(), "save review and flip to independent draft")
	var loaded := Document.new()
	check(loaded.load_project(saved).is_empty(), "reload independent review draft")
	check(bool(loaded.asset("axe_01").get("flip_h", false)) != original_flip and loaded.review_state("axe_02").flagged, "flip and marks persist")
	await capture("horizontal-flip")
	var failures := checks.filter(func(item): return not item.ok)
	var report := {"display": DisplayServer.get_name(), "checks": checks.size(), "failures": failures, "source": source, "screenshots": ["scale-125.png", "scale-150.png", "review-flags.png", "alignment-preview.png", "alignment-combination.png", "alignment-250.png", "pending-composition.png", "random-composition.png", "horizontal-flip.png"]}
	Document.atomic_json(output.path_join("report.json"), report)
	print(JSON.stringify({"checks": checks.size(), "failures": failures.size(), "output": output}))
	get_tree().quit(0 if failures.is_empty() else 1)
