extends Control
## Editor-only surface. Shares the exact static-bust renderer, no campaign access.
const Document = preload("res://presentation/paperdoll_document.gd")
const Actor = preload("res://presentation/static_bust_actor.gd")
const Motion = preload("res://presentation/static_bust_motion.gd")
signal closed
var document=Document.new()
var selected:="bust"
var armor:="mail"
var weapon:="sword"
var damaged:=false
var damage_scope:="outer"
var wounded:=false
var view:="fit"
var backdrop:="green"
var hidden_layers:Array=[]
var guides:=true
var ghost:=false
var ghost_alpha:=.28
var zoom:=4.0
var playing:=false
var progress:=0.0
var elapsed:=0.0
var project_path:=""
var catalog_data:Dictionary
var stage:Control
var status:Label
var selection_label:Label
var notes:Label
var x_field:SpinBox
var y_field:SpinBox
var size_field:SpinBox
var angle_field:SpinBox
var crop_x:SpinBox
var crop_y:SpinBox
var crop_rx:SpinBox
var crop_ry:SpinBox
var crop_top:SpinBox
var transform_box:VBoxContainer
var crop_box:VBoxContainer
var action_box:VBoxContainer
var duration_field:SpinBox
var release_field:SpinBox
var contact_field:SpinBox
var key_list:ItemList
var key_t:SpinBox
var key_x:SpinBox
var key_y:SpinBox
var key_angle:SpinBox
var head_choice:OptionButton
var appearance_checks:Dictionary={}
var selected_groups:Array[String]=["bust"]
var selected_key:=""
var pan:=Vector2.ZERO
var _panning:=false
var _rotating:=false
var _rotation_start:=0.0
var _rotation_mouse:=0.0
var _pan_start:=Vector2.ZERO
var source_view:=false
var slider:HSlider
var play_button:Button
var undo_button:Button
var redo_button:Button
var layer_list:ItemList
var armor_choice:OptionButton
var weapon_choice:OptionButton
var view_choice:OptionButton
var background_choice:OptionButton
var _font:=SystemFont.new()
var _dragging:=false
var _drag_start:=Vector2.ZERO
var _drag_offset:=Vector2.ZERO
var _drag_recorded:=false
var _syncing:=false
var _dialogs:Array=[]
var _close_dialog:ConfirmationDialog
var _notice:="选择左侧部件，Ctrl 多选后可统一改大小和旋转。"

class Stage extends Control:
	var owner_ui:Control
	func _draw() -> void:owner_ui.draw_stage(self)
	func _gui_input(event:InputEvent) -> void:owner_ui.stage_input(event)

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_font.font_names=PackedStringArray(["Microsoft YaHei","Noto Sans CJK SC"])
	_build_theme()
	var margin:=MarginContainer.new();margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);add_child(margin)
	for side in ["left","top","right","bottom"]:margin.add_theme_constant_override("margin_"+side,14)
	var root:=VBoxContainer.new();root.add_theme_constant_override("separation",10);margin.add_child(root)
	var header:=HBoxContainer.new();root.add_child(header)
	var title:=Label.new();title.text="奇幻兄弟 · 人物装配台";title.add_theme_font_size_override("font_size",25);title.size_flags_horizontal=Control.SIZE_EXPAND_FILL;header.add_child(title)
	_button(header,"打开配置",func():_file_dialog("open"))
	_button(header,"保存调整",save_current)
	_button(header,"另存为",func():_file_dialog("save"))
	_button(header,"导出候选",func():_file_dialog("catalog"))
	_button(header,"截图",func():_file_dialog("image"))
	_button(header,"关闭",request_close)
	var toolbar:=HFlowContainer.new();root.add_child(toolbar)
	view_choice=_choice(toolbar,["装配与对照","穿戴组合检查","战场尺寸检查","内外层检查"],["fit","matrix","field","nesting"],func(v):view=v;playing=false;refresh(),"fit")
	armor_choice=_choice(toolbar,["基础内衣","亚麻","绗缝甲","绗缝＋链甲","裸身"],["bare","linen","padded","mail","nude"],func(v):armor=v;refresh(),armor)
	weapon_choice=_choice(toolbar,["无武器","剑盾","长矛","弓"],["none","sword","spear","bow"],func(v):weapon=v;progress=0;elapsed=0;refresh(),weapon)
	_toggle(toolbar,"甲损",func(v):damaged=v;refresh())
	_choice(toolbar,["损外层","损衬甲","全损"],["outer","padding","all"],func(v):damage_scope=v;refresh(),damage_scope)
	_toggle(toolbar,"脸伤",func(v):wounded=v;refresh())
	background_choice=_choice(toolbar,["苔绿底","泥土底","浅底","深底"],["green","earth","light","dark"],func(v):backdrop=v;refresh(),backdrop)
	head_choice=_choice(toolbar,["H 原整头","H 拆件试样"],["legacy","modular"],func(v):document.set_appearance("head",v);refresh(),document.appearance.head)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);root.add_child(body)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=218;body.add_child(left)
	_label(left,"装配部件 · Ctrl 多选",19)
	layer_list=ItemList.new();layer_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;layer_list.custom_minimum_size.y=180;left.add_child(layer_list)
	layer_list.select_mode=ItemList.SELECT_MULTI
	for group in Document.SELECT_ORDER:layer_list.add_item(Document.label_for(group))
	layer_list.select(0,true)
	layer_list.item_selected.connect(func(_i):sync_layer_selection())
	layer_list.multi_selected.connect(func(_i,_on):sync_layer_selection())
	var layer_scroll:=ScrollContainer.new();layer_scroll.custom_minimum_size.y=210;layer_scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL;layer_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;left.add_child(layer_scroll)
	var layer_panel:=VBoxContainer.new();layer_panel.size_flags_horizontal=Control.SIZE_EXPAND_FILL;layer_scroll.add_child(layer_panel)
	_label(layer_panel,"启用部件 · 随配置保存",15)
	var details:=GridContainer.new();details.columns=2;layer_panel.add_child(details)
	for id in ["skin","hair","beard","scar","bandage","blood"]:
		var label:String={"skin":"身体","hair":"发型","beard":"胡须","scar":"伤痕","bandage":"绷带","blood":"血迹"}[id]
		var checkbox:=CheckBox.new();checkbox.text=label;checkbox.button_pressed=document.appearance[id];details.add_child(checkbox);appearance_checks[id]=checkbox
		checkbox.toggled.connect(func(on):document.set_appearance(id,on);refresh())
	_label(layer_panel,"临时隐藏 · 仅检查",15)
	var layers:=GridContainer.new();layers.columns=2;layer_panel.add_child(layers)
	for id in ["base","head","body","linen","padded","mail","shield"]:
		var label:String={"base":"底座","head":"头部","body":"内衣","linen":"亚麻","padded":"绗缝","mail":"链甲","shield":"盾"}[id]
		_toggle(layers,label,func(on):set_layer_visible(id,on),true)
	var hint:=_label(layer_panel,"发须需切到 H 拆件试样\n血迹在皮肤上、衣物下\n盘面裁取与底座锚点可调\n默认保持现行范围",13);hint.modulate=Color("a8b4a4")
	stage=Stage.new();stage.owner_ui=self;stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stage.clip_contents=true;stage.focus_mode=Control.FOCUS_ALL;stage.mouse_default_cursor_shape=Control.CURSOR_MOVE;body.add_child(stage)
	var right_scroll:=ScrollContainer.new();right_scroll.custom_minimum_size.x=234;right_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(right_scroll)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",9);right_scroll.add_child(right)
	selection_label=_label(right,"人物整体",18)
	transform_box=VBoxContainer.new();transform_box.add_theme_constant_override("separation",9);right.add_child(transform_box)
	x_field=_number(transform_box,"左右 · ±128",-128,128,.25,func(_v):numbers_changed())
	y_field=_number(transform_box,"上下 · ±128",-128,128,.25,func(_v):numbers_changed())
	size_field=_number(transform_box,"等比大小 % · 25–300",25,300,1,func(_v):numbers_changed())
	angle_field=_number(transform_box,"旋转 ° · 绕锚点",-180,180,.5,func(_v):numbers_changed())
	crop_box=VBoxContainer.new();crop_box.add_theme_constant_override("separation",9);right.add_child(crop_box)
	crop_x=_number(crop_box,"裁取中心左右",-80,80,.25,func(_v):crop_changed())
	crop_y=_number(crop_box,"裁取中心上下",-80,80,.25,func(_v):crop_changed())
	crop_rx=_number(crop_box,"裁取半径横向 · 8–80",8,80,.25,func(_v):crop_changed())
	crop_ry=_number(crop_box,"裁取半径纵向 · 2–40",2,40,.25,func(_v):crop_changed())
	crop_top=_number(crop_box,"裁取顶边",-240,-20,1,func(_v):crop_changed())
	_button(crop_box,"恢复现行盘面",func():var d:=document.default_crop();document.change_crop(Vector2(d.center[0],d.center[1]),Vector2(d.radius[0],d.radius[1]),d.top);refresh())
	var undos:=HBoxContainer.new();right.add_child(undos)
	undo_button=_button(undos,"撤销",func():document.undo();refresh())
	redo_button=_button(undos,"重做",func():document.redo();refresh())
	_button(right,"复原此部件",reset_selected)
	_button(right,"复原全部调整",func():document.reset_all();refresh())
	_label(right,"对照与视图",18)
	_toggle(right,"盘面与锚点",func(v):guides=v;refresh(),true)
	_toggle(right,"查看选中部件原图",func(v):source_view=v;refresh())
	_button(right,"定位选中部件",focus_selected)
	_button(right,"视图归位",func():pan=Vector2.ZERO;zoom=4;refresh())
	_toggle(right,"叠加 v3 基准",func(v):ghost=v;refresh())
	var alpha:=HSlider.new();alpha.min_value=.05;alpha.max_value=.7;alpha.step=.05;alpha.value=ghost_alpha;alpha.tooltip_text="基准叠图透明度";right.add_child(alpha);alpha.value_changed.connect(func(v):ghost_alpha=v;refresh())
	_choice(right,["放大 1×","放大 2×","放大 3×","放大 4×","放大 5×","放大 6×"],[1.0,2.0,3.0,4.0,5.0,6.0],func(v):zoom=v;refresh(),4.0)
	_label(right,"武器动作 · 可编辑",18)
	play_button=_button(right,"播放动作",func():playing=not playing;elapsed=progress*Motion.duration(weapon,current_action());refresh())
	slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.001;right.add_child(slider)
	slider.value_changed.connect(func(v):playing=false;progress=v;elapsed=v*Motion.duration(weapon,current_action());refresh())
	_button(right,"回到待机",func():playing=false;progress=0;refresh())
	action_box=VBoxContainer.new();action_box.add_theme_constant_override("separation",7);right.add_child(action_box)
	duration_field=_number(action_box,"时长 · 秒",.2,4,.01,func(_v):action_timing_changed())
	release_field=_number(action_box,"出手 / 离弦",.02,.9,.001,func(_v):action_timing_changed())
	contact_field=_number(action_box,"接触 / 结果",.05,.98,.001,func(_v):action_timing_changed())
	_label(action_box,"关键帧 · 稳定编号",14)
	key_list=ItemList.new();key_list.custom_minimum_size.y=140;action_box.add_child(key_list)
	key_list.item_selected.connect(func(i):select_keyframe(i))
	key_t=_number(action_box,"帧时间 0–1",0,1,.001,func(_v):keyframe_changed())
	key_x=_number(action_box,"武器左右",-80,80,.25,func(_v):keyframe_changed())
	key_y=_number(action_box,"武器上下",-80,80,.25,func(_v):keyframe_changed())
	key_angle=_number(action_box,"武器角度 °",-180,180,.5,func(_v):keyframe_changed())
	var keys:=HBoxContainer.new();action_box.add_child(keys)
	_button(keys,"加帧",add_keyframe)
	_button(keys,"删帧",remove_keyframe)
	_button(action_box,"恢复默认动作",func():document.reset_action(weapon);selected_key="";refresh())
	notes=_label(right,"",14);notes.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;notes.custom_minimum_size.x=216
	status=_label(root,"",14);status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_close_dialog=ConfirmationDialog.new();_close_dialog.title="保留你的调整";_close_dialog.dialog_text="有尚未保存的调整。关闭会丢弃本次修改。";_close_dialog.ok_button_text="丢弃并关闭";_close_dialog.cancel_button_text="返回保存";add_child(_close_dialog);_close_dialog.confirmed.connect(func():closed.emit())
	get_tree().auto_accept_quit=false;get_window().close_requested.connect(request_close)
	refresh()

func _build_theme() -> void:
	var t:=Theme.new();t.default_font=_font;t.default_font_size=15
	for type in ["Button","OptionButton","LineEdit","ItemList"]:
		for state in ["normal","panel","hover","pressed","focus"]:
			var box:=StyleBoxFlat.new();box.bg_color=Color("283a34") if state not in ["hover","pressed"] else Color("4c5540")
			box.border_color=Color("a98b55") if state=="focus" else Color("596551");box.set_border_width_all(1);box.set_corner_radius_all(4)
			box.content_margin_left=10;box.content_margin_right=10;box.content_margin_top=7;box.content_margin_bottom=7;t.set_stylebox(state,type,box)
		for name in ["font_color","font_hover_color","font_pressed_color"]:t.set_color(name,type,Color("e8dcc4"))
	t.set_color("font_color","Label",Color("e8dcc4"));theme=t

func _label(parent:Node,value:String,font_size:int=16) -> Label:
	var l:=Label.new();l.text=value;l.add_theme_font_size_override("font_size",font_size);parent.add_child(l);return l

func _button(parent:Node,value:String,callback:Callable) -> Button:
	var b:=Button.new();b.text=value;b.pressed.connect(callback);parent.add_child(b);return b

func _toggle(parent:Node,value:String,callback:Callable,initial:bool=false) -> void:
	var b:=CheckBox.new();b.text=value;b.button_pressed=initial;b.toggled.connect(callback);parent.add_child(b)

func _choice(parent:Node,labels:Array,values:Array,callback:Callable,initial:Variant) -> OptionButton:
	var b:=OptionButton.new();for label in labels:b.add_item(str(label))
	b.selected=maxi(values.find(initial),0);b.item_selected.connect(func(i):callback.call(values[i]));parent.add_child(b)
	return b

func _number(parent:Node,label:String,low:float,high:float,step:float,callback:Callable) -> SpinBox:
	_label(parent,label,14);var field:=SpinBox.new();field.min_value=low;field.max_value=high;field.step=step;field.allow_greater=false;field.allow_lesser=false;field.value_changed.connect(callback);parent.add_child(field);return field

func select_order() -> Array:
	return Document.SELECT_ORDER

func transform_targets() -> Array[String]:
	var result:Array[String]=[]
	for group in selected_groups:
		if group!="crop" and group in Document.GROUPS:result.append(group)
	return result

func current_action() -> Dictionary:
	return document.action_for(weapon) if weapon!="none" else {}

func sync_layer_selection() -> void:
	if _syncing or layer_list==null:return
	var next:Array[String]=[]
	for index in layer_list.get_selected_items():
		next.append(Document.SELECT_ORDER[index])
	if next.is_empty():next=["bust"]
	selected_groups=next;selected=selected_groups[-1]
	if selected in ["sword","spear","bow"]:weapon=selected
	elif selected=="shield":weapon="sword"
	elif selected in ["body","linen","padded","mail","skin"]:armor={"body":"bare","skin":"nude"}.get(selected,selected)
	playing=false;progress=0;refresh()

func select_group(group:String) -> void:
	select_groups([group])

func select_groups(groups:Array) -> void:
	if groups.is_empty():groups=["bust"]
	selected_groups=[]
	for group in groups:
		if group in Document.SELECT_ORDER:selected_groups.append(str(group))
	if selected_groups.is_empty():selected_groups=["bust"]
	selected=selected_groups[-1]
	_syncing=true
	if layer_list!=null:
		layer_list.deselect_all()
		for group in selected_groups:layer_list.select(Document.SELECT_ORDER.find(group),false)
	_syncing=false
	if selected in ["sword","spear","bow"]:weapon=selected
	elif selected=="shield":weapon="sword"
	elif selected in ["body","linen","padded","mail","skin"]:armor={"body":"bare","skin":"nude"}.get(selected,selected)
	playing=false;progress=0;refresh()

func numbers_changed() -> void:
	if size_field==null or _syncing:return
	var targets:=transform_targets()
	if targets.is_empty():return
	if targets.size()==1:document.change(targets[0],Vector2(x_field.value,y_field.value),size_field.value/100.0,true,angle_field.value)
	else:document.change_shared(targets,Vector2(x_field.value,y_field.value),size_field.value/100.0,angle_field.value)
	refresh()

func crop_changed() -> void:
	if crop_x==null or _syncing:return
	document.change_crop(Vector2(crop_x.value,crop_y.value),Vector2(crop_rx.value,crop_ry.value),crop_top.value)
	refresh()

func reset_selected() -> void:
	if selected=="crop":
		var spec:=document.default_crop()
		document.change_crop(Vector2(spec.center[0],spec.center[1]),Vector2(spec.radius[0],spec.radius[1]),spec.top)
	elif selected_groups.size()>1:
		for group in transform_targets():document.change(group,Vector2.ZERO,1,group==transform_targets()[0],0)
	else:document.change(selected,Vector2.ZERO,1,true,0)
	refresh()

func refresh_action_fields() -> void:
	if action_box==null or weapon=="none":return
	var action:=current_action()
	duration_field.set_value_no_signal(action.duration)
	release_field.set_value_no_signal(action.release)
	contact_field.set_value_no_signal(action.contact)
	key_list.clear()
	var selected_index:=0
	for i in range(action.keyframes.size()):
		var key:Dictionary=action.keyframes[i]
		key_list.add_item("%s  t=%.2f"%[key.id,key.t])
		if key.id==selected_key:selected_index=i
	if action.keyframes.is_empty():return
	if selected_key.is_empty() or not action.keyframes.any(func(key):return key.id==selected_key):
		selected_key=action.keyframes[0].id;selected_index=0
	key_list.select(selected_index)
	var current:Dictionary=action.keyframes[selected_index]
	key_t.editable=selected_index>0 and selected_index<action.keyframes.size()-1
	key_t.set_value_no_signal(current.t)
	key_x.set_value_no_signal(current.x);key_y.set_value_no_signal(current.y)
	key_angle.set_value_no_signal(snappedf(rad_to_deg(current.angle),.1))

func select_keyframe(index:int) -> void:
	var action:=current_action()
	if index<0 or index>=action.keyframes.size():return
	selected_key=action.keyframes[index].id
	progress=action.keyframes[index].t;playing=false
	refresh()

func action_timing_changed() -> void:
	if _syncing or weapon=="none":return
	var action:=current_action()
	action.duration=duration_field.value;action.release=release_field.value;action.contact=contact_field.value
	document.set_action(weapon,action);refresh()

func keyframe_changed() -> void:
	if _syncing or weapon=="none" or selected_key.is_empty():return
	var action:=current_action()
	for key in action.keyframes:
		if key.id!=selected_key:continue
		key.t=key_t.value;key.x=key_x.value;key.y=key_y.value;key.angle=deg_to_rad(key_angle.value)
	document.set_action(weapon,action);refresh()

func add_keyframe() -> void:
	if weapon=="none":return
	var action:=current_action()
	var index:=0
	for i in range(action.keyframes.size()):
		if action.keyframes[i].id==selected_key:index=i
	var left:Dictionary=action.keyframes[index]
	var right:Dictionary=action.keyframes[mini(index+1,action.keyframes.size()-1)]
	if left.id==right.id and index>0:left=action.keyframes[index-1]
	var inserted:={"id":Motion.next_key_id(weapon,action.keyframes),"t":lerpf(left.t,right.t,.5) if left.t!=right.t else clampf(left.t+.05,0.02,.98),
		"x":lerpf(left.x,right.x,.5),"y":lerpf(left.y,right.y,.5),"angle":lerpf(left.angle,right.angle,.5)}
	action.keyframes.insert(mini(index+1,action.keyframes.size()-1),inserted)
	selected_key=inserted.id
	document.set_action(weapon,action);refresh()

func remove_keyframe() -> void:
	if weapon=="none" or selected_key.is_empty():return
	var action:=current_action()
	if action.keyframes.size()<=2:return
	for i in range(action.keyframes.size()):
		if action.keyframes[i].id!=selected_key:continue
		if i==0 or i==action.keyframes.size()-1:return
		action.keyframes.remove_at(i)
		selected_key=action.keyframes[maxi(i-1,0)].id
		document.set_action(weapon,action);refresh();return

func set_layer_visible(group:String,on:bool) -> void:
	var ids:Array=Document.GROUPS.get(group,[group])
	for id in ids:
		if on:hidden_layers.erase(id)
		elif id not in hidden_layers:hidden_layers.append(id)
	refresh()

func refresh() -> void:
	if stage==null:return
	_syncing=true
	catalog_data=document.composed()
	var editing_crop:=selected=="crop" and selected_groups.size()==1
	if transform_box!=null:transform_box.visible=not editing_crop
	if crop_box!=null:crop_box.visible=editing_crop
	if selected_groups.size()>1:
		var names:Array[String]=[]
		for group in selected_groups:names.append(Document.label_for(group))
		selection_label.text="多选 · "+str(selected_groups.size())+" 项"
	else:selection_label.text=Document.label_for(selected)
	armor_choice.select(["bare","linen","padded","mail","nude"].find(armor))
	head_choice.select(["legacy","modular"].find(document.appearance.head))
	for id in appearance_checks:appearance_checks[id].set_pressed_no_signal(document.appearance[id])
	weapon_choice.select(["none","sword","spear","bow"].find(weapon))
	view_choice.select(["fit","matrix","field","nesting"].find(view))
	background_choice.select(["green","earth","light","dark"].find(backdrop))
	var t:Dictionary=document.transform_for(selected if selected!="crop" else "bust")
	x_field.set_value_no_signal(t.offset[0]);y_field.set_value_no_signal(t.offset[1]);size_field.set_value_no_signal(t.scale*100)
	angle_field.set_value_no_signal(t.angle)
	var can_scale:=false
	for group in transform_targets():
		if Document.allows_scale(group):can_scale=true
	angle_field.editable=can_scale;size_field.editable=can_scale
	size_field.modulate=Color.WHITE if can_scale else Color(.6,.6,.6)
	var spec:=document.crop_spec()
	if crop_x!=null:
		crop_x.set_value_no_signal(spec.center[0]);crop_y.set_value_no_signal(spec.center[1])
		crop_rx.set_value_no_signal(spec.radius[0]);crop_ry.set_value_no_signal(spec.radius[1]);crop_top.set_value_no_signal(spec.top)
	slider.set_value_no_signal(progress);play_button.text="暂停动作" if playing else "播放动作"
	play_button.disabled=weapon=="none" or view!="fit"
	slider.editable=not play_button.disabled
	if action_box!=null:action_box.visible=weapon!="none" and view=="fit"
	refresh_action_fields()
	undo_button.disabled=document.history.is_empty();redo_button.disabled=document.future.is_empty()
	undo_button.text="撤销 (%d)"%document.history.size();redo_button.text="重做 (%d)"%document.future.size()
	var warnings:Array[String]=document.warnings()
	notes.text="\n".join(warnings) if not warnings.is_empty() else "配置有效\n仍需目视检查领口、遮挡和原尺寸效果。"
	notes.modulate=Color("e1b178") if not warnings.is_empty() else Color("a8b4a4")
	status.text=("● 未保存  " if document.dirty() else "H 装配台  ")+_notice
	_syncing=false
	stage.queue_redraw()

func _process(delta:float) -> void:
	if not playing or weapon=="none" or view!="fit":return
	elapsed+=delta
	var duration:=Motion.duration(weapon,current_action())
	if elapsed>duration+.6:elapsed=0
	progress=clampf(elapsed/duration,0,1)
	slider.set_value_no_signal(progress);stage.queue_redraw()

func camera() -> Dictionary:
	var scale_value:=minf(zoom,minf(stage.size.x/(230.0 if weapon=="bow" else 135.0),(stage.size.y-150)/100.0))
	return {"origin":Vector2(stage.size.x*(.30 if weapon=="bow" else .43),stage.size.y*.63)+pan,"scale":maxf(scale_value,1.0)}

func selected_id() -> String:
	if selected=="crop":return "base"
	if selected=="head" and document.appearance.head=="modular":return "face"
	if selected=="bust":return "head"
	if selected in Document.GROUPS:return Document.GROUPS[selected][0]
	return "head"

func selected_anchor() -> Vector2:
	if selected=="crop":
		var spec:=document.crop_spec()
		return Vector2(spec.center[0],spec.center[1])
	var id:=selected_id();var part:Dictionary=catalog_data.parts[id]
	var pos:=Vector2(part.position[0],part.position[1])
	if id in ["sword","spear","bow"]:pos+=Motion.sample(id,progress,"hit",current_action()).position
	return pos

func focus_selected() -> void:
	var cam:=camera();pan+=stage.size*Vector2(.5,.5)-(cam.origin+selected_anchor()*cam.scale);refresh()

func local_delta(delta:Vector2,group:String="") -> Vector2:
	# Child offsets are local to their head/skin. Drag stays under the pointer.
	if group.is_empty():group=selected
	if group=="crop" or not group in Document.GROUPS:return delta
	var id:String=Document.GROUPS[group][0]
	if group=="head" and document.appearance.head=="modular":id="face"
	var parent:String=catalog_data.parts[id].get("parent","")
	if not parent.is_empty():
		var t:Dictionary=document.transform_for(parent)
		delta=delta.rotated(-deg_to_rad(t.angle))/t.scale
	return delta

func stage_input(event:InputEvent) -> void:
	if view!="fit" or _modal_open():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_MIDDLE:
		_panning=event.pressed;_drag_start=event.position;_pan_start=pan;stage.accept_event();return
	if event is InputEventMouseMotion and _panning:pan=_pan_start+event.position-_drag_start;stage.queue_redraw();stage.accept_event();return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			stage.grab_focus();playing=false;progress=0;_dragging=true;_drag_start=event.position
			if selected=="crop":
				var spec:=document.crop_spec();_drag_offset=Vector2(spec.center[0],spec.center[1])
			else:
				var t:Dictionary=document.transform_for(selected);_drag_offset=Vector2(t.offset[0],t.offset[1])
			_drag_recorded=false
			_rotating=event.alt_pressed and selected!="crop" and transform_targets().any(func(group):return Document.allows_scale(group))
			_rotation_start=document.transform_for(selected).angle if selected!="crop" else 0.0
			_rotation_mouse=(event.position-camera().origin-selected_anchor()*camera().scale).angle()
		else:_dragging=false;_rotating=false
		stage.accept_event()
	if event is InputEventMouseMotion and _dragging:
		if _rotating:
			var angle:=rad_to_deg(wrapf((event.position-camera().origin-selected_anchor()*camera().scale).angle()-_rotation_mouse,-PI,PI))+_rotation_start
			angle=snappedf(clampf(angle,-180,180),.5)
			var targets:=transform_targets()
			var ok:=false
			if targets.size()>1:ok=document.rotate_shared(targets,angle,not _drag_recorded)
			elif not targets.is_empty():ok=document.change(targets[0],_drag_offset,document.transform_for(targets[0]).scale,not _drag_recorded,angle)
			if ok:_drag_recorded=true
			refresh();stage.accept_event();return
		var delta:Vector2=local_delta((event.position-_drag_start)/camera().scale)
		if selected=="crop":
			var spec:=document.crop_spec()
			var center:=(_drag_offset+delta).snapped(Vector2(.25,.25))
			if document.change_crop(center,Vector2(spec.radius[0],spec.radius[1]),spec.top,not _drag_recorded):_drag_recorded=true
		elif selected_groups.size()>1:
			if document.nudge_shared(transform_targets(),delta.snapped(Vector2(.25,.25)),not _drag_recorded):_drag_recorded=true
			_drag_start=event.position
		else:
			var offset:=(_drag_offset+delta).snapped(Vector2(.25,.25)).clamp(Vector2(-128,-128),Vector2(128,128))
			if offset!=_drag_offset or _drag_recorded:
				if document.change(selected,offset,document.transform_for(selected).scale,not _drag_recorded):_drag_recorded=true
		refresh();stage.accept_event()

func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:_dragging=false
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_MIDDLE:_panning=false
	if event is InputEventKey and event.pressed and not event.echo and not _modal_open():
		if event.ctrl_pressed and event.keycode==KEY_S:save_current();get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode==KEY_Z:
			if event.shift_pressed:document.redo()
			else:document.undo()
			refresh();get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode==KEY_Y:document.redo();refresh();get_viewport().set_input_as_handled()
		elif stage.has_focus() and view=="fit" and event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var delta:Vector2={KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}[event.keycode]
			delta*=1.0 if event.shift_pressed else .25
			if selected=="crop":
				var spec:=document.crop_spec()
				document.change_crop(Vector2(spec.center[0],spec.center[1])+delta,Vector2(spec.radius[0],spec.radius[1]),spec.top)
			elif selected_groups.size()>1:document.nudge_shared(transform_targets(),delta)
			else:
				var t:Dictionary=document.transform_for(selected)
				document.change(selected,Vector2(t.offset[0],t.offset[1])+local_delta(delta),t.scale)
			refresh();get_viewport().set_input_as_handled()

func _modal_open() -> bool:
	if _close_dialog!=null and _close_dialog.visible:return true
	for dialog in _dialogs:
		if is_instance_valid(dialog) and dialog.visible:return true
	return false

func _text(c:CanvasItem,value:String,at:Vector2,size_value:int=16,color:Color=Color("dfcda9")) -> void:
	if backdrop=="light":color=Color("584934")
	c.draw_string(_font,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,size_value,color)

func preview_catalog(data:Dictionary,wear:String,has_damage:bool) -> Dictionary:
	# Preview state is not part of the saved geometry or exported candidate.
	var result:=data.duplicate()
	result.wear_damage={"mail":has_damage and damage_scope in ["outer","all"],
		"padded":has_damage and (wear=="padded" or damage_scope in ["padding","all"])}
	return result

func draw_stage(c:Control) -> void:
	var bg:Color={"green":Color("293930"),"earth":Color("423a30"),"light":Color("e7e0d2"),"dark":Color("151d20")}[backdrop]
	c.draw_rect(Rect2(Vector2.ZERO,c.size),bg)
	if view=="matrix":_draw_matrix(c);return
	if view=="field":_draw_field(c);return
	if view=="nesting":_draw_nesting(c);return
	var cam:=camera();var at:Vector2=cam.origin;var s:float=cam.scale
	var rendered:=preview_catalog(catalog_data,armor,damaged)
	var reference:=preview_catalog(Actor.v3_catalog(),armor,damaged)
	if guides:
		for x in range(-40,61,10):c.draw_line(at+Vector2(x,-95)*s,at+Vector2(x,10)*s,Color(.6,.7,.6,.10))
		for y in range(-90,11,10):c.draw_line(at+Vector2(-45,y)*s,at+Vector2(65,y)*s,Color(.6,.7,.6,.10))
	Actor.draw_actor(c,at,s,armor,weapon,damaged,wounded,progress,"hit",rendered,hidden_layers)
	if source_view and selected not in ["bust","crop"]:
		var id:=selected_id();var pose:Dictionary=Motion.sample(id,progress,"hit",current_action()) if id in ["sword","spear","bow"] else {"position":Vector2.ZERO,"angle":0.0}
		Actor.draw_part(c,id,at,s,pose.position,pose.angle,Color(1,1,1,.42),catalog_data.parts)
	if weapon=="bow" and "bow" not in hidden_layers:
		var arrow:=Actor.arrow_sample(progress,"hit",catalog_data)
		if arrow.visible:Actor.draw_part(c,"arrow",at,s,arrow.position,arrow.angle,Color.WHITE,catalog_data.parts)
	if ghost:Actor.draw_actor(c,at,s,armor,weapon,damaged,wounded,progress,"hit",reference,[],Color(.6,.85,1,ghost_alpha))
	if guides:_draw_guides(c,at,s)
	_text(c,"拖动平移 · Alt 拖动旋转 · Ctrl 多选统一变换",Vector2(18,29),16)
	_text(c,"方向键微调 / Shift 加速 · Ctrl Z 撤销 · 盘面可调",Vector2(18,52),13)
	var small_y:=c.size.y-28
	Actor.draw_actor(c,Vector2(64,small_y),1,armor,weapon,damaged,wounded,0,"hit",rendered)
	Actor.draw_actor(c,Vector2(215,small_y),2,armor,weapon,damaged,wounded,0,"hit",rendered)
	Actor.draw_actor(c,Vector2(c.size.x-130,small_y),2,armor,weapon,damaged,wounded,0,"hit",reference)
	_text(c,"1×",Vector2(50,small_y-85),13);_text(c,"2× 当前",Vector2(173,small_y-156),13)
	_text(c,"2× v3 基准",Vector2(c.size.x-183,small_y-156),13)

func _draw_guides(c:Control,at:Vector2,s:float) -> void:
	var window:=Actor.bust_window(catalog_data)
	var outline:=PackedVector2Array()
	for point in window:outline.append(at+point*s)
	if outline.size()>1:outline.append(outline[0])
	c.draw_polyline(outline,Color("7d9ec8") if selected=="crop" else Color("c8aa6e"),2.0 if selected=="crop" else 1.5,true)
	c.draw_line(at+Vector2(-38,0)*s,at+Vector2(38,0)*s,Color("c8aa6e"),1)
	var spec:=document.crop_spec()
	var crop_center:=at+Vector2(spec.center[0],spec.center[1])*s
	c.draw_circle(crop_center,3,Color("7d9ec8"))
	var anchor:=at+selected_anchor()*s
	c.draw_circle(anchor,4,Color("f2d08a"));c.draw_line(anchor-Vector2(9,0),anchor+Vector2(9,0),Color("f2d08a"));c.draw_line(anchor-Vector2(0,9),anchor+Vector2(0,9),Color("f2d08a"))

func _draw_matrix(c:Control) -> void:
	_text(c,"穿戴 × 状态  ·  同一配置 / 同一镜头",Vector2(18,30),18)
	var cell:=Vector2(c.size.x/3.0,(c.size.y-65)/3.0)
	var s:=minf(cell.x/115,cell.y/105)
	for row in range(3):
		for col in range(3):
			var at:=Vector2((col+.42)*cell.x,65+(row+.89)*cell.y)
			var a:String=["linen","padded","mail"][col]
			Actor.draw_actor(c,at,s,a,weapon,row>0,row==2,0,"hit",preview_catalog(catalog_data,a,row>0))
			var state_label:String=["完好","甲损","甲损 / 脸伤"][row]
			if col==0:state_label=["完好","无甲损变体","脸伤"][row]
			_text(c,["亚麻","绗缝","链甲"][col]+" · "+state_label,Vector2(col*cell.x+14,65+row*cell.y),13)

func _draw_field(c:Control) -> void:
	_text(c,"战场尺寸检查  ·  1× / 2×",Vector2(18,30),18)
	_text(c,"仅为尺寸与相邻遮挡检查；不代表新增战场美术。",Vector2(18,53),14)
	for row in range(2):
		var s:=float(row+1);var y:=c.size.y*(.38 if row==0 else .8)
		var step:=82*s;var start:=c.size.x*.5-step
		for i in range(3):
			var at:=Vector2(start+i*step,y)
			var hex:=PackedVector2Array()
			for j in range(6):hex.append(at+Vector2(cos(j*PI/3),sin(j*PI/3))*(39*s))
			c.draw_colored_polygon(hex,Color(.45,.49,.35,.13));hex.append(hex[0]);c.draw_polyline(hex,Color(.7,.7,.55,.25),1,true)
			Actor.draw_actor(c,at,s,["linen","padded","mail"][i],["sword","spear","bow"][i],damaged,wounded,0,"hit",preview_catalog(catalog_data,["linen","padded","mail"][i],damaged))
		_text(c,str(row+1)+"×",Vector2(18,y),18)

func _draw_nesting(c:Control) -> void:
	_text(c,"内外层检查  ·  露出的材质来自实际内层",Vector2(18,30),18)
	_text(c,"隐藏头、武器和底座查看透空；下排仅链甲破损。",Vector2(18,54),14)
	var cell:=Vector2(c.size.x/3.0,(c.size.y-80)/2.0)
	var s:=minf(cell.x/82.0,cell.y/72.0)
	var labels:=["旧 v3：领口暗面遮挡","亚麻＋基础内衣","同件亚麻：移除内衣","破损链甲＋完好绗缝","同件链甲：移除绗缝","同件链甲：移除所有内层"]
	for i in range(6):
		var row:=i/3;var col:=i%3
		var data:Dictionary=Actor.v3_catalog() if i==0 else catalog_data.duplicate(true)
		data=data.duplicate(true);data.wear_damage={"mail":true,"padded":false}
		var hidden:Array=["head","wounded","base"]
		if i==2:hidden.append_array(["body","skin","blood"])
		if i>=4:hidden.append_array(["padded","padded_damaged"])
		if i==5:hidden.append_array(["linen","body","skin","blood"])
		var at:=Vector2((col+.50)*cell.x,80+(row+.82)*cell.y)
		Actor.draw_body(c,at,s,"linen" if row==0 else "mail",false,false,data,hidden)
		_text(c,labels[i],Vector2(col*cell.x+12,80+row*cell.y),13)

func request_close() -> void:
	playing=false
	if document.dirty():_close_dialog.popup_centered(Vector2i(440,160))
	else:closed.emit()

func save_current() -> void:
	if project_path.is_empty():_file_dialog("save")
	else:_save_project(project_path)

func _save_project(path:String) -> void:
	var error:String=document.save_project(path)
	if error.is_empty():project_path=path;_notice="已保存："+path
	else:_notice=error
	refresh()

func open_project(path:String) -> bool:
	var error:String=document.load_project(path)
	if error.is_empty():
		project_path=path
		if document.migrated_v3:project_path=path.get_basename()+"-v2.json"
		_notice=("旧配置已无损载入；保存将写入新副本：" if document.migrated_v3 else "已载入：")+project_path
	else:_notice=error
	refresh();return error.is_empty()

func _file_dialog(action:String) -> void:
	playing=false;_dragging=false
	if action=="open" and document.dirty():
		var confirm:=ConfirmationDialog.new();confirm.title="打开另一份调整";confirm.dialog_text="当前修改尚未保存。继续打开会替换它；可用撤销恢复。";confirm.ok_button_text="继续打开";confirm.cancel_button_text="返回保存";add_child(confirm);_dialogs.append(confirm)
		confirm.confirmed.connect(func():_show_file_dialog(action));confirm.popup_centered();return
	_show_file_dialog(action)

func _show_file_dialog(action:String) -> void:
	var dialog:=FileDialog.new();dialog.access=FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode=FileDialog.FILE_MODE_OPEN_FILE if action=="open" else FileDialog.FILE_MODE_SAVE_FILE
	dialog.title={"open":"打开装配调整","save":"保存装配调整","catalog":"导出候选装配目录","image":"保存工作台截图"}[action]
	dialog.filters=PackedStringArray(["*.png ; PNG 截图"] if action=="image" else ["*.json ; 装配 JSON"])
	dialog.current_dir=project_path.get_base_dir() if not project_path.is_empty() else OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)
	dialog.current_file={"open":"","save":"my-paperdoll.json","catalog":"candidate-catalog.json","image":"paperdoll-review.png"}[action]
	add_child(dialog);_dialogs.append(dialog)
	dialog.file_selected.connect(func(path):
		if action=="open":open_project(path)
		elif action=="save":_save_project(path)
		elif action=="catalog":
			var error:=Document.write_json(path,catalog_data)
			_notice="候选已导出，正式基准未改变："+path if error.is_empty() else error;refresh()
		else:call_deferred("save_screenshot",path))
	dialog.popup_centered_ratio(.75)

func save_screenshot(path:String) -> void:
	var path_error:=Document.output_path_error(path)
	if not path_error.is_empty():_notice=path_error;refresh();return
	if path.get_extension().to_lower()!="png":_notice="请选择 .png 文件。";refresh();return
	await RenderingServer.frame_post_draw
	var error:=get_viewport().get_texture().get_image().save_png(path)
	_notice="截图已保存："+path if error==OK else "截图保存失败。";refresh()

func capture_all(output:String) -> void:
	if DisplayServer.get_name()=="headless":get_tree().quit(1);return
	DirAccess.make_dir_recursive_absolute(output)
	get_window().size=Vector2i(1440,960);get_window().content_scale_size=get_window().size
	for item in [["fit","green"],["matrix","green"],["field","earth"],["fit","light"],["nesting","green"],["nesting","light"]]:
		view=item[0];backdrop=item[1];refresh();await get_tree().process_frame;await RenderingServer.frame_post_draw
		if get_viewport().get_texture().get_image().save_png(output.path_join(item[0]+"-"+item[1]+".png"))!=OK:get_tree().quit(1);return
	view="fit";backdrop="green";ghost=true;document.change("head",Vector2(2,-1),.95);refresh()
	await get_tree().process_frame;await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png(output.path_join("adjusted-overlay.png"))!=OK:get_tree().quit(1);return
	print("Paperdoll captures: "+output);get_tree().quit()

func run_smoke(output:String) -> void:
	await preload("res://tests/paperdoll_smoke.gd").new().run(self,output)

func run_nesting_test(output:String) -> void:
	await preload("res://tests/nested_wear_smoke.gd").new().run(self,output)

func run_modular_test(output:String) -> void:
	await preload("res://tests/paperdoll_modular_smoke.gd").new().run(self,output)
