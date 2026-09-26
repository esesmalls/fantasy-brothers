extends Node
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Saves = preload("res://core/save_store.gd")
const Equipment = preload("res://core/equipment_rules.gd")
const Company = preload("res://core/company_rules.gd")
const Policy = preload("res://tests/play_policy.gd")
const Runtime = preload("res://presentation/asset_runtime.gd")
var checks: Array = []
var output := ""

func check(ok: bool, message: String) -> void:
	checks.append({"ok": ok, "name": message})
	if not ok: push_error(message)

func capture(name: String) -> void:
	await get_tree().process_frame
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output.path_join(name + ".png"))

func run(app: Control) -> void:
	output = ProjectSettings.globalize_path("res://").get_base_dir().path_join("../builds/foundation/qa").simplify_path()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--foundation-output="): output = arg.trim_prefix("--foundation-output=")
	DirAccess.make_dir_recursive_absolute(output)
	app._new_campaign("free", 6023)
	app._show_camp_view()
	await capture("01-camp")
	if OS.get_cmdline_user_args().has("--foundation-packaged"):
		Runtime.current()
		check(Runtime.cached_directory.begins_with("res://"), "standalone export reads embedded assets, not loose workspace files")
	check(app.campaign.roster[0].has("appearance"), "roster stores stable appearance")
	var identity := JSON.stringify(app.campaign.roster[3].appearance)
	var purchase := Equipment.buy(app.campaign, "weapon_skirmisher_axe")
	check(purchase.get("ok", false), "camp buys an actual axe")
	if purchase.get("ok", false):
		check(Equipment.equip(app.campaign, str(app.campaign.roster[3].id), str(purchase.instance_id)).get("ok", false), "camp equips purchased axe")
	check(identity == JSON.stringify(app.campaign.roster[3].appearance), "gear change preserves the same person")
	app._show_equipment(str(app.campaign.roster[3].id))
	await capture("01-equipment")
	app._show_company()
	await capture("01-company")
	check(Company.get_view(app.campaign).candidates.size() >= 2, "company exposes saved recruitment choices")
	app._start_expedition("ridge")
	while app.campaign.phase == "travel": app._advance_travel()
	if app.campaign.phase == "event": app._event_choice(str(app.campaign.event.choices[0].id))
	while app.campaign.phase == "travel": app._advance_travel()
	app._enter_battle()
	await capture("02-battle")
	check(app.campaign.phase == "battle", "actual interface enters tactical battle")
	check(app.battle_hud.actor_stats.text.contains("疲劳"), "HUD shows actual fatigue")
	var actions := 0
	var observed := {}
	while app.campaign.battle.outcome == "" and actions < 650:
		var b: Dictionary = app.campaign.battle
		var unit := Battle.active_unit(b)
		var result := {}
		if unit.get("team", "") == "player" and unit.get("kind", "") != "dog" and int(unit.get("morale", 3)) > 0:
			if not observed.has("captured_player"):
				observed.captured_player = true
				await capture("03-player")
			var command := Policy.next_command(b)
			if command.is_empty(): result = {"ok": true, "events": Battle.end_turn(b)}
			else: result = Battle.apply_action(b, str(unit.id), str(command.action), command.target)
		else: result = Battle.ai_step(b)
		check(result.get("ok", false), "legal action %d" % actions)
		if not result.get("ok", false): break
		var snapshot := JSON.stringify(b)
		app._refresh_battle(result.get("events", []))
		var first_attack := false
		for event: Dictionary in result.get("events", []):
			observed[str(event.get("type", ""))] = true
			if event.get("type", "") == "attack" and not observed.has("captured_attack"):
				first_attack = true
		if first_attack:
			observed.captured_attack = true
			app.board.set_animation_speed(2.0)
			await get_tree().create_timer(0.25).timeout
			await capture("03-action")
		app.board.skip_animations()
		check(snapshot == JSON.stringify(b), "animation and skip preserve settled state %d" % actions)
		actions += 1
		if actions % 20 == 0: await get_tree().process_frame
	check(not str(app.campaign.battle.outcome).is_empty(), "complete battle reaches terminal outcome")
	check(observed.has("attack") and observed.has("hit"), "real actions delivered attack and damage feedback")
	check(Saves.validate(app.campaign).is_empty(), "terminal campaign saves: " + Saves.validate(app.campaign))
	await capture("04-result")
	app._resolve()
	check(app.campaign.phase in ["growth", "returning"], "actual interface settles battle")
	if app.campaign.phase == "growth": app._growth_choice(str(app.campaign.growth_offers[0].id))
	if app.campaign.phase == "returning": app._return_to_camp()
	check(app.campaign.phase == "camp", "actual interface returns to camp")
	await capture("05-return")
	check(Saves.load_campaign(app.save_path).get("ok", false), "exported game autosave reloads")
	var failures := 0
	for result: Dictionary in checks:
		if not result.ok: failures += 1
	var report := {"checks": checks, "failures": failures, "actions": actions, "observed": observed, "display": DisplayServer.get_name(), "note": "Automated exported-game rule and interface flow; not human mouse or audio approval."}
	var file := FileAccess.open(output.path_join("report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t")); file.close()
	print("Foundation exported flow: %d checks, %d failures" % [checks.size(), failures])
	get_tree().quit(0 if failures == 0 else 1)
