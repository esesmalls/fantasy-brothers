extends SceneTree
const Rules = preload("res://core/battle_rules.gd")
const Inspection = preload("res://presentation/battle_inspection.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	var battle := Rules.create_battle([
		{"id": "hunter", "name": "林恩", "kind": "hunter", "perks": ["precision", "packbond"]},
		{"id": "dog", "name": "灰耳", "kind": "dog", "perks": ["firewise"]},
		{"id": "guard", "name": "柯尔", "kind": "guard", "perks": ["breacher", "vigor"]}], 1709, {"id": "inspection"})
	_test_units_order_and_read_only(battle)
	_test_dead_and_preferred(battle)
	_test_statuses_and_dog(battle)
	_test_props_and_surfaces(battle)
	print("Battle inspection: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures:
		printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures.append(label)

func _has(lines: Array, fragment: String) -> bool:
	for line in lines:
		if str(line).contains(fragment):
			return true
	return false

func _test_units_order_and_read_only(battle: Dictionary) -> void:
	var before := JSON.stringify(battle)
	var player := Inspection.inspect_cell(battle, int(battle.units[0].q), int(battle.units[0].r))
	check(player.title == "林恩" and player.team == "player" and player.subtitle.contains("猎人"), "player inspection identifies name, team, and role")
	check(_has(player.lines, "生命：") and _has(player.lines, "护甲：") and _has(player.lines, "基础命中") and _has(player.lines, "射程"), "unit inspection exposes combat statistics")
	check(_has(player.lines, "行动顺序：当前行动者") and not _has(player.lines, "order") and not _has(player.lines, "速度"), "active unit uses a concise player-facing turn label")
	check(_has(player.lines, "沉着瞄准") and _has(player.lines, "同猎"), "known perks use their official names and readable descriptions")
	var enemy: Dictionary = battle.units[3]
	var enemy_info := Inspection.inspect_cell(battle, int(enemy.q), int(enemy.r))
	check(enemy_info.team == "enemy" and enemy_info.subtitle.contains("敌方"), "enemy inspection keeps enemy allegiance")
	check(_has(enemy_info.lines, "此前还有 3 名单位行动"), "future turn count includes the current living actor and later living actors before the target")
	var next_actor := Inspection.inspect_cell(battle, int(battle.units[1].q), int(battle.units[1].r))
	check(_has(next_actor.lines, "此前还有 1 名单位行动"), "the next actor is shown after one current unit rather than zero")
	check(JSON.stringify(battle) == before and int(battle.rng_state) == 1710 and battle.action_log.is_empty(), "inspection leaves full state, RNG, and action history unchanged")
	check(Inspection.inspect_cell(battle, -1, 0).is_empty() and Inspection.inspect_cell(battle, 99, 99).is_empty(), "out-of-bounds inspection returns an empty result")

func _test_dead_and_preferred(battle: Dictionary) -> void:
	var dead: Dictionary = battle.units[2]
	dead.hp = 0
	dead.q = int(battle.units[0].q)
	dead.r = int(battle.units[0].r)
	var default_info := Inspection.inspect_cell(battle, int(dead.q), int(dead.r), "missing-or-other-cell")
	check(default_info.title == "林恩", "invalid preferred id cannot override the living unit actually on the cell")
	var dead_info := Inspection.inspect_cell(battle, int(dead.q), int(dead.r), str(dead.id))
	check(dead_info.title == "柯尔" and dead_info.subtitle.contains("已倒下") and _has(dead_info.lines, "不会再行动"), "matching preferred id can inspect a dead overlapping unit without implying it can act")
	check(_has(dead_info.lines, "坚韧") and _has(dead_info.lines, "破阵协同"), "dead unit still reports official perk names and descriptions")
	check(_has(dead_info.lines, "同格单位：林恩"), "preferred dead unit still reports another occupant on the cell")

func _test_statuses_and_dog(battle: Dictionary) -> void:
	var enemy: Dictionary = battle.units[3]
	enemy.statuses = {
		"defending": {"source": "enemy_0"},
		"exposed": {"expires": 2, "source": "guard"},
		"marked": {"expires": 3, "source": "hunter"},
		"pinned": {"expires": 2, "source": "dog"}}
	var info := Inspection.inspect_cell(battle, int(enemy.q), int(enemy.r))
	check(_has(info.lines, "戒备") and _has(info.lines, "命中 -20") and _has(info.lines, "下回合开始"), "defending inspection explains its hit penalty and own-turn lifetime")
	check(_has(info.lines, "破绽") and _has(info.lines, "+25 命中") and _has(info.lines, "第 2 轮末") and _has(info.lines, "来源：柯尔"), "exposed inspection explains effect, expiry, and readable source")
	check(_has(info.lines, "标记") and _has(info.lines, "+15 命中") and _has(info.lines, "来源：林恩"), "marked inspection explains effect and source")
	check(_has(info.lines, "牵制标记") and _has(info.lines, "第 2 轮末") and _has(info.lines, "来源：灰耳"), "pinned compatibility output reports only its marker, expiry, and source")
	check(not _has(info.lines, "行动限制") and not _has(info.lines, "以规则状态为准"), "pinned compatibility output does not imply an unimplemented restriction")
	var dog: Dictionary = battle.units[1]
	dog.command = "pin"
	dog.command_target = str(enemy.id)
	battle.cells["%d,%d" % [int(dog.q), int(dog.r)]].field = "fire"
	battle.cells["%d,%d" % [int(dog.q), int(dog.r)]].expires = 2
	var dog_info := Inspection.inspect_cell(battle, int(dog.q), int(dog.r))
	check(_has(dog_info.lines, "战犬指令：牵制") and _has(dog_info.lines, "绑定猎人：林恩") and _has(dog_info.lines, "牵制目标：劫掠者"), "dog inspection reports command, hunter binding, and readable target")
	check(_has(dog_info.lines, "识火") and _has(dog_info.lines, "伤害减半") and not _has(dog_info.lines, "读取单位专长"), "firewise hazard distinction is shown without implementation language")

func _test_props_and_surfaces(battle: Dictionary) -> void:
	var grain := Inspection.inspect_cell(battle, 6, 2)
	check(grain.title == "粮仓" and grain.glyph == "物" and _has(grain.lines, "耐久：14 / 14") and _has(grain.lines, "阻挡：是"), "living grain prop uses the campaign name and reports durability and blocking")
	check(_has(grain.lines, "2 份口粮") and _has(grain.lines, "10 金"), "grain destruction reports its concrete settlement consequence")
	var oil := Inspection.inspect_cell(battle, 4, 2)
	check(_has(oil.lines, "铺油") and _has(oil.lines, "形成火区"), "oil prop reports destruction interaction")
	var water := Inspection.inspect_cell(battle, 3, 4)
	check(_has(water.lines, "灭火") and _has(water.lines, "蒸汽"), "water prop reports destruction interaction")
	var cover := Inspection.inspect_cell(battle, 4, 3)
	check(_has(cover.lines, "打开通路与射线"), "cover prop reports opening the route")
	battle.props[2].hp = 0
	var broken_cover := Inspection.inspect_cell(battle, 4, 3)
	check(broken_cover.title.begins_with("已毁") and bool(battle.props[2].blocks) and _has(broken_cover.lines, "阻挡：否"), "destroyed prop never claims to block even when its saved blocks flag is stale")
	battle.cells["0,0"].surface = "oil"
	battle.cells["0,0"].field = "fire"
	battle.cells["0,0"].expires = 2
	var fire := Inspection.inspect_cell(battle, 0, 0)
	check(fire.title.contains("(0, 0)") and _has(fire.lines, "地表：油地") and _has(fire.lines, "火区"), "empty cell reports coordinates, surface, and field")
	check(_has(fire.lines, "第 2 轮末") and _has(fire.lines, "当前第 1 轮"), "field inspection reports expiry relative to current battle round")
	check(_has(fire.lines, "热浪逼人") and not _has(fire.lines, "仅表现") and not _has(fire.lines, "士气数值"), "atmosphere stays a short player-facing phrase")
	battle.cells["0,1"].surface = "water"
	battle.cells["0,1"].field = "steam"
	battle.cells["0,1"].expires = 3
	var steam := Inspection.inspect_cell(battle, 0, 1)
	check(_has(steam.lines, "蒸汽") and _has(steam.lines, "遮挡远程视线"), "steam inspection exposes its actual line-of-sight effect")
