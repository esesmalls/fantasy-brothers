extends RefCounted
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Saves = preload("res://core/save_store.gd")
const Policy = preload("res://tests/play_policy.gd")
var failures: Array[String] = []
var checks: int = 0
var output: String = "user://qa/screens"

func run(app: Control) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--smoke-dir="):
			output = argument.trim_prefix("--smoke-dir=").replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(output)
	await _capture(app, "01-title")
	app._new_campaign("free", 1709)
	await _capture(app, "02-camp")
	for expedition in range(3):
		app._start_expedition()
		_check(app.campaign.phase == "event", "event opens")
		if expedition == 0:
			await _capture(app, "03-event")
		app._event_choice(str(app.campaign.event.choices[0].id))
		_check(app.campaign.phase == "ready", "event choice reaches briefing")
		if expedition == 0:
			await _capture(app, "04-briefing")
		app._enter_battle()
		_check(app.campaign.phase == "battle", "battle opens")
		if expedition == 0:
			app.board._layout()
			for q in range(9):
				for r in range(7):
					_check(app.board._point_to_hex(app.board._hex_center(q, r)) == Vector2i(q, r), "hex input mapping %d,%d" % [q, r])
			app._on_cell_hovered(3, 2)
			await _capture(app, "05-battle")
			var input: InputEventMouseButton = InputEventMouseButton.new()
			input.button_index = MOUSE_BUTTON_LEFT
			input.pressed = true
			input.position = app.board._offset + app.board._hex_center(3, 2) * app.board._scale
			var seq: int = int(app.campaign.battle.action_seq)
			app.board._gui_input(input)
			_check(int(app.campaign.battle.action_seq) == seq + 1, "board mouse click dispatches one real action")
			var post_action: String = JSON.stringify(app.campaign)
			app._set_speed(3.0)
			await app.get_tree().create_timer(0.15).timeout
			app._set_speed(0.0)
			_check(JSON.stringify(app.campaign) == post_action, "animation speed and skip leave rule state unchanged")
			app._manual_save()
			# save_campaign canonicalizes GDScript StringName keys in the live
			# state; capture that canonical state before the UI reloads it.
			var saved_state: Dictionary = app.campaign.duplicate(true)
			app._load(app.manual_path)
			_check(app.campaign == saved_state, "mid-battle save/load exact state")
		app._set_speed(0.0)
		var steps: int = 0
		while str(app.campaign.battle.outcome).is_empty() and steps < 900:
			var active: Dictionary = Battle.active_unit(app.campaign.battle)
			if active.team == "enemy" or active.kind == "dog":
				var result: Dictionary = Battle.ai_step(app.campaign.battle)
				app._refresh_battle(result.get("events", []))
			else:
				var command: Dictionary = Policy.next_command(app.campaign.battle)
				if command.is_empty():
					app._end_turn()
				else:
					app.selected_action = command.action
					app.board.cell_clicked.emit(int(command.target.q), int(command.target.r))
			steps += 1
			if steps % 8 == 0:
				await app.get_tree().process_frame
		_check(not str(app.campaign.battle.outcome).is_empty(), "battle terminates under legal play")
		_check(app.campaign.battle.outcome == "victory", "seed1709 expedition %d victory" % expedition)
		await _capture(app, "06-result-%d" % expedition)
		app._resolve()
		_check(app.campaign.phase in ["growth", "camp"], "result resolves")
		if app.campaign.phase == "growth":
			if expedition == 0:
				await _capture(app, "07-growth")
			app._growth_choice(str(app.campaign.growth_offers[0].id))
		_check(app.campaign.phase == "camp", "returns to camp")
		for unused in range(4):
			Campaign.camp_action(app.campaign, "rest")
		Campaign.camp_action(app.campaign, "repair")
		Campaign.camp_action(app.campaign, "resupply")
		for unused in range(4):
			Campaign.camp_action(app.campaign, "recruit")
		app._show_campaign()
	_check(bool(app.campaign.flags.ending_seen), "three-expedition ending")
	await _capture(app, "08-ending")
	app._new_campaign("hunters", 1710)
	app._start_expedition()
	app._event_choice(str(app.campaign.event.choices[0].id))
	app._enter_battle()
	app._set_speed(3.0)
	await _capture(app, "09-hunters")
	app._retreat()
	app._resolve()
	_check(app.campaign.phase == "camp" and app.campaign.flags.last_outcome == "retreat", "retreat returns to camp")
	app._autosave()
	var reload_result: Dictionary = Saves.load_campaign(app.save_path)
	_check(reload_result.get("ok", false), "final autosave readable")
	app.get_window().size = Vector2i(1180, 740)
	await _capture(app, "10-small-window")
	app._start_expedition()
	app._event_choice(str(app.campaign.event.choices[0].id))
	app._enter_battle()
	await _capture(app, "11-small-battle")
	_check(app.end_button.get_global_rect().end.y < app.get_viewport_rect().size.y, "small-window end-turn remains visible")
	var report: Dictionary = {"checks": checks, "failures": failures, "engine": Engine.get_version_info().string, "exported": not OS.has_feature("editor"), "screen_dir": output}
	var file: FileAccess = FileAccess.open(output.path_join("smoke-report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("UI_SMOKE: %d checks, %d failures; %s" % [checks, failures.size(), output])
	app.get_tree().quit(0 if failures.is_empty() else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures.append(label)
		push_error("SMOKE FAIL: " + label)

func _capture(app: Control, name: String) -> void:
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var screenshot: Image = app.get_viewport().get_texture().get_image()
	var error: Error = screenshot.save_png(output.path_join(name + ".png"))
	_check(error == OK, "screenshot " + name)
