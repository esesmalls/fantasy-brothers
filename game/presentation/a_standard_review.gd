extends Control
## Production review of the entire currently defined character/equipment family.
## Fixture selection and scrubbing never write the campaign or combat model.

const Actor = preload("res://presentation/a_standard_actor.gd")
const Motion = preload("res://presentation/a_standard_motion.gd")
const Equipment = preload("res://core/equipment_data.gd")
const OldSounds = preload("res://presentation/hand_style_review.gd")
signal review_closed

var weapon := "weapon_guard_sword"
var armor := "armor_mail"
var face := 0
var damage := 0
var wounded := false
var action := "attack"
var outcome := "hit"
var progress := 0.0
var elapsed := -0.4
var speed := 1.0
var paused := false
var show_fx := true
var sound_on := false
var background := "battle"
var mode := "motion"
var capture_mode := false
var impact_count := 0
var _impact_applied := false
var _release_played := false
var _capture_failed := false
var _font := SystemFont.new()
var _canvas: Control
var _slider: HSlider
var _status: Label
var _pause: Button
var _toolbar: VBoxContainer
var _audio: AudioStreamPlayer
var _sounds: Dictionary = {}

class ReviewCanvas extends Control:
	var review: Control
	func _draw() -> void:
		review.draw_scene(self)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_build_ui()
	_audio = AudioStreamPlayer.new()
	add_child(_audio)
	var synthesis = OldSounds.new()
	_sounds = {"swing":synthesis._synth_sound("swing",0.13),"armor":synthesis._synth_sound("armor",0.20),"block":synthesis._synth_sound("block",0.19)}
	synthesis.free()
	_refresh()

func _build_ui() -> void:
	var outer := VBoxContainer.new()
	outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(outer)
	_toolbar = VBoxContainer.new()
	outer.add_child(_toolbar)
	var title := Label.new()
	title.text = "A 标准 · 人物、套层与武器动作"
	title.add_theme_font_size_override("font_size",24)
	_toolbar.add_child(title)
	var row := HFlowContainer.new()
	_toolbar.add_child(row)
	_choice(row, Equipment.DEFINITIONS.keys().filter(func(k):return str(k).begins_with("weapon_")), func(value):weapon=value;replay(), weapon)
	_choice(row, ["armor_padded","armor_leather","armor_brigandine","armor_mail"],func(value):armor=value;_refresh(),armor)
	var face_options: Array = []
	for i in range(12):face_options.append("人物 %02d" % (i+1))
	_choice(row,face_options,func(value):face=int(str(value).get_slice(" ",1))-1;_refresh(),face_options[0])
	_choice(row,["完好","受损","重损","耗尽"],func(value):damage=["完好","受损","重损","耗尽"].find(value);_refresh(),"完好")
	_button(row,"伤势",func():wounded=not wounded;_refresh())
	_choice(row,["动作","人物总览","10件武器","四甲四状态","套层拆解","倒伏","战犬"],func(value):mode={"动作":"motion","人物总览":"faces","10件武器":"weapons","四甲四状态":"armor","套层拆解":"layers","倒伏":"terminal","战犬":"dog"}[value];_refresh(),"动作")
	var controls := HFlowContainer.new()
	_toolbar.add_child(controls)
	_choice(controls,["攻击","待机","移动","盾击","推开","戒备","受击","倒地","死亡","指令"],func(value):action={"攻击":"attack","待机":"idle","移动":"move","盾击":"shield_bash","推开":"push","戒备":"defend","受击":"hit","倒地":"downed","死亡":"death","指令":"command"}[value];replay(),"攻击")
	_choice(controls,["命中","格挡","落空"],func(value):outcome={"命中":"hit","格挡":"block","落空":"miss"}[value];replay(),"命中")
	_pause=_button(controls,"暂停",func():paused=not paused;_refresh())
	_button(controls,"重播",replay)
	_button(controls,"跳过",func():progress=1;elapsed=float(Motion.timing(weapon,action).duration);paused=true;_refresh())
	_choice(controls,["0.5×","1×","2×"],func(value):speed=float(str(value).trim_suffix("×")),"1×")
	_button(controls,"特效开关",func():show_fx=not show_fx;_refresh())
	_button(controls,"声音开关",func():sound_on=not sound_on;_audio.stop();_refresh())
	_choice(controls,["战场底","浅底","深底"],func(value):background={"战场底":"battle","浅底":"light","深底":"deep"}[value];_refresh(),"战场底")
	_button(controls,"关闭",func():review_closed.emit())
	_slider=HSlider.new();_slider.min_value=0;_slider.max_value=1;_slider.step=.001
	_slider.value_changed.connect(func(value):progress=value;elapsed=value*float(Motion.timing(weapon,action).duration);paused=true;_refresh())
	_toolbar.add_child(_slider)
	_status=Label.new();_toolbar.add_child(_status)
	_canvas=ReviewCanvas.new();_canvas.review=self;_canvas.size_flags_vertical=Control.SIZE_EXPAND_FILL;_canvas.size_flags_horizontal=Control.SIZE_EXPAND_FILL;outer.add_child(_canvas)

func _choice(parent:Node,options:Array,callback:Callable,selected:String) -> void:
	var choice:=OptionButton.new()
	for value in options:choice.add_item(str(Equipment.DEFINITIONS.get(value,{}).get("name",value)))
	choice.selected=maxi(0,options.find(selected))
	choice.item_selected.connect(func(index):callback.call(options[index]))
	parent.add_child(choice)

func _button(parent:Node,text:String,callback:Callable) -> Button:
	var b:=Button.new();b.text=text;b.pressed.connect(callback);parent.add_child(b);return b

func replay() -> void:
	elapsed=-0.4;progress=0;paused=false;_impact_applied=false;_release_played=false;_refresh()

func sample_unit(weapon_value:String="", armor_value:String="", identity_value:int=-1, stage:int=-1) -> Dictionary:
	if weapon_value.is_empty():weapon_value=weapon
	if armor_value.is_empty():armor_value=armor
	if identity_value<0:identity_value=face
	if stage<0:stage=damage
	return {"id":"production_actor","kind":"guard","name":"人物 %02d" % (identity_value+1),"visual_identity":identity_value,"hp":35 if wounded else 80,"max_hp":80,"armor":[24,12,5,0][stage],"max_armor":24,"visual_loadout":{"weapon":weapon_value,"armor":armor_value}}

func _process(delta:float) -> void:
	if paused or capture_mode:return
	var active_weapon := "" if mode=="dog" else weapon
	var active_action := "bite" if mode=="dog" and action=="attack" else action
	var timing:=Motion.timing(active_weapon,active_action)
	elapsed+=delta*speed
	progress=clampf(elapsed/float(timing.duration),0,1)
	if not _release_played and elapsed>=float(timing.release) and active_action in ["attack","shield_bash","push","bite"]:
		_release_played=true
		_play("swing",1.35 if Motion.is_bow(str(timing.family)) else 1.0)
	if not _impact_applied and elapsed>=float(timing.contact) and active_action in ["attack","shield_bash","push","bite"]:
		_impact_applied=true;impact_count+=1
		if outcome!="miss":_play("block" if outcome=="block" else "armor",.80 if str(timing.family) in ["axe","cleaver"] else 1.15)
	if elapsed>float(timing.duration)+.8 and action not in ["death","downed"]:replay()
	_refresh()

func _play(kind:String,pitch:float) -> void:
	if not sound_on or capture_mode:return
	_audio.stream=_sounds[kind];_audio.pitch_scale=pitch;_audio.play()

func _refresh() -> void:
	if _canvas==null:return
	_slider.set_value_no_signal(progress)
	_pause.text="继续" if paused else "暂停"
	var motion:=Motion.sample(weapon,"bite" if mode=="dog" and action=="attack" else action,progress,outcome)
	_status.text="%s · %s · %d%% · 声音%s" % ["战犬" if mode=="dog" else str(Equipment.DEFINITIONS[weapon].name),str(motion.phase),roundi(progress*100),"开" if sound_on else "关"]
	_canvas.queue_redraw()

func _text(c:CanvasItem,text:String,at:Vector2,size_value:int=16,color:Color=Color("eee3cc")) -> void:
	c.draw_string(_font,at,text,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func draw_scene(c:Control) -> void:
	var bg:Color={"battle":Color("25382e"),"light":Color("e8e0ce"),"deep":Color("131c1c")}[background]
	c.draw_rect(Rect2(Vector2.ZERO,c.size),bg)
	if mode=="motion" or mode=="dog":_draw_motion(c);return
	var count:=12 if mode=="faces" else (10 if mode=="weapons" else (16 if mode=="armor" else (5 if mode=="layers" else 8)))
	var cols:=5 if mode in ["weapons","layers"] else 4
	var rows:=ceili(float(count)/cols)
	var cell:=Vector2(c.size.x/cols,c.size.y/rows)
	var keys:Array=Actor.catalog().weapons.keys()
	var armors:Array=Actor.catalog().armors.keys()
	for i in range(count):
		var origin:=Vector2((i%cols+(.56 if mode=="terminal" else .46))*cell.x,(floori(float(i)/cols)+(.85 if mode!="layers" else .69))*cell.y)
		var scale_value:=minf(cell.x/107,cell.y/88)
		var unit:=sample_unit()
		var pose:Dictionary={"action":"idle","progress":0.0}
		var label:=""
		if mode=="faces":unit.visual_identity=i;label="人物 %02d"%(i+1)
		elif mode=="weapons":unit.visual_loadout.weapon=keys[i];label=Equipment.DEFINITIONS[keys[i]].name
		elif mode=="armor":unit.visual_loadout.armor=armors[i/4];unit.armor=[24,12,5,0][i%4];label=Equipment.DEFINITIONS[armors[i/4]].name+" · "+["完好","受损","重损","耗尽"][i%4]
		elif mode=="layers":pose.layer_limit=i;unit.armor=0;label=["亚麻内衣","防护衬衣","独立外甲","领口·肩甲·扣带","装备完成"][i]
		else:unit.visual_loadout.armor=armors[i/2];pose.action="death" if i%2==0 else "downed";pose.progress=1.0;label=Equipment.DEFINITIONS[armors[i/2]].name+" · "+("侧倒" if i%2==0 else "仰倒")
		Actor.draw_actor(c,unit,origin,scale_value,pose)
		_text(c,label,Vector2((i%cols)*cell.x+14,floori(float(i)/cols)*cell.y+23),15,Color("9b7845") if background=="light" else Color("dfc48a"))

func _draw_motion(c:Control) -> void:
	var scale_value:=clampf(minf(c.size.x/235,c.size.y/102),1.7,4.5)
	var origin:=Vector2(c.size.x*.28,c.size.y*.77)
	var kind:=Motion.family(weapon)
	var entry:Dictionary=Actor.catalog().weapons[weapon]
	var timing_at_contact:=Motion.timing(weapon,action)
	var contact_pose:=Actor.rig(sample_unit(),{"action":action,"progress":float(timing_at_contact.brake_end)/float(timing_at_contact.duration)})
	var contact_grip:Vector2=contact_pose.grip
	var target_distance:=contact_grip.x+float(entry.size[1])*float(entry.pivot[1])*sin(float(contact_pose.weapon_angle))+6.0
	if Motion.is_bow(kind):target_distance=72
	if action in ["shield_bash","push"]:target_distance=49
	if mode=="dog":target_distance=41
	var target:=origin+Vector2(target_distance*scale_value,0)
	var active_action:="bite" if mode=="dog" and action=="attack" else action
	var pose:Dictionary={"action":active_action,"progress":progress,"outcome":outcome}
	var unit:=sample_unit()
	if mode=="dog":unit.kind="dog"
	Actor.draw_actor(c,unit,origin,scale_value,pose)
	var reaction:=Motion.target_response(weapon,active_action,progress,outcome) if active_action in ["attack","shield_bash","push","bite"] else 0.0
	var target_shift:=Vector2(reaction*2.8,0)
	# Real armor shell over a padded hanging training form: the same material state
	# demonstrates a surface response, without inventing armor loss on real actors.
	var target_unit:=sample_unit(weapon,"armor_mail",8,1 if action in ["attack","shield_bash","push"] and progress>=float(Motion.timing(weapon,action).contact)/float(Motion.timing(weapon,action).duration) and outcome=="hit" else 0)
	c.draw_line(target+Vector2(0,-48)*scale_value,target+Vector2(0,3)*scale_value,Color("705031"),scale_value*3)
	Actor._draw(c,Actor.catalog().underlayer,target+target_shift*scale_value,scale_value,Vector2(0,-6),reaction*.06)
	Actor._draw(c,Actor.catalog().armors.armor_mail[Actor.damage_stage(target_unit)],target+target_shift*scale_value,scale_value,Vector2(0,-6),reaction*.06)
	# Foreground is also above the target, never swallowed by another character.
	Actor.draw_weapon_front(c,unit,origin,scale_value,pose)
	var timing:=Motion.timing(weapon,action)
	var t:=progress*float(timing.duration)
	if Motion.is_bow(kind) and action=="attack" and t>=float(timing.release) and t<=float(timing.contact):
		var flight:=inverse_lerp(float(timing.release),float(timing.contact),t)
		var arrow:=(origin+Vector2(42,-28)*scale_value).lerp(target+Vector2(-13,-28)*scale_value,flight)
		c.draw_line(arrow-Vector2(16*scale_value,0),arrow,Color("d3bd8a"),maxf(.8,scale_value*.5))
	if show_fx and reaction>0:
		var hit_point:=target+Vector2(-13,-28)*scale_value
		var tint:=Color("d9b768") if outcome=="block" else Color("aebac4")
		for a in [-.8,-.25,.32,.86]:c.draw_line(hit_point+Vector2.RIGHT.rotated(a)*3*scale_value,hit_point+Vector2.RIGHT.rotated(a)*11*reaction*scale_value,tint,maxf(1,scale_value*.5),true)
	_text(c,"A · %s"%("战犬" if mode=="dog" else Equipment.DEFINITIONS[weapon].name),Vector2(24,28),23)
	_text(c,"%s / %s"%[str(Motion.sample(weapon,active_action,progress,outcome).phase),{"hit":"命中","block":"格挡","miss":"落空"}[outcome]],Vector2(24,53))
	var small:=Vector2(c.size.x-145,c.size.y-26)
	Actor.draw_actor(c,unit,small,1.0,pose)
	_text(c,"人物原尺寸 1×",small+Vector2(-50,-85),14)
	_text(c,"仅表现评审：可关特效检查武器、握点和停顿；伤损由所选状态展示。",Vector2(22,c.size.y-12),14)

func set_fixed_frame(next_mode:String,next_action:String,p:float) -> void:
	capture_mode=true;paused=true;mode=next_mode;action=next_action;progress=p;_refresh()

func capture(output:String) -> void:
	if DisplayServer.get_name()=="headless":printerr("A production capture requires a real renderer");get_tree().quit(1);return
	if DirAccess.make_dir_recursive_absolute(output)!=OK:
		printerr("Cannot create capture directory: "+output);get_tree().quit(1);return
	capture_mode=true
	_toolbar.hide()
	get_window().size=Vector2i(1440,760);get_window().content_scale_size=Vector2i(1440,760)
	for gallery in ["faces","weapons","armor","layers","terminal"]:
		get_window().size=Vector2i(1440,400 if gallery=="layers" else 760);get_window().content_scale_size=get_window().size
		set_fixed_frame(gallery,"idle",0)
		await _save(output.path_join(gallery+".png"))
	wounded=true;set_fixed_frame("faces","idle",0);await _save(output.path_join("faces-wounded.png"));wounded=false
	damage=3;set_fixed_frame("terminal","idle",0);await _save(output.path_join("terminal-damaged.png"));damage=0
	get_window().size=Vector2i(1440,400);get_window().content_scale_size=get_window().size
	armor="armor_padded";set_fixed_frame("layers","idle",0);await _save(output.path_join("layers-padded.png"));armor="armor_mail"
	_toolbar.show();get_window().size=Vector2i(1440,900);get_window().content_scale_size=get_window().size
	for item in Actor.catalog().weapons:
		weapon=item;armor="armor_mail";face=0;damage=0
		set_fixed_frame("motion","idle",0);await _save(output.path_join(item+"-idle.png"))
	_toolbar.hide();get_window().size=Vector2i(1120,480);get_window().content_scale_size=Vector2i(1120,480)
	for item in Actor.catalog().weapons:
		weapon=item
		for i in range(24):
			set_fixed_frame("motion","attack",float(i)/23)
			await _save(output.path_join(item+"-%02d.png"%i))
	for special in ["shield_bash","hit","move","defend","command","push"]:
		weapon="weapon_guard_sword"
		for i in range(12):
			set_fixed_frame("motion",special,float(i)/11)
			await _save(output.path_join(special+"-%02d.png"%i))
	for i in range(12):
		set_fixed_frame("dog","attack",float(i)/11)
		await _save(output.path_join("dog-%02d.png"%i))
	for state in ["hit","downed","death"]:
		set_fixed_frame("dog",state,1);await _save(output.path_join("dog-"+state+".png"))
	if _capture_failed:
		printerr("A production capture failed");get_tree().quit(1);return
	print("A production captures complete: "+output)
	get_tree().quit()

func _save(path:String) -> void:
	if _capture_failed:return
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error:=get_viewport().get_texture().get_image().save_png(path)
	if error!=OK:printerr("Capture failed: "+path);_capture_failed=true
