extends "res://core/battle_rules.gd"
# Existing regression cases continue to exercise already-started 0.1.5 semantics.
static func create_battle(roster: Array, seed: int, mission: Dictionary = {}) -> Dictionary:
	var legacy = mission.duplicate(true)
	legacy.rules_version = "prototype-0.1.5"
	return preload("res://core/battle_rules.gd").create_battle(roster, seed, legacy)
