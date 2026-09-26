extends RefCounted
## Converts finalized tactical casualties to a campaign settlement copy.
## Never changes the battle snapshot or draws random numbers during settlement.
const VERSION := "prototype-0.1.6"

static func prepare(battle: Dictionary) -> Dictionary:
	var settled := battle.duplicate(true)
	if str(battle.get("rules_version", "")) != VERSION:
		return {"ok": true, "battle": settled, "survivors": []}
	var records := {}
	for record: Dictionary in battle.get("casualties", []):
		if records.has(str(record.get("unit_id", ""))):
			return {"ok": false, "reason": "伤亡记录重复，未结算。"}
		records[str(record.get("unit_id", ""))] = record
	var survivors := []
	for unit: Dictionary in settled.get("units", []):
		if unit.get("team", "") != "player" or int(unit.get("hp", 0)) > 0:
			continue
		var record: Dictionary = records.get(str(unit.id), {})
		if record.is_empty() or str(record.get("status", "pending")) not in ["survived", "dead"]:
			return {"ok": false, "reason": "伤亡尚未确定，未结算装备和经验。"}
		if record.status == "survived":
			if battle.get("outcome", "") != "victory":
				return {"ok": false, "reason": "重伤幸存结果与战果不符。"}
			unit.hp = maxi(1, int(unit.get("max_hp", 1)) / 4)
			survivors.append({"unit_id": str(unit.id), "casualty_id": str(record.get("id", "")), "name": str(unit.name)})
	return {"ok": true, "battle": settled, "survivors": survivors}

static func apply_recovery(campaign: Dictionary, survivors: Array) -> void:
	for survivor: Dictionary in survivors:
		for unit: Dictionary in campaign.roster:
			if str(unit.id) != str(survivor.unit_id): continue
			unit.recovery_until_day = int(campaign.day) + 2
			unit.injury = {"id": "serious_wound", "source": survivor.casualty_id, "until_day": int(unit.recovery_until_day)}
			unit.get("character_history", []).append("战后被找到并重伤幸存，需要两天休养。")
