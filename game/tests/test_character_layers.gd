extends SceneTree
## Renderer-only checks: equipment values are read as snapshots and never mutate
## gameplay data. Raster review belongs to the exported UI smoke run.

const Portrait = preload("res://presentation/character_portrait.gd")

var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	_test_snapshot_and_identity()
	_test_loadout_and_damage_fallbacks()
	print("Character layers: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _test_snapshot_and_identity() -> void:
	var portrait := Portrait.new()
	get_root().add_child(portrait)
	var unit := {
		"id": "crew_layer_guard", "kind": "guard", "team": "player", "hp": 12, "max_hp": 38,
		"armor": 5, "max_armor": 24,
		"visual_loadout": {"weapon": "weapon_guard_cleaver", "armor": "armor_mail"},
		"weapon_style": "guard"
	}
	portrait.set_unit(unit)
	unit.hp = 38
	unit.visual_loadout.weapon = "weapon_guard_sword"
	_check(int(portrait._unit.hp) == 12 and str(portrait._unit.visual_loadout.weapon) == "weapon_guard_cleaver", "portrait copies a read-only unit snapshot")
	_check(portrait.custom_minimum_size == Vector2(220, 200), "portrait preserves the documented 220 by 200 minimum")
	var original_id := Portrait._identity(portrait._unit)
	portrait._unit.weapon_style = "skirmisher"
	_check(Portrait._identity(portrait._unit) == original_id, "stable identity is derived from unit ID rather than equipped weapon style")
	portrait.queue_free()

func _test_loadout_and_damage_fallbacks() -> void:
	var equipped := {
		"id": "crew_archer", "kind": "archer", "hp": 8, "max_hp": 30, "armor": 2, "max_armor": 10,
		"visual_loadout": {"weapon": "weapon_archer_longbow", "armor": "armor_padded"}, "weapon_style": "archer"
	}
	_check(Portrait._weapon_id(equipped) == "weapon_archer_longbow" and Portrait._armor_id(equipped) == "armor_padded", "renderer reads the explicit weapon and armor definition IDs")
	_check(Portrait._ratio(equipped, "hp", "max_hp") < 0.38 and Portrait._ratio(equipped, "armor", "max_armor") < 0.30, "low HP and armor snapshots reach the wound and broken-armor thresholds")
	var cross_human := {"id": "crew_crossbow", "kind": "guard", "hp": 38, "max_hp": 38, "armor": 14, "max_armor": 14, "visual_loadout": {"weapon": "weapon_archer_longbow", "armor": "armor_leather"}, "weapon_style": "archer"}
	_check(Portrait._weapon_id(cross_human) == "weapon_archer_longbow" and Portrait._armor_id(cross_human) == "armor_leather", "cross-human loadouts select their equipped silhouette instead of the old unit kind")
	var legacy := {"id": "old_spear", "kind": "spear", "hp": 30, "max_hp": 30, "armor": 16, "max_armor": 16}
	_check(Portrait._weapon_id(legacy) == "weapon_spear_long" and Portrait._armor_id(legacy) == "armor_brigandine", "old battle snapshots fall back to role and real max armor")
