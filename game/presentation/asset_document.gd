extends RefCounted
const Visuals = preload("res://presentation/asset_visuals.gd")
const Legacy = preload("res://presentation/paperdoll_document.gd")
const Actor = preload("res://presentation/static_bust_actor.gd")
const Motion = preload("res://presentation/static_bust_motion.gd")
const SCHEMA := 5
const PROPERTIES := ["x", "y", "rotation", "scale_x", "scale_y", "visible"]
static var storage_override := ""
static var publication_serial := 0
var data: Dictionary = {}
var defaults: Dictionary = {}
var history: Array = []
var future: Array = []
var path := ""
var disk_hash := ""
var saved := ""
var base_dir := ""
var expected_revision := ""
var notices: Array = []

static func project_root() -> String:
	if OS.has_feature("editor"): return ProjectSettings.globalize_path("res://").trim_suffix("/").get_base_dir()
	var current := OS.get_executable_path().get_base_dir()
	for i in range(7):
		if FileAccess.file_exists(current.path_join("game/project.godot")): return current
		current = current.get_base_dir()
	return OS.get_executable_path().get_base_dir()

static func runtime_dir() -> String:
	if not storage_override.is_empty(): return storage_override
	return project_root().path_join("game/assets/art/paperdoll")

static func read_json(file: String) -> Dictionary:
	if not FileAccess.file_exists(file): return {}
	var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(file))
	return value if value is Dictionary else {}

static func revision() -> String:
	return str(read_json(runtime_dir().path_join("current.json")).get("revision", ""))

func _init() -> void:
	base_dir = project_root().path_join("art/workbench")
	expected_revision = revision()
	from_legacy(Legacy.new())
	saved = JSON.stringify(data)

func from_legacy(legacy: RefCounted) -> void:
	var catalog: Dictionary = legacy.composed()
	data = {"schema": SCHEMA, "kind": "asset-workbench", "assets": {}, "adaptations": {}, "masks": {"bust": catalog.bust_crop.duplicate(true)}, "actions": {}, "editor": {"scene": [], "hidden": [], "locked": [], "view": {}}, "game": {"appearance": catalog.get("assembly", {}).duplicate(true)}, "baseline": {}}
	data.masks.bust.type = "bust"
	for id: String in catalog.parts:
		var p: Dictionary = catalog.parts[id]
		var category := "身体"
		if id in ["head", "wounded", "face", "hair", "beard", "scar", "bandage"]: category = "头面"
		elif id in ["linen", "padded", "padded_damaged", "mail", "mail_damaged"]: category = "衣甲"
		elif id in ["sword", "spear", "bow", "shield", "arrow"]: category = "装备"
		elif id == "base": category = "参照"
		var group: String = Actor.PART_GROUP.get(id, id)
		var a := {"id": id, "name": Legacy.label_for(group) + (" · 破损" if id.ends_with("damaged") else ""), "category": category, "tags": [], "image": p.atlas, "rect": p.rect.duplicate(), "size": p.size.duplicate(), "pivot": p.pivot.duplicate(), "position": p.position.duplicate(), "rotation": rad_to_deg(float(p.get("rotation", 0))), "scale": [1.0, 1.0], "layer": legacy.layer_rank(group), "parent": "", "anchor": "origin", "anchors": {"origin": [0, 0]}, "masks": [], "clip_to": p.get("clip_to", ""), "source": {"origin": "existing-project", "image": p.atlas}}
		a.name = {"head": "整头 · 完好", "wounded": "整头 · 受伤", "face": "净面头", "base": "底座", "padded": "绗缝甲 · 完好", "padded_damaged": "绗缝甲 · 破损", "mail": "链甲 · 完好", "mail_damaged": "链甲 · 破损", "hair": "发型", "beard": "胡须", "scar": "脸部伤痕", "bandage": "头部绷带", "blood": "皮肤血迹", "arrow": "箭矢"}.get(id, a.name)
		if id in ["skin", "blood", "body", "linen", "padded", "padded_damaged", "mail", "mail_damaged"]: a.masks = ["bust"]
		if a.clip_to == "face" and legacy.appearance.head == "legacy": a.clip_to = "head"
		if id in ["sword", "spear", "bow"]:
			var rest := Motion.sample(id, 0, "hit", legacy.action_for(id))
			a.position = [float(a.position[0]) + rest.position.x, float(a.position[1]) + rest.position.y]
			a.rotation += rad_to_deg(rest.angle)
		data.assets[id] = a
	# Convert baked legacy world placement back into true parent-local coordinates.
	for id: String in ["hair", "beard", "scar", "bandage", "blood"]:
		var parent := "skin" if id == "blood" else ("face" if legacy.appearance.head == "modular" else "head")
		var a: Dictionary = data.assets[id]
		var owner: Dictionary = data.assets[parent]
		var local := Visuals.local_transform(owner).affine_inverse() * Visuals.local_transform(a)
		a.parent = parent
		a.position = [local.origin.x, local.origin.y]
		a.rotation = rad_to_deg(local.get_rotation())
		a.scale = [local.get_scale().x, local.get_scale().y]
	for weapon: String in ["sword", "spear", "bow"]:
		var old: Dictionary = legacy.action_for(weapon)
		var normalized := Motion.normalize_action(weapon, old)
		if not normalized.is_empty(): old = normalized
		var action := {"id": weapon, "duration": old.duration, "events": [{"id": "release", "time": old.release * old.duration}, {"id": "contact", "time": old.contact * old.duration}], "tracks": [], "legacy_weapon": weapon, "legacy_action": old.duplicate(true)}
		var rest: Dictionary = old.keyframes[0]
		for property: String in ["x", "y", "rotation"]:
			var track := {"target": weapon, "property": property, "keys": []}
			for k: Dictionary in old.keyframes:
				var field := "angle" if property == "rotation" else property
				var value := float(k[field]) - float(rest[field])
				if property == "rotation": value = rad_to_deg(value)
				track.keys.append({"id": str(k.id) + "." + property, "time": float(k.t) * float(old.duration), "value": value, "interpolation": "smooth"})
			action.tracks.append(track)
		data.actions[weapon] = action
	data.editor.scene = Actor.assembly_layers("mail", false, false, catalog) + ["shield", "sword"]
	defaults = data.assets.duplicate(true)
	data.baseline = defaults.duplicate(true)

func checkpoint(label: String = "编辑") -> void:
	history.append({"label": label, "data": data.duplicate(true)})
	if history.size() > 150: history.pop_front()
	future.clear()

func undo() -> void:
	if history.is_empty(): return
	var item: Dictionary = history.pop_back()
	future.append({"label": item.label, "data": data.duplicate(true)})
	data = item.data

func redo() -> void:
	if future.is_empty(): return
	var item: Dictionary = future.pop_back()
	history.append({"label": item.label, "data": data.duplicate(true)})
	data = item.data

func dirty() -> bool:
	return JSON.stringify(data) != saved

func asset(id: String, adaptation: String = "") -> Dictionary:
	return Visuals.resolve(data, id, adaptation)

func set_value(id: String, field: String, value: Variant, adaptation: String = "") -> void:
	if adaptation.is_empty(): data.assets[id][field] = value
	else:
		if not data.adaptations.has(adaptation): data.adaptations[adaptation] = {}
		if not data.adaptations[adaptation].has(id): data.adaptations[adaptation][id] = {}
		data.adaptations[adaptation][id][field] = value

func move_selection(ids: Array, delta: Vector2, before: Dictionary, adaptation: String = "") -> void:
	for id: String in ids:
		var a := Visuals.resolve(before, id, adaptation)
		var parent: String = a.get("parent", "")
		var ancestor := parent
		var carried := false
		while not ancestor.is_empty() and before.assets.has(ancestor):
			if ancestor in ids: carried = true; break
			ancestor = str(Visuals.resolve(before, ancestor, adaptation).get("parent", ""))
		if carried: continue
		var local_delta := delta
		if not parent.is_empty(): local_delta = Visuals.world_transform(before, parent, adaptation).basis_xform_inv(delta)
		var position := Visuals.vector(a.position) + local_delta
		set_value(id, "position", [position.x, position.y], adaptation)

static func finite_array(value: Variant, count: int) -> bool:
	if not value is Array or value.size() != count: return false
	for x in value:
		if not (x is int or x is float) or not is_finite(float(x)): return false
	return true

func validate(value: Dictionary = {}, check_images: bool = true) -> Array:
	var d := data if value.is_empty() else value
	var errors := []
	if d.get("schema") != SCHEMA or not d.get("assets") is Dictionary: return ["不支持的资产工程格式"]
	for section: String in ["adaptations", "masks", "actions", "editor", "game"]:
		if not d.get(section) is Dictionary: return ["缺少对象: " + section]
	if not finite_array(d.game.get("placement", [0, 0]), 2): errors.append("人物整体偏移无效")
	for field: String in ["scene", "hidden", "locked"]:
		if not d.editor.get(field) is Array: return ["编辑状态无效: " + field]
		for id in d.editor[field]:
			if not d.assets.has(id): errors.append("编辑状态引用缺失资产: " + str(id))
	if not d.editor.get("view", {}) is Dictionary or not d.editor.get("groups", {}) is Dictionary: errors.append("编辑视图或分组格式无效")
	var review: Variant = d.editor.get("review", {})
	if not review is Dictionary: errors.append("资产评审状态无效")
	else:
		for id in review:
			if not d.assets.has(id): errors.append("评审状态引用缺失资产: " + str(id)); continue
			var state: Variant = review[id]
			if not state is Dictionary or not state.get("handled", false) is bool or not state.get("flagged", false) is bool: errors.append("评审状态无效: " + str(id))
	for id in d.masks:
		var mask: Variant = d.masks[id]
		if not mask is Dictionary: errors.append("遮罩格式无效"); continue
		var follow: String = mask.get("follow", "assembly")
		if follow not in ["assembly", "grid"] and not d.assets.has(follow): errors.append("遮罩跟随资产不存在: " + str(id) + " → " + follow)
		if mask.get("type") == "rect":
			if not finite_array(mask.get("rect"), 4): errors.append("矩形遮罩坐标无效")
			elif mask.rect[2] <= 0 or mask.rect[3] <= 0: errors.append("矩形遮罩尺寸必须大于零")
		elif mask.get("type") == "bust":
			if not finite_array(mask.get("center"), 2) or not finite_array(mask.get("radius"), 2) or not finite_array([mask.get("top")], 1): errors.append("盘面遮罩坐标无效")
			elif mask.radius[0] <= 0 or mask.radius[1] <= 0: errors.append("盘面半径必须大于零")
		else: errors.append("未知遮罩类型")
	for id in d.assets:
		var a: Variant = d.assets[id]
		if not a is Dictionary or a.get("id") != id: errors.append("资产 ID 不匹配: " + str(id)); continue
		var structural := false
		for field: String in ["name", "category", "image", "parent", "anchor", "clip_to"]:
			if not a.get(field) is String: errors.append(str(id) + " 字段需为字符串: " + field); structural = true
		if structural: continue
		if not a.get("source") is Dictionary: errors.append(str(id) + " 来源记录缺失")
		if not a.get("flip_h", false) is bool: errors.append(str(id) + " 水平翻转必须是布尔值")
		if not a.get("slot", "") is String: errors.append(str(id) + " 功能槽必须是文字")
		if not a.get("masks") is Array or not a.get("tags") is Array: errors.append(str(id) + " 标签与遮罩需为数组"); continue
		for field: String in ["position", "size", "scale", "pivot"]:
			if not finite_array(a.get(field), 2): errors.append(str(id) + "." + field + " 必须为两个有限数值")
		if not finite_array(a.get("rect"), 4): errors.append(str(id) + ".rect 无效"); continue
		if a.rect[2] <= 0 or a.rect[3] <= 0 or a.rect[0] < 0 or a.rect[1] < 0: errors.append(str(id) + " 源图范围无效")
		for field: String in ["rotation", "layer"]:
			if not finite_array([a.get(field)], 1): errors.append(str(id) + "." + field + " 无效")
		if finite_array(a.get("size"), 2) and (a.size[0] <= 0 or a.size[1] <= 0): errors.append(str(id) + " 尺寸必须大于零")
		if finite_array(a.get("scale"), 2) and (absf(a.scale[0]) < 0.0001 or absf(a.scale[1]) < 0.0001): errors.append(str(id) + " 缩放不能为零")
		if not a.get("anchors") is Dictionary: errors.append(str(id) + " 锚点无效")
		else:
			for anchor in a.anchors:
				if not finite_array(a.anchors[anchor], 2): errors.append(str(id) + " 锚点坐标无效")
		var visited := [id]
		var parent: String = a.get("parent", "")
		while not parent.is_empty():
			if parent in visited or not d.assets.has(parent): errors.append(str(id) + " 附着循环或父资产缺失"); break
			visited.append(parent)
			parent = str(d.assets[parent].get("parent", ""))
		parent = str(a.get("parent", ""))
		if not parent.is_empty() and d.assets.has(parent) and not d.assets[parent].get("anchors", {}).has(a.get("anchor", "origin")): errors.append(str(id) + " 锚点缺失")
		var owner: String = a.get("clip_to", "")
		visited = [id]
		while not owner.is_empty():
			if owner in visited or not d.assets.has(owner): errors.append(str(id) + " 遮罩循环或目标缺失"); break
			visited.append(owner); owner = str(d.assets[owner].get("clip_to", ""))
		for mask in a.get("masks", []):
			if not d.masks.has(mask): errors.append(str(id) + " 缺少遮罩 " + str(mask))
		if check_images:
			var tex := Visuals.texture(a, base_dir)
			if tex == null: errors.append(str(id) + " 图片缺失")
			elif a.rect[0] + a.rect[2] > tex.get_width() or a.rect[1] + a.rect[3] > tex.get_height(): errors.append(str(id) + " 裁切超出图片")
	for name in d.adaptations:
		if not d.adaptations[name] is Dictionary: errors.append("适配配置无效: " + str(name)); continue
		var expanded := d.duplicate(true)
		expanded.adaptations = {}
		for id in d.adaptations[name]:
			if not d.assets.has(id): errors.append("适配资产缺失: " + str(id)); continue
			if not d.adaptations[name][id] is Dictionary: errors.append("适配覆盖无效"); continue
			expanded.assets[id].merge(d.adaptations[name][id], true)
		errors.append_array(validate(expanded, check_images))
	for id in d.actions:
		var action: Variant = d.actions[id]
		if not action is Dictionary or not finite_array([action.get("duration")], 1) or action.duration <= 0 or not action.get("tracks") is Array: errors.append("动作格式无效: " + str(id)); continue
		if action.get("id") != id: errors.append("动作 ID 不匹配: " + str(id))
		var used := {}
		var tracks := {}
		for track in action.tracks:
			if not track is Dictionary or not d.assets.has(track.get("target", "")) or track.get("property") not in PROPERTIES or not track.get("keys") is Array: errors.append("动作轨道无效: " + str(id)); continue
			var key := str(track.target) + "/" + str(track.property)
			if tracks.has(key): errors.append("重复轨道: " + key)
			tracks[key] = true
			var previous := -1.0
			for frame in track.keys:
				if not frame is Dictionary or str(frame.get("id", "")).is_empty() or used.has(frame.get("id")): errors.append("关键帧 ID 缺失或重复"); continue
				used[frame.id] = true
				if not finite_array([frame.get("time")], 1): errors.append("关键帧时间无效"); continue
				if frame.time <= previous or frame.time < 0 or frame.time > action.duration: errors.append("关键帧需按时间严格递增且位于动作范围内")
				previous = float(frame.time)
				if track.property == "visible":
					if not frame.get("value") is bool: errors.append("显隐关键帧必须是布尔值")
				elif not finite_array([frame.get("value")], 1): errors.append("关键帧数值无效")
				elif track.property in ["scale_x", "scale_y"] and absf(float(frame.value)) < 0.0001: errors.append("关键帧缩放不能为零")
				if frame.get("interpolation", "linear") not in ["linear", "smooth", "hold"]: errors.append("未知插值方式")
		if not action.get("events", []) is Array: errors.append("动作事件需为数组"); continue
		var event_ids := {}
		for event in action.get("events", []):
			if not event is Dictionary or str(event.get("id", "")).is_empty() or not finite_array([event.get("time")], 1): errors.append("动作事件无效")
			elif event.time < 0 or event.time > action.duration: errors.append("动作事件超出范围")
			elif event_ids.has(event.id): errors.append("事件 ID 重复")
			else: event_ids[event.id] = true
	return errors

func load_project(file: String) -> String:
	var value := read_json(file)
	if value.is_empty(): return "工程无法读取"
	if int(value.get("schema", 0)) < SCHEMA:
		var old := Legacy.new()
		var error := old.load_project(file)
		if not error.is_empty(): return error
		from_legacy(old)
		path = ""; disk_hash = ""
		notices = ["旧草案已迁移，请另存新版；原文件未改。"]
	else:
		var old_base := base_dir
		base_dir = file.get_base_dir()
		var errors := validate(value, false)
		if not errors.is_empty(): base_dir = old_base; return "\n".join(errors)
		data = value
		defaults = data.get("baseline", data.assets).duplicate(true)
		if not data.has("baseline"): data.baseline = defaults.duplicate(true)
		path = file; disk_hash = FileAccess.get_sha256(file)
		notices = validate()
	history.clear(); future.clear(); saved = JSON.stringify(data)
	expected_revision = revision()
	return ""

static func atomic_json(file: String, value: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(file.get_base_dir())
	var tmp := file + ".tmp"
	var handle := FileAccess.open(tmp, FileAccess.WRITE)
	if handle == null: return "无法写入: " + file
	handle.store_string(JSON.stringify(value, "\t")); handle.close()
	if FileAccess.file_exists(file):
		var err := DirAccess.copy_absolute(file, file + ".bak")
		if err != OK: return "无法备份: " + file
	var error := DirAccess.rename_absolute(tmp, file)
	return "" if error == OK else "无法替换文件: " + file

func save_project(file: String) -> String:
	if file == path and FileAccess.file_exists(file) and FileAccess.get_sha256(file) != disk_hash: return "文件已被外部修改，请重新打开或另存"
	if file != path and FileAccess.file_exists(file): return "目标文件已存在，请使用新文件名"
	var next := data.duplicate(true)
	var portable_assets: Array = next.assets.values() + next.get("baseline", {}).values()
	for a: Dictionary in portable_assets:
		if not str(a.image).begins_with("res://"):
			var source := Visuals.source_path(a, base_dir)
			if FileAccess.file_exists(source):
				var relative := "images/" + FileAccess.get_sha256(source) + ".png"
				var destination := file.get_base_dir().path_join(relative)
				DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
				if source != destination and DirAccess.copy_absolute(source, destination) != OK: return "图片复制失败"
				a.image = relative
	var error := atomic_json(file, next)
	if error.is_empty():
		data = next; path = file; base_dir = file.get_base_dir(); disk_hash = FileAccess.get_sha256(file); saved = JSON.stringify(data)
	return error

func import_png(file: String, id: String, name: String, category: String, region: Array = []) -> String:
	if id.is_empty() or data.assets.has(id): return "资产 ID 为空或重复"
	var img := Image.load_from_file(file)
	if img == null: return "无法读取图片"
	var rect := [0, 0, img.get_width(), img.get_height()] if region.is_empty() else region
	if not finite_array(rect, 4) or rect[0] < 0 or rect[1] < 0 or rect[2] <= 0 or rect[3] <= 0 or rect[0] + rect[2] > img.get_width() or rect[1] + rect[3] > img.get_height(): return "图集区域无效"
	var relative := "images/" + FileAccess.get_sha256(file) + ".png"
	var destination := base_dir.path_join(relative)
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	if file != destination and DirAccess.copy_absolute(file, destination) != OK: return "无法复制图片"
	checkpoint("导入资产")
	var a := {"id": id, "name": name, "category": category, "tags": [], "image": relative, "rect": rect, "size": [32.0, 32.0 * float(rect[3]) / float(rect[2])], "pivot": [0.5, 0.5], "position": [0, -40], "rotation": 0.0, "scale": [1.0, 1.0], "layer": 160, "parent": "", "anchor": "origin", "anchors": {"origin": [0, 0]}, "masks": [], "clip_to": "", "source": {"file": file.get_file(), "sha256": FileAccess.get_sha256(file), "tool": "user-import", "license": "user-supplied"}}
	data.assets[id] = a; data.baseline[id] = a.duplicate(true)
	return ""

static func functional_slot(id: String, asset_data: Dictionary) -> String:
	# slot is the concrete component type, independent of the broad library category.
	var explicit: String = str(asset_data.get("slot", "")).strip_edges()
	if not explicit.is_empty(): return explicit
	# Keep the established one-handed sword slot while preventing named two-handed
	# variants from silently joining it. Other new types need an explicit slot.
	if id.begins_with("sword_2h") or id.begins_with("sword_twohand") or id.begins_with("greatsword"): return "sword_2h"
	if id.begins_with("sword_1h"): return "sword"
	if id == "skin" or id.begins_with("body_"): return "skin"
	if id.begins_with("outer_"): return "outer_damaged" if id.ends_with("_damaged") else "outer"
	if id.begins_with("padded_"): return "padded_damaged" if id.ends_with("_damaged") else "padded"
	for prefix in ["face", "hair", "beard", "linen", "shield", "sword", "axe", "spear", "bow", "scar", "bandage", "blood"]:
		if id == prefix or id.begins_with(prefix + "_"): return prefix
	if id in ["mail", "mail_damaged"]: return "outer_damaged" if id.ends_with("damaged") else "outer"
	return id

static func slot_label(slot: String) -> String:
	var known := {"face": "脸", "hair": "头发", "beard": "胡须", "skin": "身体底层", "body": "基础衣身", "linen": "亚麻衣", "padded": "绗缝身甲", "padded_damaged": "破损绗缝身甲", "outer": "外层身甲", "outer_damaged": "破损外层身甲", "helmet_layer2": "第二层头盔", "shield": "盾", "sword": "单手剑", "sword_2h": "双手剑", "axe": "斧", "spear": "长矛", "bow": "弓", "scar": "脸部伤痕", "bandage": "绷带", "blood": "血迹"}
	return str(known.get(slot, slot)) + " [" + slot + "]" if known.has(slot) else slot

func review_state(id: String) -> Dictionary:
	return data.editor.get("review", {}).get(id, {"handled": false, "flagged": false})

func set_review(id: String, field: String, value: bool) -> bool:
	if not data.assets.has(id) or field not in ["handled", "flagged"]: return false
	return set_review_bulk([id], field, value) > 0

func set_review_bulk(ids: Array, field: String, value: bool) -> int:
	if field not in ["handled", "flagged"]: return 0
	var valid: Array = ids.filter(func(id): return data.assets.has(id) and bool(review_state(id).get(field, false)) != value)
	if valid.is_empty(): return 0
	checkpoint("资产评审")
	if not data.editor.has("review"): data.editor.review = {}
	for id: String in valid:
		var state: Dictionary = review_state(id).duplicate(true)
		state[field] = value
		if not state.handled and not state.flagged: data.editor.review.erase(id)
		else: data.editor.review[id] = state
	return valid.size()

func _reattach_scene(adaptation: String) -> void:
	var selected_by_slot := {}
	for id: String in data.editor.scene:
		selected_by_slot[functional_slot(id, data.assets[id])] = id
	for id: String in data.editor.scene:
		var a := asset(id, adaptation)
		for field in ["parent", "clip_to"]:
			var reference: String = str(a.get(field, ""))
			if reference.is_empty() or not data.assets.has(reference): continue
			if reference in data.editor.scene: continue
			var selected_reference: String = selected_by_slot.get(functional_slot(reference, data.assets[reference]), "")
			if selected_reference.is_empty() or selected_reference == reference: continue
			if field == "parent" and not data.assets[selected_reference].get("anchors", {}).has(str(a.get("anchor", "origin"))): continue
			set_value(id, field, selected_reference, adaptation)

func replace_scene(mode: String, seed: int = -1, adaptation: String = "") -> Dictionary:
	if mode not in ["pending", "random"]: return {"changed": 0, "slots": 0, "reason": "未知替换模式"}
	var available := {}
	for id: String in data.assets:
		var slot := functional_slot(id, data.assets[id])
		if mode == "pending":
			var state := review_state(id)
			if bool(state.handled) and not bool(state.flagged): continue
		if not available.has(slot): available[slot] = []
		available[slot].append(id)
	for slot in available:
		available[slot].sort_custom(func(left, right):
			var first := review_state(left)
			var second := review_state(right)
			if bool(first.flagged) != bool(second.flagged): return bool(first.flagged)
			return str(left) < str(right))
	var rng := RandomNumberGenerator.new()
	if seed < 0: rng.randomize()
	else: rng.seed = seed
	var chosen: Dictionary = {}
	var original := data.duplicate(true)
	var old_scene: Array = data.editor.scene.duplicate()
	for old_id: String in old_scene:
		if not data.assets.has(old_id) or old_id in data.editor.locked: continue
		var slot := functional_slot(old_id, data.assets[old_id])
		var options: Array = available.get(slot, []).filter(func(id): return id != old_id and id not in data.editor.scene and id not in data.editor.locked)
		if options.is_empty(): continue
		if mode == "random":
			for i in range(options.size() - 1, 0, -1):
				var j := rng.randi_range(0, i)
				var swap: Variant = options[i]
				options[i] = options[j]
				options[j] = swap
		for next_id: String in options:
			var trial := data.duplicate(true)
			data.editor.scene[data.editor.scene.find(old_id)] = next_id
			var was_hidden: bool = old_id in data.editor.hidden
			data.editor.hidden.erase(old_id)
			data.editor.hidden.erase(next_id)
			if was_hidden: data.editor.hidden.append(next_id)
			for group in data.editor.get("groups", {}):
				var index: int = data.editor.groups[group].find(old_id)
				if index >= 0: data.editor.groups[group][index] = next_id
			_reattach_scene(adaptation)
			if validate({}, false).is_empty(): chosen[old_id] = next_id; break
			data = trial
	if chosen.is_empty(): return {"changed": 0, "slots": 0, "reason": "没有可替换的同类素材"}
	history.append({"label": "批量替换素材", "data": original}); future.clear()
	return {"changed": chosen.size(), "slots": chosen.size(), "mapping": chosen}

func alignment_candidates(sources: Dictionary, scope: String = "all", ungrouped: bool = false) -> Dictionary:
	var errors := []
	if scope not in ["all", "unhandled", "flagged", "pending"]: errors.append("未知目标范围")
	for slot in sources:
		var id: String = str(sources[slot])
		if not data.assets.has(id) or functional_slot(id, data.assets.get(id, {})) != str(slot):
			errors.append("参考组件与具体分类不一致: " + id)
	var rows := []
	var skipped := []
	if not errors.is_empty(): return {"rows": rows, "skipped": skipped, "errors": errors}
	var source_ids: Array = sources.values()
	var assigned := {}
	for group in data.editor.get("groups", {}):
		for id in data.editor.groups[group]: assigned[id] = true
	var ids: Array = data.assets.keys()
	ids.sort()
	for id: String in ids:
		var slot := functional_slot(id, data.assets[id])
		if not sources.has(slot) or id in source_ids: continue
		if id in data.editor.locked:
			skipped.append({"id": id, "reason": "已锁定"}); continue
		var state := review_state(id)
		if scope == "unhandled" and bool(state.handled): continue
		if scope == "flagged" and not bool(state.flagged): continue
		if scope == "pending" and bool(state.handled) and not bool(state.flagged): continue
		if ungrouped and assigned.has(id): continue
		rows.append({"id": id, "source": sources[slot], "slot": slot})
	return {"rows": rows, "skipped": skipped, "errors": errors}

func alignment_plan(mapping: Dictionary, preset: String = "fit", adaptation: String = "") -> Dictionary:
	var result := {"trial": data.duplicate(true), "changes": [], "skipped": [], "warnings": [], "errors": [], "signature": JSON.stringify(data).sha256_text()}
	if preset not in ["position", "fit", "exact"]: result.errors.append("未知对齐方式"); return result
	if not adaptation.is_empty() and not data.adaptations.has(adaptation): result.errors.append("适配配置不存在"); return result
	var source_ids: Array = mapping.values()
	var targets: Array = mapping.keys()
	targets.sort_custom(func(left, right):
		var left_depth := _alignment_depth(str(left), data)
		var right_depth := _alignment_depth(str(right), data)
		return left_depth < right_depth if left_depth != right_depth else str(left) < str(right))
	for target: String in targets:
		var source: String = str(mapping[target])
		if not data.assets.has(target) or not data.assets.has(source):
			result.skipped.append({"id": target, "reason": "组件不存在"}); continue
		if target == source or target in source_ids or target in data.editor.locked:
			result.skipped.append({"id": target, "reason": "来源或锁定组件不可修改"}); continue
		if functional_slot(target, data.assets[target]) != functional_slot(source, data.assets[source]):
			result.skipped.append({"id": target, "reason": "具体分类不同"}); continue
		var aligned := _alignment_values(data, result.trial, target, source, preset, adaptation)
		if aligned.has("error"):
			result.skipped.append({"id": target, "reason": aligned.error}); continue
		if preset == "exact":
			var source_quad := Visuals.quad(Visuals.resolve(data, source, adaptation), Visuals.world_transform(data, source, adaptation))
			var target_quad := Visuals.quad(Visuals.resolve(result.trial, target, adaptation), Visuals.world_transform(result.trial, target, adaptation))
			var source_ratio := (source_quad[1] - source_quad[0]).length() / (source_quad[3] - source_quad[0]).length()
			var target_ratio := (target_quad[1] - target_quad[0]).length() / (target_quad[3] - target_quad[0]).length()
			if absf(log(source_ratio / target_ratio)) > 0.02: result.warnings.append({"id": target, "reason": "原图宽高比不同，完全重合可能拉伸"})
		var values: Dictionary = aligned.values
		var current: Dictionary = Visuals.resolve(result.trial, target, adaptation)
		var changed := false
		for field in values:
			if not _alignment_near(current[field], values[field]): changed = true
			_alignment_set(result.trial, target, field, values[field], adaptation)
		if changed: result.changes.append({"id": target, "source": source, "slot": functional_slot(target, data.assets[target]), "fields": values.keys()})
	result.errors.append_array(validate(result.trial, false))
	return result

func alignment_adjust(plan: Dictionary, target: String, world_offset: Vector2, uniform_scale: float, adaptation: String = "") -> Dictionary:
	var result: Dictionary = plan.duplicate(true)
	if not result.get("errors", []).is_empty(): return result
	if str(result.get("signature", "")) != JSON.stringify(data).sha256_text(): result.errors.append("工程已变化，请重新预览对齐"); return result
	if is_nan(uniform_scale) or is_inf(uniform_scale) or uniform_scale < 0.05 or uniform_scale > 8.0:
		result.errors.append("预览缩放超出范围"); return result
	var trial: Dictionary = result.get("trial", {})
	if not trial.get("assets", {}).has(target) or target in data.editor.locked: result.errors.append("目标组件不可编辑"); return result
	var asset_data := Visuals.resolve(trial, target, adaptation)
	var points := Visuals.quad(asset_data, Visuals.world_transform(trial, target, adaptation))
	var center := (points[0] + points[2]) * 0.5 + world_offset
	var x_axis := (points[1] - points[0]) * uniform_scale
	var y_axis := (points[3] - points[0]) * uniform_scale
	var parent_result := _alignment_parent_frame(trial, asset_data, adaptation)
	if parent_result.has("error"): result.errors.append(parent_result.error); return result
	var aligned := _alignment_box_values(asset_data, parent_result.frame, center, x_axis, y_axis)
	if aligned.has("error"): result.errors.append(aligned.error); return result
	for field in aligned.values: _alignment_set(trial, target, field, aligned.values[field], adaptation)
	var before := Visuals.resolve(data, target, adaptation)
	var after := Visuals.resolve(trial, target, adaptation)
	var changed_fields := []
	for field in ["position", "rotation", "scale"]:
		if not _alignment_near(before[field], after[field]): changed_fields.append(field)
	result.changes = result.changes.filter(func(item): return item.id != target)
	result.skipped = result.skipped.filter(func(item): return item.id != target)
	if not changed_fields.is_empty(): result.changes.append({"id": target, "slot": functional_slot(target, data.assets[target]), "fields": changed_fields})
	result.errors.append_array(validate(trial, false))
	return result

func apply_alignment(plan: Dictionary) -> String:
	if not plan.get("errors", []).is_empty(): return "对齐预览未通过校验"
	if str(plan.get("signature", "")) != JSON.stringify(data).sha256_text(): return "工程已变化，请重新预览对齐"
	if plan.get("changes", []).is_empty(): return "没有需要修改的组件"
	var trial: Dictionary = plan.get("trial", {})
	var errors := validate(trial, false)
	if not errors.is_empty(): return "\n".join(errors)
	checkpoint("按具体分类快速对齐")
	data = trial.duplicate(true)
	return ""

static func _alignment_depth(id: String, document: Dictionary) -> int:
	var depth := 0
	var parent: String = str(document.assets.get(id, {}).get("parent", ""))
	while not parent.is_empty() and document.assets.has(parent) and depth <= document.assets.size():
		depth += 1
		parent = str(document.assets[parent].get("parent", ""))
	return depth

static func _alignment_near(first: Variant, second: Variant) -> bool:
	if first is Array and second is Array and first.size() == second.size():
		for i in range(first.size()):
			if not is_equal_approx(float(first[i]), float(second[i])): return false
		return true
	return is_equal_approx(float(first), float(second))

static func _alignment_set(document: Dictionary, id: String, field: String, value: Variant, adaptation: String) -> void:
	if adaptation.is_empty(): document.assets[id][field] = value
	else:
		if not document.adaptations[adaptation].has(id): document.adaptations[adaptation][id] = {}
		document.adaptations[adaptation][id][field] = value

static func _alignment_values(original: Dictionary, trial: Dictionary, target: String, source: String, preset: String, adaptation: String) -> Dictionary:
	var source_asset := Visuals.resolve(original, source, adaptation)
	var target_asset := Visuals.resolve(trial, target, adaptation)
	var source_quad := Visuals.quad(source_asset, Visuals.world_transform(original, source, adaptation))
	var target_world := Visuals.world_transform(trial, target, adaptation)
	var target_quad := Visuals.quad(target_asset, target_world)
	var source_center := (source_quad[0] + source_quad[2]) * 0.5
	var target_center := (target_quad[0] + target_quad[2]) * 0.5
	var desired_x := target_quad[1] - target_quad[0]
	var desired_y := target_quad[3] - target_quad[0]
	var source_x := source_quad[1] - source_quad[0]
	var source_y := source_quad[3] - source_quad[0]
	if minf(desired_x.length(), desired_y.length()) < 0.0001 or minf(source_x.length(), source_y.length()) < 0.0001:
		return {"error": "显示框尺寸过小"}
	if preset == "fit":
		var factor := minf(source_x.length() / desired_x.length(), source_y.length() / desired_y.length())
		desired_x = source_x.normalized() * desired_x.length() * factor
		desired_y = source_y.normalized() * desired_y.length() * factor
	elif preset == "exact":
		desired_x = source_x
		desired_y = source_y
	var parent_result := _alignment_parent_frame(trial, target_asset, adaptation)
	if parent_result.has("error"): return parent_result
	var parent_frame: Transform2D = parent_result.frame
	if preset == "position":
		var local_point := parent_frame.affine_inverse() * (target_world.origin + source_center - target_center)
		return {"values": {"position": [local_point.x, local_point.y]}}
	return _alignment_box_values(target_asset, parent_frame, source_center, desired_x, desired_y)

static func _alignment_parent_frame(trial: Dictionary, target_asset: Dictionary, adaptation: String) -> Dictionary:
	var parent_frame := Transform2D(0.0, Visuals.placement(trial))
	var parent: String = str(target_asset.get("parent", ""))
	if not parent.is_empty():
		if not trial.assets.has(parent): return {"error": "父组件不存在"}
		var owner := Visuals.resolve(trial, parent, adaptation)
		var anchor: String = str(target_asset.get("anchor", "origin"))
		if not owner.get("anchors", {}).has(anchor): return {"error": "父组件锚点不存在"}
		parent_frame = Visuals.world_transform(trial, parent, adaptation) * Transform2D(0.0, Visuals.vector(owner.anchors[anchor]))
	if absf(parent_frame.determinant()) < 0.000001: return {"error": "父组件变换不可逆"}
	return {"frame": parent_frame}

static func _alignment_box_values(target_asset: Dictionary, parent_frame: Transform2D, desired_center: Vector2, desired_x: Vector2, desired_y: Vector2) -> Dictionary:
	var size := Visuals.vector(target_asset.size)
	var pivot := Visuals.vector(target_asset.pivot)
	var world_x := desired_x / size.x
	var world_y := desired_y / size.y
	var world_origin := desired_center - desired_x * (0.5 - pivot.x) - desired_y * (0.5 - pivot.y)
	var local := parent_frame.affine_inverse() * Transform2D(world_x, world_y, world_origin)
	var x_length := local.x.length()
	var y_length := local.y.length()
	if minf(x_length, y_length) < 0.0001: return {"error": "结果缩放过小"}
	if absf(local.x.dot(local.y) / (x_length * y_length)) > 0.0005:
		return {"error": "父级与来源角度产生斜切，无法无损对齐"}
	var y_scale := y_length if local.x.cross(local.y) > 0 else -y_length
	return {"values": {"position": [local.origin.x, local.origin.y], "rotation": rad_to_deg(local.x.angle()), "scale": [x_length, y_scale]}}

func runtime_data() -> Dictionary:
	var result := data.duplicate(true)
	result.erase("editor"); result.erase("baseline"); result.erase("applied_revision")
	return result

func differences() -> Array:
	var current := read_json(runtime_dir().path_join(revision() + ".json"))
	var result := []
	for section: String in ["assets", "adaptations", "masks", "actions", "game"]:
		_diff_values(section, current.get(section, {}), data[section], result)
	return result

static func _diff_values(location: String, old: Variant, next: Variant, output: Array) -> void:
	if JSON.stringify(old) == JSON.stringify(next): return
	if old is Dictionary and next is Dictionary:
		var keys: Array = old.keys()
		for key in next:
			if key not in keys: keys.append(key)
		for key in keys: _diff_values(location + "/" + str(key), old.get(key), next.get(key), output)
	else:
		output.append(location + "  " + ("未设置" if old == null else JSON.stringify(old)) + " → " + ("移除" if next == null else JSON.stringify(next)))

func apply() -> String:
	if not path.is_empty() and FileAccess.file_exists(path) and FileAccess.get_sha256(path) != disk_hash: return "草案已被外部修改，请重新打开或另存后再应用"
	if revision() != expected_revision: return "应用版本已被外部更新，请重新打开工程后比较"
	var errors := validate()
	if not errors.is_empty(): return "\n".join(errors)
	var result := runtime_data()
	for id in result.assets:
		var a: Dictionary = result.assets[id]
		var source := Visuals.source_path(a, base_dir)
		if source.begins_with("res://"): continue
		var relative := "images/" + FileAccess.get_sha256(source) + ".png"
		var destination := runtime_dir().path_join(relative)
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		if DirAccess.copy_absolute(source, destination) != OK: return "应用图片失败"
		a.image = relative
	var next := str(Time.get_unix_time_from_system()).replace(".", "-") + "-" + str(randi())
	var error := atomic_json(runtime_dir().path_join(next + ".json"), result)
	if not error.is_empty(): return error
	# Recheck before publishing the pointer; immutable version file is harmless on conflict.
	if revision() != expected_revision: return "应用冲突：当前版本已改变"
	error = publish_pointer({"revision": next, "previous": expected_revision})
	if error.is_empty(): expected_revision = next; data.applied_revision = next
	if error.is_empty(): publication_serial += 1
	return error

func rollback() -> String:
	var pointer := read_json(runtime_dir().path_join("current.json"))
	if revision() != expected_revision: return "回退冲突：当前版本已改变"
	if pointer.is_empty(): return "没有已应用版本"
	var previous: String = pointer.get("previous", "")
	var error := publish_pointer({"revision": previous, "previous": expected_revision})
	if error.is_empty(): expected_revision = previous; data.applied_revision = previous
	if error.is_empty(): publication_serial += 1
	return error

func publish_pointer(pointer: Dictionary) -> String:
	var lock := runtime_dir().path_join(".publish-lock")
	if DirAccess.make_dir_absolute(lock) != OK: return "另一进程正在应用资源；若其异常退出，请先检查 .publish-lock"
	var error := ""
	if revision() != expected_revision: error = "应用冲突：当前版本已改变"
	else: error = atomic_json(runtime_dir().path_join("current.json"), pointer)
	DirAccess.remove_absolute(lock)
	return error

func transact(operations: Array) -> Array:
	var before := data.duplicate(true)
	for operation in operations:
		if not operation is Dictionary: data = before; return ["操作必须为对象"]
		var section: String = operation.get("section", "assets")
		if section in ["actions", "adaptations", "masks", "game"]:
			data[section][operation.get("id", "")] = operation.get("value")
			continue
		var id: String = operation.get("id", "")
		var field: String = operation.get("field", "")
		if not data.assets.has(id) or (not data.assets[id].has(field) and field not in ["flip_h", "slot"]) or field == "id": data = before; return ["未知资产或属性"]
		set_value(id, operation.field, operation.get("value"), operation.get("adaptation", ""))
	var errors := validate()
	if not errors.is_empty(): data = before; return errors
	history.append({"label": "批量修改", "data": before}); future.clear()
	return []
