extends RefCounted
## Shared visual mapping: every component is positioned relative to the
## center of the unit's current board cell.
## A project config supplies optional per-configuration overrides; the profile
## below is the current runtime sample promoted from my_test-v2.json.

const PROFILE_PATH := "res://assets/art/static-bust/runtime-profile.json"
static var _profile: Dictionary = {}

static func profile() -> Dictionary:
	if _profile.is_empty() and FileAccess.file_exists(PROFILE_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PROFILE_PATH))
		if parsed is Dictionary:
			_profile = parsed
	return _profile

static func supports(unit: Dictionary) -> bool:
	var id := str(unit.get("visual_profile", ""))
	if id == str(profile().get("id", "")):
		return true
	return str(unit.get("id", "")) in profile().get("sample_unit_ids", [])

static func edits() -> Dictionary:
	return profile().get("edits", {})

static func appearance() -> Dictionary:
	return profile().get("appearance", {})
