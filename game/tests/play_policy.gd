extends RefCounted
## Test player: only uses the public preview/apply interface, no state shortcuts.
const Battle = preload("res://core/battle_rules.gd")

static func next_command(b: Dictionary) -> Dictionary:
	var u: Dictionary = Battle.active_unit(b)
	if u.is_empty():
		return {}
	if int(u.get("fatigue", 0)) >= int(u.get("max_fatigue", 100)) - 20 and Battle.preview(b, str(u.id), "recover", {}).ok:
		return {"action": "recover", "target": {}}
	if str(b.get("objective", {}).get("kind", "")) == "evacuation":
		return _evacuation_command(b, u)
	var opponents: Array = []
	for enemy: Dictionary in b.units:
		if str(enemy.team) != str(u.team) and int(enemy.hp) > 0 and not bool(enemy.get("escaped", false)):
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
					if str(dog.kind) == "dog" and int(dog.hp) > 0 and not bool(dog.get("escaped", false)) and str(dog.get("command_target", "")) != str(enemy.id):
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
	if best.is_empty() and Battle.preview(b, str(u.id), "recover", {}).ok:
		return {"action": "recover", "target": {}}
	return best

static func _evacuation_command(b: Dictionary, u: Dictionary) -> Dictionary:
	if int(u.q) == int(b.width) - 1 and Battle.preview(b, str(u.id), "flee", {}).ok:
		return {"action": "flee", "target": {}}
	var best: Dictionary = {}
	var best_score := 100000.0
	for q in range(int(b.width)):
		for r in range(int(b.height)):
			var target := {"q": q, "r": r}
			var p := Battle.preview(b, str(u.id), "move", target)
			if not p.ok: continue
			var distance := _steps_to_exit(b, u, q, r)
			if distance >= 100000: continue
			var score := float(distance) * 100.0 + float(p.cost) * 0.1
			if b.cells["%d,%d" % [q, r]].field == "fire": score += 40.0
			if score < best_score:
				best_score = score
				best = {"action": "move", "target": target}
	if best.is_empty() and Battle.preview(b, str(u.id), "recover", {}).ok:
		return {"action": "recover", "target": {}}
	return best

static func _steps_to_exit(b: Dictionary, mover: Dictionary, q: int, r: int) -> int:
	var blocked := {}
	for prop: Dictionary in b.props:
		if int(prop.hp) > 0 and bool(prop.blocks): blocked["%d,%d" % [int(prop.q), int(prop.r)]] = true
	for unit: Dictionary in b.units:
		if unit.id != mover.id and int(unit.hp) > 0 and not bool(unit.get("escaped", false)):
			blocked["%d,%d" % [int(unit.q), int(unit.r)]] = true
	var queue := [{"q": q, "r": r, "steps": 0}]
	var visited := {"%d,%d" % [q, r]: true}
	var directions := [[1, 0], [1, -1], [0, -1], [-1, 0], [-1, 1], [0, 1]]
	var cursor := 0
	while cursor < queue.size():
		var cell: Dictionary = queue[cursor]
		cursor += 1
		if int(cell.q) == int(b.width) - 1: return int(cell.steps)
		for direction in directions:
			var next_q := int(cell.q) + int(direction[0])
			var next_r := int(cell.r) + int(direction[1])
			var key := "%d,%d" % [next_q, next_r]
			if next_q < 0 or next_q >= int(b.width) or next_r < 0 or next_r >= int(b.height) or visited.has(key) or blocked.has(key): continue
			visited[key] = true
			queue.append({"q": next_q, "r": next_r, "steps": int(cell.steps) + 1})
	return 100000

static func _distance(aq: int, ar: int, bq: int, br: int) -> int:
	return maxi(absi(aq - bq), maxi(absi(ar - br), absi(aq + ar - bq - br)))
