extends RefCounted
## Stable presentation identity. No campaign or combat random numbers are consumed.
const SCHEMA := 1
const SLOTS := ["body", "face", "hair", "beard", "linen", "padded", "outer", "shield", "scar", "bandage", "blood"]
const WEAPON_ASSETS := {
	"weapon_guard_sword": "sword_01", "weapon_guard_cleaver": "sword_02",
	"weapon_skirmisher_blade": "sword_03", "weapon_skirmisher_axe": "axe_01",
	"weapon_spear_long": "spear_01", "weapon_spear_hooked": "spear_02",
	"weapon_archer_bow": "bow_01", "weapon_archer_longbow": "bow_02",
	"weapon_hunter_bow": "bow_03", "weapon_hunter_recurve": "bow_04"
}
const ARMOR_ASSETS := {
	"armor_padded": {"padded": "padded_01"},
	"armor_leather": {"padded": "padded_02", "outer": "outer_03"},
	"armor_brigandine": {"padded": "padded_03", "outer": "outer_02"},
	"armor_mail": {"padded": "padded_04", "outer": "outer_01"}
}

static func ensure_unit(unit: Dictionary) -> bool:
	if str(unit.get("kind", "")) == "dog" or unit.has("appearance"):
		return false
	var identity := str(unit.get("id", "unknown"))
	var choices := {"schema": SCHEMA, "library": "foundation-1"}
	for slot: String in SLOTS:
		# Use a fixed digest rather than engine hash or evolving catalog ordering.
		var index := (identity + ":" + slot).sha256_text().left(6).hex_to_int() % 4 + 1
		var serial := identity.get_slice("_", identity.get_slice_count("_") - 1)
		if slot in ["face", "body"] and serial.is_valid_int():
			index = posmod(int(serial) - 1, 4) + 1
		choices[slot] = "%s_%02d" % [slot, index]
	choices.has_beard = identity.sha256_text().left(2).hex_to_int() % 3 != 0
	unit.appearance = choices
	return true

static func validate(unit: Dictionary) -> String:
	if not unit.has("appearance"):
		return ""
	var value = unit.appearance
	if not value is Dictionary or int(value.get("schema", -1)) != SCHEMA:
		return "人物外观版本损坏。"
	for slot: String in SLOTS:
		if not value.get(slot) is String or not str(value[slot]) in [slot + "_01", slot + "_02", slot + "_03", slot + "_04"]:
			return "人物外观组件损坏：" + slot
	return "" if value.get("has_beard") is bool else "人物胡须选择损坏。"
