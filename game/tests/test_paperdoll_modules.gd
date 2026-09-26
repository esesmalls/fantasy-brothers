extends SceneTree
const D=preload("res://presentation/paperdoll_document.gd")
const A=preload("res://presentation/static_bust_actor.gd")
const VisualProfile=preload("res://presentation/visual_profile.gd")
const ModularActor=preload("res://presentation/modular_actor.gd")
var passed:=0
var failed:=0
func check(ok:bool,label:String) -> void:
	if ok:passed+=1
	else:failed+=1;printerr("MODULES: "+label)
func _initialize() -> void:call_deferred("run")
func run() -> void:
	var latest:=D.new()
	check(latest.load_project(ProjectSettings.globalize_path("../my_test-v2.json"))=="","latest my_test-v2 loads")
	var runtime:=A.runtime_catalog()
	var expected_runtime:=latest.composed()
	check(VisualProfile.profile().get("anchor_space","")=="cell_center","runtime profile uses the unit cell center")
	check(runtime.get("assembly",{}).get("head","")=="modular","runtime profile preserves my_test-v2 appearance")
	check(Vector2(runtime.parts.head.position[0],runtime.parts.head.position[1]).distance_to(Vector2(expected_runtime.parts.head.position[0],expected_runtime.parts.head.position[1]))<0.001,"head uses board-origin mapping")
	check(Vector2(runtime.parts.mail.position[0],runtime.parts.mail.position[1]).distance_to(Vector2(expected_runtime.parts.mail.position[0],expected_runtime.parts.mail.position[1]))<0.001,"mail uses board-origin mapping")
	var sample:={"id":"crew_1","kind":"guard","visual_loadout":{"armor":"armor_mail","weapon":"weapon_guard_sword"},"hp":30,"max_hp":40,"armor":20,"max_armor":24}
	check(VisualProfile.supports(sample) and ModularActor.supports(sample),"formal board accepts the runtime visual profile")
	check(runtime.get("bust_crop",{}).get("radius",[])[0]==30.25,"runtime crop comes from my_test-v2")
	var d=D.new()
	check(d.change("spear",Vector2(-60,45),1.6,true,-30),"wide move, scale and rotation accepted")
	check(not d.change("head",Vector2.ZERO,1,true,181),"rotation bounded")
	check(not d.change("head",Vector2.ZERO,1,true,INF),"nonfinite rotation rejected")
	check(not d.change("bust",Vector2.ZERO,1,true,1),"whole bust rotation locked")
	var base:Dictionary=d.baseline.duplicate(true)
	d.change("head",Vector2(4,-5),1.2,true,30)
	var data:Dictionary=d.composed()
	var anchor:=Vector2(base.parts.head.position[0],base.parts.head.position[1])
	for id in ["hair","beard","scar","bandage"]:
		var original:=Vector2(base.parts[id].position[0],base.parts[id].position[1])
		var expected:=anchor+((original-anchor)*1.2).rotated(PI/6)+Vector2(4,-5)
		check(Vector2(data.parts[id].position[0],data.parts[id].position[1]).distance_to(expected)<.0001,id+" follows parent transform")
		check(is_equal_approx(data.parts[id].rotation,PI/6),id+" inherits angle")
	check(data.parts.base==base.parts.base and data.bust_crop==base.bust_crop,"base and crop locked through rotations")
	d.change("scar",Vector2(2,1),.8,true,-12);data=d.composed()
	check(is_equal_approx(data.parts.scar.rotation,deg_to_rad(18)),"child angle composes with parent")
	check(is_equal_approx(data.parts.scar.size[0],base.parts.scar.size[0]*.96),"child scale composes")
	d.change("skin",Vector2(3,1),1.1,true,-10);data=d.composed()
	check(is_equal_approx(data.parts.blood.rotation,deg_to_rad(-10)),"blood follows skin")
	for id in ["linen","head","scar"]:
		var part:Dictionary=data.parts[id]
		for uv in [Vector2.ZERO,Vector2(.37,.64),Vector2.ONE]:
			var point:=A.part_point(part,uv*Vector2(part.size[0],part.size[1]))
			check(A.part_uv(part,point).distance_to(uv)<.00001,id+" rotated crop UV inverse")
	d.set_appearance("head","modular");d.set_appearance("scar",true);d.undo()
	check(not d.appearance.scar and d.appearance.head=="modular","undo appearance toggle")
	d.redo();check(d.appearance.scar,"redo appearance toggle")
	var path:="user://paperdoll-modules.json"
	check(d.save_project(path)=="","save schema2")
	var restored=D.new();check(restored.load_project(path)=="" and restored.composed()==d.composed(),"schema2 exact composition roundtrip")
	var legacy:={"schema":1,"kind":"fantasy-brothers-paperdoll","baseline_sha256":d.fingerprint,"edits":{"spear":{"offset":[-20,13],"scale":1}}}
	D.write_json("user://paperdoll-old-user.json",legacy)
	check(restored.load_project("user://paperdoll-old-user.json")=="","legacy draft accepted")
	check(restored.transform_for("spear").offset==[-20.0,13.0] and restored.transform_for("spear").angle==0,"legacy positioning preserved")
	check(restored.dirty() and restored.appearance==D.DEFAULT_APPEARANCE,"legacy migration clearly marked")
	var before:Dictionary=restored.snapshot();var bad:Dictionary=d.payload();bad.modules_sha256="unknown"
	D.write_json("user://paperdoll-bad-module.json",bad)
	check(restored.load_project("user://paperdoll-bad-module.json")!="" and restored.snapshot()==before,"incompatible module load transactional")
	bad=d.payload();bad.appearance.blood="true";check(not d.validate(bad).is_empty(),"typed appearance flags")
	for angle in [-180,-109.5,-90,-20,0,19.5,90,180]:
		d.change("bow",Vector2(-8,2),1.3,true,angle);data=d.composed()
		var launch:=A.nocked_arrow(A.Motion.release("bow"),data)
		var first:=A.arrow_sample(A.Motion.release("bow"),"hit",data)
		check(first.position.distance_to(launch.position)<.0001,"rotated bow departure position "+str(angle))
		check(absf(wrapf(first.angle-launch.angle,-PI,PI))<.0001,"rotated bow departure tangent "+str(angle))
		for p in [.44,.6,.76]:
			var point:=A.arrow_sample(p,"hit",data)
			check(point.position.is_finite() and is_finite(point.angle) and point.position.length()<1000,"finite rotated flight "+str(angle))
		check(A.arrow_sample(.76,"hit",data).position.distance_to(A.Motion.ARROW_TARGET)<.0001,"rotated flight fixed destination")
	check(d.baseline==base,"baseline never mutated")
	print("Paperdoll module checks: %d passed, %d failed"%[passed,failed]);quit(1 if failed else 0)
