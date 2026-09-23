extends SceneTree
const Document = preload("res://presentation/asset_document.gd")
const Feedback = preload("res://presentation/weapon_feedback.gd")
const Appearance = preload("res://core/appearance_rules.gd")
const Runtime = preload("res://presentation/asset_runtime.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var input := Document.project_root().path_join("art/workbench/projects/foundation.asset.json")
	var output := Document.project_root().path_join("art/workbench/projects/foundation-ready.asset.json")
	for arg: String in args:
		if arg.begins_with("--input="): input = arg.trim_prefix("--input=")
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	var doc := Document.new()
	var error := doc.load_project(input)
	if not error.is_empty(): printerr(error); quit(1); return
	var pending: Array[String] = []
	for slot: String in ["body", "face", "hair", "beard", "linen", "padded", "outer", "shield", "sword", "axe", "spear", "bow", "scar", "bandage", "blood"]:
		for index in range(1, 5):
			if not doc.data.assets.has("%s_%02d" % [slot, index]):
				pending.append("%s_%02d" % [slot, index])
	if not pending.is_empty():
		printerr("基础库尚缺 %s；未发布。" % ", ".join(pending)); quit(1); return
	doc.data.game.foundation = {"complete": pending.is_empty(), "ready": 60 - pending.size(), "pending": pending}
	for weapon_id: String in Appearance.WEAPON_ASSETS:
		var slot: String = Runtime.WEAPONS[weapon_id]
		for kind: String in (["attack", "shield_bash"] if weapon_id in ["weapon_guard_sword", "weapon_guard_cleaver"] else ["attack"]):
			var id := kind + "_" + weapon_id
			if not doc.data.actions.has(id):
				doc.data.actions[id] = Feedback.authored_action(doc.data.actions.get(slot, {}), weapon_id, kind)
				# Workbench timelines address the actual new weapon, not the old
				# sword placeholder. Runtime remaps this ID into its selected slot.
				for track: Dictionary in doc.data.actions[id].tracks:
					if str(track.target) == slot: track.target = Appearance.WEAPON_ASSETS[weapon_id]
	if not doc.data.actions.has("defend_shield"):
		doc.data.actions.defend_shield = Feedback.defend_action()
	if not doc.data.game.has("terminal"):
		doc.data.game.terminal = {"incapacitated": {"rotation": 72, "offset": [-15, -3], "scale": [0.8, 0.55]}, "dead": {"rotation": 86, "offset": [-15, -3], "scale": [0.8, 0.55]}}
	var terminal_dir := Document.project_root().path_join("art/production/terminal-20260923")
	var terminal := Document.read_json(terminal_dir.path_join("assets.fragment.json"))
	for id: String in ["state_down", "state_dead"]:
		if not doc.data.assets.has(id) and terminal.has(id):
			var definition: Dictionary = terminal[id].duplicate(true)
			definition.image = terminal_dir.path_join(id + ".png")
			doc.data.assets[id] = definition
	var errors := doc.validate()
	if not errors.is_empty(): printerr(JSON.stringify(errors)); quit(1); return
	# Separate ready project keeps the user's original and the production draft intact.
	error = doc.save_project(output)
	if not error.is_empty(): printerr(error); quit(1); return
	var diff := doc.differences()
	Document.atomic_json(output.get_base_dir().path_join("foundation-publish-diff.json"), {"changes": diff, "input": input, "output": output})
	if args.has("--apply"):
		error = doc.apply()
		if not error.is_empty(): printerr(error); quit(1); return
	print(JSON.stringify({"ok": true, "project": output, "applied": args.has("--apply"), "changes": diff.size()}))
	quit(0)
