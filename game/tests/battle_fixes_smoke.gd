extends Node
## Exportable endgame fixtures: actual controller actions, not a complete natural battle.
const Battle = preload("res://core/battle_rules.gd")
const Saves = preload("res://core/save_store.gd")
const World = preload("res://core/world_data.gd")
var checks: Array = []
var output := ""
var app: Control

func check(ok: bool, label: String) -> void:
	checks.append({"ok": ok, "name": label})
	if not ok: push_error(label)

func capture(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))
	check(result == OK, "screenshot saved: " + name)

func setup(evacuation: bool) -> Dictionary:
	app._new_campaign("free", 9113)
	if evacuation: app._accept_contract(World.EVACUATION_ID, "road")
	else: app._start_expedition("road")
	while app.campaign.phase == "travel": app._advance_travel()
	if app.campaign.phase == "event": app._event_choice(str(app.campaign.event.choices[0].id))
	while app.campaign.phase == "travel": app._advance_travel()
	app._enter_battle()
	check(app.campaign.phase == "battle", "controller enters contract battle")
	var b: Dictionary = app.campaign.battle
	# Fixture setup only. Record real casualty data, so normal saves/settlement remain valid.
	var last: Dictionary = b.units.back()
	for unit: Dictionary in b.units:
		if unit.team == "enemy" and (evacuation or unit != last):
			Battle._damage_unit(b, unit, 1000, str(b.units[0].id), true, [])
	if evacuation:
		for index in range(2):
			b.units[index].q = 7
			b.units[index].r = index + 1
		b.order = [str(b.units[0].id), str(b.units[1].id)]
		for unit: Dictionary in b.units:
			if str(unit.id) not in b.order: b.order.append(str(unit.id))
		b.turn_index = 0
	else:
		last.hp = 1; last.armor = 0; last.q = 3; last.r = 2
		b.units[0].q = 2; b.units[0].r = 2
		b.turn_index = b.order.find(b.units[0].id)
	Battle._check_outcome(b)
	app.board.skip_animations()
	app.selected_action = "move"
	app._refresh_battle()
	app._autosave()
	check(Saves.validate(app.campaign).is_empty(), "endgame fixture passes normal save validation")
	return b

func run(controller: Control) -> void:
	app = controller
	output = ProjectSettings.globalize_path("user://qa/battle-fixes")
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--battle-fixes-output="): output = argument.trim_prefix("--battle-fixes-output=")
	DirAccess.make_dir_recursive_absolute(output)
	check(app.smoke_mode and app.save_path == "user://qa/battle-fixes-campaign.json", "test isolates saves and disables ambient AI processing")
	var b := setup(true)
	check(b.outcome == "" and not app.resolve_button.visible, "cleared evacuation still requires two exits")
	check(app.outcome_label.text.contains("右侧撤离 0/2") and not app.outcome_label.text.contains("粮仓"), "cleared HUD displays the actual evacuation objective")
	check(app.preview_label.text.contains("右侧") and app.preview_label.text.contains("撤离战场"), "cleared HUD explains how to finish")
	await capture("01-evacuation-cleared-objective")
	for index in range(2):
		var active := Battle.active_unit(b)
		check(active.get("id", "") == b.units[index].id, "normal turn progression reaches evacuation participant %d" % (index + 1))
		app._choose_action("move")
		app._on_cell_clicked(8, index + 1)
		app.board.skip_animations()
		check(int(b.units[index].q) == 8, "controller move reaches the right edge")
		app._choose_action("flee")
		app.board.skip_animations()
		check(b.objective.evacuated_ids.size() == index + 1, "controller exit advances contract objective")
	check(b.outcome == "victory" and app.resolve_button.visible and app.outcome_label.text.contains("撤离"), "evacuation completion exposes correct result and settlement button")
	check(Saves.validate(app.campaign).is_empty(), "evacuation terminal snapshot validates")
	await capture("02-evacuation-success")
	app._resolve()
	check(app.campaign.phase in ["growth", "returning"], "controller settles evacuation")
	await capture("03-evacuation-settled")
	b = setup(false)
	app._choose_action("fire")
	app._on_cell_clicked(3, 2)
	check(app.board.has_pending_animation(), "final real command starts damage presentation")
	app.board.skip_animations()
	check(b.outcome == "victory" and app.resolve_button.visible and not app.end_button.visible, "ordinary last-enemy defeat exposes settlement")
	check(Saves.validate(app.campaign).is_empty(), "ordinary victory snapshot validates")
	await capture("04-granary-success")
	app._resolve()
	check(app.campaign.phase in ["growth", "returning"], "controller settles ordinary victory")
	check(Saves.load_campaign(app.save_path).get("ok", false), "isolated autosave reloads after settlement")
	var failures := 0
	for result: Dictionary in checks:
		if not result.ok: failures += 1
	var report := {"checks": checks, "failures": failures, "display": DisplayServer.get_name(), "window_size": str(get_viewport().get_visible_rect().size), "note": "Automated real controller endgame fixtures. Evacuation starts with defeated enemies and two survivors near the exit; granary starts with one 1-HP enemy. Not a complete natural battle or human input playtest.", "save_path": app.save_path}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	if file == null:
		push_error("Cannot write battle fixes report: " + output)
		get_tree().quit(1)
		return
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("Battle fixes exported flow: %d checks; %d failures" % [checks.size(), failures])
	get_tree().quit(0 if failures == 0 else 1)
