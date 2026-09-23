extends RefCounted
const Visuals = preload("res://presentation/asset_visuals.gd")
const Legacy = preload("res://presentation/paperdoll_document.gd")
const Actor = preload("res://presentation/static_bust_actor.gd")
const Motion = preload("res://presentation/static_bust_motion.gd")
const SCHEMA := 5
const PROPERTIES := ["x", "y", "rotation", "scale_x", "scale_y", "visible"]
static var storage_override := ""
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
	return error

func rollback() -> String:
	var pointer := read_json(runtime_dir().path_join("current.json"))
	if revision() != expected_revision: return "回退冲突：当前版本已改变"
	if pointer.is_empty(): return "没有已应用版本"
	var previous: String = pointer.get("previous", "")
	var error := publish_pointer({"revision": previous, "previous": expected_revision})
	if error.is_empty(): expected_revision = previous; data.applied_revision = previous
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
		if not data.assets.has(id) or not data.assets[id].has(operation.get("field", "")) or operation.get("field") == "id": data = before; return ["未知资产或属性"]
		set_value(id, operation.field, operation.get("value"), operation.get("adaptation", ""))
	var errors := validate()
	if not errors.is_empty(): data = before; return errors
	history.append({"label": "批量修改", "data": before}); future.clear()
	return []
