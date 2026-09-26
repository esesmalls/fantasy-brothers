extends SceneTree
const Document = preload("res://presentation/asset_document.gd")
const Workbench = preload("res://presentation/asset_workbench.gd")
var checks := 0
var failures := []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); push_error(description)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var file := Document.project_root().path_join("art/workbench/projects/foundation-ready.asset.json")
	var doc := Document.new()
	check(doc.load_project(file).is_empty(), "load foundation read only")
	check(doc.validate().is_empty(), "foundation valid")
	check(not doc.review_state("face_02").handled, "legacy asset starts unprocessed")
	check(Document.functional_slot("face_02", doc.data.assets.face_02) == "face", "face variants share functional slot")
	check(Document.functional_slot("hair_02", doc.data.assets.hair_02) != "face", "hair cannot replace face")
	check(Document.functional_slot("outer_03", doc.data.assets.outer_03) != "padded", "outer cannot replace padded")
	check(doc.set_review("face_02", "handled", true), "mark asset handled")
	check(doc.set_review("face_02", "flagged", true), "flag handled asset")
	check(doc.review_state("face_02").handled and doc.review_state("face_02").flagged, "handled and flagged coexist")
	doc.undo()
	check(not doc.review_state("face_02").flagged and doc.review_state("face_02").handled, "review undo")
	doc.redo()
	check(doc.review_state("face_02").flagged, "review redo")
	doc.data.editor.hidden.append("shield")
	doc.data.editor.groups = {"weapons": ["shield", "sword"]}
	var before := doc.data.duplicate(true)
	seed(742)
	randi()
	var queue := doc.replace_scene("pending", 71)
	var random_after := randi()
	seed(742)
	randi()
	check(random_after == randi(), "batch selection leaves global battle RNG alone")
	check(int(queue.changed) >= 10, "pending button replaces available reference assets")
	check(queue.mapping.get("face", "") == "face_02", "flagged handled asset has review priority")
	check(queue.mapping.get("shield", "") in doc.data.editor.hidden and "shield" not in doc.data.editor.hidden, "hidden state moves with reference slot")
	check(queue.mapping.get("shield", "") in doc.data.editor.groups.weapons and queue.mapping.get("sword", "") in doc.data.editor.groups.weapons, "editor groups follow replacements")
	check(doc.data.editor.scene.size() == before.editor.scene.size(), "batch keeps reference slot count")
	var unique := {}
	for id: String in doc.data.editor.scene: unique[id] = true
	check(unique.size() == doc.data.editor.scene.size(), "batch avoids duplicate assets")
	for old_id in queue.mapping:
		var next_id: String = queue.mapping[old_id]
		check(Document.functional_slot(old_id, doc.data.assets[old_id]) == Document.functional_slot(next_id, doc.data.assets[next_id]), "batch matches slot " + old_id)
	for id: String in doc.data.editor.scene:
		var a: Dictionary = doc.asset(id)
		if a.parent.is_empty(): continue
		var parent_slot := Document.functional_slot(a.parent, doc.data.assets[a.parent])
		if parent_slot in ["face", "skin"]:
			check(a.parent in doc.data.editor.scene, "selected child parent remains present " + id)
	check(doc.validate({}, false).is_empty(), "batch has no broken parent references")
	doc.undo()
	check(doc.data.editor.scene == before.editor.scene, "whole batch undoes once")
	doc.redo()
	check(doc.data.editor.scene != before.editor.scene, "whole batch redoes once")
	var round_one: Array = doc.data.editor.scene.duplicate()
	var shuffled := doc.replace_scene("random", 55)
	check(int(shuffled.changed) >= 10, "random button changes available slots")
	check(doc.data.editor.scene != round_one, "random changes composition")
	check(doc.validate({}, false).is_empty(), "random composition valid")
	var output := Document.project_root().path_join("builds/asset-workbench/review-" + str(Time.get_ticks_usec()) + ".asset.json")
	check(doc.save_project(output).is_empty(), "save review draft separately")
	var loaded := Document.new()
	check(loaded.load_project(output).is_empty(), "reload review draft")
	check(loaded.review_state("face_02").flagged, "review mark persists")
	check(loaded.data.editor.scene == doc.data.editor.scene, "batch composition persists")
	var ui := Workbench.new()
	check(is_equal_approx(Workbench.automatic_ui_scale(1.0, 192, 1080), 2.0), "192 DPI auto scales two times")
	check(is_equal_approx(Workbench.automatic_ui_scale(1.0, 96, 2160), 2.0), "4K fallback scales two times")
	check(is_equal_approx(Workbench.automatic_ui_scale(1.5, 0, 900), 1.5), "reported OS scale takes precedence")
	root.add_child(ui)
	await process_frame
	check(ui.review_filter.item_count == 5, "workbench has review categories")
	check(ui.left_scroll != null and ui.right_panel != null, "both side panels scroll")
	check(ui.review_label("face").contains("未处理"), "library labels unprocessed")
	ui.queue_free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
