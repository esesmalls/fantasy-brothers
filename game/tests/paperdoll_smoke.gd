extends RefCounted
## Actual viewport input in the Windows export; does not touch campaign saves.
var ui:Control
var checks:=0
var failures:Array[String]=[]

func check(ok:bool,label:String) -> void:
	checks+=1
	if not ok:failures.append(label);printerr("Paperdoll UI: "+label)

func settle() -> void:
	await ui.get_tree().process_frame
	await ui.get_tree().process_frame

func move(at:Vector2,pressed:bool=false) -> void:
	var event:=InputEventMouseMotion.new();event.position=at;event.global_position=at
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if pressed else 0
	ui.get_viewport().push_input(event,true);await settle()

func press(at:Vector2,down:bool) -> void:
	var event:=InputEventMouseButton.new();event.position=at;event.global_position=at
	event.button_index=MOUSE_BUTTON_LEFT;event.pressed=down
	ui.get_viewport().push_input(event,true);await settle()

func click(at:Vector2) -> void:
	await move(at);await press(at,true);await press(at,false)

func key(code:Key,ctrl:bool=false) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.pressed=true;event.ctrl_pressed=ctrl
	ui.get_viewport().push_input(event,true);event=event.duplicate();event.pressed=false
	ui.get_viewport().push_input(event,true);await settle()

func capture(output:String,name:String) -> void:
	await settle();await RenderingServer.frame_post_draw
	check(ui.get_viewport().get_texture().get_image().save_png(output.path_join(name+".png"))==OK,"capture "+name)

func run(workbench:Control,output:String) -> void:
	ui=workbench
	if DisplayServer.get_name()=="headless":ui.get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	var original:=FileAccess.get_sha256(ui.Actor.CATALOG)
	for resolution in [Vector2i(1440,960),Vector2i(1180,740)]:
		ui.get_window().size=resolution;ui.get_window().content_scale_size=resolution;await settle()
		check(ui.stage.size.x>=600 and ui.stage.size.y>=570,"usable canvas "+str(resolution))
		var head_index:int=ui.Document.SELECT_ORDER.find("head")
		var rect:Rect2=ui.layer_list.get_item_rect(head_index)
		await click(ui.layer_list.global_position+rect.get_center())
		check(ui.selected=="head","pointer selects head "+str(resolution))
		var start:Vector2=ui.stage.global_position+ui.camera().origin+Vector2(0,-45)*ui.camera().scale
		var prior:float=ui.document.transform_for("head").offset[0]
		await move(start);await press(start,true)
		await move(start+Vector2(2*ui.camera().scale,0),true);await press(start+Vector2(2*ui.camera().scale,0),false)
		check(is_equal_approx(ui.x_field.value,prior+2),"pointer drag updates field "+str(resolution))
		await click(ui.undo_button.get_global_rect().get_center())
		check(is_equal_approx(ui.x_field.value,prior),"pointer undo "+str(resolution))
		await click(ui.redo_button.get_global_rect().get_center())
		check(is_equal_approx(ui.x_field.value,prior+2),"pointer redo "+str(resolution))
		# Enter a numeric value through the real LineEdit, then leave it.
		await click(ui.x_field.get_line_edit().get_global_rect().get_center());await key(KEY_A,true)
		var typed:=InputEventKey.new();typed.pressed=true;typed.unicode=51;typed.keycode=KEY_3
		ui.get_viewport().push_input(typed,true);typed=typed.duplicate();typed.pressed=false;ui.get_viewport().push_input(typed,true)
		await key(KEY_ENTER)
		check(is_equal_approx(ui.document.transform_for("head").offset[0],3),"typed numeric value "+str(resolution))
		await capture(output,"input-"+str(resolution.x))
		ui.document.reset_all();ui.refresh()
	# Keyboard nudging, one undo per gesture, and clean clicks preserving redo.
	await click(ui.stage.get_global_rect().get_center());await key(KEY_RIGHT)
	check(is_equal_approx(ui.x_field.value,.25),"arrow-key nudge")
	await key(KEY_Z,true);check(is_equal_approx(ui.x_field.value,0),"ctrl-z")
	await click(ui.stage.get_global_rect().get_center());await key(KEY_Y,true)
	check(is_equal_approx(ui.x_field.value,.25),"stationary click preserves redo")
	ui.project_path=output.path_join("ui-saved.json");await key(KEY_S,true)
	check(FileAccess.file_exists(ui.project_path) and not ui.document.dirty(),"ctrl-s saves draft")
	ui.document.change("head",Vector2.ONE,1);ui.refresh()
	check(ui.open_project(ui.project_path) and is_equal_approx(ui.x_field.value,.25),"reload restores render values")
	check(ui.Document.write_json(ProjectSettings.globalize_path("res://").path_join("blocked.json"),{})!="","export resource path protected")
	var source_catalog:=OS.get_executable_path().get_base_dir().path_join("../../../game/assets/art/static-bust/catalog.json").simplify_path()
	check(ui.Document.write_json(source_catalog,{})!="","export cannot overwrite workspace catalog")
	ui.select_group("bow");check(ui.weapon_choice.selected==3,"part selection synchronizes weapon selector")
	# Reach the action panel with actual wheel input in the short window.
	var scroll_at:Vector2=ui.x_field.global_position+Vector2(70,220)
	await move(scroll_at)
	for _step in range(6):
		var wheel:=InputEventMouseButton.new();wheel.position=scroll_at;wheel.global_position=scroll_at;wheel.button_index=MOUSE_BUTTON_WHEEL_DOWN;wheel.pressed=true
		ui.get_viewport().push_input(wheel,true)
		wheel=wheel.duplicate();wheel.pressed=false;ui.get_viewport().push_input(wheel,true)
	await ui.get_tree().create_timer(.35).timeout
	await settle()
	check(ui.play_button.get_global_rect().end.y<ui.stage.get_global_rect().end.y,"scroll exposes action controls")
	await click(ui.play_button.get_global_rect().get_center());await ui.get_tree().create_timer(.2).timeout
	check(ui.playing and ui.progress>0,"real play button")
	await click(ui.slider.global_position+Vector2(ui.slider.size.x*.57,ui.slider.size.y*.5))
	check(not ui.playing and ui.progress>.45 and ui.progress<.7,"pointer scrubs and pauses")
	await capture(output,"bow-scrub")
	ui.document.change("head",Vector2.ONE,1);ui.request_close();await settle()
	check(ui._close_dialog.visible,"dirty close prompts without discarding")
	ui._close_dialog.hide();ui.view="matrix";ui.refresh();await capture(output,"matrix-small")
	check(FileAccess.get_sha256(ui.Actor.CATALOG)==original,"approved catalog unchanged")
	var report:={"checks":checks,"failed":failures.size(),"failures":failures,"engine":Engine.get_version_info().string,"executable":OS.get_executable_path(),"baseline_sha256":original}
	ui.Document.write_json(output.path_join("ui-report.json"),report)
	print("Paperdoll UI checks: %d passed, %d failed"%[checks-failures.size(),failures.size()])
	ui.get_tree().quit(1 if not failures.is_empty() else 0)
