extends RefCounted
## Test player: only uses the public preview/apply interface, no state shortcuts.
const Battle = preload("res://core/battle_rules.gd")

static func next_command(b: Dictionary) -> Dictionary:
	var u: Dictionary = Battle.active_unit(b)
	if u.is_empty():
		return {}
	var opponents: Array = []
	for enemy: Dictionary in b.units:
		if str(enemy.team) != str(u.team) and int(enemy.hp) > 0:
			opponents.append(enemy)
	var best: Dictionary = {}
	var best_score: float = -100000.0
	for action: Dictionary in Battle.get_actions(b, str(u.id)):
		if not str(action.id) in ["attack", "shield_bash", "command_pin"]:
			continue
		for enemy: Dictionary in opponents:
			var target: Dictionary = {"q": int(enemy.q), "r": int(enemy.r)}
			var p: Dictionary = Battle.preview(b, str(u.id), str(action.id), target)
			if not p.ok:
				continue
			var score: float = float(p.damage) * float(p.chance) / 100.0 + 2.0
			if action.id == "shield_bash" and not enemy.statuses.has("exposed"):
				score += 9.0
			if action.id == "command_pin":
				var needs_order: bool = false
				for dog: Dictionary in b.units:
					if str(dog.kind) == "dog" and int(dog.hp) > 0 and str(dog.get("command_target", "")) != str(enemy.id):
						needs_order = true
				if not needs_order:
					continue
				score = 2.5
			if score > best_score:
				best_score = score
				best = {"action": str(action.id), "target": target}
	if not best.is_empty():
		return best
	var current: int = 100
	for enemy: Dictionary in opponents:
		current = mini(current, _distance(int(u.q), int(u.r), int(enemy.q), int(enemy.r)))
	best_score = -float(current) * 10.0
	for q in range(9):
		for r in range(7):
			var p: Dictionary = Battle.preview(b, str(u.id), "move", {"q": q, "r": r})
			if not p.ok:
				continue
			var distance: int = 100
			for enemy: Dictionary in opponents:
				distance = mini(distance, _distance(q, r, int(enemy.q), int(enemy.r)))
			var score: float = -float(distance) * 10.0 - float(p.cost) * 0.1
			if b.cells["%d,%d" % [q, r]].field == "fire":
				score -= 30
			if score > best_score:
				best_score = score
				best = {"action": "move", "target": {"q": q, "r": r}}
	return best

static func _distance(aq: int, ar: int, bq: int, br: int) -> int:
	return maxi(absi(aq - bq), maxi(absi(ar - br), absi(aq + ar - bq - br)))
