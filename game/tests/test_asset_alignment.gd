extends SceneTree
const Document = preload("res://presentation/asset_document.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Workbench = preload("res://presentation/asset_workbench.gd")
var checks := 0
var failures := []

func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok: failures.append(description); push_error(description)

func _initialize() -> void:
	call_deferred("run")

func quad(data: Dictionary, id: String, adaptation: String = "") -> PackedVector2Array:
	return Visuals.quad(Visuals.resolve(data, id, adaptation), Visuals.world_transform(data, id, adaptation))

func center(points: PackedVector2Array) -> Vector2:
	return (points[0] + points[2]) * 0.5

func same_quad(first: PackedVector2Array, second: PackedVector2Array) -> bool:
	for i in range(4):
		if not first[i].is_equal_approx(second[i]): return false
	return true

func run() -> void:
	var doc := Document.new()
	var face: Dictionary = doc.data.assets.face.duplicate(true)
	face.id = "face_01"; face.position = [15.0, -15.0]; face.size = [45.0, 20.0]; face.pivot = [0.2, 0.8]; face.rotation = 30.0
	doc.data.assets.face_01 = face
	var hair: Dictionary = doc.data.assets.hair.duplicate(true)
	hair.id = "hair_01"; hair.parent = "face_01"; hair.position = [8.0, 4.0]; hair.rotation = -20.0
	doc.data.assets.hair_01 = hair
	var sword: Dictionary = doc.data.assets.sword.duplicate(true)
	sword.id = "sword_01"; doc.data.assets.sword_01 = sword
	var greatsword: Dictionary = sword.duplicate(true)
	greatsword.id = "sword_2h_01"; greatsword.slot = "sword_2h"; doc.data.assets.sword_2h_01 = greatsword
	var helm: Dictionary = face.duplicate(true)
	helm.id = "helm_outer_01"; helm.slot = "helmet_layer2"; doc.data.assets.helm_outer_01 = helm
	var helm_second: Dictionary = helm.duplicate(true)
	helm_second.id = "helm_outer_02"; doc.data.assets.helm_outer_02 = helm_second
	check(doc.validate({}, false).is_empty(), "alignment fixture valid")
	check(Document.functional_slot("sword_2h_02", sword) == "sword_2h", "two-handed ID does not fall into old sword slot")
	check(Document.functional_slot("sword_01", sword) == "sword", "legacy swords retain their slot")
	check(Document.functional_slot("helm_outer_01", helm) == "helmet_layer2", "explicit helmet layer classification")
	var foundation := Document.new()
	check(foundation.load_project(Document.project_root().path_join("art/workbench/projects/foundation-ready.asset.json")).is_empty(), "load real foundation classifications")
	for pair in [["skin", "body_01"], ["face", "face_01"], ["hair", "hair_01"], ["beard", "beard_01"], ["padded", "padded_01"], ["mail", "outer_01"], ["sword", "sword_01"]]:
		check(Document.functional_slot(pair[0], foundation.data.assets[pair[0]]) == Document.functional_slot(pair[1], foundation.data.assets[pair[1]]), "real foundation concrete type " + pair[0])
	check(Document.functional_slot("padded_01", foundation.data.assets.padded_01) != Document.functional_slot("outer_01", foundation.data.assets.outer_01), "foundation armor layers stay separate")
	var armor_candidates := foundation.alignment_candidates({"outer": "mail"})
	check(armor_candidates.rows.size() == 4 and armor_candidates.rows.any(func(item): return item.id == "outer_03"), "hardened leather is a selectable outer armor target")
	var armor_plan := foundation.alignment_plan({"outer_03": "mail"}, "fit")
	check(armor_plan.errors.is_empty() and armor_plan.changes.is_empty(), "existing hardened leather already has the source display box")
	var armor_adjusted := foundation.alignment_adjust(armor_plan, "outer_03", Vector2(6, -4), 1.2)
	var armor_before := quad(foundation.data, "outer_03")
	var armor_after := quad(armor_adjusted.trial, "outer_03")
	check(armor_adjusted.errors.is_empty() and armor_adjusted.changes.size() == 1, "preview adjustment creates a real armor draft change")
	check(center(armor_after).is_equal_approx(center(armor_before) + Vector2(6, -4)), "preview move uses world box coordinates")
	check(is_equal_approx((armor_after[1] - armor_after[0]).length() / (armor_before[1] - armor_before[0]).length(), 1.2), "preview resize preserves proportional size")
	check(armor_adjusted.trial.assets.outer_03.rect == foundation.data.assets.outer_03.rect and armor_adjusted.trial.assets.mail == foundation.data.assets.mail, "manual preview leaves crop and source untouched")
	var armor_reverted := foundation.alignment_adjust(armor_plan, "outer_03", Vector2.ZERO, 1.0)
	check(armor_reverted.changes.is_empty(), "resetting manual preview returns to unchanged draft")
	var armor_draft := Document.new(); armor_draft.data = foundation.data.duplicate(true)
	var armor_commit := armor_draft.alignment_adjust(armor_draft.alignment_plan({"outer_03": "mail"}, "fit"), "outer_03", Vector2(6, -4), 1.2)
	check(armor_draft.apply_alignment(armor_commit).is_empty() and same_quad(quad(armor_draft.data, "outer_03"), armor_after), "manual preview commits its exact displayed box")
	armor_draft.undo()
	check(same_quad(quad(armor_draft.data, "outer_03"), armor_before), "one undo restores manual preview adjustment")
	var sword_candidates := doc.alignment_candidates({"sword": "sword"})
	check(sword_candidates.rows.any(func(item): return item.id == "sword_01"), "single source finds same concrete type")
	check(not sword_candidates.rows.any(func(item): return item.id == "sword_2h_01"), "single source excludes two-handed sword")
	var helm_candidates := doc.alignment_candidates({"helmet_layer2": "helm_outer_01"})
	check(helm_candidates.rows.size() == 1 and helm_candidates.rows[0].id == "helm_outer_02", "second helmet layer matches itself")
	doc.data.editor.groups = {"needs-shaping": ["face_01"]}
	doc.set_review("face_01", "flagged", true)
	check(doc.alignment_candidates({"face": "face"}, "flagged").rows.size() == 1, "flagged filter finds candidate")
	check(doc.alignment_candidates({"face": "face"}, "flagged", true).rows.is_empty(), "ungrouped intersects review filter")
	doc.data.editor.groups.clear()
	doc.data.editor.locked.append("sword_01")
	var locked := doc.alignment_candidates({"sword": "sword"})
	check(locked.rows.is_empty() and locked.skipped.size() == 1, "locked target skipped with reason")
	doc.data.editor.locked.clear()
	var original := doc.data.duplicate(true)
	var position := doc.alignment_plan({"face_01": "face"}, "position")
	check(position.errors.is_empty() and position.changes.size() == 1, "position plan changes target")
	check(center(quad(position.trial, "face_01")).is_equal_approx(center(quad(original, "face"))), "position mode matches box centers")
	check(position.trial.assets.face_01.size == original.assets.face_01.size and position.trial.assets.face_01.rotation == original.assets.face_01.rotation, "position mode preserves size and angle")
	var fit := doc.alignment_plan({"face_01": "face"}, "fit")
	var source_quad := quad(original, "face")
	var fit_quad := quad(fit.trial, "face_01")
	check(center(fit_quad).is_equal_approx(center(source_quad)), "fit mode centers on source")
	check((fit_quad[1] - fit_quad[0]).length() <= (source_quad[1] - source_quad[0]).length() + 0.01 and (fit_quad[3] - fit_quad[0]).length() <= (source_quad[3] - source_quad[0]).length() + 0.01, "fit mode stays inside source box")
	var old_ratio := (quad(original, "face_01")[1] - quad(original, "face_01")[0]).length() / (quad(original, "face_01")[3] - quad(original, "face_01")[0]).length()
	var fit_ratio := (fit_quad[1] - fit_quad[0]).length() / (fit_quad[3] - fit_quad[0]).length()
	check(is_equal_approx(old_ratio, fit_ratio), "fit mode preserves target proportions")
	var exact := doc.alignment_plan({"hair_01": "hair", "face_01": "face"}, "exact")
	check(exact.errors.is_empty() and exact.changes.size() == 2, "combined parent-child plan valid")
	check(exact.warnings.any(func(item): return item.id == "face_01"), "exact box warns when native aspect ratios differ")
	check(same_quad(quad(exact.trial, "face_01"), quad(original, "face")), "exact mode matches source face box with different pivot")
	check(same_quad(quad(exact.trial, "hair_01"), quad(original, "hair")), "child aligns after parent in combined plan")
	check(exact.trial.assets.hair_01.parent == "face_01" and exact.trial.assets.hair_01.clip_to == original.assets.hair_01.clip_to, "alignment preserves attachment and clipping")
	check(exact.trial.editor == original.editor and exact.trial.actions == original.actions, "alignment leaves review and actions alone")
	check(doc.apply_alignment(exact).is_empty(), "apply alignment to draft")
	check(same_quad(quad(doc.data, "face_01"), quad(original, "face")), "applied face matches preview")
	doc.undo()
	check(doc.data.assets.face_01 == original.assets.face_01 and doc.data.assets.hair_01 == original.assets.hair_01, "one undo restores entire batch")
	doc.redo()
	check(same_quad(quad(doc.data, "hair_01"), quad(original, "hair")), "one redo restores alignment")
	var saved_path := Document.project_root().path_join("builds/asset-workbench/alignment-" + str(Time.get_ticks_usec()) + ".asset.json")
	check(doc.save_project(saved_path).is_empty(), "save aligned draft separately")
	var reopened := Document.new()
	check(reopened.load_project(saved_path).is_empty() and same_quad(quad(reopened.data, "face_01"), quad(original, "face")), "aligned boxes survive draft reload")
	var stale := doc.alignment_plan({"face_01": "face"}, "position")
	doc.set_value("face", "position", [1, -35])
	check(not doc.apply_alignment(stale).is_empty(), "stale preview cannot overwrite new edits")
	var adapted := Document.new()
	adapted.data.assets.face_01 = face.duplicate(true)
	adapted.data.adaptations.small = {"face": {"position": [4, -40]}}
	var adapted_base: Dictionary = adapted.data.assets.face_01.duplicate(true)
	var adaptation_plan := adapted.alignment_plan({"face_01": "face"}, "exact", "small")
	check(adaptation_plan.errors.is_empty() and adaptation_plan.changes.size() == 1, "named adaptation plan valid")
	var manual_adaptation := adapted.alignment_adjust(adaptation_plan, "face_01", Vector2(3, -2), 1.1, "small")
	check(manual_adaptation.errors.is_empty() and manual_adaptation.trial.assets.face_01 == adapted_base and manual_adaptation.trial.adaptations.small.has("face_01"), "manual preview writes only named adaptation override")
	check(adapted.apply_alignment(adaptation_plan).is_empty(), "named adaptation applies")
	check(adapted.data.assets.face_01 == adapted_base and adapted.data.adaptations.small.has("face_01"), "adaptation alignment does not rewrite base values")
	var ui := Workbench.new(); ui.doc = doc; root.add_child(ui)
	await process_frame
	ui.open_alignment_dialog()
	check(ui.alignment_dialog != null and ui.alignment_tree != null and ui.alignment_preview != null, "quick alignment dialog opens")
	check(ui.alignment_source_mode.selected == 0 and ui.alignment_rows.size() > 0, "selected single source lists same type targets")
	ui.alignment_dialog.hide(); ui.queue_free()
	await process_frame
	var armor_ui := Workbench.new(); armor_ui.doc = foundation; root.add_child(armor_ui)
	await process_frame
	armor_ui.select(["mail"]); armor_ui.open_alignment_dialog()
	check(armor_ui.alignment_rows.has("outer_03") and armor_ui.alignment_rows.size() == 4, "outer armor dialog lists hardened leather and peers")
	check(armor_ui.alignment_dialog.get_ok_button().disabled and armor_ui.alignment_summary.text.contains("蓝框参数已与来源一致"), "disabled button explains unchanged armor geometry")
	armor_ui.alignment_rows.outer_03.select(0); armor_ui._alignment_check_highlighted()
	check(armor_ui.alignment_preview.editable and armor_ui.alignment_dialog.get_ok_button().disabled, "one selected armor target enables preview editing")
	armor_ui._alignment_manual_begin(); armor_ui._alignment_manual_changed(Vector2(6, -4), 1.0)
	check(armor_ui.alignment_plan_data.changes.size() == 1 and not armor_ui.alignment_dialog.get_ok_button().disabled, "manual preview movement enables apply")
	armor_ui._alignment_clear_manual(); armor_ui._alignment_update_plan()
	check(armor_ui.alignment_plan_data.changes.is_empty() and armor_ui.alignment_dialog.get_ok_button().disabled, "reset preview restores no-change state")
	armor_ui.alignment_dialog.hide(); armor_ui.queue_free()
	print(JSON.stringify({"checks": checks, "failures": failures}))
	quit(0 if failures.is_empty() else 1)
