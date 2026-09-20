extends SceneTree
const Document=preload("res://presentation/paperdoll_document.gd")
const Workbench=preload("res://presentation/paperdoll_workbench.gd")
const Actor=preload("res://presentation/static_bust_actor.gd")
var passed:=0
var failed:=0

func check(value:bool,message:String) -> void:
	if value:passed+=1
	else:failed+=1;printerr("PAPERDOLL: "+message)

func _initialize() -> void:call_deferred("run")

func run() -> void:
	var d=Document.new();var original:=JSON.stringify(Actor.catalog())
	check(d.composed()==d.baseline,"zero edits equal approved v3")
	check(d.change("bust",Vector2(2,-1),1),"move group")
	var data:Dictionary=d.composed()
	check(data.parts.base==d.baseline.parts.base and data.bust_crop==d.baseline.bust_crop,"base and crop stay locked")
	for id in Document.GROUPS.bust:
		check(is_equal_approx(data.parts[id].position[0],d.baseline.parts[id].position[0]+2),"group shared x: "+id)
	check(d.change("head",Vector2(-1,2),.9),"head scale and offset")
	data=d.composed()
	check(data.parts.head.position==data.parts.wounded.position and data.parts.head.size==data.parts.wounded.size,"paired faces stay registered")
	check(is_equal_approx(data.parts.head.size[0]/data.parts.head.size[1],d.baseline.parts.head.size[0]/d.baseline.parts.head.size[1]),"uniform scaling")
	d.undo();check(d.edits.size()==1,"undo one edit");d.redo();check(d.edits.size()==2,"redo one edit")
	d.undo();d.change("mail",Vector2.ONE,1.02);check(d.future.is_empty(),"new branch clears redo")
	d.reset_all();check(d.edits.is_empty(),"reset all");d.undo();check(d.edits.size()==2,"reset undoable")
	check(not d.change("base",Vector2.ONE,1),"cannot move base")
	check(not d.change("bust",Vector2.ZERO,.9),"cannot scale whole group")
	check(not d.change("head",Vector2(INF,0),1),"reject infinite position")
	check(not d.change("head",Vector2.ZERO,NAN),"reject nan scale")
	check(not d.change("head",Vector2(129,0),1),"reject excessive movement")
	for invalid in [null,[],{}, {"schema":99}, {"kind":"fantasy-brothers-paperdoll","schema":1,"baseline_sha256":"old","edits":{}}]:
		check(not d.validate(invalid).is_empty(),"malformed or incompatible file rejected")
	for invalid_edit in [{"offset":["x",0],"scale":1},{"offset":[0],"scale":1},{"offset":[0,0],"scale":3.01},{"offset":[0,0],"scale":1,"atlas":"x"}]:
		var payload:Dictionary=d.payload();payload.edits={"head":invalid_edit};check(not d.validate(payload).is_empty(),"invalid edit rejected")
	var payload:Dictionary=d.payload();payload.edits.base={"offset":[1,0],"scale":1};check(not d.validate(payload).is_empty(),"file cannot bypass locked base")
	var dir:="user://paperdoll-qa";DirAccess.make_dir_recursive_absolute(dir)
	var path:=dir+"/roundtrip.json"
	check(d.save_project(path)=="","save draft")
	check(not d.dirty(),"save clears dirty")
	var restored=Document.new();check(restored.load_project(path)=="" and restored.composed()==d.composed(),"round trip exact render data")
	d.change("head",Vector2.ONE,1);check(d.dirty(),"dirty after change")
	check(d.save_project(path)=="" and FileAccess.file_exists(path+".bak"),"overwrite keeps previous copy")
	check(Document.write_json(Actor.CATALOG,{})!="","catalog protected from editor write")
	check(Document.write_json("relative.json",{})!="","relative output cannot target resources")
	check(Document.output_path_error("res://assets/art/static-bust/anatomy.png")!="","screenshot path cannot overwrite original art")
	check(Document.write_json(dir+"/wrong.png",{})!="","non-json write blocked")
	var before:Dictionary=d.edits.duplicate(true)
	var file:=FileAccess.open(dir+"/broken.json",FileAccess.WRITE);file.store_string("{broken");file.close()
	check(d.load_project(dir+"/broken.json")!="" and d.edits==before,"bad load is transactional")
	d.reset_all();d.change("bow",Vector2(2,-3),1.1);data=d.composed()
	var launch:=Actor.nocked_arrow(Actor.Motion.release("bow"),data)
	var flight:=Actor.arrow_sample(Actor.Motion.release("bow"),"hit",data)
	check(launch.position.distance_to(flight.position)<.0001,"adjusted bow arrow leaves without jump")
	check(absf(launch.angle-flight.angle)<.0001,"adjusted launch tangent matches")
	check(Actor.arrow_sample(Actor.Motion.contact("bow"),"hit",data).position==Actor.Motion.ARROW_TARGET,"edited bow keeps result anchor")
	d.change("bow",Vector2(0,20),1.3);check(not d.warnings().is_empty(),"bow ground crossing reported")
	check(JSON.stringify(Actor.catalog())==original,"editor cannot mutate baseline cache")
	var ui=Workbench.new();root.add_child(ui);await process_frame;await process_frame
	ui.select_group("head");ui.x_field.value=2
	check(ui.document.transform_for("head").offset[0]==2,"numeric input reaches document")
	ui.document.undo();ui.refresh();check(ui.x_field.value==0,"undo updates controls")
	ui.set_layer_visible("head",false);check("wounded" in ui.hidden_layers and "head" in ui.hidden_layers,"hide both head states")
	ui.set_layer_visible("head",true);check(not "head" in ui.hidden_layers,"show layer")
	ui.select_group("bust");check(not ui.size_field.editable,"group scale control locked")
	ui.select_group("head")
	var button:=InputEventMouseButton.new();button.button_index=MOUSE_BUTTON_LEFT;button.pressed=true;button.position=Vector2(200,200);ui.stage_input(button)
	var motion:=InputEventMouseMotion.new();motion.position=button.position+Vector2(ui.camera().scale*2,0);ui.stage_input(motion)
	button.pressed=false;ui.stage_input(button)
	check(ui.document.transform_for("head").offset[0]==2,"drag moves selected part in logical coordinates")
	ui.document.undo();ui.refresh();check(ui.document.transform_for("head").offset[0]==0,"whole drag is one undo")
	ui.weapon="bow";ui.playing=true;ui._process(.3);check(ui.progress>0,"motion advances")
	ui.slider.value=.6;check(not ui.playing and is_equal_approx(ui.progress,.6),"scrubbing pauses")
	ui._save_project(dir+"/ui.json");ui.document.change("head",Vector2.ONE,1)
	check(ui.open_project(dir+"/ui.json") and not ui.document.dirty(),"UI reload saved configuration")
	ui.document.change("head",Vector2.ONE,1);ui.request_close();check(ui._close_dialog.visible,"dirty close preserves chance to save")
	ui._close_dialog.hide();ui.queue_free();await process_frame
	check(FileAccess.get_sha256(Actor.CATALOG)==d.fingerprint,"source file unchanged")
	print("Paperdoll checks: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
