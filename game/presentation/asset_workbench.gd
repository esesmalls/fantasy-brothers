extends Control
signal closed
const Document = preload("res://presentation/asset_document.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Canvas = preload("res://presentation/asset_canvas.gd")
const Timeline = preload("res://presentation/asset_timeline.gd")
var doc := Document.new()
var selected: Array = []
var placement_selected := false
var through_box := false
var solo: Array = []
var adaptation := ""
var action_id := "sword"
var animation_mode := false
var auto_key := false
var time := 0.0
var playing := false
var loop := true
var speed := 1.0
var refreshing := false
var library: ItemList
var layers: Tree
var search: LineEdit
var category: OptionButton
var tag_filter: LineEdit
var inspector: VBoxContainer
var canvas: Control
var timeline: Control
var timeline_panel: VBoxContainer
var status: Label
var adapt_choice: OptionButton
var action_choice: OptionButton
var left_panel: VBoxContainer
var right_panel: ScrollContainer
var file_dialog: FileDialog
var pending_file_action := ""
var last_row := ""
var layer_sort := "绘制顺序"
var key_property := "x"
var key_value: SpinBox
var key_interpolation := "linear"
var import_path := ""
var import_dialog: ConfirmationDialog
var import_preview: Control
var import_regions: Array = []
var import_image: Texture2D
var import_start := Vector2.ZERO
var import_end := Vector2.ZERO
var import_drag := false
var import_id: LineEdit
var import_name: LineEdit
var import_category: LineEdit
var import_hint: Label
var unsaved_dialog: ConfirmationDialog
var pending_close: Callable
var status_note := ""
var same_values := false
var inspector_values: Dictionary = {}

func _ready() -> void:
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_window().content_scale_size = Vector2i.ZERO
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_theme()
	var root := VBoxContainer.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(root)
	var menu := HBoxContainer.new(); root.add_child(menu)
	menu_button(menu, "文件", ["打开工程", "保存工程", "另存为", "导入图片／图集", "应用到游戏", "恢复上次应用", "导出截图", "关闭"], file_menu)
	menu_button(menu, "编辑", ["撤销", "重做", "恢复所选默认参数", "移出参考组合", "独显所选／取消独显", "将所选建立编辑组"], edit_menu)
	menu_button(menu, "视图", ["显示／隐藏资产面板", "显示／隐藏属性面板", "适应画布", "定位所选", "1×实际尺寸", "叠加／隐藏默认基准", "参考叠图透明度…"], view_menu)
	menu_button(menu, "帮助", ["操作与数据说明"], func(_i): show_text("装配台", "资产参数用于游戏表现；参考组合不决定游戏装备。\n点击选中，Ctrl 增减，Shift 连续／框选追加。\n空格或中键平移，滚轮缩放，F 定位。\nCtrl+Z 撤销，Ctrl+Shift+Z 重做，Ctrl+S 保存。\n眼睛、锁定与独显只影响编辑。\n源图区域是图片像素；位置是游戏逻辑像素；角度为度。\n保存草案后可另行应用，普通游戏重新进入场景或重启生效。"))
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; menu.add_child(spacer)
	label(menu, "PAPERDOLL  /  资产表现", 14)
	var bar := HBoxContainer.new(); root.add_child(bar)
	var tool_group := ButtonGroup.new()
	for entry in [["选择 V", "select"], ["移动 G", "move"], ["旋转 R", "rotate"], ["缩放 S", "scale"]]:
		var button := button(bar, entry[0], func(): canvas.mode = entry[1]; canvas.queue_redraw())
		button.toggle_mode = true; button.button_group = tool_group; button.button_pressed = entry[1] == "move"
	button(bar, "撤销", func(): doc.undo(); refresh())
	button(bar, "重做", func(): doc.redo(); refresh())
	choice(bar, ["组合", "单件", "战场"], func(value): canvas.preview = value; canvas.queue_redraw())
	check_box(bar, "网格", true, func(on): canvas.grid = on; canvas.queue_redraw())
	check_box(bar, "吸附", false, func(on): canvas.snap = on)
	choice(bar, ["共同中心", "各自枢轴"], func(value): canvas.individual = value == "各自枢轴")
	button(bar, "保存", save)
	button(bar, "应用…", review_apply)
	var main := HSplitContainer.new(); main.size_flags_vertical = Control.SIZE_EXPAND_FILL; root.add_child(main)
	left_panel = VBoxContainer.new(); left_panel.custom_minimum_size.x = 230; main.add_child(left_panel)
	var lib_header := HBoxContainer.new(); left_panel.add_child(lib_header)
	label(lib_header, "资产库", 16); button(lib_header, "+ 导入", func(): browse("import")); button(lib_header, "刷新", refresh_assets)
	search = LineEdit.new(); search.placeholder_text = "搜索名称或 ID"; left_panel.add_child(search); search.text_changed.connect(func(_v): refresh_library())
	category = OptionButton.new(); left_panel.add_child(category); category.item_selected.connect(func(_i): refresh_library())
	tag_filter = LineEdit.new(); tag_filter.placeholder_text = "标签筛选"; left_panel.add_child(tag_filter); tag_filter.text_changed.connect(func(_v): refresh_library())
	library = ItemList.new(); library.custom_minimum_size.y = 170; library.size_flags_vertical = Control.SIZE_EXPAND_FILL; library.fixed_icon_size = Vector2i(38, 38); left_panel.add_child(library)
	library.item_selected.connect(func(index): select([library.get_item_metadata(index)]))
	library.item_activated.connect(func(index): add_to_scene(library.get_item_metadata(index)))
	button(left_panel, "添加所选到参考组合", func():
		for id in selected: add_to_scene(id))
	button(left_panel, "人物整体 · 棋格内摆放", select_placement)
	var selection_bar := HBoxContainer.new(); left_panel.add_child(selection_bar)
	button(selection_bar, "选择整个装配", select_assembly)
	check_box(selection_bar, "穿透框选", false, func(on): through_box = on)
	var scene_header := HBoxContainer.new(); left_panel.add_child(scene_header)
	label(scene_header, "场景层", 16)
	choice(scene_header, ["绘制顺序", "附着层级", "编辑分组"], func(value): layer_sort = value; refresh_layers())
	layers = Tree.new(); layers.hide_root = true; layers.columns = 3; layers.set_column_expand(0, true)
	layers.set_column_expand(1, false); layers.set_column_custom_minimum_width(1, 32); layers.set_column_expand(2, false); layers.set_column_custom_minimum_width(2, 32)
	layers.set_column_title(0, "名称"); layers.set_column_title(1, "显"); layers.set_column_title(2, "锁"); layers.column_titles_visible = true
	layers.custom_minimum_size.y = 170; layers.size_flags_vertical = Control.SIZE_EXPAND_FILL; left_panel.add_child(layers)
	layers.item_selected.connect(layer_selected); layers.item_edited.connect(layer_edited)
	var order := HBoxContainer.new(); left_panel.add_child(order)
	button(order, "上移层", func(): reorder(1)); button(order, "下移层", func(): reorder(-1)); button(order, "独显", toggle_solo)
	var center_right := HSplitContainer.new(); center_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL; main.add_child(center_right)
	var center_column := VBoxContainer.new(); center_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL; center_right.add_child(center_column)
	var context := HBoxContainer.new(); center_column.add_child(context)
	label(context, "编辑：", 13)
	adapt_choice = OptionButton.new(); context.add_child(adapt_choice); adapt_choice.item_selected.connect(func(index): adaptation = adapt_choice.get_item_metadata(index); refresh())
	button(context, "+ 适配", new_adaptation)
	button(context, "预览组合…", preview_dialog)
	button(context, "适应", func(): canvas.fit())
	canvas = Canvas.new(); canvas.ui = self; canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL; canvas.custom_minimum_size = Vector2(300, 200); center_column.add_child(canvas)
	var animation_bar := HBoxContainer.new(); center_column.add_child(animation_bar)
	check_box(animation_bar, "动作模式", false, func(on): animation_mode = on; playing = false; timeline_panel.visible = on; refresh_inspector(); canvas.queue_redraw())
	label(animation_bar, "基础姿态 / 动作分开编辑", 12)
	timeline_panel = VBoxContainer.new(); timeline_panel.visible = false; center_column.add_child(timeline_panel)
	var playback := HFlowContainer.new(); timeline_panel.add_child(playback)
	action_choice = OptionButton.new(); playback.add_child(action_choice); action_choice.item_selected.connect(func(index): action_id = action_choice.get_item_text(index); time = 0; refresh())
	button(playback, "+ 动作", new_action)
	button(playback, "▶ / Ⅱ", func(): playing = not playing)
	button(playback, "◀ 帧", func(): time = maxf(0, time - 1.0 / 30); refresh_time())
	button(playback, "帧 ▶", func(): time = minf(float(current_action().get("duration", 1)), time + 1.0 / 30); refresh_time())
	check_box(playback, "循环", true, func(on): loop = on)
	choice(playback, ["1×", "0.25×", "0.5×", "2×"], func(value): speed = float(value.trim_suffix("×")))
	check_box(playback, "自动关键帧", false, func(on): auto_key = on)
	timeline = Timeline.new(); timeline.ui = self; timeline.custom_minimum_size.y = 135; timeline_panel.add_child(timeline)
	var key_bar := HFlowContainer.new(); timeline_panel.add_child(key_bar)
	choice(key_bar, Document.PROPERTIES, func(value): key_property = value; refresh_inspector())
	key_value = SpinBox.new(); key_value.min_value = -10000; key_value.max_value = 10000; key_value.step = 0.01; key_value.custom_minimum_size.x = 85; key_bar.add_child(key_value)
	choice(key_bar, ["linear", "smooth", "hold"], func(value): key_interpolation = value)
	button(key_bar, "落帧", func():
		doc.checkpoint("关键帧")
		for id: String in selected: put_key(id, key_property, bool(key_value.value) if key_property == "visible" else key_value.value, false)
		refresh())
	button(key_bar, "复制帧", func(): timeline.copy_keys())
	button(key_bar, "删除帧", func(): timeline.delete_keys())
	right_panel = ScrollContainer.new(); right_panel.custom_minimum_size.x = 270; right_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; center_right.add_child(right_panel)
	inspector = VBoxContainer.new(); inspector.size_flags_horizontal = Control.SIZE_EXPAND_FILL; right_panel.add_child(inspector)
	status = Label.new(); status.custom_minimum_size.y = 26; status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS; root.add_child(status)
	file_dialog = FileDialog.new(); file_dialog.access = FileDialog.ACCESS_FILESYSTEM; file_dialog.size = Vector2i(850, 560); add_child(file_dialog); file_dialog.file_selected.connect(file_chosen)
	get_window().files_dropped.connect(files_dropped)
	get_tree().auto_accept_quit = false; get_window().close_requested.connect(request_close)
	selected = ["sword"]
	refresh()

func _build_theme() -> void:
	var t := Theme.new(); t.default_font_size = 14
	var font := SystemFont.new(); font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"]); t.default_font = font
	for type: String in ["Button", "OptionButton", "LineEdit", "Tree", "ItemList", "PopupMenu", "SpinBox"]:
		for state: String in ["normal", "panel", "read_only"]:
			var style := StyleBoxFlat.new(); style.bg_color = Color("2c2f35"); style.set_corner_radius_all(3); style.content_margin_left = 8; style.content_margin_right = 8; style.content_margin_top = 5; style.content_margin_bottom = 5
			t.set_stylebox(state, type, style)
		var active := StyleBoxFlat.new(); active.bg_color = Color("345577"); active.set_corner_radius_all(3); active.content_margin_left = 8; active.content_margin_right = 8; active.content_margin_top = 5; active.content_margin_bottom = 5
		t.set_stylebox("hover", type, active); t.set_stylebox("pressed", type, active); t.set_stylebox("selected", type, active)
		t.set_color("font_color", type, Color("dde1e8"))
	t.set_constant("separation", "VBoxContainer", 6); t.set_constant("separation", "HBoxContainer", 6)
	theme = t

func label(parent: Node, text: String, font_size: int = 14) -> Label:
	var node := Label.new(); node.text = text; node.add_theme_font_size_override("font_size", font_size); parent.add_child(node); return node

func button(parent: Node, text: String, callback: Callable) -> Button:
	var node := Button.new(); node.text = text; node.pressed.connect(callback); parent.add_child(node); return node

func choice(parent: Node, values: Array, callback: Callable) -> OptionButton:
	var node := OptionButton.new()
	for value in values: node.add_item(str(value))
	node.item_selected.connect(func(index): callback.call(values[index])); parent.add_child(node); return node

func check_box(parent: Node, text: String, initial: bool, callback: Callable) -> CheckBox:
	var node := CheckBox.new(); node.text = text; node.button_pressed = initial; node.toggled.connect(callback); parent.add_child(node); return node

func number(parent: Node, text: String, value: float, callback: Callable, step: float = 0.1) -> SpinBox:
	var row := HBoxContainer.new(); parent.add_child(row)
	var caption := label(row, text, 13); caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var node := SpinBox.new(); node.min_value = -100000; node.max_value = 100000; node.step = step; node.value = value; node.custom_minimum_size.x = 118; row.add_child(node)
	node.value_changed.connect(func(v):
		if not refreshing: callback.call(v))
	return node

func text_field(parent: Node, title: String, value: String, callback: Callable) -> LineEdit:
	label(parent, title, 12)
	var edit := LineEdit.new(); edit.text = value; parent.add_child(edit)
	edit.text_submitted.connect(callback); edit.focus_exited.connect(func():
		if edit.text != value and not refreshing: callback.call(edit.text))
	return edit

func menu_button(parent: Node, title: String, entries: Array, callback: Callable) -> void:
	var node := MenuButton.new(); node.text = title; parent.add_child(node)
	for entry in entries: node.get_popup().add_item(entry)
	node.get_popup().id_pressed.connect(callback)

func message(value: String) -> void:
	status_note = value; refresh_status()

func refresh_status() -> void:
	if status == null: return
	status.text = ("● 未保存" if doc.dirty() else "已保存") + "  |  " + ("默认参数" if adaptation.is_empty() else "适配：" + adaptation) + "  |  " + status_note
	status.tooltip_text = status.text

func select(ids: Array) -> void:
	placement_selected = false
	selected = ids.duplicate(); refresh_inspector(); refresh_layers(); canvas.queue_redraw(); timeline.queue_redraw()

func select_placement() -> void:
	selected.clear(); placement_selected = true
	refresh_inspector(); refresh_layers(); canvas.queue_redraw()

func select_assembly() -> void:
	select(doc.data.editor.scene.filter(func(id): return id not in doc.data.editor.locked))

func change_placement(axis: int, value: float) -> void:
	doc.checkpoint("人物整体摆放")
	var offset := Visuals.placement(doc.data); offset[axis] = value
	doc.data.game.placement = [offset.x, offset.y]
	canvas.queue_redraw(); refresh_status()

func refresh() -> void:
	refreshing = true
	selected = selected.filter(func(id): return doc.data.assets.has(id))
	var filter := category.get_item_text(category.selected) if category.item_count else "全部分类"
	category.clear(); category.add_item("全部分类")
	var categories := []
	for a: Dictionary in doc.data.assets.values():
		if a.category not in categories: categories.append(a.category)
	categories.sort()
	for name in categories: category.add_item(name)
	for i in range(category.item_count):
		if category.get_item_text(i) == filter: category.select(i)
	adapt_choice.clear(); adapt_choice.add_item("资产默认值"); adapt_choice.set_item_metadata(0, "")
	for name in doc.data.adaptations:
		adapt_choice.add_item(name); var i := adapt_choice.item_count - 1; adapt_choice.set_item_metadata(i, name)
		if name == adaptation: adapt_choice.select(i)
	action_choice.clear()
	for id in doc.data.actions:
		action_choice.add_item(id)
		if id == action_id: action_choice.select(action_choice.item_count - 1)
	refresh_library(); refresh_layers(); refresh_inspector(); refresh_status(); canvas.queue_redraw(); timeline.queue_redraw()
	refreshing = false

func refresh_library() -> void:
	if library == null: return
	library.clear()
	var query := search.text.to_lower()
	var filter := category.get_item_text(category.selected) if category.item_count else "全部分类"
	for id: String in doc.data.assets:
		var a: Dictionary = doc.data.assets[id]
		if not query.is_empty() and not (str(a.name) + id).to_lower().contains(query): continue
		if filter != "全部分类" and a.category != filter: continue
		if not tag_filter.text.is_empty() and not ",".join(a.tags).contains(tag_filter.text): continue
		var tex := Visuals.texture(a, doc.base_dir)
		var icon: AtlasTexture
		if tex != null:
			icon = AtlasTexture.new(); icon.atlas = tex; icon.region = Rect2(a.rect[0], a.rect[1], a.rect[2], a.rect[3])
		var index := library.add_item(a.name, icon); library.set_item_metadata(index, id); library.set_item_tooltip(index, id + "\n双击添加到参考组合")

func refresh_layers() -> void:
	if layers == null: return
	var was := refreshing; refreshing = true; layers.clear(); var root := layers.create_item()
	var order := Visuals.ordered(doc.data, doc.data.editor.scene, adaptation); order.reverse()
	var rows := {}
	for id: String in order:
		if not doc.data.assets.has(id): continue
		var row := layers.create_item(root); rows[id] = row
		var a: Dictionary = doc.asset(id, adaptation)
		row.set_text(0, a.name); row.set_metadata(0, id); row.set_tooltip_text(0, id + (" → " + a.parent + ":" + a.anchor if not a.parent.is_empty() else ""))
		for col in [1, 2]: row.set_cell_mode(col, TreeItem.CELL_MODE_CHECK); row.set_editable(col, true); row.set_selectable(col, false)
		row.set_checked(1, id not in doc.data.editor.hidden); row.set_checked(2, id in doc.data.editor.locked)
		row.set_custom_color(0, Color("8ec4ff") if id in selected else Color("dde1e8"))
		if id in selected: row.set_custom_bg_color(0, Color("344455"))
	if layer_sort == "附着层级":
		for id in rows:
			var parent: String = doc.asset(id, adaptation).parent
			if rows.has(parent): root.remove_child(rows[id]); rows[parent].add_child(rows[id])
	elif layer_sort == "编辑分组":
		var assigned := []
		for name in doc.data.editor.get("groups", {}):
			var group_row := layers.create_item(root); group_row.set_text(0, name); group_row.set_metadata(0, "@group:" + name)
			for id in doc.data.editor.groups[name]:
				if rows.has(id) and id not in assigned: root.remove_child(rows[id]); group_row.add_child(rows[id]); assigned.append(id)
	refreshing = was

func layer_selected() -> void:
	if refreshing: return
	var row := layers.get_selected()
	if row == null: return
	var id: String = row.get_metadata(0)
	if id.begins_with("@group:"):
		call_deferred("select", doc.data.editor.groups.get(id.trim_prefix("@group:"), [])); return
	var next := [id]
	if Input.is_key_pressed(KEY_CTRL):
		next = selected.duplicate()
		if id in next: next.erase(id)
		else: next.append(id)
	elif Input.is_key_pressed(KEY_SHIFT) and not last_row.is_empty():
		var order := Visuals.ordered(doc.data, doc.data.editor.scene, adaptation); order.reverse()
		var a := order.find(last_row); var b := order.find(id)
		if a >= 0 and b >= 0: next = order.slice(min(a, b), max(a, b) + 1)
	last_row = id
	call_deferred("select", next)

func layer_edited() -> void:
	if refreshing: return
	var row := layers.get_edited(); var col := layers.get_edited_column()
	if row == null or col == 0: return
	var id: String = row.get_metadata(0); var field := "hidden" if col == 1 else "locked"
	doc.checkpoint("编辑显隐／锁定")
	var on := not row.is_checked(col) if col == 1 else row.is_checked(col)
	if on and id not in doc.data.editor[field]: doc.data.editor[field].append(id)
	elif not on: doc.data.editor[field].erase(id)
	call_deferred("refresh")

func add_to_scene(id: String) -> void:
	if id in doc.data.editor.scene: return
	doc.checkpoint("添加参考资产"); doc.data.editor.scene.append(id); refresh()

func toggle_solo() -> void:
	solo = selected.duplicate() if solo.is_empty() else []; canvas.queue_redraw()

func reorder(delta: int) -> void:
	doc.checkpoint("绘制层")
	var order := Visuals.ordered(doc.data, doc.data.editor.scene, adaptation)
	var indices := range(order.size())
	if delta > 0: indices.reverse()
	for index in indices:
		var id: String = order[index]; var neighbor: int = index + delta
		if id not in selected or id in doc.data.editor.locked or neighbor < 0 or neighbor >= order.size() or order[neighbor] in selected: continue
		var other: String = order[neighbor]
		if other in doc.data.editor.locked: continue
		var first: float = doc.asset(id, adaptation).layer; var second: float = doc.asset(other, adaptation).layer
		doc.set_value(id, "layer", second + (delta if first == second else 0), adaptation)
		doc.set_value(other, "layer", first, adaptation)
		order[index] = other; order[neighbor] = id
	refresh()

func refresh_inspector() -> void:
	if inspector == null: return
	inspector_values.clear()
	for child in inspector.get_children(): inspector.remove_child(child); child.queue_free()
	if placement_selected:
		label(inspector, "人物整体 · 棋格内摆放", 16)
		var note := label(inspector, "全局基础偏移，包含底座、隐藏部件与备用外观。动作和局部锚点不变。", 12)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if animation_mode:
			label(inspector, "请退出动作模式调整整体基准", 13); return
		var offset := Visuals.placement(doc.data)
		for axis in range(2): number(inspector, "棋格内偏移 " + ("X" if axis == 0 else "Y"), offset[axis], func(v): change_placement(axis, v))
		button(inspector, "重置整体偏移", func(): doc.checkpoint("重置整体偏移"); doc.data.game.placement = [0, 0]; refresh())
		return
	if selected.is_empty(): label(inspector, "选择资产以编辑", 16); return
	var id: String = selected[-1]; var a := doc.asset(id, adaptation)
	label(inspector, a.name if selected.size() == 1 else "已选择 %d 个资产" % selected.size(), 16)
	label(inspector, id if selected.size() == 1 else "数值调整默认为增量", 12)
	if id in doc.data.editor.locked:
		label(inspector, "已锁定，请在场景层解锁", 14); return
	if animation_mode:
		label(inspector, "动作偏移 · 不改基础姿态", 14)
		var state := Visuals.sample(current_action(), id, time)
		for property: String in ["x", "y", "rotation", "scale_x", "scale_y"]:
			number(inspector, property, float(state.get(property, 1 if property.begins_with("scale") else 0)), func(value):
				doc.checkpoint("动作落帧"); put_key(id, property, value, false); refresh_time())
		check_box(inspector, "动作显隐", bool(state.get("visible", true)), func(on): put_key(id, "visible", on); refresh_time())
		number(inspector, "时长（秒）", float(current_action().get("duration", 1)), func(value):
			var before := doc.data.duplicate(true); doc.data.actions[action_id].duration = value
			var errors := doc.validate({}, false)
			if not errors.is_empty(): doc.data = before; message("时长不能小于现有关键帧或事件时间")
			else: doc.history.append({"label": "动作时长", "data": before}); doc.future.clear()
			refresh_time())
		button(inspector, "编辑表现事件…", event_dialog)
		return
	if selected.size() > 1: check_box(inspector, "设为统一局部值", same_values, func(on): same_values = on; refresh_inspector())
	label(inspector, "变换 · 逻辑像素", 14)
	label(inspector, "相对：" + ("棋格中心" if a.parent.is_empty() else a.parent + " / " + a.anchor), 12)
	for axis in range(2):
		var delta_mode := selected.size() > 1 and not same_values
		var initial: float = 0.0 if delta_mode else a.position[axis]
		number(inspector, ("画布移动 Δ" if delta_mode else "局部位置 ") + ("X" if axis == 0 else "Y"), initial, func(v): change_numeric("position", axis, v, initial))
	number(inspector, "旋转 °", a.rotation, func(v): change_numeric("rotation", -1, v, a.rotation))
	for axis in range(2):
		number(inspector, "缩放 " + ("X" if axis == 0 else "Y"), a.scale[axis], func(v): change_numeric("scale", axis, v, a.scale[axis]), 0.01)
	number(inspector, "绘制层", a.layer, func(v): change_numeric("layer", -1, v, a.layer), 1)
	if selected.size() > 1:
		button(inspector, "恢复所选默认参数", reset_selected); return
	text_field(inspector, "名称", a.name, func(v): set_field(id, "name", v))
	text_field(inspector, "分类", a.category, func(v): set_field(id, "category", v))
	text_field(inspector, "标签（逗号分隔）", ",".join(a.tags), func(v): set_field(id, "tags", Array(v.split(",", false))))
	label(inspector, "显示尺寸 / 枢轴", 14)
	for field: String in ["size", "pivot"]:
		for axis in range(2): number(inspector, ("尺寸" if field == "size" else "枢轴比例") + (" X" if axis == 0 else " Y"), a[field][axis], func(v): change_numeric(field, axis, v, a[field][axis]), 0.01)
	label(inspector, "源图区域 · 图片像素", 14)
	for axis in range(4): number(inspector, ["左", "上", "宽", "高"][axis], a.rect[axis], func(v): change_numeric("rect", axis, v, a.rect[axis]), 1)
	button(inspector, "在源图中框选区域…", func(): open_import(Visuals.source_path(a, doc.base_dir), id))
	label(inspector, "附着与显示遮罩", 14)
	text_field(inspector, "父资产 ID（空为独立）", a.parent, func(v): reparent_asset(id, v))
	text_field(inspector, "父锚点名称", a.anchor, func(v): set_field(id, "anchor", v))
	button(inspector, "编辑本资产锚点…", func(): anchor_dialog(id))
	text_field(inspector, "轮廓遮罩资产 ID", a.clip_to, func(v): set_field(id, "clip_to", v))
	text_field(inspector, "显示遮罩 ID（逗号分隔）", ",".join(a.masks), func(v): set_field(id, "masks", Array(v.split(",", false))))
	button(inspector, "编辑显示遮罩…", mask_dialog)
	button(inspector, "恢复默认参数", reset_selected)
	var affected := []
	for name in doc.data.adaptations:
		if doc.data.adaptations[name].has(id): affected.append(name)
	var note := label(inspector, "适配引用：" + ("无" if affected.is_empty() else ", ".join(affected)), 12); note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var source := label(inspector, "来源：" + str(a.source), 11); source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func change_numeric(field: String, axis: int, value: float, old: float) -> void:
	var control_key := field + str(axis)
	old = inspector_values.get(control_key, old)
	if field == "position" and selected.size() > 1 and not same_values:
		var delta := Vector2.ZERO; delta[axis] = value - old
		doc.checkpoint("画布批量位移")
		doc.move_selection(selected.filter(func(id): return id not in doc.data.editor.locked), delta, doc.data.duplicate(true), adaptation)
		inspector_values[control_key] = value
		canvas.queue_redraw(); refresh_layers(); refresh_status(); return
	var operations := []
	for id: String in selected:
		if id in doc.data.editor.locked: continue
		var a := doc.asset(id, adaptation)
		var next: Variant = a[field].duplicate() if a[field] is Array else a[field]
		if axis >= 0: next[axis] = value if selected.size() == 1 or same_values else float(next[axis]) + value - old
		else: next = value if selected.size() == 1 or same_values else float(next) + value - old
		operations.append({"id": id, "field": field, "value": next, "adaptation": adaptation})
	var errors := doc.transact(operations)
	if not errors.is_empty(): message("\n".join(errors))
	else: inspector_values[control_key] = value
	canvas.queue_redraw(); refresh_layers(); refresh_status()
	# Rebuild only after focus leaves, preserving SpinBox text entry.

func refresh_assets() -> void:
	Visuals.textures.clear(); Visuals.images.clear(); Visuals.outlines_cache.clear(); Visuals.geometry_cache.clear(); Visuals.hit_signature = 0
	if not doc.path.is_empty() and FileAccess.file_exists(doc.path) and FileAccess.get_sha256(doc.path) != doc.disk_hash:
		if doc.dirty(): message("磁盘工程已改变；先另存当前修改，再重新打开以载入 agent 新增资产。")
		else: open_project(doc.path)
	refresh()

func set_field(id: String, field: String, value: Variant) -> void:
	var errors := doc.transact([{"id": id, "field": field, "value": value, "adaptation": adaptation}])
	if not errors.is_empty(): message("\n".join(errors))
	call_deferred("refresh")

func reparent_asset(id: String, parent: String) -> void:
	if not parent.is_empty() and not doc.data.assets.has(parent): message("父资产不存在"); return
	var world := Visuals.world_transform(doc.data, id, adaptation)
	var local := Transform2D(0.0, -Visuals.placement(doc.data)) * world if parent.is_empty() else Visuals.world_transform(doc.data, parent, adaptation).affine_inverse() * world
	var errors := doc.transact([{"id": id, "field": "parent", "value": parent, "adaptation": adaptation}, {"id": id, "field": "anchor", "value": "origin", "adaptation": adaptation}, {"id": id, "field": "position", "value": [local.origin.x, local.origin.y], "adaptation": adaptation}, {"id": id, "field": "rotation", "value": rad_to_deg(local.get_rotation()), "adaptation": adaptation}, {"id": id, "field": "scale", "value": [local.get_scale().x, local.get_scale().y], "adaptation": adaptation}])
	if not errors.is_empty(): message("\n".join(errors))
	refresh()

func reset_selected() -> void:
	doc.checkpoint("恢复默认参数")
	for id in selected:
		if id in doc.data.editor.locked: continue
		if not adaptation.is_empty(): doc.data.adaptations[adaptation].erase(id)
		elif doc.data.baseline.has(id): doc.data.assets[id] = doc.data.baseline[id].duplicate(true)
	refresh()

func current_action() -> Dictionary:
	return doc.data.actions.get(action_id, {})

func put_key(id: String, property: String, value: Variant, history: bool = true) -> void:
	if current_action().is_empty() or id in doc.data.editor.locked: return
	if history: doc.checkpoint("关键帧")
	var action: Dictionary = doc.data.actions[action_id]
	var track: Dictionary = {}
	for candidate: Dictionary in action.tracks:
		if candidate.target == id and candidate.property == property: track = candidate; break
	if track.is_empty():
		track = {"target": id, "property": property, "keys": []}; action.tracks.append(track)
	for key: Dictionary in track.keys:
		if is_equal_approx(float(key.time), time): key.value = value; key.interpolation = key_interpolation; return
	track.keys.append({"id": "key-" + str(Time.get_ticks_usec()) + "-" + str(randi()), "time": time, "value": value, "interpolation": key_interpolation})
	track.keys.sort_custom(func(a, b): return a.time < b.time)

func refresh_time() -> void:
	canvas.queue_redraw(); timeline.queue_redraw(); refresh_status()

func _process(delta: float) -> void:
	if playing and animation_mode:
		time += delta * speed
		var duration := float(current_action().get("duration", 1))
		if time > duration:
			if loop: time = fmod(time, duration)
			else: time = duration; playing = false
		refresh_time()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed: return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit or get_viewport().gui_get_focus_owner() is SpinBox: return
	if event.ctrl_pressed:
		if event.keycode == KEY_S: save()
		elif event.keycode == KEY_Z:
			if event.shift_pressed: doc.redo()
			else: doc.undo()
			refresh()
		elif event.keycode == KEY_Y: doc.redo(); refresh()
		else: return
	elif event.keycode == KEY_F: canvas.focus_selection()
	elif event.keycode == KEY_V: canvas.mode = "select"
	elif event.keycode == KEY_G: canvas.mode = "move"
	elif event.keycode == KEY_R: canvas.mode = "rotate"
	elif event.keycode == KEY_S: canvas.mode = "scale"
	elif event.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] and not animation_mode:
		var delta := Vector2.ZERO
		if event.keycode == KEY_LEFT: delta.x = -1
		elif event.keycode == KEY_RIGHT: delta.x = 1
		elif event.keycode == KEY_UP: delta.y = -1
		else: delta.y = 1
		if placement_selected:
			var offset := Visuals.placement(doc.data) + delta * (10 if event.shift_pressed else 1)
			doc.checkpoint("整体微移"); doc.data.game.placement = [offset.x, offset.y]; refresh()
			get_viewport().set_input_as_handled(); return
		var targets := selected.filter(func(id): return id not in doc.data.editor.locked)
		doc.checkpoint("微移"); doc.move_selection(targets, delta * (10 if event.shift_pressed else 1), doc.data.duplicate(true), adaptation); refresh()
	else: return
	get_viewport().set_input_as_handled()

func file_menu(index: int) -> void:
	match index:
		0: guard_unsaved(func(): browse("open"))
		1: save()
		2: browse("save")
		3: browse("import")
		4: review_apply()
		5: message(doc.rollback()); refresh_status()
		6: browse("screenshot")
		7: request_close()

func edit_menu(index: int) -> void:
	match index:
		0: doc.undo(); refresh()
		1: doc.redo(); refresh()
		2: reset_selected()
		3:
			doc.checkpoint("移出参考组合")
			for id in selected: doc.data.editor.scene.erase(id)
			refresh()
		4: toggle_solo()
		5:
			ask_name("编辑分组 · 不改变游戏附着", func(name):
				doc.checkpoint("编辑分组")
				if not doc.data.editor.has("groups"): doc.data.editor.groups = {}
				doc.data.editor.groups[name] = selected.duplicate(); refresh_layers())

func view_menu(index: int) -> void:
	match index:
		0: left_panel.visible = not left_panel.visible
		1: right_panel.visible = not right_panel.visible
		2: canvas.fit()
		3: canvas.focus_selection()
		4: canvas.zoom = 1; canvas.queue_redraw()
		5: canvas.ghost = not canvas.ghost; canvas.queue_redraw()
		6:
			var dialog := AcceptDialog.new(); dialog.title = "参考叠图透明度"; add_child(dialog)
			var slider := HSlider.new(); slider.min_value = 0.05; slider.max_value = 0.9; slider.step = 0.05; slider.value = canvas.ghost_alpha; slider.custom_minimum_size = Vector2(300, 50); dialog.add_child(slider)
			slider.value_changed.connect(func(v): canvas.ghost_alpha = v; canvas.ghost = true; canvas.queue_redraw()); dialog.popup_centered()

func browse(action: String) -> void:
	pending_file_action = action
	file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE if action in ["save", "screenshot"] else FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.filters = PackedStringArray(["*.png ; PNG 图片"]) if action in ["import", "screenshot"] else PackedStringArray(["*.json ; 资产工程"])
	file_dialog.current_dir = doc.base_dir
	file_dialog.current_file = "assembly.asset.json" if action == "save" else ("preview.png" if action == "screenshot" else "")
	file_dialog.popup_centered()

func file_chosen(file: String) -> void:
	match pending_file_action:
		"open": open_project(file)
		"save": persist_view(); message(doc.save_project(file)); refresh()
		"import": open_import(file)
		"screenshot": get_viewport().get_texture().get_image().save_png(file); message("截图已保存")

func persist_view() -> void:
	doc.data.editor.view = {"zoom": canvas.zoom, "pan": [canvas.pan.x, canvas.pan.y], "adaptation": adaptation, "grid": canvas.grid}

func save() -> void:
	persist_view()
	if doc.path.is_empty(): browse("save")
	else: message(doc.save_project(doc.path)); refresh()

func open_project(file: String) -> bool:
	var error := doc.load_project(file)
	if not error.is_empty(): message(error); return false
	var view: Dictionary = doc.data.editor.get("view", {})
	canvas.zoom = view.get("zoom", 4.0); canvas.pan = Visuals.vector(view.get("pan", [0, 0])); adaptation = view.get("adaptation", ""); canvas.grid = view.get("grid", true)
	message("；".join(doc.notices)); refresh(); return true

func review_apply() -> void:
	var errors := doc.validate()
	if not errors.is_empty(): show_text("不能应用", "\n".join(errors)); return
	var dialog := ConfirmationDialog.new(); dialog.title = "应用到游戏"; dialog.ok_button_text = "应用此版本"
	var changes := doc.differences()
	var box := VBoxContainer.new(); dialog.add_child(box)
	label(box, "将应用 %d 处差异；编辑显隐不会进入游戏。" % changes.size())
	var list := ItemList.new(); list.custom_minimum_size = Vector2(660, 320); box.add_child(list)
	for change: String in changes:
		var index := list.add_item(change); list.set_item_tooltip(index, change)
	label(box, "普通游戏重新进入场景或重启生效；可恢复上一版。", 13)
	add_child(dialog); dialog.confirmed.connect(func():
		var error := doc.apply(); message("应用成功" if error.is_empty() else error); dialog.queue_free())
	dialog.popup_centered(Vector2i(700, 430))

func guard_unsaved(callback: Callable) -> void:
	if not doc.dirty(): callback.call(); return
	var dialog := ConfirmationDialog.new(); dialog.title = "有未保存修改"; dialog.dialog_text = "可以返回保存，或丢弃本次未保存修改。"; dialog.ok_button_text = "丢弃修改"; dialog.cancel_button_text = "返回保存"
	add_child(dialog); dialog.confirmed.connect(func(): dialog.queue_free(); callback.call()); dialog.popup_centered()

func request_close() -> void:
	guard_unsaved(func(): closed.emit())

func show_text(title: String, text: String) -> void:
	var dialog := AcceptDialog.new(); dialog.title = title; dialog.dialog_text = text; add_child(dialog); dialog.popup_centered(Vector2i(620, 400)); dialog.confirmed.connect(dialog.queue_free)

func ask_name(title: String, callback: Callable) -> void:
	var dialog := ConfirmationDialog.new(); dialog.title = title
	var edit := LineEdit.new(); edit.placeholder_text = "输入唯一名称"; dialog.add_child(edit); add_child(dialog)
	dialog.confirmed.connect(func():
		if not edit.text.strip_edges().is_empty(): callback.call(edit.text.strip_edges())
		dialog.queue_free())
	dialog.popup_centered(Vector2i(380, 120)); edit.grab_focus()

func new_adaptation() -> void:
	ask_name("新增适配配置", func(name):
		if doc.data.adaptations.has(name): message("名称已存在"); return
		doc.checkpoint("新增适配"); doc.data.adaptations[name] = {}; adaptation = name; refresh())

func new_action() -> void:
	ask_name("新增动作", func(name):
		if doc.data.actions.has(name): message("动作已存在"); return
		doc.checkpoint("新增动作"); doc.data.actions[name] = {"id": name, "duration": 1.0, "events": [], "tracks": []}; action_id = name; time = 0; refresh())

func dictionary_dialog(title: String, value: Variant, callback: Callable) -> void:
	var dialog := ConfirmationDialog.new(); dialog.title = title
	var edit := TextEdit.new(); edit.text = JSON.stringify(value, "\t"); edit.custom_minimum_size = Vector2(520, 280); dialog.add_child(edit); add_child(dialog)
	dialog.confirmed.connect(func():
		var parsed: Variant = JSON.parse_string(edit.text)
		if parsed == null: message("JSON 格式无效")
		else: callback.call(parsed)
		dialog.queue_free())
	dialog.popup_centered(Vector2i(560, 360))

func event_dialog() -> void:
	var dialog := ConfirmationDialog.new(); dialog.title = "表现事件 · 不参与战斗结算"
	var box := VBoxContainer.new(); dialog.add_child(box); add_child(dialog)
	var rows := VBoxContainer.new(); box.add_child(rows)
	var add_row := func(id: String, at: float):
		var row := HBoxContainer.new(); rows.add_child(row)
		var name := LineEdit.new(); name.text = id; name.placeholder_text = "事件 ID"; name.custom_minimum_size.x = 170; row.add_child(name)
		var seconds := SpinBox.new(); seconds.max_value = current_action().duration; seconds.step = 0.01; seconds.value = at; row.add_child(seconds)
		button(row, "移除", func(): rows.remove_child(row); row.queue_free())
	for event: Dictionary in current_action().get("events", []): add_row.call(event.id, event.time)
	button(box, "+ 事件", func(): add_row.call("event_" + str(rows.get_child_count() + 1), time))
	dialog.confirmed.connect(func():
		var value := []
		for row in rows.get_children(): value.append({"id": row.get_child(0).text, "time": row.get_child(1).value})
		var errors := doc.transact([{"section": "actions", "id": action_id, "value": merged_action_events(value)}])
		if not errors.is_empty(): message("\n".join(errors))
		else: dialog.queue_free(); refresh())
	dialog.popup_centered(Vector2i(460, 300))

func merged_action_events(events: Array) -> Dictionary:
	var action := current_action().duplicate(true); action.events = events; return action

func anchor_dialog(id: String) -> void:
	var dialog := ConfirmationDialog.new(); dialog.title = "锚点 · 相对资产枢轴的逻辑坐标"
	var box := VBoxContainer.new(); dialog.add_child(box); add_child(dialog)
	var rows := VBoxContainer.new(); box.add_child(rows)
	var add_row := func(name: String, point: Array):
		var row := HBoxContainer.new(); rows.add_child(row)
		var edit := LineEdit.new(); edit.text = name; edit.placeholder_text = "锚点名称"; edit.custom_minimum_size.x = 160; row.add_child(edit)
		for axis in range(2):
			var coordinate := SpinBox.new(); coordinate.min_value = -10000; coordinate.max_value = 10000; coordinate.step = 0.1; coordinate.value = point[axis]; row.add_child(coordinate)
		button(row, "移除", func(): rows.remove_child(row); row.queue_free())
	for name in doc.asset(id, adaptation).anchors: add_row.call(name, doc.asset(id, adaptation).anchors[name])
	button(box, "+ 锚点", func(): add_row.call("anchor_" + str(rows.get_child_count() + 1), [0, 0]))
	dialog.confirmed.connect(func():
		var value := {}
		for row in rows.get_children():
			var name: String = row.get_child(0).text
			if name.is_empty() or value.has(name): message("锚点名称为空或重复"); return
			value[name] = [row.get_child(1).value, row.get_child(2).value]
		var errors := doc.transact([{"id": id, "field": "anchors", "value": value, "adaptation": adaptation}])
		if not errors.is_empty(): message("\n".join(errors))
		else: dialog.queue_free(); refresh())
	dialog.popup_centered(Vector2i(550, 300))

func mask_dialog() -> void:
	var dialog := ConfirmationDialog.new(); dialog.title = "显示遮罩（跟随对象局部坐标）"
	var box := VBoxContainer.new(); dialog.add_child(box); add_child(dialog)
	var current_id: String = doc.asset(selected[-1], adaptation).masks[0] if not doc.asset(selected[-1], adaptation).masks.is_empty() else "bust"
	var current_mask: Dictionary = doc.data.masks.get(current_id, {"type": "bust", "center": [-0.05, -17.22], "radius": [28.77, 7.17], "top": -120})
	var id_edit := text_field(box, "遮罩 ID", current_id, func(_v): pass)
	var follow_ids: Array = ["assembly", "grid"] + doc.data.assets.keys()
	var follow_labels: Array = ["人物整体", "固定棋格"] + doc.data.assets.keys()
	label(box, "跟随对象（切换后使用该对象局部坐标）", 12)
	var follow_choice := choice(box, follow_labels, func(_v): pass)
	follow_choice.select(maxi(0, follow_ids.find(current_mask.get("follow", "assembly"))))
	var type_choice := choice(box, ["bust", "rect"], func(_v): pass)
	type_choice.select(0 if current_mask.type == "bust" else 1)
	var values: Array = current_mask.get("center", [0, 0]) + current_mask.get("radius", [30, 10]) + [current_mask.get("top", -120)] if current_mask.type == "bust" else current_mask.rect + [-120]
	var fields := []
	for i in range(5): fields.append(number(box, ["中心 X / 左", "中心 Y / 上", "半径 X / 宽", "半径 Y / 高", "盘面顶边"][i], values[i], func(_v): pass))
	dialog.confirmed.connect(func():
		if id_edit.text.is_empty(): return
		var mask: Dictionary
		if type_choice.selected == 0: mask = {"type": "bust", "center": [fields[0].value, fields[1].value], "radius": [fields[2].value, fields[3].value], "top": fields[4].value}
		else: mask = {"type": "rect", "rect": [fields[0].value, fields[1].value, fields[2].value, fields[3].value]}
		mask.follow = follow_ids[follow_choice.selected]
		if fields[2].value <= 0 or fields[3].value <= 0: message("遮罩尺寸必须大于零"); return
		doc.checkpoint("显示遮罩"); doc.data.masks[id_edit.text] = mask
		for id in selected: doc.set_value(id, "masks", [id_edit.text], adaptation)
		dialog.queue_free(); refresh())
	dialog.popup_centered(Vector2i(440, 330))

func preview_dialog() -> void:
	var dialog := ConfirmationDialog.new(); dialog.title = "参考组合 · 仅用于预览"
	var box := VBoxContainer.new(); dialog.add_child(box); add_child(dialog)
	var armor := choice(box, ["裸身", "基础内衣", "亚麻", "绗缝甲", "绗缝＋链甲"], func(_v): pass); armor.select(4)
	var weapon := choice(box, ["无", "剑盾", "长矛", "弓"], func(_v): pass); weapon.select(1)
	var damaged := check_box(box, "破损外甲", false, func(_v): pass)
	var wound := check_box(box, "脸伤", false, func(_v): pass)
	dialog.confirmed.connect(func():
		doc.checkpoint("预览组合")
		var scene: Array = ["base", "skin", "head"]
		if doc.data.game.appearance.get("head", "legacy") == "modular":
			scene.erase("head"); scene.append("face")
			for id: String in ["hair", "beard", "bandage", "blood"]:
				if doc.data.game.appearance.get(id, false): scene.append(id)
		if armor.selected >= 1: scene.append("body")
		if armor.selected >= 2: scene.append("linen")
		if armor.selected >= 3: scene.append("padded_damaged" if damaged.button_pressed and armor.selected == 3 else "padded")
		if armor.selected == 4: scene.append("mail_damaged" if damaged.button_pressed else "mail")
		if wound.button_pressed: scene.append("scar")
		if weapon.selected == 1: scene.append_array(["shield", "sword"])
		elif weapon.selected == 2: scene.append("spear")
		elif weapon.selected == 3: scene.append("bow")
		doc.data.editor.scene = scene; dialog.queue_free(); refresh())
	dialog.popup_centered(Vector2i(360, 280))

func files_dropped(files: PackedStringArray) -> void:
	if files.is_empty(): return
	if files[0].get_extension().to_lower() == "json": guard_unsaved(func(): open_project(files[0]))
	else: open_import(files[0])

func open_import(file: String, existing: String = "") -> void:
	var image: Image
	if file.begins_with("res://"):
		var texture: Texture2D = load(file); image = texture.get_image()
	else: image = Image.load_from_file(file)
	if image == null: message("无法打开图片"); return
	import_path = file; import_image = ImageTexture.create_from_image(image); import_regions = []; import_drag = false
	import_dialog = ConfirmationDialog.new(); import_dialog.title = "图集区域 / PNG 导入"; import_dialog.ok_button_text = "登记资产" if existing.is_empty() else "更新源图区域"
	import_dialog.canceled.connect(import_dialog.queue_free)
	var box := VBoxContainer.new(); import_dialog.add_child(box); add_child(import_dialog)
	import_hint = label(box, "拖动框选区域，可连续框选多块；不框选则使用整张图片。", 13)
	import_preview = Control.new(); import_preview.custom_minimum_size = Vector2(720, 390); box.add_child(import_preview)
	import_preview.draw.connect(draw_import)
	import_preview.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed: import_start = event.position; import_end = event.position; import_drag = true
			elif import_drag:
				import_drag = false
				var scale := minf(import_preview.size.x / import_image.get_width(), import_preview.size.y / import_image.get_height())
				var rect := Rect2(import_start / scale, (event.position - import_start) / scale).abs().intersection(Rect2(Vector2.ZERO, import_image.get_size()))
				if rect.size.x >= 1 and rect.size.y >= 1: import_regions.append([floori(rect.position.x), floori(rect.position.y), floori(rect.size.x), floori(rect.size.y)])
				import_hint.text = "已框选 %d 块区域" % import_regions.size()
		elif event is InputEventMouseMotion and import_drag: import_end = event.position
		import_preview.queue_redraw())
	button(box, "清除框选", func(): import_regions.clear(); import_preview.queue_redraw())
	import_id = text_field(box, "稳定 ID（多块自动添加编号）", file.get_file().get_basename().replace(" ", "_"), func(_v): pass)
	import_name = text_field(box, "名称", file.get_file().get_basename(), func(_v): pass)
	import_category = text_field(box, "分类", "未分类", func(_v): pass)
	import_dialog.confirmed.connect(func():
		if not existing.is_empty():
			if import_regions.size() != 1: message("修改源图区域需框选一块"); return
			set_field(existing, "rect", import_regions[0]); import_dialog.queue_free(); return
		var regions: Array = import_regions if not import_regions.is_empty() else [[0, 0, import_image.get_width(), import_image.get_height()]]
		var before := doc.data.duplicate(true); var history_count := doc.history.size(); var previous_future := doc.future.duplicate(true)
		for i in range(regions.size()):
			var suffix := "_%02d" % (i + 1) if regions.size() > 1 else ""
			var error := doc.import_png(import_path, import_id.text + suffix, import_name.text + suffix, import_category.text, regions[i])
			if not error.is_empty():
				doc.data = before; doc.history.resize(history_count); doc.future = previous_future; message(error); return
		doc.history.resize(history_count); doc.history.append({"label": "导入图片／图集", "data": before})
		import_dialog.queue_free(); refresh(); message("已登记到资产库；双击资产加入参考组合。"))
	import_dialog.popup_centered(Vector2i(760, 740))

func draw_import() -> void:
	var scale := minf(import_preview.size.x / import_image.get_width(), import_preview.size.y / import_image.get_height())
	import_preview.draw_rect(Rect2(Vector2.ZERO, import_preview.size), Color("181a1f"))
	import_preview.draw_texture_rect(import_image, Rect2(Vector2.ZERO, import_image.get_size() * scale), false)
	for rect: Array in import_regions: import_preview.draw_rect(Rect2(rect[0] * scale, rect[1] * scale, rect[2] * scale, rect[3] * scale), Color("79b4f5"), false, 2)
	if import_drag: import_preview.draw_rect(Rect2(import_start, import_end - import_start).abs(), Color("79b4f5"), false, 2)
