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
var _dialogs:Array=[]
var _close_dialog:ConfirmationDialog
var _notice:="选择左侧部件，拖动人物或用右侧数值微调。"

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
	armor_choice=_choice(toolbar,["基础内衣","亚麻","绗缝甲","绗缝＋链甲"],["bare","linen","padded","mail"],func(v):armor=v;refresh(),armor)
	weapon_choice=_choice(toolbar,["无武器","剑盾","长矛","弓"],["none","sword","spear","bow"],func(v):weapon=v;progress=0;elapsed=0;refresh(),weapon)
	_toggle(toolbar,"甲损",func(v):damaged=v;refresh())
	_choice(toolbar,["损外层","损衬甲","全损"],["outer","padding","all"],func(v):damage_scope=v;refresh(),damage_scope)
	_toggle(toolbar,"脸伤",func(v):wounded=v;refresh())
	background_choice=_choice(toolbar,["苔绿底","泥土底","浅底","深底"],["green","earth","light","dark"],func(v):backdrop=v;refresh(),backdrop)
	var body:=HBoxContainer.new();body.size_flags_vertical=Control.SIZE_EXPAND_FILL;body.add_theme_constant_override("separation",12);root.add_child(body)
	var left:=VBoxContainer.new();left.custom_minimum_size.x=218;body.add_child(left)
	_label(left,"装配部件",19)
	layer_list=ItemList.new();layer_list.size_flags_vertical=Control.SIZE_EXPAND_FILL;layer_list.custom_minimum_size.y=265;left.add_child(layer_list)
	for group in Document.GROUPS:layer_list.add_item(Document.LABELS[group])
	layer_list.select(0);layer_list.item_selected.connect(func(i):select_group(Document.GROUPS.keys()[i]))
	_label(left,"查看图层",17)
	var layers:=GridContainer.new();layers.columns=2;left.add_child(layers)
	for id in ["base","head","body","linen","padded","mail","shield"]:
		var label:String={"base":"底座","head":"头部","body":"内衣","linen":"亚麻","padded":"绗缝","mail":"链甲","shield":"盾"}[id]
		_toggle(layers,label,func(on):set_layer_visible(id,on),true)
	var hint:=_label(left,"完好与破损同步调整\n底座、盘面和层序锁定\n图层开关仅用于检查",14);hint.modulate=Color("a8b4a4")
	stage=Stage.new();stage.owner_ui=self;stage.size_flags_horizontal=Control.SIZE_EXPAND_FILL;stage.size_flags_vertical=Control.SIZE_EXPAND_FILL
	stage.clip_contents=true;stage.focus_mode=Control.FOCUS_ALL;stage.mouse_default_cursor_shape=Control.CURSOR_MOVE;body.add_child(stage)
	var right_scroll:=ScrollContainer.new();right_scroll.custom_minimum_size.x=234;right_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED;body.add_child(right_scroll)
	var right:=VBoxContainer.new();right.size_flags_horizontal=Control.SIZE_EXPAND_FILL;right.add_theme_constant_override("separation",9);right_scroll.add_child(right)
	selection_label=_label(right,"人物整体",18)
	x_field=_number(right,"左右",-20,20,.25,func(_v):numbers_changed())
	y_field=_number(right,"上下",-20,20,.25,func(_v):numbers_changed())
	size_field=_number(right,"等比大小 %",70,130,1,func(_v):numbers_changed())
	var undos:=HBoxContainer.new();right.add_child(undos)
	undo_button=_button(undos,"撤销",func():document.undo();refresh())
	redo_button=_button(undos,"重做",func():document.redo();refresh())
	_button(right,"复原此部件",func():document.change(selected,Vector2.ZERO,1);refresh())
	_button(right,"复原全部调整",func():document.reset_all();refresh())
	_label(right,"对照与视图",18)
	_toggle(right,"盘面与锚点",func(v):guides=v;refresh(),true)
	_toggle(right,"叠加 v3 基准",func(v):ghost=v;refresh())
	var alpha:=HSlider.new();alpha.min_value=.05;alpha.max_value=.7;alpha.step=.05;alpha.value=ghost_alpha;alpha.tooltip_text="基准叠图透明度";right.add_child(alpha);alpha.value_changed.connect(func(v):ghost_alpha=v;refresh())
	_choice(right,["放大 3×","放大 4×","放大 5×","放大 6×"],[3.0,4.0,5.0,6.0],func(v):zoom=v;refresh(),4.0)
	_label(right,"动作检查",18)
	play_button=_button(right,"播放动作",func():playing=not playing;elapsed=progress*Motion.duration(weapon);refresh())
	slider=HSlider.new();slider.min_value=0;slider.max_value=1;slider.step=.001;right.add_child(slider)
	slider.value_changed.connect(func(v):playing=false;progress=v;elapsed=v*Motion.duration(weapon);refresh())
	_button(right,"回到待机",func():playing=false;progress=0;refresh())
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

func select_group(group:String) -> void:
	selected=group;layer_list.select(Document.GROUPS.keys().find(group))
	if group in ["sword","spear","bow"]:weapon=group
	elif group=="shield":weapon="sword"
	elif group in ["body","linen","padded","mail"]:armor="bare" if group=="body" else group
	playing=false;progress=0;refresh()

func numbers_changed() -> void:
	if size_field==null:return
	document.change(selected,Vector2(x_field.value,y_field.value),size_field.value/100.0)
	refresh()

func set_layer_visible(group:String,on:bool) -> void:
	var ids:Array=Document.GROUPS.get(group,[group])
	for id in ids:
		if on:hidden_layers.erase(id)
		elif id not in hidden_layers:hidden_layers.append(id)
	refresh()

func refresh() -> void:
	if stage==null:return
	catalog_data=document.composed()
	var t:Dictionary=document.transform_for(selected)
	selection_label.text=Document.LABELS[selected]
	armor_choice.select(["bare","linen","padded","mail"].find(armor))
	weapon_choice.select(["none","sword","spear","bow"].find(weapon))
	view_choice.select(["fit","matrix","field","nesting"].find(view))
	background_choice.select(["green","earth","light","dark"].find(backdrop))
	x_field.set_value_no_signal(t.offset[0]);y_field.set_value_no_signal(t.offset[1]);size_field.set_value_no_signal(t.scale*100)
	size_field.editable=selected!="bust";size_field.modulate=Color.WHITE if selected!="bust" else Color(.6,.6,.6)
	slider.set_value_no_signal(progress);play_button.text="暂停动作" if playing else "播放动作"
	play_button.disabled=weapon=="none" or view!="fit"
	slider.editable=not play_button.disabled
	undo_button.disabled=document.history.is_empty();redo_button.disabled=document.future.is_empty()
	var warnings:Array[String]=document.warnings()
	notes.text="\n".join(warnings) if not warnings.is_empty() else "配置有效\n仍需目视检查领口、遮挡和原尺寸效果。"
	notes.modulate=Color("e1b178") if not warnings.is_empty() else Color("a8b4a4")
	status.text=("● 未保存  " if document.dirty() else "H 嵌套穿戴  ")+_notice
	stage.queue_redraw()

func _process(delta:float) -> void:
	if not playing or weapon=="none" or view!="fit":return
	elapsed+=delta
	var duration:=Motion.duration(weapon)
	if elapsed>duration+.6:elapsed=0
	progress=clampf(elapsed/duration,0,1)
	slider.set_value_no_signal(progress);stage.queue_redraw()

func camera() -> Dictionary:
	var scale_value:=minf(zoom,minf(stage.size.x/(230.0 if weapon=="bow" else 135.0),(stage.size.y-150)/100.0))
	return {"origin":Vector2(stage.size.x*(.30 if weapon=="bow" else .43),stage.size.y*.63),"scale":maxf(scale_value,1.0)}

func stage_input(event:InputEvent) -> void:
	if view!="fit" or _modal_open():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			stage.grab_focus();playing=false;progress=0;_dragging=true;_drag_start=event.position
			var t:Dictionary=document.transform_for(selected);_drag_offset=Vector2(t.offset[0],t.offset[1]);_drag_recorded=false
		else:_dragging=false
		stage.accept_event()
	if event is InputEventMouseMotion and _dragging:
		var delta:Vector2=(event.position-_drag_start)/camera().scale
		var offset:=(_drag_offset+delta).snapped(Vector2(.25,.25)).clamp(Vector2(-20,-20),Vector2(20,20))
		if offset!=_drag_offset or _drag_recorded:
			if document.change(selected,offset,document.transform_for(selected).scale,not _drag_recorded):_drag_recorded=true
		refresh();stage.accept_event()

func _input(event:InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed and event.button_index==MOUSE_BUTTON_LEFT:_dragging=false
	if event is InputEventKey and event.pressed and not event.echo and not _modal_open():
		if event.ctrl_pressed and event.keycode==KEY_S:save_current();get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode==KEY_Z:document.undo();refresh();get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode==KEY_Y:document.redo();refresh();get_viewport().set_input_as_handled()
		elif stage.has_focus() and view=="fit" and event.keycode in [KEY_LEFT,KEY_RIGHT,KEY_UP,KEY_DOWN]:
			var delta:Vector2={KEY_LEFT:Vector2.LEFT,KEY_RIGHT:Vector2.RIGHT,KEY_UP:Vector2.UP,KEY_DOWN:Vector2.DOWN}[event.keycode]
			var t:Dictionary=document.transform_for(selected);delta*=1.0 if event.shift_pressed else .25
			document.change(selected,Vector2(t.offset[0],t.offset[1])+delta,t.scale);refresh();get_viewport().set_input_as_handled()

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
	if weapon=="bow" and "bow" not in hidden_layers:
		var arrow:=Actor.arrow_sample(progress,"hit",catalog_data)
		if arrow.visible:Actor.draw_part(c,"arrow",at,s,arrow.position,arrow.angle,Color.WHITE,catalog_data.parts)
	if ghost:Actor.draw_actor(c,at,s,armor,weapon,damaged,wounded,progress,"hit",reference,[],Color(.6,.85,1,ghost_alpha))
	if guides:_draw_guides(c,at,s)
	_text(c,"当前调整  ·  拖动 / 方向键微调",Vector2(18,29),18)
	_text(c,"底座与截取线固定；原画保持完整。",Vector2(18,52),14)
	var small_y:=c.size.y-28
	Actor.draw_actor(c,Vector2(64,small_y),1,armor,weapon,damaged,wounded,0,"hit",rendered)
	Actor.draw_actor(c,Vector2(215,small_y),2,armor,weapon,damaged,wounded,0,"hit",rendered)
	Actor.draw_actor(c,Vector2(c.size.x-130,small_y),2,armor,weapon,damaged,wounded,0,"hit",reference)
	_text(c,"1×",Vector2(50,small_y-85),13);_text(c,"2× 当前",Vector2(173,small_y-156),13)
	_text(c,"2× v3 基准",Vector2(c.size.x-183,small_y-156),13)

func _draw_guides(c:Control,at:Vector2,s:float) -> void:
	var arc:=Actor.bust_window(catalog_data).slice(2)
	for i in range(arc.size()):arc[i]=at+arc[i]*s
	c.draw_polyline(arc,Color("c8aa6e"),1.5,true)
	c.draw_line(at+Vector2(-38,0)*s,at+Vector2(38,0)*s,Color("c8aa6e"),1)
	var id:String="head" if selected=="bust" else Document.GROUPS[selected][0]
	var part:Dictionary=catalog_data.parts[id]
	var pos:=Vector2(part.position[0],part.position[1])
	if id in ["sword","spear","bow"]:pos+=Motion.sample(id,progress).position
	var anchor:=at+pos*s
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
		if i==2:hidden.append("body")
		if i>=4:hidden.append_array(["padded","padded_damaged"])
		if i==5:hidden.append_array(["linen","body"])
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
		project_path=path;_notice=("已保留 v3 定位，衣甲已更新，请复看并另存：" if document.migrated_v3 else "已载入：")+path
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
