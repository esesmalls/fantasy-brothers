extends RefCounted
const Actor=preload("res://presentation/static_bust_actor.gd")
const Document=preload("res://presentation/paperdoll_document.gd")
var checks:=0
var failures:Array[String]=[]
var canvas:Control
var viewport:SubViewport
var ui:Control
var output:String

class Sample extends Control:
	var data:Dictionary
	var armor:="linen"
	var omitted:Array=[]
	func _draw() -> void:
		draw_rect(Rect2(0,0,512,420),Color("e7e0d2"))
		Actor.draw_body(self,Vector2(215,350),6,armor,false,false,data,["head","wounded","base"]+omitted)

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("Nested wear: "+label)

func render(name:String,armor:String,hidden:Array,damage:Dictionary={}) -> Image:
	canvas.armor=armor;canvas.omitted=hidden;canvas.data=Actor.catalog().duplicate(true);canvas.data.wear_damage=damage
	canvas.queue_redraw();viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	await ui.get_tree().process_frame;await RenderingServer.frame_post_draw
	var img:Image=viewport.get_texture().get_image()
	check(img.save_png(output.path_join(name+".png"))==OK,"capture "+name)
	return img

func color(img:Image,point:Vector2) -> Color:
	var at:=Vector2i(Vector2(215,350)+point*6)
	return img.get_pixel(at.x,at.y)

func difference(a:Color,b:Color) -> float:
	return Vector3(a.r,a.g,a.b).distance_to(Vector3(b.r,b.g,b.b))

func run(workbench:Control,directory:String) -> void:
	ui=workbench;output=directory
	if DisplayServer.get_name()=="headless":ui.get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var current:=Actor.catalog();var v3:=Actor.v3_catalog()
	for id in current.parts:
		for field in ["rect","position","size","pivot"]:check(current.parts[id][field]==v3.parts[id][field],id+" preserves "+field)
	check(current.bust_crop==v3.bust_crop and current.parts.base==v3.parts.base,"base and crop preserved")
	var d=Document.new();var legacy:=d.payload();legacy.baseline_sha256=FileAccess.get_sha256(Actor.V3_CATALOG)
	legacy.edits={"linen":{"offset":[-.5,-2.3],"scale":1.0}}
	check(d.validate(legacy).is_empty(),"v3 user adjustments remain compatible")
	var legacy_lf:=FileAccess.get_file_as_string(Actor.V3_CATALOG).replace("\r\n","\n")
	for text_version in [legacy_lf,legacy_lf.replace("\n","\r\n")]:
		var portable:=legacy.duplicate(true);portable.baseline_sha256=text_version.sha256_text()
		check(d.validate(portable).is_empty(),"v3 drafts portable across Git LF and old Windows CRLF")
	Document.write_json(output.path_join("v3-draft.json"),legacy)
	check(d.load_project(output.path_join("v3-draft.json"))=="" and d.migrated_v3 and d.dirty(),"v3 loaded without losing offsets, marked for re-save")
	check(d.transform_for("linen").offset==[-.5,-2.3],"preserve user linen offset")
	check(d.save_project(output.path_join("migrated-draft.json"))=="" and not d.migrated_v3 and not d.dirty(),"re-save updates baseline signature")
	check(Actor.body_layers("mail",true,false,{"mail":true,"padded":false})==["base","body","linen","padded","mail_damaged","head"],"outer damage independent from intact padding")
	check(ui.preview_catalog(current,"mail",true).wear_damage=={"mail":true,"padded":false},"workbench defaults to damage on outer armor only")
	ui.damage_scope="padding"
	check(ui.preview_catalog(current,"mail",true).wear_damage=={"mail":false,"padded":true},"workbench can inspect damaged padding under intact mail")
	ui.damage_scope="outer"
	check(not ui.document.composed().has("wear_damage"),"preview damage never leaks into saved candidate")
	viewport=SubViewport.new();viewport.size=Vector2i(512,420);ui.add_child(viewport)
	canvas=Sample.new();canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;viewport.add_child(canvas)
	var linen_on:=await render("linen-with-underwear","linen",[])
	var linen_off:=await render("linen-alone","linen",["body"])
	# Interior of the V, away from the antialiased collar edge at y=-20.
	var neck:=Vector2(12.5,-22)
	check(difference(color(linen_on,neck),color(linen_off,neck))>.1,"linen V opening changes with actual undergarment")
	check(difference(color(linen_off,neck),Color("e7e0d2"))<.08,"linen V opening is empty without undergarment")
	check(difference(color(linen_on,Vector2(-10,-20)),color(linen_off,Vector2(-10,-20)))<.015,"linen fabric remains opaque outside opening")
	var mail_pad:=await render("mail-over-padding","mail",[],{"mail":true,"padded":false})
	var mail_linen:=await render("mail-over-linen","mail",["padded"],{"mail":true,"padded":false})
	var mail_alone:=await render("mail-alone","mail",["padded","linen","body"],{"mail":true,"padded":false})
	var tear:=Vector2(18,-18)
	check(difference(color(mail_pad,tear),color(mail_linen,tear))>.1,"same mail tear shows different real padding/linen")
	check(difference(color(mail_alone,tear),Color("e7e0d2"))<.08,"mail tear has no baked yellow lining")
	check(difference(color(mail_pad,Vector2(-10,-20)),color(mail_alone,Vector2(-10,-20)))<.015,"opaque mail shell encloses inner layers")
	var padded_linen:=await render("padded-over-linen","padded",[],{"padded":true})
	var padded_body:=await render("padded-over-underwear","padded",["linen"],{"padded":true})
	check(difference(color(padded_linen,Vector2(17,-19)),color(padded_body,Vector2(17,-19)))>.1,"padding tear shows actual layer below")
	viewport.queue_free()
	Document.write_json(output.path_join("report.json"),{"checks":checks,"failures":failures,"engine":Engine.get_version_info().string,"executable":OS.get_executable_path(),"catalog_sha256":FileAccess.get_sha256(Actor.CATALOG)})
	print("Nested wear checks: %d passed, %d failed"%[checks-failures.size(),failures.size()])
	ui.get_tree().quit(1 if not failures.is_empty() else 0)
