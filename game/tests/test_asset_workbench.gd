extends SceneTree
const Document = preload("res://presentation/asset_document.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Legacy = preload("res://presentation/paperdoll_document.gd")
const Runtime = preload("res://presentation/asset_runtime.gd")
var count := 0
var failures := []
func check(value: bool, label: String) -> void:
	count += 1
	if not value: failures.append(label); push_error(label)
func _initialize() -> void:
	test_placement()
	var doc := Document.new()
	check(doc.validate().is_empty(), "default validates: " + str(doc.validate()))
	check(doc.data.assets.size() > 15, "dynamic asset registry")
	var before := doc.data.duplicate(true)
	doc.set_value("head", "rotation", 90)
	before = doc.data.duplicate(true)
	var hair := Visuals.world_transform(before, "hair").origin
	var sword := Visuals.world_transform(before, "sword").origin
	doc.move_selection(["hair", "sword"], Vector2(4, 0), before)
	check(Visuals.world_transform(doc.data, "hair").origin.is_equal_approx(hair + Vector2(4, 0)), "rotated parent child world move")
	check(Visuals.world_transform(doc.data, "sword").origin.is_equal_approx(sword + Vector2(4, 0)), "mixed selection independent space")
	before = doc.data.duplicate(true)
	hair = Visuals.world_transform(before, "hair").origin
	doc.move_selection(["head", "hair"], Vector2(2, 0), before)
	check(Visuals.world_transform(doc.data, "hair").origin.is_equal_approx(hair + Vector2(2, 0)), "parent child moves once")
	before = doc.data.duplicate(true)
	sword = Visuals.world_transform(before, "sword").origin
	for i in range(20): doc.move_selection(["sword"], Vector2((i + 1) * 0.1, 0), before)
	check(Visuals.world_transform(doc.data, "sword").origin.is_equal_approx(sword + Vector2(2, 0)), "subpixel motion accumulated")
	doc.checkpoint(); doc.set_value("sword", "rotation", 72); doc.undo()
	check(doc.asset("sword").rotation != 72, "undo")
	doc.redo(); check(doc.asset("sword").rotation == 72, "redo")
	doc.set_value("sword", "rotation", 12, "small")
	doc.set_value("sword", "rotation", 34, "large")
	check(doc.asset("sword", "small").rotation == 12 and doc.asset("sword", "large").rotation == 34 and doc.asset("sword").rotation == 72, "adaptation isolation")
	check(not doc.runtime_data().has("editor"), "runtime excludes editor")
	var action: Dictionary = doc.data.actions.sword.duplicate(true)
	action.tracks[0].keys.reverse()
	doc.data.actions.bad = action
	check(not doc.validate().is_empty(), "reject reversed keyframes")
	doc.data.actions.erase("bad")
	action = doc.data.actions.sword.duplicate(true); action.tracks[0].keys[0].erase("id")
	doc.data.actions.bad = action
	check(not doc.validate().is_empty(), "reject missing keyframe ID")
	doc.data.actions.erase("bad")
	check(not Visuals.diagnostics(doc.data, ["hair"]).is_empty(), "missing attachment context diagnosed")
	check(Visuals.diagnostics(doc.data, ["hair"], "", {}, true).is_empty(), "independent root drawing allowed")
	check(Visuals.hits(doc.data, ["mail"], Vector2(0, 20), doc.base_dir).is_empty(), "clipped area not selectable")
	var snapshot := doc.data.duplicate(true)
	check(not doc.transact([{"id": "sword", "field": "scale", "value": [0, 1]}]).is_empty(), "invalid transaction rejected")
	check(doc.data == snapshot, "transaction atomic")
	var output := Document.project_root().path_join("builds/asset-workbench/unit")
	DirAccess.make_dir_recursive_absolute(output)
	doc.base_dir = output
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8); img.fill(Color.TRANSPARENT); img.fill_rect(Rect2i(8, 8, 16, 16), Color.WHITE)
	var png := output.path_join("alpha.png"); img.save_png(png)
	check(doc.import_png(png, "test.object", "物件", "场景").is_empty(), "import independent object")
	check(not doc.import_png(png, "test.object", "重复", "场景").is_empty(), "duplicate ID rejected")
	check(not doc.import_png(png, "test.invalid", "越界", "场景", [0, 0, 100, 100]).is_empty(), "out of bounds region rejected")
	doc.data.assets["test.object"].position = [0, 0]
	check(Visuals.hits(doc.data, ["test.object"], Vector2(-15, -15), doc.base_dir).is_empty(), "transparent source pixel not hit")
	check(Visuals.hits(doc.data, ["test.object"], Vector2.ZERO, doc.base_dir) == ["test.object"], "opaque source pixel hit")
	doc.import_png(png, "test.front", "前景", "场景")
	doc.data.assets["test.front"].position = [0, 0]; doc.data.assets["test.front"].layer = 200
	check(Visuals.hits(doc.data, ["test.object", "test.front"], Vector2.ZERO, doc.base_dir)[0] == "test.front", "frontmost overlapping selection")
	doc.data.masks.rectangle = {"type": "rect", "rect": [0, 0, 8, 8]}; doc.data.assets["test.object"].masks = ["rectangle"]
	check(Visuals.hits(doc.data, ["test.object"], Vector2(-2, -2), doc.base_dir).is_empty(), "rect mask shared with picking")
	check(not Visuals.hits(doc.data, ["test.object"], Vector2(2, 2), doc.base_dir).is_empty(), "rect mask inside hit")
	var invalid := doc.data.duplicate(true); invalid.assets.head.parent = "hair"
	check(not doc.validate(invalid, false).is_empty(), "parent cycle rejected")
	invalid = doc.data.duplicate(true); invalid.assets.head.clip_to = "scar"; invalid.assets.scar.clip_to = "head"
	check(not doc.validate(invalid, false).is_empty(), "mask cycle rejected")
	invalid = doc.data.duplicate(true); invalid.assets.hair.anchor = "missing"
	check(not doc.validate(invalid, false).is_empty(), "missing named anchor rejected")
	invalid = doc.data.duplicate(true); invalid.assets.head.image = false
	check(not doc.validate(invalid, false).is_empty(), "wrong data type rejected without crash")
	invalid = doc.data.duplicate(true); invalid.masks.rectangle.rect[2] = -2
	check(not doc.validate(invalid, false).is_empty(), "invalid mask dimensions rejected")
	var old := Legacy.new()
	var old_action: Dictionary = old.action_for("sword"); old_action.keyframes.reverse(); old_action.keyframes[0].erase("id"); old.actions.sword = old_action
	var migrated := Document.new(); migrated.from_legacy(old)
	check(migrated.validate().is_empty(), "legacy action normalized into valid tracks")
	check(migrated.data.actions.sword.tracks[0].keys[0].time == 0, "legacy action sorted before use")
	var standalone := Visuals.regions(migrated.data, "scar", "", {}, 0, migrated.base_dir, {}, true)
	check(not standalone.is_empty(), "independent scar retains rebased clipping")
	var action2 := {"duration": 1, "tracks": [{"target": "head", "property": "x", "keys": [{"id": "a", "time": 0, "value": 0, "interpolation": "linear"}, {"id": "b", "time": 1, "value": 10}]}]}
	check(is_equal_approx(Visuals.sample(action2, "head", 0.5).x, 5), "linear interpolation")
	action2.tracks[0].keys[0].interpolation = "hold"
	check(is_equal_approx(Visuals.sample(action2, "head", 0.5).x, 0), "hold interpolation")
	action2.tracks[0].keys[0].interpolation = "smooth"
	check(Visuals.sample(action2, "head", 0.25).x < 2.5, "smooth interpolation")
	var unit := {"visual_assets": ["test.object"]}
	check(Runtime.selection(doc.runtime_data(), unit) == ["test.object"], "game independently chooses one object")
	check("test.object" not in Runtime.selection(doc.runtime_data(), {}), "new registry entries never auto equip")
	var file := output.path_join("draft-" + str(Time.get_ticks_usec()) + ".json")
	check(doc.save_project(file).is_empty(), "portable draft save")
	var writer := FileAccess.open(file, FileAccess.WRITE); writer.store_string("{}"); writer.close()
	check(not doc.save_project(file).is_empty(), "external draft overwrite rejected")
	print(JSON.stringify({"checks": count, "failures": failures}))
	quit(0 if failures.is_empty() else 1)

func test_placement() -> void:
	var doc := Document.new()
	var initial := doc.data.duplicate(true)
	doc.checkpoint("placement")
	doc.data.game.placement = [7, 8]
	var delta := Vector2(7, 8)
	for id: String in doc.data.assets:
		for time in [0.0, 0.4, 0.9]:
			var action: Dictionary = doc.data.actions.bow
			var before := Visuals.world_transform(initial, id, "", action, time)
			var after := Visuals.world_transform(doc.data, id, "", action, time)
			check(after.origin.is_equal_approx(before.origin + delta) and after.x.is_equal_approx(before.x), "placed animated transform " + id + str(time))
	for time in [0.0, 0.7, 1.0, 1.3]:
		var a := Runtime.arrow_pose(initial, "", initial.actions.bow, time)
		var b := Runtime.arrow_pose(doc.data, "", doc.data.actions.bow, time)
		check(a.position.is_equal_approx(b.position) and is_equal_approx(a.angle, b.angle), "arrow local trajectory unchanged " + str(time))
	check(doc.data.assets == initial.assets and doc.data.actions == initial.actions, "placement preserves calibration anchors keys events")
	var owner := Visuals.world_transform(doc.data, "head")
	var explicit := Visuals.world_transform(doc.data, "hair", "", {}, 0, {"head:origin": owner})
	check(explicit.is_equal_approx(Visuals.world_transform(doc.data, "hair")), "explicit world anchor not shifted twice")
	check(Visuals.world_transform(doc.data, "hair", "", {}, 0, {}, true).origin.is_equal_approx(Visuals.world_transform(initial, "hair", "", {}, 0, {}, true).origin + delta), "independent root receives placement once")
	var polygons := Visuals.regions(initial, "skin", "", {}, 0, doc.base_dir)
	var shifted := Visuals.regions(doc.data, "skin", "", {}, 0, doc.base_dir)
	var equal := polygons.size() == shifted.size()
	for i in range(polygons.size()):
		equal = equal and polygons[i].size() == shifted[i].size()
		for j in range(polygons[i].size()): equal = equal and shifted[i][j].is_equal_approx(polygons[i][j] + delta)
	check(equal, "shared crop translates with geometry")
	var mask := {"type": "rect", "rect": [0, 0, 10, 10], "follow": "grid"}
	check(Visuals.mask_world_polygon(doc.data, mask) == Visuals.mask_polygon(mask), "fixed grid mask stays fixed")
	mask.follow = "head"
	check(Visuals.mask_world_polygon(doc.data, mask) == owner * Visuals.mask_polygon(mask), "asset mask follows animated anchor frame")
	var point := Visuals.world_transform(initial, "sword").origin
	var hits := Visuals.hits(initial, ["sword"], point, doc.base_dir)
	check(Visuals.hits(doc.data, ["sword"], point + delta, doc.base_dir) == hits, "hit cache invalidated on placement")
	check(doc.runtime_data().game.placement == [7, 8], "placement published to runtime")
	doc.undo(); check(Visuals.placement(doc.data) == Vector2.ZERO, "placement undo")
	doc.redo(); check(Visuals.placement(doc.data) == delta, "placement redo")
	doc.data.game.placement = [0]; check(not doc.validate().is_empty(), "invalid placement rejected")
