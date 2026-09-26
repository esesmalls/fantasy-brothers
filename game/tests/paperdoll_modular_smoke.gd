extends "res://tests/paperdoll_smoke.gd"
## Export-only visual and actual-input acceptance for the modular workbench.
class Sample extends Control:
	var data:Dictionary
	var armor:="nude"
	var omitted:Array=[]
	func _draw() -> void:
		draw_rect(Rect2(0,0,512,512),Color("e7e0d2"))
		preload("res://presentation/static_bust_actor.gd").draw_body(self,Vector2(210,450),6,armor,false,false,data,omitted)

func render_sample(canvas:Control,viewport:SubViewport,data:Dictionary,armor:String="nude",omitted:Array=[]) -> Image:
	canvas.data=data;canvas.armor=armor;canvas.omitted=omitted;canvas.queue_redraw()
	await settle();await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func different_pixels(a:Image,b:Image,region:Rect2i=Rect2i(0,0,512,512)) -> int:
	var count:=0
	for y in range(region.position.y,region.end.y):
		for x in range(region.position.x,region.end.x):
			var c:=a.get_pixel(x,y);var d:=b.get_pixel(x,y)
			if Vector3(c.r-d.r,c.g-d.g,c.b-d.b).length()>.08:count+=1
	return count

func run(workbench:Control,output:String) -> void:
	ui=workbench
	if DisplayServer.get_name()=="headless":ui.get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	ui.get_window().size=Vector2i(1440,960);ui.get_window().content_scale_size=ui.get_window().size;await settle()
	check(ui.document.transform_for("spear").offset==[-20.0,13.0],"user spear calibration loaded")
	check(ui.document.transform_for("bust").offset==[.25,-1.25],"user bust calibration loaded")
	check(ui.project_path.ends_with("-v2.json"),"legacy saves use separate copy")
	ui.weapon="spear";ui.select_group("spear");await capture(output,"user-calibration")
	ui.select_group("head");ui.angle_field.value=12;await settle()
	check(is_equal_approx(ui.document.transform_for("head").angle,12),"rotation control changes document")
	await click(ui.undo_button.get_global_rect().get_center());check(ui.angle_field.value==0,"rotation undo button")
	await click(ui.redo_button.get_global_rect().get_center());check(ui.angle_field.value==12,"rotation redo button")
	ui.document.undo();ui.refresh()
	ui.select_group("spear");var start:Vector2=ui.stage.global_position+ui.pointer_for("spear")
	await move(start);await press(start,true);await move(start+Vector2(-25*ui.camera().scale,0),true);await press(start+Vector2(-25*ui.camera().scale,0),false)
	check(is_equal_approx(ui.x_field.value,-45),"pointer moves beyond former -20 limit")
	await key(KEY_Z,true);check(is_equal_approx(ui.x_field.value,-20),"one drag is one undo")
	# Alt-drag uses the selected pivot, one history entry even over many moves.
	var pivot:Vector2=ui.stage.global_position+ui.camera().origin+ui.selected_anchor()*ui.camera().scale
	var alt_press:=InputEventMouseButton.new();alt_press.button_index=MOUSE_BUTTON_LEFT;alt_press.pressed=true;alt_press.alt_pressed=true;alt_press.position=pivot+Vector2(60,0)
	ui.get_viewport().push_input(alt_press,true);await settle()
	await move(pivot+Vector2(42.4264,42.4264),true);await press(pivot+Vector2(42.4264,42.4264),false)
	check(absf(ui.angle_field.value-45)<1,"Alt pointer gesture rotates around pivot")
	await key(KEY_Z,true);check(ui.angle_field.value==0,"Alt drag undo restores angle")
	ui.document.change("spear",Vector2(-100,100),1);ui.refresh();ui.focus_selected()
	check((ui.camera().origin+ui.selected_anchor()*ui.camera().scale).distance_to(ui.stage.size*Vector2(.5,.5))<.01,"locate far-away selected part")
	ui.document.undo();ui.pan=Vector2.ZERO;ui.refresh()
	ui.document.set_appearance("head","modular");ui.weapon="none";ui.select_group("skin");ui.guides=false;ui.refresh();await capture(output,"body-and-head")
	ui.document.set_appearance("hair",false);ui.document.set_appearance("beard",false);ui.refresh();await capture(output,"bald-body")
	ui.document.set_appearance("scar",true);ui.refresh();await capture(output,"scar-only")
	ui.document.set_appearance("hair",true);ui.document.set_appearance("beard",true);ui.document.set_appearance("scar",true);ui.document.set_appearance("bandage",true);ui.document.set_appearance("blood",true);ui.refresh();await capture(output,"body-details")
	ui.armor="linen";ui.refresh();await capture(output,"dressed-details")
	ui.armor="mail";ui.weapon="sword";ui.refresh();await capture(output,"armed-details")
	ui.document.change("head",Vector2(3,-1),1,true,8);ui.select_group("scar");ui.guides=true;ui.refresh();await capture(output,"parent-rotation")
	var before:Dictionary=ui.document.snapshot()
	ui._save_project(output.path_join("modular-sample.json"));ui.document.reset_all();check(ui.open_project(output.path_join("modular-sample.json")) and ui.document.snapshot()==before,"appearance and transforms reload")
	ui.get_window().size=Vector2i(1180,740);ui.get_window().content_scale_size=ui.get_window().size;await settle()
	check(ui.stage.size.x>=600 and ui.stage.size.y>=500,"small window retains canvas")
	check(ui.undo_button.get_global_rect().end.y<ui.stage.get_global_rect().end.y,"undo stays reachable without scroll")
	await capture(output,"small-window")
	var viewport:=SubViewport.new();viewport.size=Vector2i(512,512);viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;ui.add_child(viewport)
	var canvas:=Sample.new();canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS;viewport.add_child(canvas)
	var d=ui.Document.new();d.set_appearance("head","modular");d.set_appearance("hair",false);d.set_appearance("beard",false)
	var clean:=await render_sample(canvas,viewport,d.composed())
	d.set_appearance("blood",true);var blood:=await render_sample(canvas,viewport,d.composed())
	check(different_pixels(clean,blood)>20,"blood is visibly drawn on bare skin")
	check(different_pixels(clean,blood,Rect2i(0,0,512,240))==0,"body stain does not affect head")
	blood.save_png(output.path_join("skin-blood-closeup.png"))
	d.change("blood",Vector2(100,0),1);var outside:=await render_sample(canvas,viewport,d.composed())
	check(different_pixels(clean,outside)==0,"blood cannot float outside skin silhouette")
	d.change("blood",Vector2.ZERO,1);d.set_appearance("scar",true)
	var scar:=await render_sample(canvas,viewport,d.composed())
	check(different_pixels(blood,scar)>5,"scar visible on clean face")
	d.change("scar",Vector2(90,-40),1);outside=await render_sample(canvas,viewport,d.composed())
	check(different_pixels(blood,outside)==0,"scar cannot float off face")
	d.set_appearance("scar",false);d.set_appearance("blood",false)
	var dressed_clean:=await render_sample(canvas,viewport,d.composed(),"mail")
	d.set_appearance("blood",true);var dressed_blood:=await render_sample(canvas,viewport,d.composed(),"mail")
	check(different_pixels(dressed_clean,dressed_blood)==0,"opaque clothes cover skin blood")
	var worn:Dictionary=d.composed();var without_skin:=await render_sample(canvas,viewport,worn,"linen",["skin","blood"])
	var with_skin:=await render_sample(canvas,viewport,worn,"linen")
	# The corrected compact torso must not stick out of either shoulder contour.
	check(different_pixels(with_skin,without_skin,Rect2i(30,160,145,235))==0,"no bare shoulder outside left clothing")
	check(different_pixels(with_skin,without_skin,Rect2i(305,160,110,235))==0,"no bare shoulder outside right clothing")
	with_skin.save_png(output.path_join("clothed-closeup.png"));viewport.queue_free()
	ui.Document.write_json(output.path_join("report.json"),{"checks":checks,"failed":failures.size(),"failures":failures,"engine":Engine.get_version_info().string,"executable":OS.get_executable_path()})
	print("Modular export checks: %d passed, %d failed"%[checks-failures.size(),failures.size()]);ui.get_tree().quit(1 if not failures.is_empty() else 0)
