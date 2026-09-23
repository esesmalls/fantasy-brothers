extends Node
const Document = preload("res://presentation/asset_document.gd")
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
	var report := {"display": DisplayServer.get_name(), "checks": checks.size(), "failures": failures, "source": source, "screenshots": ["scale-125.png", "scale-150.png", "review-flags.png", "pending-composition.png", "random-composition.png", "horizontal-flip.png"]}
	Document.atomic_json(output.path_join("report.json"), report)
	print(JSON.stringify({"checks": checks.size(), "failures": failures.size(), "output": output}))
	get_tree().quit(0 if failures.is_empty() else 1)
