extends SceneTree
const Runtime = preload("res://presentation/asset_runtime.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Appearance = preload("res://core/appearance_rules.gd")
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func _initialize() -> void:
	var library := Runtime.current()
	var pending: Array = library.get("game", {}).get("foundation", {}).get("pending", [])
	check(pending.is_empty(), "foundation has no pending originals")
	check(bool(library.get("game", {}).get("foundation", {}).get("complete", false)) == pending.is_empty(), "release completeness is truthful")
	for category: String in ["body", "face", "hair", "beard", "linen", "padded", "outer", "shield", "sword", "axe", "spear", "bow", "scar", "bandage", "blood"]:
		var hashes := {}
		for index in range(1, 5):
			var id := "%s_%02d" % [category, index]
			var definition: Dictionary = library.get("assets", {}).get(id, {})
			check(not definition.is_empty(), "released variant exists: " + id)
			if definition.is_empty(): continue
			var path := Visuals.source_path(definition, Runtime.cached_directory)
			var img := Image.load_from_file(path)
			check(img != null and img.detect_alpha() != Image.ALPHA_NONE, "transparent source imports: " + id)
			if img != null: hashes[FileAccess.get_sha256(path)] = true
		check(hashes.size() == 4, "four distinct images, not aliases: " + category)
	var campaign := Campaign.create_campaign("free", 6023)
	var faces := {}
	var battle := Battle.create_battle(campaign.roster, 6023)
	for unit: Dictionary in battle.units:
		if unit.kind == "dog": continue
		check(Runtime.supports(unit), "every human uses published rig: " + str(unit.id))
		var data := Runtime.data_for_unit(unit)
		check(Visuals.diagnostics(data, Runtime.selection(data, unit), "", {}, false).is_empty(), "composed equipment has valid parents: " + str(unit.id))
		if unit.team == "player": faces[str(data.assets.face.image)] = true
	check(faces.size() == 4, "starting company has four distinct faces")
	for weapon_id: String in Appearance.WEAPON_ASSETS:
		var unit: Dictionary = campaign.roster[0].duplicate(true)
		unit.visual_loadout.weapon = weapon_id
		var data := Runtime.data_for_unit(unit)
		var canonical: String = Runtime.WEAPONS[weapon_id]
		check(data.assets[canonical].image == library.assets[Appearance.WEAPON_ASSETS[weapon_id]].image, "weapon maps to the correct actual asset: " + weapon_id)
		check(not Runtime.action_for_unit(unit, "attack").is_empty(), "weapon has authored timing: " + weapon_id)
	for id: String in ["state_down", "state_dead"]:
		check(library.assets.has(id), "distinct terminal overlay exists: " + id)
	for category: String in ["padded", "outer"]:
		for index in range(1, 5):
			check(library.assets.has("%s_%02d_damaged" % [category, index]), "armor damage keeps its own base variant")
	print("Foundation library: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
