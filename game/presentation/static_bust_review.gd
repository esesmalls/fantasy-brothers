extends Control
const Actor = preload("res://presentation/static_bust_actor.gd")
const Motion = preload("res://presentation/static_bust_motion.gd")
const SoundDemo = preload("res://presentation/hand_style_review.gd")
signal review_closed

var weapon := "sword"
var armor := "mail"
var mode := "gallery"
var outcome := "hit"
var damaged := false
var wounded := false
var background := "battle"
var progress := 0.0
var elapsed := -0.5
var speed := 1.0
var paused := false
var fx := true
var sound_on := false
var capture_mode := false
var failed_capture := false
var _canvas: Control
var _toolbar: VBoxContainer
var _slider: HSlider
var _status: Label
var _pause: Button
var _font := SystemFont.new()
var _audio: AudioStreamPlayer
var _sounds: Dictionary = {}

class Stage extends Control:
	var review: Control
	func _draw() -> void:review.draw_scene(self)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)
	_toolbar=VBoxContainer.new();outer.add_child(_toolbar)
	var title := Label.new();title.text="H · 静态半身穿戴评审";title.add_theme_font_size_override("font_size",24);_toolbar.add_child(title)
	var row := HFlowContainer.new();_toolbar.add_child(row)
	_choice(row,["穿戴总览","分层展开","武器回放"],["gallery","layers","motion"],func(v):mode=v;replay(),"gallery")
	_choice(row,["剑盾","长枪","短弓"],["sword","spear","bow"],func(v):weapon=v;replay(),weapon)
	_choice(row,["裸身模板","亚麻内衬","绗缝甲","绗缝＋链甲"],["bare","linen","padded","mail"],func(v):armor=v;_refresh(),armor)
	_toggle(row,"装备破损",func(v):damaged=v;_refresh())
	_toggle(row,"脸部受伤",func(v):wounded=v;_refresh())
	_choice(row,["苔绿底","浅底","深底"],["battle","light","deep"],func(v):background=v;_refresh(),background)
	var controls := HFlowContainer.new();_toolbar.add_child(controls)
	_choice(controls,["命中","格挡","落空"],["hit","block","miss"],func(v):outcome=v;replay(),outcome)
	_pause=_button(controls,"暂停",func():paused=not paused;_refresh())
	_button(controls,"重播",replay)
	_choice(controls,["0.5×","1×","2×"],[0.5,1.0,2.0],func(v):speed=v,1.0)
	_toggle(controls,"命中效果",func(v):fx=v;_refresh(),true)
	_toggle(controls,"示意音效",func(v):sound_on=v)
	_button(controls,"关闭",func():review_closed.emit())
	_slider=HSlider.new();_slider.min_value=0;_slider.max_value=1;_slider.step=.001
	_slider.value_changed.connect(func(v):progress=v;elapsed=v*Motion.duration(weapon);paused=true;_refresh())
	_toolbar.add_child(_slider)
	_status=Label.new();_toolbar.add_child(_status)
	_canvas=Stage.new();_canvas.review=self;_canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL;outer.add_child(_canvas)
	_audio=AudioStreamPlayer.new();add_child(_audio)
	var sound_source := SoundDemo.new()
	_sounds={"release":sound_source._synth_sound("swing",.13),"impact":sound_source._synth_sound("armor",.20),"block":sound_source._synth_sound("block",.19)}
	sound_source.free()
	_refresh()

func _choice(parent:Node,labels:Array,values:Array,callback:Callable,value:Variant) -> void:
	var button:=OptionButton.new()
	for label in labels:button.add_item(str(label))
	button.selected=maxi(0,values.find(value));button.item_selected.connect(func(i):callback.call(values[i]))
	parent.add_child(button)

func _button(parent:Node,text:String,callback:Callable) -> Button:
	var button:=Button.new();button.text=text;button.pressed.connect(callback);parent.add_child(button);return button

func _toggle(parent:Node,text:String,callback:Callable,initial:bool=false) -> void:
	var button:=CheckButton.new();button.text=text;button.button_pressed=initial;button.toggled.connect(callback);parent.add_child(button)

func replay() -> void:
	elapsed=-.5;progress=0;paused=false;_refresh()

func _process(delta:float) -> void:
	if paused or capture_mode or mode!="motion":return
	var before:=progress
	elapsed+=delta*speed
	progress=clampf(elapsed/Motion.duration(weapon),0,1)
	for event in Motion.events_between(weapon,before,progress,outcome):
		if sound_on and _sounds.has(event):
			_audio.stream=_sounds[event];_audio.pitch_scale=1.25 if weapon=="bow" else 1.0;_audio.play()
	if elapsed>Motion.duration(weapon)+.8:replay()
	_refresh()

func _refresh() -> void:
	if _canvas==null:return
	_slider.set_value_no_signal(progress);_pause.text="继续" if paused else "暂停"
	_status.text="%s  ·  %d%%"%[Motion.phase(weapon,progress,outcome),roundi(progress*100)]
	_canvas.queue_redraw()

func _text(c:CanvasItem,text:String,at:Vector2,size_value:int=18) -> void:
	var color:=Color("533f29") if background=="light" else Color("dcc9a2")
	c.draw_string(_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func draw_scene(c:Control) -> void:
	c.draw_rect(Rect2(Vector2.ZERO,c.size),{"battle":Color("293930"),"light":Color("e7e0d2"),"deep":Color("141b1c")}[background])
	if mode=="motion":_draw_motion(c);return
	if mode=="layers":_draw_layers(c);return
	var cols:=3
	var cell:=Vector2(c.size.x/cols,(c.size.y-42)/2)
	for i in range(6):
		var row:=i/3
		var column:=i%3
		var at:=Vector2((column+.46)*cell.x,(row+.92)*cell.y)
		var scale_value:=minf(cell.x/125,cell.y/114)
		var shown_armor:String=["linen","padded","mail"][column] if row==0 else armor
		var shown_weapon:String="none" if row==0 else ["sword","spear","bow"][column]
		Actor.draw_actor(c,at,scale_value,shown_armor,shown_weapon,damaged,wounded)
		_text(c,(["内衬 · 头身分离","一层 · 绗缝甲","两层 · 绗缝＋链甲"] if row==0 else ["剑盾","长枪","短弓"])[column],Vector2(column*cell.x+22,row*cell.y+28))
	_text(c,"H · 无手短胸样板     /     所有组合共用头、躯干与底座位置",Vector2(22,c.size.y-13),16)

func _draw_layers(c:Control) -> void:
	var ids:Array[String]=["base","body","wounded" if wounded else "head","linen","padded_damaged" if damaged else "padded","mail_damaged" if damaged else "mail"]
	var labels:=["低底座","肩胸身体","独立头部","短胸内衬","绗缝甲","外层链甲"]
	var cell:=c.size.x/7.0
	var scale_value:=minf(cell/91,(c.size.y-100)/110)
	for i in range(6):
		var at:=Vector2((i+.5)*cell,c.size.y*.72)
		Actor.draw_part(c,ids[i],at,scale_value)
		_text(c,labels[i],Vector2(i*cell+12,40),17)
	Actor.draw_actor(c,Vector2(6.5*cell,c.size.y*.72),scale_value,armor,"none",damaged,wounded)
	_text(c,"实际合成",Vector2(6*cell+12,40),17)
	_text(c,"身体承托头颈，衣甲包住胸肩；整张衣甲套层，无补丁盖缝。",Vector2(20,c.size.y-24),16)

func _draw_motion(c:Control) -> void:
	var scale_value:=minf(c.size.x/335,(c.size.y-85)/112)
	var origin:=Vector2(c.size.x*.27,c.size.y*.81)
	var contact_at:=Actor.contact_point(weapon)
	var reaction:=Motion.response(weapon,progress,outcome)
	# The target is a whole bust: head/clothes/base share the same translation.
	var target:=origin+Vector2(contact_at.x+32,0)*scale_value
	var shifted:=target+Vector2(reaction*2.0,0)*scale_value
	var struck:=progress>=Motion.contact(weapon) and outcome=="hit"
	Actor.draw_body(c,shifted,scale_value,"mail",struck,false)
	if outcome=="block":Actor.draw_part(c,"shield",shifted,scale_value,Vector2(-49,-4))
	Actor.draw_actor(c,origin,scale_value,armor,weapon,damaged,wounded,progress,outcome)
	var hit_point:=origin+contact_at*scale_value
	if weapon=="bow" and progress>=Motion.release(weapon) and progress<.94:
		var flight:=clampf(inverse_lerp(Motion.release(weapon),Motion.contact(weapon),progress),0,1)
		var destination:=contact_at if outcome!="miss" else contact_at+Vector2(47,-13)
		var arrow_at:=Vector2(44,-35).lerp(destination,flight)
		if outcome!="miss" or progress<Motion.contact(weapon):
			Actor.draw_part(c,"arrow",origin,scale_value,arrow_at,PI/2)
	var fx_time:=progress-Motion.contact(weapon)
	if fx and outcome!="miss" and fx_time>=0 and fx_time<.16:
		Actor.draw_part(c,"impact",hit_point,scale_value*(.6+.5*fx_time/.16),Vector2.ZERO,0,Color(1,1,1,1-fx_time/.16))
	_text(c,"%s  /  %s"%[{"sword":"剑盾 · 短挥斩","spear":"长枪 · 前刺","bow":"短弓 · 离弦"}[weapon],Motion.phase(weapon,progress,outcome)],Vector2(22,32),22)
	_text(c,"身体静止 · 武器独立运动",Vector2(22,60),16)
	var small:=Vector2(c.size.x-151,c.size.y-26)
	Actor.draw_actor(c,small,1.0,armor,weapon,damaged,wounded,progress,outcome)
	_text(c,"1×",small+Vector2(-12,-106),14)
	_text(c,"只读表现样例 · 音效为节奏示意",Vector2(22,c.size.y-13),15)

func capture(output:String) -> void:
	if DisplayServer.get_name()=="headless":printerr("Needs real renderer");get_tree().quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:get_tree().quit(1);return
	capture_mode=true;paused=true;_toolbar.hide()
	get_window().size=Vector2i(1440,920);get_window().content_scale_size=get_window().size
	mode="gallery"
	for bg in ["battle","light","deep"]:
		background=bg;await _save(output.path_join("overview-"+bg+".png"))
	background="battle";damaged=true;wounded=true
	await _save(output.path_join("overview-damaged.png"))
	# Bare/linen/padded/mail registration at the same anchor, without a weapon.
	damaged=false;wounded=false;mode="layers";armor="bare"
	await _save(output.path_join("bare-template.png"));armor="mail"
	damaged=false;wounded=false;mode="layers"
	get_window().size=Vector2i(1500,530);get_window().content_scale_size=get_window().size
	await _save(output.path_join("layers.png"))
	damaged=true;wounded=true;await _save(output.path_join("layers-damaged.png"));damaged=false;wounded=false
	mode="motion";get_window().size=Vector2i(1280,570);get_window().content_scale_size=get_window().size
	for item in ["sword","spear","bow"]:
		weapon=item;outcome="hit"
		for i in range(32):
			progress=float(i)/31;await _save(output.path_join(item+"-%02d.png"%i))
		for result in ["block","miss"]:
			outcome=result;progress=Motion.contact(weapon)+.04
			await _save(output.path_join(item+"-"+result+".png"))
	_toolbar.show();mode="motion";weapon="sword";outcome="hit";progress=0
	get_window().size=Vector2i(1440,900);get_window().content_scale_size=get_window().size
	await _save(output.path_join("interactive.png"))
	print("Static bust captures: "+output)
	get_tree().quit(1 if failed_capture else 0)

func _save(path:String) -> void:
	_refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(path)!=OK:failed_capture=true;printerr(path)
