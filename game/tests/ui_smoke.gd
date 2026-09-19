extends RefCounted
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Saves = preload("res://core/save_store.gd")
const Policy = preload("res://tests/play_policy.gd")
var failures: Array[String] = []
var checks: int = 0
var output: String = "user://qa/screens"
var captured_attack: bool = false

func run(app: Control) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--smoke-dir="):
			output = argument.trim_prefix("--smoke-dir=").replace("\\", "/")
	DirAccess.make_dir_recursive_absolute(output)
	await _capture(app, "01-title")
	app._new_campaign("free", 1709)
	await app.get_tree().process_frame
	_check(is_instance_valid(app.world_screen) and is_instance_valid(app.world_screen.map), "new campaign opens the world map with an interactive map control")
	_check(app.route_buttons.has("road") and app.route_buttons.has("ridge") and app.route_buttons == app.world_screen.route_buttons, "world map exposes both real route buttons through the controller alias")
	var map_read_before: String = JSON.stringify(app.campaign)
	var ferry_name: String = _world_location_name(app.campaign, "loc_ferry_crossing")
	await _real_map_location(app, "loc_ferry_crossing")
	_check(app.world_screen.map._hover_id == "loc_ferry_crossing" and app.world_screen.location_title.text.begins_with(ferry_name), "real pointer hover and click select a discovered map location")
	_check(JSON.stringify(app.campaign) == map_read_before and app.campaign.phase == "camp", "map location browsing is read-only and does not begin travel")
	var route_preview_text: String = _node_text(app.world_screen)
	for route: Dictionary in Campaign.get_routes(app.campaign):
		var route_id: String = str(route.id)
		_check(app.route_buttons[route_id].tooltip_text == str(route.description), "%s route button exposes the rule description" % route_id)
		_check(route_preview_text.contains("%d 粮 · %d 天" % [int(route.food_cost), int(route.days)]) and route_preview_text.contains("%d 金" % int(route.reward)) and route_preview_text.contains("油 %d · 火 %d · 水 %d" % [int(route.supplies.oil), int(route.supplies.fire), int(route.supplies.water)]), "%s route card displays rule-owned cost, duration, reward, and tools" % route_id)
	var before_routes: String = JSON.stringify(app.campaign)
	app._show_campaign()
	_check(JSON.stringify(app.campaign) == before_routes, "reopening the world map does not reroll or spend resources")
	_check(is_instance_valid(app.world_screen.camp_button) and app.world_screen.camp_button.is_visible_in_tree(), "world map offers the separate camp-life view")
	await _capture(app, "02-world-camp")
	await _activate_button(app, app.world_screen.camp_button)
	_check(app.campaign.phase == "camp" and app.camp_detail and app.world_screen == null, "camp button opens roster and life actions without changing campaign phase")
	app._show_world_view()
	for expedition in range(3):
		if not is_instance_valid(app.world_screen):
			app._show_world_view()
		var departure_food: int = int(app.campaign.food)
		var departure_day: int = int(app.campaign.day)
		var road_rule: Dictionary = Campaign.get_routes(app.campaign)[0]
		await _activate_button(app, app.route_buttons["road"])
		_check(app.campaign.phase == "travel", "road route button accepts the contract and starts saved travel")
		_check(str(app.campaign.world.travel.route_id) == "road" and int(app.campaign.world.travel.current_edge_index) == 0, "accepted road route begins at the saved origin node")
		_check(int(app.campaign.food) == departure_food - int(road_rule.food_cost) and int(app.campaign.day) == departure_day + int(road_rule.days), "road route charges its previewed food and days exactly once on departure")
		if expedition == 0:
			await _capture(app, "03-world-travel")
			app._manual_save()
			var travel_state: Dictionary = app.campaign.duplicate(true)
			app._load(app.manual_path)
			_check(app.campaign == travel_state and str(app.campaign.world.travel.event_instance_id) == str(travel_state.world.travel.event_instance_id), "saved in-progress travel reloads its exact node, RNG, and generated event instance")
			var reopened_travel: String = JSON.stringify(app.campaign)
			app._show_campaign()
			_check(JSON.stringify(app.campaign) == reopened_travel and int(app.campaign.food) == departure_food - int(road_rule.food_cost), "reopening in-progress travel neither rerolls nor charges the route again")
		await _advance_until(app, "event")
		_check(app.campaign.phase == "event", "travel reaches its saved event node")
		if expedition == 0:
			await _capture(app, "04-world-event")
			app._manual_save()
			var event_state: Dictionary = app.campaign.duplicate(true)
			app._load(app.manual_path)
			_check(app.campaign == event_state, "saved travel event and choices reload exactly without reroll")
			var event_view_before: String = JSON.stringify(app.campaign)
			app._show_world_view()
			await app.get_tree().process_frame
			_check(is_instance_valid(app.world_screen) and is_instance_valid(app.world_screen.continue_button), "event exposes a read-only map overview with a continue control")
			await _real_map_location(app, str(app.campaign.world.company_location_id))
			_check(JSON.stringify(app.campaign) == event_view_before and app.campaign.phase == "event", "browsing the event location on the map does not resolve or reroll the event")
			await _capture(app, "04a-world-event-overview")
			await _activate_button(app, app.world_screen.continue_button)
			_check(app.world_screen == null and app.campaign.phase == "event" and JSON.stringify(app.campaign) == event_view_before, "closing the map overview restores the same unresolved event")
		app._event_choice(str(app.campaign.event.choices[0].id))
		_check(app.campaign.phase in ["travel", "ready"], "event choice resumes the saved trip")
		await _advance_until(app, "ready")
		_check(app.campaign.phase == "ready", "remaining travel reaches the contract briefing")
		if expedition == 0:
			await _capture(app, "05-briefing")
		app._enter_battle()
		_check(app.campaign.phase == "battle", "battle opens")
		if expedition == 0:
			await app.get_tree().process_frame
			await app.get_tree().process_frame
			app.board._layout()
			_check(app.board.position.is_equal_approx(Vector2.ZERO) and app.board.size.x >= app.get_viewport_rect().size.x - 1.0 and app.board.size.y >= app.get_viewport_rect().size.y - 1.0, "battle board fills the viewport behind the HUD")
			_check(app.battle_hud.dock.position.y > app.battle_hud.size.y * 0.55 and app.battle_hud.dock.get_global_rect().end.y <= app.get_viewport_rect().size.y + 1.0, "battle command dock stays at the bottom of the viewport")
			_check(app.battle_hud.dock.size.y <= 260.0 and app.battle_hud.top_summary.size.y <= 80.0, "battle dock and top summary keep bounded readable heights")
			_check(app.battle_hud.log_panel.position.x <= 14.0 and app.battle_hud.log_panel.position.y <= 14.0, "collapsed battle log stays in the upper-left corner")
			_check(app.battle_hud.queue_ids == _living_queue(app.campaign.battle), "turn queue starts at the current actor and lists living units in cyclic order")
			_check(app.battle_hud.queue_box.size.y <= 50.0, "turn timeline remains a compact single row")
			_check(app.battle_hud.action_box.get_child_count() == 5 and app.battle_hud.item_box.get_child_count() == 3, "skills and shared battle items occupy separate bottom HUD groups")
			for q in range(9):
				for r in range(7):
					_check(app.board._point_to_hex(app.board._hex_center(q, r)) == Vector2i(q, r), "hex input mapping %d,%d" % [q, r])
			var inspect_before: String = JSON.stringify(app.campaign)
			var inspect_rng: int = int(app.campaign.battle.rng_state)
			var ally: Dictionary = app.campaign.battle.units[1]
			app._on_unit_hovered(str(ally.id))
			app._on_cell_hovered(int(ally.q), int(ally.r))
			_check(app.battle_hud.inspection_panel.visible and app.battle_hud.inspection_title.text == str(ally.name) and app.battle_hud.inspection_subtitle.text.contains("我方"), "ally hover opens its readable inspection card")
			var enemy: Dictionary = _first_unit(app.campaign.battle, "enemy")
			app._on_unit_hovered(str(enemy.id))
			app._on_cell_hovered(int(enemy.q), int(enemy.r))
			_check(app.battle_hud.inspection_panel.visible and app.battle_hud.inspection_title.text == str(enemy.name) and app.battle_hud.inspection_subtitle.text.contains("敌方"), "enemy hover opens its own inspection card")
			await _real_unit_hover(app, enemy)
			_check(app.hovered_unit_id == str(enemy.id) and app.hovered_cell == Vector2i(int(enemy.q), int(enemy.r)) and app.battle_hud.inspection_title.text == str(enemy.name), "real mouse hover over a unit upper body resolves that unit")
			var card_rect: Rect2 = app.battle_hud.inspection_panel.get_global_rect()
			_check(card_rect.size.y < app.get_viewport_rect().size.y and card_rect.position.x >= 0.0 and card_rect.position.y >= 0.0 and card_rect.end.x <= app.get_viewport_rect().size.x + 1.0 and card_rect.end.y <= app.battle_hud.dock.get_global_rect().position.y + 1.0, "inspection card is clamped inside the viewport and above the command dock")
			await _capture(app, "05a-tooltip")
			app._on_unit_hovered("")
			app._on_cell_hovered(4, 2)
			_check(app.battle_hud.inspection_title.text == "油罐" and app.battle_hud.inspection_body.text.contains("耐久"), "prop hover shows durability and identity")
			app._on_cell_hovered(4, 1)
			_check(app.battle_hud.inspection_title.text.contains("(4, 1)") and app.battle_hud.inspection_body.text.contains("地表：油地"), "empty terrain hover shows its surface state")
			var queued_id: String = app.battle_hud.queue_ids[1]
			app._inspect_unit(queued_id)
			_check(app.battle_hud.inspection_panel.visible and app.battle_hud.inspection_title.text == _unit_name(app.campaign.battle, queued_id), "turn queue inspection opens the selected living unit")
			app._hide_inspection()
			_check(not app.battle_hud.inspection_panel.visible, "leaving an inspection target clears the card")
			_check(JSON.stringify(app.campaign) == inspect_before and int(app.campaign.battle.rng_state) == inspect_rng, "unit, prop, terrain, and queue inspection leave rules and RNG unchanged")
			var refresh_target: Dictionary = app.campaign.battle.units[0]
			app._on_unit_hovered(str(refresh_target.id))
			app._on_cell_hovered(int(refresh_target.q), int(refresh_target.r))
			var refresh_before: String = JSON.stringify(app.campaign)
			app._refresh_battle()
			_check(app.battle_hud.inspection_panel.visible and app.battle_hud.inspection_title.text == str(refresh_target.name) and JSON.stringify(app.campaign) == refresh_before, "refresh recomputes the same hovered cell without mutating battle state")
			var original_perks: Array = refresh_target.perks.duplicate(true)
			var original_statuses: Dictionary = refresh_target.statuses.duplicate(true)
			var refresh_key := "%d,%d" % [int(refresh_target.q), int(refresh_target.r)]
			var original_cell: Dictionary = app.campaign.battle.cells[refresh_key].duplicate(true)
			refresh_target.perks = ["vigor", "precision", "breacher", "firewise", "packbond"]
			refresh_target.statuses = {"defending": {"source": refresh_target.id}, "exposed": {"expires": 2, "source": "enemy_0"}, "marked": {"expires": 2, "source": "enemy_1"}, "pinned": {"expires": 2, "source": "enemy_2"}}
			app.campaign.battle.cells[refresh_key].field = "fire"
			app.campaign.battle.cells[refresh_key].expires = 2
			app._on_unit_hovered(str(refresh_target.id))
			app._on_cell_hovered(int(refresh_target.q), int(refresh_target.r))
			await app.get_tree().process_frame
			await app.get_tree().process_frame
			var long_rect: Rect2 = app.battle_hud.inspection_panel.get_global_rect()
			_check(app.battle_hud.inspection_body.text.contains("同猎") and app.battle_hud.inspection_body.text.contains("破绽") and app.battle_hud.inspection_body.text.contains("火区"), "long inspection fixture shows five perks, multiple statuses, and its fire field")
			var long_dock_top: float = app.battle_hud.dock.get_global_rect().position.y
			_check(long_rect.size.y < app.get_viewport_rect().size.y and long_rect.position.y >= 0.0 and long_rect.end.y <= long_dock_top + 1.0, "long inspection card remains inside the viewport and above the command dock [card=%s dock_top=%.1f viewport=%s]" % [long_rect, long_dock_top, app.get_viewport_rect().size])
			await _capture(app, "05c-long-inspection")
			refresh_target.perks = original_perks
			refresh_target.statuses = original_statuses
			app.campaign.battle.cells[refresh_key] = original_cell
			_check(JSON.stringify(app.campaign) == refresh_before, "long inspection fixture restores the complete battle state")
			app.board._clear_hover()
			_check(not app.battle_hud.inspection_panel.visible and app.hovered_cell == Vector2i(-1, -1), "board exit clears tooltip and hovered cell")
			var log_before: String = JSON.stringify(app.campaign)
			var log_seq: int = int(app.campaign.battle.action_seq)
			_check(app.battle_hud.dock.mouse_filter == Control.MOUSE_FILTER_STOP and app.battle_hud.log_panel.mouse_filter == Control.MOUSE_FILTER_STOP and app.battle_hud.log_toggle.mouse_filter == Control.MOUSE_FILTER_STOP, "HUD panels and controls intercept pointer input above the board")
			await _activate_button(app, app.battle_hud.log_toggle)
			_check(app.battle_hud.log_expanded and app.battle_hud.log_panel.size.y > 100.0, "log toggle expands the upper-left battle report")
			_check(JSON.stringify(app.campaign) == log_before and int(app.campaign.battle.action_seq) == log_seq, "HUD log click does not pass through to a board action or change rules")
			await _capture(app, "05b-log-expanded")
			await _activate_button(app, app.battle_hud.log_toggle)
			_check(not app.battle_hud.log_expanded, "log toggle collapses the battle report again")
			app._on_cell_hovered(3, 2)
			_check(app.board._selected == Battle.active_unit(app.campaign.battle).id, "board identifies current acting unit")
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
			app.action_buttons["attack"].grab_focus()
			var turn_before: int = int(app.campaign.battle.turn_index)
			var space: InputEventKey = InputEventKey.new()
			space.keycode = KEY_SPACE
			space.pressed = true
			Input.parse_input_event(space)
			await app.get_tree().process_frame
			space.pressed = false
			Input.parse_input_event(space)
			await app.get_tree().process_frame
			_check(int(app.campaign.battle.turn_index) != turn_before, "space ends turn while an action button has keyboard focus")
			while str(Battle.active_unit(app.campaign.battle).get("team", "")) == "player":
				app._end_turn()
			var automated_enemy: Dictionary = Battle.active_unit(app.campaign.battle)
			var enemy_turn_before: String = JSON.stringify(app.campaign)
			app._on_unit_hovered(str(automated_enemy.id))
			app._on_cell_hovered(int(automated_enemy.q), int(automated_enemy.r))
			_check(app.battle_hud.inspection_panel.visible and app.battle_hud.inspection_title.text == str(automated_enemy.name), "enemy automatic turn still allows enemy inspection")
			_check(JSON.stringify(app.campaign) == enemy_turn_before, "enemy-turn inspection is read-only")
			app._load(app.manual_path)
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
					if not captured_attack and command.action in ["attack", "shield_bash"]:
						var before_preview: String = JSON.stringify(app.campaign)
						app._choose_action(str(command.action))
						app._on_cell_hovered(int(command.target.q), int(command.target.r))
						_check(app.preview_label.text.contains("命中") and app.preview_label.text.contains("伤害"), "legal attack preview presents chance and damage")
						_check(JSON.stringify(app.campaign) == before_preview, "attack hover does not mutate rules or RNG")
						_check(not app.board._action_overlay.get("range_cells", []).is_empty(), "attack range remains visible before execution")
						_check(command.target in app.board._action_overlay.get("valid_targets", []), "legal attack is highlighted on board")
						await _capture(app, "05b-attack-preview")
						captured_attack = true
					app.board.cell_clicked.emit(int(command.target.q), int(command.target.r))
			steps += 1
			if steps % 8 == 0:
				await app.get_tree().process_frame
		_check(not str(app.campaign.battle.outcome).is_empty(), "battle terminates under legal play")
		_check(app.campaign.battle.outcome == "victory", "seed1709 expedition %d victory" % expedition)
		await _capture(app, "06-result-%d" % expedition)
		app._resolve()
		_check(app.campaign.phase in ["growth", "returning"], "result resolves once before return travel")
		if app.campaign.phase == "growth":
			if expedition == 0:
				await _capture(app, "07-growth")
			app._growth_choice(str(app.campaign.growth_offers[0].id))
		_check(app.campaign.phase == "returning" and is_instance_valid(app.world_screen.return_button), "growth completion reaches the explicit return journey")
		if expedition == 0:
			await _capture(app, "08-world-return")
			app._manual_save()
			var returning_state: Dictionary = app.campaign.duplicate(true)
			app._load(app.manual_path)
			_check(app.campaign == returning_state and is_instance_valid(app.world_screen.return_button), "returning state reloads with its return control")
		await _activate_button(app, app.world_screen.return_button)
		_check(app.campaign.phase == "camp" and str(app.campaign.world.company_location_id) == "loc_greyshore_camp", "return button restores the company to camp")
		if expedition == 0:
			await _capture(app, "09-camp-life")
			var granary_state: Dictionary = app.campaign.world.location_states.get("loc_granary", {}).duplicate(true)
			app._show_world_view()
			await _real_map_location(app, "loc_granary")
			_check(not granary_state.is_empty() and str(granary_state.get("flags", {}).get("last_outcome", "")) == "victory", "victory return preserves the granary's latest outcome in world state")
			var granary_name: String = _world_location_name(app.campaign, "loc_granary")
			_check(app.world_screen.location_title.text.begins_with(granary_name) and (app.world_screen.location_body.text.contains("胜") or app.world_screen.location_body.text.contains("粮")), "returned company can inspect the granary's saved victory consequence on the map [expected=%s title=%s body=%s]" % [granary_name, app.world_screen.location_title.text, app.world_screen.location_body.text])
			_check(app.campaign.world.location_states.get("loc_granary", {}) == granary_state, "reading the returned granary record does not mutate its saved consequence")
			app._show_camp_view()
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
	app.get_window().size = Vector2i(1180, 740)
	await app.get_tree().process_frame
	_check(is_instance_valid(app.world_screen) and is_instance_valid(app.world_screen.map) and app.world_screen.map.get_global_rect().size.x > 0.0 and app.world_screen.map.get_global_rect().size.y > 0.0, "minimum window keeps a visible world-map control")
	_check(app.world_screen.camp_button.get_global_rect().end.y <= app.get_viewport_rect().size.y + 1.0 and app.route_buttons["road"].get_global_rect().end.y <= app.get_viewport_rect().size.y + 1.0 and app.route_buttons["ridge"].get_global_rect().end.y <= app.get_viewport_rect().size.y + 1.0, "minimum window keeps camp and both route controls inside the viewport")
	await _capture(app, "10-small-world")
	await _activate_button(app, app.route_buttons["road"])
	await _advance_until(app, "event")
	app._event_choice(str(app.campaign.event.choices[0].id))
	await _advance_until(app, "ready")
	app._enter_battle()
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	while str(Battle.active_unit(app.campaign.battle).get("kind", "")) != "hunter":
		app._end_turn()
	var hunter_actions: Array[String] = ["move", "attack", "defend", "mark", "command_follow", "command_pin", "command_recall", "oil", "fire", "water"]
	var hunter_ready := true
	for action_id: String in hunter_actions:
		hunter_ready = hunter_ready and app.action_buttons.has(action_id) and not app.action_buttons[action_id].disabled and app.action_buttons[action_id].is_visible_in_tree() and app.action_buttons[action_id].get_global_rect().end.y <= app.get_viewport_rect().size.y + 1.0
	_check(hunter_ready, "minimum window exposes every hunter skill and shared battle item as usable controls")
	_check(app.battle_hud.action_box.get_child_count() == 7 and app.battle_hud.item_box.get_child_count() == 3, "minimum-window hunter keeps seven skills and three items in their HUD groups")
	_check(app.battle_hud.dock.size.y <= 260.0 and app.battle_hud.top_summary.size.y <= 80.0 and app.battle_hud.queue_box.size.y <= 50.0, "minimum-window HUD preserves bounded dock, summary, and timeline heights")
	var hunter: Dictionary = Battle.active_unit(app.campaign.battle)
	app.board._layout()
	var hunter_upper: Vector2 = app.board._unit_display_point(hunter) + Vector2(0, -30)
	var hunter_direct_hit: Dictionary = app.board._unit_hit_at(hunter_upper)
	_check(str(hunter_direct_hit.get("id", "")) == str(hunter.id), "minimum-window upper-body hit-test belongs to the hunter [expected=%s actual=%s point=%s]" % [hunter.id, hunter_direct_hit.get("id", ""), hunter_upper])
	await _real_unit_hover(app, hunter)
	_check(app.hovered_unit_id == str(hunter.id) and app.hovered_cell == Vector2i(int(hunter.q), int(hunter.r)), "minimum-window real upper-body hover resolves the hunter [expected=%s@%s actual=%s@%s]" % [hunter.id, Vector2i(int(hunter.q), int(hunter.r)), app.hovered_unit_id, app.hovered_cell])
	_check(app.battle_hud.inspection_panel.visible and app.battle_hud.inspection_title.text == str(hunter.name), "minimum-window hunter tooltip opens with the correct identity [expected=%s actual=%s visible=%s]" % [hunter.name, app.battle_hud.inspection_title.text, app.battle_hud.inspection_panel.visible])
	_check(app.battle_hud.inspection_panel.size.y < app.get_viewport_rect().size.y and app.battle_hud.inspection_panel.get_global_rect().end.y <= app.battle_hud.dock.get_global_rect().position.y + 1.0, "minimum-window hunter tooltip remains above the command dock")
	app._set_speed(3.0)
	await _capture(app, "09-small-hunter-hud")
	app._retreat()
	var retired_hud: Control = app.battle_hud
	app._resolve()
	_check(app.campaign.phase == "returning" and app.campaign.flags.last_outcome == "retreat", "retreat resolves into the return journey")
	app._return_to_camp()
	_check(app.campaign.phase == "camp" and app.campaign.flags.last_outcome == "retreat", "retreat return reaches camp with its outcome preserved")
	app._autosave()
	app._load(app.save_path)
	await app.get_tree().process_frame
	_check(app.battle_hud == null and not is_instance_valid(retired_hud) and app.screen.visible, "loading camp removes the old battle board, HUD, and tooltip layer")
	var reload_result: Dictionary = Saves.load_campaign(app.save_path)
	_check(reload_result.get("ok", false), "final autosave readable")
	app.get_window().size = Vector2i(1180, 740)
	await _capture(app, "10-small-window")
	app._show_world_view()
	await _activate_button(app, app.route_buttons["road"])
	await _advance_until(app, "event")
	app._event_choice(str(app.campaign.event.choices[0].id))
	await _advance_until(app, "ready")
	app._enter_battle()
	await app.get_tree().process_frame
	_check(is_instance_valid(app.battle_hud) and app.battle_hud.get_parent() == app and not app.screen.visible and not app.battle_hud.inspection_panel.visible, "re-entering battle creates one clean HUD without a stale tooltip")
	await _capture(app, "11-small-battle")
	_check(app.end_button.get_global_rect().end.y < app.get_viewport_rect().size.y, "small-window end-turn remains visible")
	# A separate playable route and archer fixture verifies the actual UI wiring.
	app._new_campaign("free", 1842)
	await _capture(app, "12-small-routes")
	var ridge: Dictionary = Campaign.get_routes(app.campaign)[1]
	await _activate_button(app, app.route_buttons["ridge"])
	_check(app.campaign.phase == "travel" and app.campaign.expedition.route_id == "ridge", "ridge button starts its own saved route")
	_check(app.campaign.expedition.reward == ridge.reward and app.campaign.expedition.difficulty == ridge.difficulty, "ridge UI preview matches generated expedition")
	app._manual_save()
	var route_state: Dictionary = app.campaign.duplicate(true)
	app._load(app.manual_path)
	_check(app.campaign == route_state, "ridge route choice and travel position survive UI save/load without reroll")
	await _advance_until(app, "event")
	app._manual_save()
	var ridge_event_state: Dictionary = app.campaign.duplicate(true)
	app._load(app.manual_path)
	_check(app.campaign == ridge_event_state, "ridge event instance survives UI save/load without reroll")
	app._event_choice(str(app.campaign.event.choices[0].id))
	await _advance_until(app, "ready")
	app._enter_battle()
	app._end_turn()
	app._end_turn()
	_check(Battle.active_unit(app.campaign.battle).kind == "archer", "archer gets actual turn for range verification")
	app._choose_action("attack")
	var range_snapshot: Dictionary = app.board._action_overlay.duplicate(true)
	_check(not range_snapshot.range_cells.is_empty() and not range_snapshot.blocked_cells.is_empty(), "archer overlay separates range and cover obstruction")
	await _capture(app, "13-small-archer-range")
	app._on_cell_hovered(5, 2)
	app._on_cell_hovered(-1, -1)
	_check(app.board._action_overlay == range_snapshot and not app.board._preview.has("q"), "leaving board clears hover without hiding persistent range")
	app.get_window().size = Vector2i(1440, 900)
	await _capture(app, "14-archer-range")
	app._choose_action("oil")
	app._on_cell_hovered(3, 2)
	_check(app.board._preview.get("ok", false) and app.board._preview.get("affected", []).size() > 1, "element targeting exposes its affected area")
	await _capture(app, "15-element-area")
	app._choose_action("move")
	_check(app.board._action_overlay.get("range_cells", []).is_empty() and not app.reachable.is_empty(), "switching to movement clears attack range")
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

func _living_queue(battle: Dictionary) -> Array[String]:
	var result: Array[String] = []
	if battle.order.is_empty():
		return result
	for step in range(battle.order.size()):
		var id: String = str(battle.order[(int(battle.turn_index) + step) % battle.order.size()])
		for unit: Dictionary in battle.units:
			if str(unit.id) == id and int(unit.hp) > 0:
				result.append(id)
				break
	return result

func _first_unit(battle: Dictionary, team: String) -> Dictionary:
	for unit: Dictionary in battle.units:
		if str(unit.team) == team and int(unit.hp) > 0:
			return unit
	return {}

func _unit_name(battle: Dictionary, unit_id: String) -> String:
	for unit: Dictionary in battle.units:
		if str(unit.id) == unit_id:
			return str(unit.name)
	return ""

func _world_location_name(campaign: Dictionary, location_id: String) -> String:
	for location: Dictionary in Campaign.get_world_view(campaign).get("locations", []):
		if str(location.get("id", "")) == location_id:
			return str(location.get("name", ""))
	return ""

func _real_unit_hover(app: Control, unit: Dictionary) -> void:
	app.board._layout()
	var local_point: Vector2 = app.board._offset + (app.board._unit_display_point(unit) + Vector2(0, -30)) * app.board._scale
	var screen_point: Vector2 = app.get_viewport().get_screen_transform() * (app.board.global_position + local_point)
	var motion := InputEventMouseMotion.new()
	motion.position = screen_point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	await app.get_tree().process_frame
	await app.get_tree().process_frame

func _real_map_location(app: Control, location_id: String) -> void:
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	var map: Control = app.world_screen.map
	map._layout()
	var location: Dictionary = {}
	for item in map._world.get("locations", []):
		if item is Dictionary and str(item.get("id", "")) == location_id:
			location = item
			break
	_check(not location.is_empty(), "map fixture contains location " + location_id)
	if location.is_empty():
		return
	var local_point: Vector2 = map._offset + map._location_point(location) * map._scale
	var screen_point: Vector2 = app.get_viewport().get_screen_transform() * (map.global_position + local_point)
	var motion := InputEventMouseMotion.new()
	motion.position = screen_point
	motion.global_position = screen_point
	Input.parse_input_event(motion)
	await app.get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = screen_point
	click.global_position = screen_point
	click.pressed = true
	Input.parse_input_event(click)
	await app.get_tree().process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await app.get_tree().process_frame

func _advance_until(app: Control, target_phase: String) -> void:
	var steps := 0
	while str(app.campaign.phase) != target_phase and str(app.campaign.phase) == "travel" and steps < 12:
		_check(is_instance_valid(app.world_screen) and is_instance_valid(app.world_screen.advance_button), "travel step exposes a real continue button")
		if not is_instance_valid(app.world_screen) or not is_instance_valid(app.world_screen.advance_button):
			return
		await _activate_button(app, app.world_screen.advance_button)
		steps += 1
	_check(str(app.campaign.phase) == target_phase, "travel reaches %s within its saved route" % target_phase)

func _node_text(root: Node) -> String:
	var lines: Array[String] = []
	_collect_node_text(root, lines)
	return "\n".join(lines)

func _collect_node_text(root: Node, lines: Array[String]) -> void:
	if root is Label:
		lines.append(str(root.text))
	elif root is Button:
		lines.append(str(root.text))
	for child: Node in root.get_children():
		_collect_node_text(child, lines)

func _activate_button(app: Control, button: Button) -> void:
	# Campaign actions rebuild the entire screen. Give the replacement controls
	# two layout passes before reading their global rectangles for native input.
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	if not is_instance_valid(button):
		_check(false, "button remains valid after the rebuilt screen settles")
		return
	if DisplayServer.get_name() == "headless":
		button.pressed.emit()
		await app.get_tree().process_frame
		return
	await _real_click(app, button.get_global_rect().get_center())

func _real_click(app: Control, point: Vector2) -> void:
	point = app.get_viewport().get_screen_transform() * point
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	Input.parse_input_event(motion)
	await app.get_tree().process_frame
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = point
	click.global_position = point
	click.pressed = true
	Input.parse_input_event(click)
	await app.get_tree().process_frame
	click.pressed = false
	Input.parse_input_event(click)
	await app.get_tree().process_frame

func _capture(app: Control, name: String) -> void:
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var screenshot: Image = app.get_viewport().get_texture().get_image()
	var error: Error = screenshot.save_png(output.path_join(name + ".png"))
	_check(error == OK, "screenshot " + name)
