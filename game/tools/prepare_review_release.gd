extends SceneTree
const Document = preload("res://presentation/asset_document.gd")
func _initialize() -> void:
	var root := Document.project_root()
	var doc := Document.new()
	var error := doc.load_project(root.path_join("art/workbench/projects/foundation-ready.asset.json"))
	if not error.is_empty(): printerr(error); quit(1); return
	var changed: Array[String] = []
	# A separate copy preserves all user assembly values and the previous project.
	# Correct only the clearly left-facing cutting edges / shield perspective.
	for id: String in ["axe_01", "axe_02", "axe_03", "shield_02", "shield_03"]:
		var asset: Dictionary = doc.data.assets.get(id, {})
		if not asset.is_empty() and not asset.has("flip_h") and float(asset.scale[0]) > 0:
			asset.flip_h = true
			changed.append(id)
	var output := root.path_join("art/workbench/projects/foundation-review.asset.json")
	error = doc.save_project(output)
	if not error.is_empty(): printerr(error); quit(1); return
	Document.atomic_json(root.path_join("builds/asset-review/publish-diff.json"), {"changes": doc.differences(), "flipped": changed, "project": output})
	error = doc.apply()
	if not error.is_empty(): printerr(error); quit(1); return
	print(JSON.stringify({"project": output, "flipped": changed, "published": true}))
	quit(0)
