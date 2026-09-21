extends SceneTree
const Document=preload("res://presentation/paperdoll_document.gd")
const Workbench=preload("res://presentation/paperdoll_workbench.gd")
const Actor=preload("res://presentation/static_bust_actor.gd")
const Motion=preload("res://presentation/static_bust_motion.gd")
var passed:=0
var failed:=0

func check(value:bool,message:String) -> void:
	if value:passed+=1
	else:failed+=1;printerr("AUTHORING: "+message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var original:=JSON.stringify(Actor.catalog())
	for weapon in ["sword","spear","bow"]:
		for p in [0.0,.25,.42,.53,.64,1.0]:
			var a:=Motion.sample(weapon,p)
			var b:=Motion.sample(weapon,p,"hit",Motion.default_action(weapon))
			check(a.position.distance_to(b.position)<.000001 and absf(a.angle-b.angle)<.000001,weapon+" default action matches hardcoded sample "+str(p))
		check(Motion.default_action(weapon).id==weapon,weapon+" keeps a stable action id")
		for key in Motion.default_action(weapon).keyframes:
			check(str(key.id).begins_with(weapon+"."),weapon+" keyframe id is stable: "+str(key.id))
	var d=Document.new()
	check(d.composed()==d.baseline and d.crop.is_empty() and d.actions.is_empty(),"authoring defaults keep existing composition")
	check(d.crop_spec()==d.baseline.bust_crop,"crop default equals current catalog window")
	var crop:=d.default_crop()
	check(not d.change_crop(Vector2(crop.center[0],crop.center[1]),Vector2(crop.radius[0],crop.radius[1]),crop.top),"writing the current crop is a no-op")
	check(d.change_crop(Vector2(crop.center[0]+4,crop.center[1]-2),Vector2(36,10),-90),"crop can expand past the old window")
	check(d.composed().bust_crop.radius[0]==36 and d.payload().schema==3,"edited crop is saved as schema 3")
	check(d.composed().parts.head==d.baseline.parts.head,"crop edit does not move parts")
	d.undo();check(d.crop.is_empty() and d.composed().bust_crop==d.baseline.bust_crop,"undo restores locked default crop")
	check(d.change("base",Vector2(3,-2),1),"base anchor is now editable")
	check(d.composed().parts.base.position==[3.0,-2.0],"base offset reaches the pedestal")
	check(d.composed().bust_crop==d.baseline.bust_crop,"base move leaves default crop")
	check(not d.change("base",Vector2(3,-2),1.2),"base scale stays locked")
	check(d.change_shared(["head","mail"],Vector2(1,-1),1.2,15),"shared scale and rotation apply together")
	check(is_equal_approx(d.transform_for("head").scale,1.2) and is_equal_approx(d.transform_for("mail").scale,1.2),"shared scale written")
	check(is_equal_approx(d.transform_for("head").angle,15) and is_equal_approx(d.transform_for("mail").angle,15),"shared rotation written")
	check(d.nudge_shared(["head","mail"],Vector2(2,0)),"shared nudge uses one history step")
	check(is_equal_approx(d.transform_for("head").offset[0],3) and is_equal_approx(d.transform_for("mail").offset[0],3),"shared offset nudged")
	d.undo();check(is_equal_approx(d.transform_for("head").offset[0],1),"shared nudge undoes as one step")
	var sword:=d.action_for("sword")
	for key in sword.keyframes:
		if key.id=="sword.contact":key.x=40;key.y=-36
	check(d.set_action("sword",sword),"authored sword path is stored")
	check(d.actions.sword.id=="sword" and d.payload().schema==3,"weapon action keeps a stable id")
	var authored:=Motion.sample("sword",.42,"hit",d.action_for("sword"))
	var stock:=Motion.sample("sword",.42)
	check(authored.position.x>stock.position.x,"preview uses the authored contact pose")
	check(Actor.motion_action("sword",d.composed()).id=="sword","composed catalog carries the action")
	check(d.reset_action("sword") and not d.actions.has("sword"),"reset returns the built-in sword path")
	check(Motion.sample("sword",.42)==stock,"reset preview matches the original resolve path")
	var invalid:=d.payload();invalid.schema=3;invalid.crop={"center":[0,0],"radius":[1,1],"top":-90}
	check(not d.validate(invalid).is_empty(),"tiny crop rejected")
	invalid=d.payload();invalid.schema=3;invalid.actions={"sword":{"id":"sword","weapon":"sword","duration":.86,"contact":.2,"release":.4,"keyframes":[]}}
	check(not d.validate(invalid).is_empty(),"empty action rejected")
	var dir:="user://paperdoll-authoring";DirAccess.make_dir_recursive_absolute(dir)
	d.change_crop(Vector2(crop.center[0],crop.center[1]),Vector2(40,12),-80)
	check(d.save_project(dir+"/stage.json")=="","save authored crop")
	var restored=Document.new();check(restored.load_project(dir+"/stage.json")=="","load authored crop")
	check(restored.crop.radius[0]==40 and restored.composed().bust_crop.top==-80,"crop roundtrip")
	d.reset_all()
	var ui=Workbench.new();root.add_child(ui);await process_frame;await process_frame
	ui.select_group("crop")
	check(ui.crop_box.visible and not ui.transform_box.visible,"crop editor shown")
	ui.crop_rx.value=40;check(is_equal_approx(ui.document.crop_spec().radius[0],40),"crop field writes the window")
	ui.document.undo();ui.refresh();check(ui.document.crop.is_empty(),"crop undo restores default")
	ui.select_groups(["head","linen"])
	check(ui.selected_groups==["head","linen"],"multi-select keeps both groups")
	ui.size_field.value=120
	check(is_equal_approx(ui.document.transform_for("head").scale,1.2) and is_equal_approx(ui.document.transform_for("linen").scale,1.2),"multi-select scale")
	ui.angle_field.value=-10
	check(is_equal_approx(ui.document.transform_for("head").angle,-10) and is_equal_approx(ui.document.transform_for("linen").angle,-10),"multi-select rotation")
	ui.select_group("sword")
	var contact_index:=0
	for i in range(ui.current_action().keyframes.size()):
		if ui.current_action().keyframes[i].id=="sword.contact":contact_index=i
	ui.select_keyframe(contact_index)
	ui.key_x.value=48
	check(is_equal_approx(ui.document.action_for("sword").keyframes[contact_index].x,48),"keyframe edit is stored")
	check(ui.document.action_for("sword").id=="sword","edited action keeps the same id")
	var preview:=Motion.sample("sword",.42,"hit",ui.document.action_for("sword"))
	check(preview.position.x>30,"workbench preview samples the authored pose")
	ui.document.reset_action("sword");ui.refresh()
	check(not ui.document.actions.has("sword"),"workbench can restore the built-in path")
	ui.queue_free();await process_frame
	check(JSON.stringify(Actor.catalog())==original,"authoring tests do not mutate the catalog")
	print("Paperdoll authoring checks: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
