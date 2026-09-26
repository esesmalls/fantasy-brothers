extends SceneTree
## Regression for the actual command/AI/HUD/settlement path, not just rules calls.
const Main = preload("res://main.gd")
const Battle = preload("res://core/battle_rules.gd")
const Campaign = preload("res://core/campaign_rules.gd")
const World = preload("res://core/world_data.gd")
var checks := 0
var failures: Array[String] = []
var app: Control

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)

func setup(evacuation: bool = false, legacy: bool = false) -> Dictionary:
	app._clear_body()
	app.campaign = Campaign.create_campaign("free", 9113)
	var c: Dictionary = app.campaign
	if evacuation: Campaign.accept_contract(c, World.EVACUATION_ID, "road")
	else: Campaign.start_expedition(c)
	while c.phase == "travel": Campaign.advance_travel(c)
	if c.phase == "event": Campaign.choose_event(c, str(c.event.choices[0].id))
	while c.phase == "travel": Campaign.advance_travel(c)
	var config := Campaign.battle_config(c)
	if legacy: config.rules_version = "prototype-0.1.1"
	var b := Battle.create_battle(Campaign.battle_roster(c), 9113, config)
	Campaign.begin_battle(c, b)
	b = c.battle
	# Small deterministic endgame: a real fire action incapacitates the last foe.
	b.props.clear()
	for unit: Dictionary in b.units:
		if unit.team == "enemy": unit.hp = 0
	var last: Dictionary = b.units.back()
	last.hp = 1; last.armor = 0; last.q = 3; last.r = 2
	b.units[0].q = 2; b.units[0].r = 2
	b.turn_index = b.order.find(b.units[0].id)
	app.selected_action = "move"
	app._show_battle()
	return b

func kill_last_enemy() -> void:
	app._choose_action("fire")
	app._on_cell_clicked(3, 2)
	check(app.board.has_pending_animation(), "actual command starts its terminal animation")
	app.board.skip_animations()

func run() -> void:
	app = Main.new()
	root.add_child(app)
	app.set_process(false)
	app.save_path = "user://qa/battle-controller.json"
	for legacy: bool in [false, true]:
		var b := setup(false, legacy)
		kill_last_enemy()
		check(b.outcome == "victory", "last enemy defeated ends granary, legacy=%s" % legacy)
		check(app.resolve_button.visible and not app.end_button.visible, "terminal UI offers settlement, legacy=%s" % legacy)
		var snapshot := JSON.stringify(b)
		app._process(2.0)
		check(JSON.stringify(b) == snapshot, "automatic processing preserves terminal snapshot")
		app._resolve()
		check(app.campaign.phase in ["growth", "returning"], "settlement button leaves battle")
	var b := setup(true)
	kill_last_enemy()
	check(b.outcome == "" and not app.resolve_button.visible, "clearing evacuation enemies still requires the contract objective")
	check(app.outcome_label.text.contains("右侧撤离") and not app.outcome_label.text.contains("粮仓"), "evacuation shows its own objective instead of granary")
	check(app.preview_label.text.contains("撤离战场") and app.preview_label.text.contains("右侧"), "cleared evacuation explains the remaining command")
	# Position the survivors one step from the exit and use the actual move/flee buttons.
	for index in range(2):
		var unit: Dictionary = b.units[index]
		unit.q = 7; unit.r = index + 1; unit.ap = 6; unit.fatigue = 0
		b.turn_index = b.order.find(unit.id)
		app._refresh_battle()
		app._choose_action("move")
		app._on_cell_clicked(8, index + 1)
		app.board.skip_animations()
		app._choose_action("flee")
		app.board.skip_animations()
		check(b.objective.evacuated_ids.size() == index + 1, "move and exit commands advance evacuation %d" % (index + 1))
	check(b.outcome == "victory" and app.resolve_button.visible, "required evacuation count exposes settlement")
	check(app.outcome_label.text.contains("撤离"), "evacuation victory identifies the completed objective")
	app._resolve()
	check(app.campaign.phase in ["growth", "returning"], "evacuation settlement leaves battle")
	b = setup()
	var enemy: Dictionary = b.units.back()
	enemy.q = 8; enemy.r = 6; enemy.morale = 0
	b.turn_index = b.order.find(enemy.id)
	app._refresh_battle()
	app.ai_timer = 0.0
	app._process(1.0)
	check(enemy.escaped and b.outcome == "victory" and app.resolve_button.visible, "actual automatic AI exit of last enemy finishes battle")
	app.board.skip_animations()
	b = setup()
	var started := Time.get_ticks_usec()
	for index in range(10): app._refresh_battle()
	print("Controller move refresh average: %.2f ms" % ((Time.get_ticks_usec() - started) / 10000.0))
	app.queue_free()
	await process_frame
	print("Battle controller: %d checks; %d failures" % [checks, failures.size()])
	for failure in failures: printerr("FAIL: " + failure)
	quit(0 if failures.is_empty() else 1)
