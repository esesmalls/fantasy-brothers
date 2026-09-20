extends SceneTree
const Actor = preload("res://presentation/a_standard_actor.gd")
const Motion = preload("res://presentation/a_standard_motion.gd")
const Review = preload("res://presentation/a_standard_review.gd")
const Equipment = preload("res://core/equipment_data.gd")
const Campaign = preload("res://core/campaign_rules.gd")
const Battle = preload("res://core/battle_rules.gd")
var checks := 0
var failures: Array[String] = []

class Probe extends Control:
	var model: Dictionary
	var drawn := 0
	func _draw() -> void:
		for item in model.weapons:
			for armor in model.armors:
				var unit := {"kind":"guard","id":"crew_1","hp":30,"max_hp":80,"armor":0,"max_armor":24,"visual_loadout":{"weapon":item,"armor":armor}}
				var before := JSON.stringify(unit)
				assert(Actor.draw_actor(self,unit,Vector2(90,140),1.0,{"action":"attack","progress":.54}))
				assert(JSON.stringify(unit)==before)
				drawn += 1

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, label: String) -> void:
	checks += 1
	if not value: failures.append(label)

func run() -> void:
	var data := Actor.catalog()
	check(data.weapons.size()==10 and data.armors.size()==4,"all existing equipment covered")
	for key in Equipment.DEFINITIONS:
		check(data.weapons.has(key) or data.armors.has(key),"rule ID has art: "+key)
	check(data.faces.size()==12,"twelve stable identities")
	for origin in ["free","hunters"]:
		var state := Campaign.create_campaign(origin,824)
		var snapshot := Battle.create_battle(state.roster,824)
		for unit in snapshot.units:
			check(Actor.supports(unit),"actual roster/enemy has assets: "+str(unit.id))
	for face in data.faces:check(face.size()==4,"four expression states per identity")
	for armor in data.armors:
		check(data.armors[armor].size()==4,"four durability states "+armor)
		check(data.terminal[armor].size()==2,"two independently drawn recumbent poses "+armor)
	check(data.linen.atlas!=data.underlayer.atlas and data.underlayer.atlas!=data.armors.armor_padded[0].atlas,"linen, padding and outer shell are separate resources")
	var durations: Array = []
	for key in data.weapons:
		var time := Motion.timing(key)
		durations.append(time.duration)
		check(time.wind_end<time.contact and time.contact<time.brake_end and time.brake_end<time.hold_end and time.rebound_end<time.duration,"ordered seconds "+key)
		var early := (float(time.brake_end)+.001)/float(time.duration)
		var late := (float(time.hold_end)-.001)/float(time.duration)
		var unit := {"kind":"guard","id":"crew_3","visual_loadout":{"weapon":key}}
		var a := Actor.rig(unit,{"action":"attack","progress":early})
		var b := Actor.rig(unit,{"action":"attack","progress":late})
		check(a.grip==b.grip and a.weapon_angle==b.weapon_angle and a.body_angle==b.body_angle,"true contact hold "+key)
		check(Motion.target_response(key,"attack",early)==Motion.target_response(key,"attack",late),"target holds with attacker "+key)
		check(not Motion.sample(key,"attack",early,"miss").holding and Motion.target_response(key,"attack",early,"miss")==0,"miss never sticks "+key)
		check(not Motion.sample(key,"idle",early).weapon_front and Motion.target_response(key,"idle",early)==0,"passive pose causes no impact "+key)
		if Motion.is_bow(str(time.family)):
			check(time.release<time.contact and data.weapons[key].string_ends.size()==2,"arrow release precedes target impact "+key)
		check(Motion.sample(key,"attack",early).weapon_front,"attack uses foreground weapon pass "+key)
	check(durations.max()-durations.min()>.4,"weapons have distinct pacing")
	check(Motion.timing("weapon_skirmisher_axe").hold_end-Motion.timing("weapon_skirmisher_axe").brake_end > Motion.timing("weapon_skirmisher_blade").hold_end-Motion.timing("weapon_skirmisher_blade").brake_end,"axe resistance longer than knife")
	for stage in range(4):
		check(Actor.damage_stage({"armor":[24,12,5,0][stage],"max_armor":24})==stage,"durability threshold %d"%stage)
	var campaign_unit := {"id":"crew_4","name":"fixed identity","kind":"archer"}
	var before := JSON.stringify(campaign_unit)
	var original_id := Actor.identity(campaign_unit)
	campaign_unit.visual_loadout={"weapon":"weapon_guard_cleaver","armor":"armor_mail"}
	check(Actor.identity(campaign_unit)==original_id,"equipment never changes identity")
	campaign_unit.erase("visual_loadout")
	check(JSON.stringify(campaign_unit)==before,"identity resolution is read only")
	var scene := Review.new()
	root.add_child(scene)
	scene.set_process(false)
	await process_frame
	scene.replay();scene.paused=false;scene._process(.85)
	check(scene.impact_count==1,"one impact crossing contact")
	scene._process(.03)
	check(scene.impact_count==1,"no repeat impact during hold/recovery")
	scene.paused=true
	var old_progress: float=scene.progress
	scene._process(1)
	check(scene.progress==old_progress and scene.impact_count==1,"pause freezes clock")
	scene.action="idle";scene.replay();scene._process(.8)
	check(scene.impact_count==1,"idle has no hit sound or impact")
	scene.action="shield_bash";scene.replay();scene._process(.8)
	check(scene.impact_count==2,"shield bash shares single contact boundary")
	scene.queue_free()
	if DisplayServer.get_name()!="headless":
		var probe:=Probe.new();probe.model=data;root.add_child(probe)
		await process_frame
		await RenderingServer.frame_post_draw
		check(probe.drawn>=40,"real renderer drew all forty loadouts without model changes")
		probe.queue_free()
	print("A standard: %d checks; %d failures"%[checks,failures.size()])
	for failure in failures:printerr(failure)
	quit(0 if failures.is_empty() else 1)
