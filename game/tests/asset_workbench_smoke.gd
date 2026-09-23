extends Node
const Document = preload("res://presentation/asset_document.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Legacy = preload("res://presentation/paperdoll_document.gd")
const Actor = preload("res://presentation/static_bust_actor.gd")
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

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var found := find_button(child, text)
		if found != null: return found
	return null

func click_control(control: Control) -> void:
	var point := control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new(); motion.position = point; motion.global_position = point; Input.parse_input_event(motion)
	await frame()
	for down in [true, false]:
		var mouse := InputEventMouseButton.new(); mouse.position = point; mouse.global_position = point; mouse.button_index = MOUSE_BUTTON_LEFT; mouse.pressed = down
		Input.parse_input_event(mouse); await frame()

func run(ui: Control) -> void:
	output = Document.project_root().path_join("builds/asset-workbench/qa")
	DirAccess.make_dir_recursive_absolute(output)
	Document.storage_override = output.path_join("runtime")
	ui.doc.expected_revision = Document.revision()
	var user_draft := Document.project_root().path_join("my_test-v2.json")
	if FileAccess.file_exists(user_draft): check(ui.open_project(user_draft), "migrate user draft")
	await frame()
	check(ui.library.item_count >= 20, "dynamic registry populated")
	check(ui.doc.validate().is_empty(), "migrated document valid")
	check(ui.doc.path.is_empty(), "legacy file cannot be overwritten")
	await click_control(find_button(ui, "旋转 R")); check(ui.canvas.mode == "rotate", "engine input selects rotate tool")
	await click_control(find_button(ui, "移动 G")); check(ui.canvas.mode == "move", "engine input selects move tool")
	ui.search.grab_focus(); ui.search.text = "shield"; ui.refresh_library()
	check(ui.library.item_count == 1, "library search by stable ID")
	var unchanged: Dictionary = ui.doc.data.duplicate(true)
	var keyboard := InputEventKey.new(); keyboard.keycode = KEY_Z; keyboard.pressed = true; keyboard.ctrl_pressed = true; Input.parse_input_event(keyboard); await frame()
	check(ui.doc.data == unchanged, "text input focus does not steal document undo")
	ui.search.text = ""; ui.refresh_library(); ui.canvas.grab_focus()
	for dimensions in [Vector2i(1440, 960), Vector2i(1180, 740)]:
		get_window().size = dimensions
		await frame()
		check(ui.canvas.size.x >= 300, "canvas usable " + str(dimensions))
		check(ui.right_panel.get_global_rect().end.x <= dimensions.x + 1, "inspector inside window " + str(dimensions))
		await capture("static-" + str(dimensions.x))
	if DisplayServer.get_name() != "headless" and FileAccess.file_exists(user_draft):
		var legacy := Legacy.new(); legacy.load_project(user_draft)
		var catalog: Dictionary = legacy.composed()
		var comparison := Node2D.new(); get_parent().add_child(comparison); ui.hide()
		comparison.draw.connect(func():
			comparison.draw_rect(Rect2(0, 0, 1180, 740), Color("202226"))
			Actor.draw_actor(comparison, Vector2(295, 580), 4, "mail", "sword", false, false, 0, "hit", catalog)
			Visuals.draw(comparison, ui.doc.data, ui.doc.data.editor.scene, Vector2(885, 580), 4, ui.doc.base_dir)
			comparison.draw_string(ThemeDB.fallback_font, Vector2(190, 40), "LEGACY", HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
			comparison.draw_string(ThemeDB.fallback_font, Vector2(760, 40), "ASSET WORKBENCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 18))
		comparison.queue_redraw(); await frame(); await capture("migration-comparison")
		var image := get_viewport().get_texture().get_image()
		var changed := 0; var occupied := 0
		for y in range(60, 640):
			for x in range(50, 590):
				var left := image.get_pixel(x, y); var right := image.get_pixel(x + 590, y)
				if absf(left.r - 0.125) + absf(left.g - 0.133) + absf(left.b - 0.149) > 0.04 or absf(right.r - 0.125) + absf(right.g - 0.133) + absf(right.b - 0.149) > 0.04:
					occupied += 1
					if absf(left.r - right.r) + absf(left.g - right.g) + absf(left.b - right.b) > 0.3: changed += 1
		var ratio := float(changed) / maxi(1, occupied)
		check(ratio < 0.03, "legacy visual parity (<3%% changed occupied pixels): %.5f" % ratio)
		comparison.queue_free(); ui.show(); await frame()
	var placement_before: Dictionary = ui.doc.data.duplicate(true)
	await click_control(find_button(ui, "人物整体 · 棋格内摆放"))
	check(ui.placement_selected and ui.selected.is_empty(), "select assembly placement")
	ui.change_placement(1, 8)
	check(ui.doc.data.assets == placement_before.assets and ui.doc.data.actions == placement_before.actions, "placement preserves anchors and animation")
	ui.canvas.original = ui.doc.data.duplicate(true); ui.canvas.start = Vector2(100, 100); ui.canvas.current = Vector2(100, 102); ui.canvas.transform_drag()
	check(is_equal_approx(Visuals.placement(ui.doc.data).y, 8 + 2 / ui.canvas.zoom), "assembly drag accumulates frame delta")
	ui.canvas.dragging = true; ui.canvas.cancel_drag()
	check(Visuals.placement(ui.doc.data) == Vector2(0, 8), "cancel assembly drag")
	await capture("placement-1180")
	ui.doc.undo(); check(ui.doc.data == placement_before, "assembly numeric undo")
	ui.doc.data.assets.head.rotation = 90
	ui.select(["head", "hair", "sword"])
	var child_before := Visuals.world_transform(ui.doc.data, "hair").origin
	var weapon_before := Visuals.world_transform(ui.doc.data, "sword").origin
	ui.change_numeric("position", 1, 6, 0)
	check(Visuals.world_transform(ui.doc.data, "hair").origin.is_equal_approx(child_before + Vector2(0, 6)), "inspector parent child moves once")
	check(Visuals.world_transform(ui.doc.data, "sword").origin.is_equal_approx(weapon_before + Vector2(0, 6)), "inspector cross parent world delta")
	ui.doc.data = placement_before.duplicate(true)
	ui.doc.data.editor.scene = ["skin", "blood", "mail"]
	ui.select_assembly()
	check("skin" in ui.selected and "blood" in ui.selected, "select assembly includes occluded members")
	ui.canvas.start = ui.canvas.origin() + Vector2(-120, -150) * ui.canvas.zoom
	ui.canvas.current = ui.canvas.origin() + Vector2(120, 80) * ui.canvas.zoom
	ui.through_box = true; ui.canvas.finish_box()
	check("skin" in ui.selected, "through box includes occluded skin")
	ui.through_box = false; ui.doc.data = placement_before; ui.refresh()
	ui.doc.checkpoint(); ui.doc.data.editor.hidden.append("sword"); ui.refresh()
	check("sword" not in ui.canvas.ids(), "eye hides editor only")
	check(not ui.doc.runtime_data().has("editor"), "editor state excluded from runtime")
	ui.doc.undo(); ui.refresh()
	ui.select(["sword"])
	var before: Dictionary = ui.doc.data.duplicate(true)
	ui.canvas.original = before; ui.canvas.center = ui.canvas.selection_center(); ui.canvas.start = Vector2(100, 100); ui.canvas.current = Vector2(108, 100); ui.canvas.mode = "move"
	ui.canvas.transform_drag()
	check(is_equal_approx(float(ui.doc.asset("sword").position[0]), float(before.assets.sword.position[0]) + 8 / ui.canvas.zoom), "canvas world drag")
	ui.canvas.dragging = true; ui.canvas.cancel_drag()
	check(ui.doc.data == before, "escape restores entire drag")
	ui.animation_mode = true; ui.timeline_panel.show(); ui.action_id = "sword"; ui.time = 0.12
	ui.put_key("head", "rotation", 7.0)
	check(is_equal_approx(float(Visuals.sample(ui.current_action(), "head", 0.12).rotation), 7), "generic head keyframe sampled")
	ui.put_key("head", "visible", false)
	check(not Visuals.sample(ui.current_action(), "head", 0.12).visible, "visibility step sampled")
	ui.select(["sword", "head"]); ui.refresh(); await frame(); await capture("timeline-1180")
	check(ui.right_panel.get_global_rect().end.x <= get_window().size.x + 1, "timeline fits small window")
	ui.doc.undo(); ui.doc.undo(); ui.animation_mode = false; ui.timeline_panel.hide()
	ui.doc.base_dir = output
	var image_path := output.path_join("fixture.png")
	var img := Image.create(64, 32, false, Image.FORMAT_RGBA8); img.fill(Color.TRANSPARENT)
	img.fill_rect(Rect2i(4, 4, 24, 24), Color("db9a63")); img.fill_rect(Rect2i(36, 4, 24, 24), Color("80acd4")); img.save_png(image_path)
	ui.files_dropped(PackedStringArray([image_path])); await frame()
	check(is_instance_valid(ui.import_dialog) and ui.import_dialog.visible, "file drop opens atlas import")
	ui.import_regions = [[0, 0, 32, 32], [32, 0, 32, 32]]; ui.import_id.text = "qa_atlas"; ui.import_name.text = "图集测试"; ui.import_category.text = "新增物件"
	await capture("atlas-import")
	ui.import_dialog.confirmed.emit(); await frame()
	check(ui.doc.data.assets.has("qa_atlas_01") and ui.doc.data.assets.has("qa_atlas_02"), "multi-region atlas registered")
	check(ui.library.item_count == ui.doc.data.assets.size(), "import discovered in library")
	ui.doc.undo(); check(not ui.doc.data.assets.has("qa_atlas_01") and not ui.doc.data.assets.has("qa_atlas_02"), "atlas import single undo")
	ui.doc.redo(); check(ui.doc.data.assets.has("qa_atlas_02"), "atlas redo")
	check(ui.doc.import_png(image_path, "qa_weapon", "独立武器", "新增装备").is_empty(), "single PNG import")
	check("qa_weapon" not in ui.doc.data.editor.scene, "new asset not auto equipped or previewed")
	ui.doc.set_value("qa_weapon", "position", [0, -15], "small")
	ui.doc.set_value("qa_weapon", "position", [0, -30], "large")
	check(ui.doc.asset("qa_weapon", "small").position != ui.doc.asset("qa_weapon", "large").position, "two adaptation profiles")
	ui.doc.data.editor.locked = ["qa_weapon"]
	ui.doc.data.game.placement = [0, 6]
	var save_path := output.path_join("session-" + str(Time.get_ticks_usec()) + ".json")
	check(ui.doc.save_project(save_path).is_empty(), "save new project")
	var loaded := Document.new(); check(loaded.load_project(save_path).is_empty(), "reopen project")
	check(loaded.data.editor.locked == ["qa_weapon"], "lock persists")
	check(Visuals.placement(loaded.data) == Vector2(0, 6), "placement survives save reopen")
	check(Visuals.vector(loaded.asset("qa_weapon", "large").position).is_equal_approx(Vector2(0, -30)), "adaptation persists")
	check(loaded.apply().is_empty(), "apply complete version")
	var first_revision := loaded.expected_revision
	check(Visuals.placement(Document.read_json(Document.runtime_dir().path_join(first_revision + ".json"))) == Vector2(0, 6), "applied resource contains placement")
	loaded.set_value("qa_weapon", "rotation", 45)
	check(loaded.apply().is_empty(), "apply second version")
	check(loaded.rollback().is_empty() and loaded.expected_revision == first_revision, "rollback previous version")
	var stale := Document.new(); stale.expected_revision = "stale"
	check(not stale.apply().is_empty(), "stale application rejected")
	loaded.data.assets.qa_weapon.image = "missing.png"
	check(not loaded.apply().is_empty() and Document.revision() == first_revision, "missing image preserves active version")
	var error_count := checks.filter(func(item): return not item.ok).size()
	Document.atomic_json(output.path_join("report.json"), {"checks": checks, "failures": error_count, "exported": not OS.has_feature("editor"), "display": DisplayServer.get_name()})
	print(JSON.stringify({"asset_ui_checks": checks.size(), "failures": error_count, "output": output}))
	get_tree().quit(0 if error_count == 0 else 1)
