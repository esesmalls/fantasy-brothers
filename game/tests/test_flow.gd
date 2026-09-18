extends SceneTree
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
const Saves = preload("res://core/save_store.gd")
const Policy = preload("res://tests/play_policy.gd")
var failures: int = 0
var checks: int = 0
var victories: int = 0
var defeats: int = 0

func _initialize() -> void:
	for seed_value in range(1700, 1720):
		for origin in ["free", "hunters"]:
			var c: Dictionary = Campaign.create_campaign(origin, seed_value)
			for expedition in range(3):
				var route_id: String = "ridge" if seed_value >= 1710 and int(c.food) >= 3 else "road"
				_check(Campaign.start_expedition(c, route_id).ok, "expedition starts on " + route_id)
				_check(Campaign.choose_event(c, str(c.event.choices[0].id)).ok, "legal event choice")
				c.battle = Battle.create_battle(c.roster, seed_value + int(c.expedition.index) * 7919, Campaign.battle_config(c))
				c.phase = "battle"
				var steps: int = 0
				while str(c.battle.outcome).is_empty() and steps < 900:
					var u: Dictionary = Battle.active_unit(c.battle)
					if u.team == "enemy" or u.kind == "dog":
						Battle.ai_step(c.battle)
					else:
						var command: Dictionary = Policy.next_command(c.battle)
						if command.is_empty():
							Battle.end_turn(c.battle)
						else:
							Battle.apply_action(c.battle, str(u.id), str(command.action), command.target)
					steps += 1
					if steps == 5:
						_check(Saves.save_campaign(c, "user://qa/flow.json").ok, "save active battle")
						var restored: Dictionary = Saves.load_campaign("user://qa/flow.json")
						_check(restored.get("ok", false), "load active battle")
						if restored.get("ok", false):
							c = restored.campaign
				_check(not str(c.battle.outcome).is_empty(), "seed %d/%s/%d terminates" % [seed_value, origin, expedition])
				if c.battle.outcome == "victory":
					victories += 1
				else:
					defeats += 1
				_check(Campaign.resolve_battle(c, c.battle).ok, "resolve once")
				_check(not Campaign.resolve_battle(c, c.battle).ok, "duplicate resolution rejected")
				if c.phase == "growth":
					_check(Campaign.choose_growth(c, str(c.growth_offers[0].id)).ok, "growth delivered")
				for unused in range(4):
					Campaign.camp_action(c, "recruit")
					Campaign.camp_action(c, "rest")
				Campaign.camp_action(c, "repair")
				Campaign.camp_action(c, "resupply")
				_check(str(c.phase) == "camp" and int(c.food) >= 2, "can continue after losses")
			_check(bool(c.flags.ending_seen), "ending always reached")
	print("Campaign flow: %d checks; %d failures; %d victories, %d other outcomes across 20 seeds x 2 origins x 3 expeditions" % [checks, failures, victories, defeats])
	quit(0 if failures == 0 else 1)

func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FLOW FAIL: " + label)
