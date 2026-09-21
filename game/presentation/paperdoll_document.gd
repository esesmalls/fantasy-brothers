extends RefCounted
## Small, reviewable transform document. Never writes source textures/catalog.
const Actor = preload("res://presentation/static_bust_actor.gd")
const Motion = preload("res://presentation/static_bust_motion.gd")
const MODULES := "res://assets/art/static-bust/modules.json"
const MOVE_LIMIT := 128.0
const MIN_SCALE := .25
const MAX_SCALE := 3.0
const CROP_CENTER_LIMIT := 80.0
const MIN_CROP_RADIUS := Vector2(8.0, 2.0)
const MAX_CROP_RADIUS := Vector2(80.0, 40.0)
const MIN_CROP_TOP := -240.0
const MAX_CROP_TOP := -20.0
const DEFAULT_APPEARANCE := {"head":"legacy","skin":true,"hair":true,"beard":true,"scar":false,"bandage":false,"blood":false}
const GROUPS = {
	"bust":["body","linen","padded","padded_damaged","mail","mail_damaged","head","wounded","skin","face","hair","beard","scar","bandage","blood"],
	"base":["base"],"head":["head","wounded","face"],"skin":["skin"],"body":["body"],"linen":["linen"],
	"padded":["padded","padded_damaged"],"mail":["mail","mail_damaged"],
	"sword":["sword"],"spear":["spear"],"bow":["bow"],"shield":["shield"],
	"hair":["hair"],"beard":["beard"],"scar":["scar"],"bandage":["bandage"],"blood":["blood"]}
const SELECT_ORDER = ["bust","base","crop","head","skin","body","linen","padded","mail","sword","spear","bow","shield","hair","beard","scar","bandage","blood"]
const LABELS = {"bust":"人物整体","base":"底座 · 锚点","crop":"盘面裁取","head":"头部 · 整头 / 拆件","skin":"身体 · 裸身","body":"基础内衣", "linen":"亚麻内衬",
	"padded":"绗缝甲 · 完好 / 破损","mail":"链甲 · 完好 / 破损", "sword":"剑", "spear":"长矛", "bow":"弓", "shield":"盾"}
const DETAIL_LABELS = {"hair":"发型 · 试样","beard":"胡须 · 试样","scar":"脸部伤痕 · 试样","bandage":"头部绷带 · 试样","blood":"皮肤血迹 · 试样"}
const SCHEMA_FIELDS = {
	1:["schema","kind","baseline_sha256","edits"],
	2:["schema","kind","baseline_sha256","modules_sha256","edits","appearance"],
	3:["schema","kind","baseline_sha256","modules_sha256","edits","appearance","crop","actions"]}
var baseline:Dictionary
var fingerprint:String
var modules_fingerprint:String
var edits:Dictionary={}
var appearance:Dictionary=DEFAULT_APPEARANCE.duplicate(true)
var crop:Dictionary={}
var actions:Dictionary={}
var history:Array=[]
var future:Array=[]
var saved_text:=""
var migrated_v3:=false

func _init() -> void:
	baseline=Actor.catalog().duplicate(true)
	var modules:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(MODULES))
	baseline.parts.merge(modules.parts,true)
	baseline.assembly=DEFAULT_APPEARANCE.duplicate(true)
	fingerprint=FileAccess.get_sha256(Actor.CATALOG)
	modules_fingerprint=FileAccess.get_sha256(MODULES)
	saved_text=JSON.stringify(snapshot())

static func label_for(group:String) -> String:
	return LABELS.get(group,DETAIL_LABELS.get(group,group))

static func allows_scale(group:String) -> bool:
	return group not in ["bust","base","crop"]

func snapshot() -> Dictionary:
	return {"edits":edits.duplicate(true),"appearance":appearance.duplicate(true),
		"crop":crop.duplicate(true),"actions":actions.duplicate(true)}

func restore(value:Dictionary) -> void:
	edits=value.edits.duplicate(true);appearance=value.appearance.duplicate(true)
	crop=value.get("crop",{}).duplicate(true);actions=value.get("actions",{}).duplicate(true)

func transform_for(group:String) -> Dictionary:
	var value:Dictionary=edits.get(group,{"offset":[0.0,0.0],"scale":1.0}).duplicate(true)
	value.angle=value.get("angle",0.0)
	return value

func default_crop() -> Dictionary:
	return baseline.bust_crop.duplicate(true)

func crop_spec() -> Dictionary:
	return crop.duplicate(true) if not crop.is_empty() else default_crop()

func action_for(weapon:String) -> Dictionary:
	return actions[weapon].duplicate(true) if actions.has(weapon) else Motion.default_action(weapon)

func checkpoint() -> void:
	history.append(snapshot())
	if history.size()>100:history.pop_front()
	future.clear()

func _identity_locked(group:String,factor:float,angle:float) -> bool:
	return group in ["bust","base"] and (not is_equal_approx(factor,1.0) or not is_zero_approx(angle))

func _normalized_transform(offset:Vector2,factor:float,angle:float) -> Dictionary:
	return {"offset":[snappedf(offset.x,.01),snappedf(offset.y,.01)],"scale":snappedf(factor,.001),"angle":snappedf(angle,.1)}

func change(group:String,offset:Vector2,factor:float,record:bool=true,angle:float=NAN) -> bool:
	if is_nan(angle):angle=transform_for(group).angle
	if group=="crop" or not GROUPS.has(group) or not offset.is_finite() or not is_finite(factor):return false
	if not is_finite(angle) or absf(angle)>180:return false
	if absf(offset.x)>MOVE_LIMIT or absf(offset.y)>MOVE_LIMIT or factor<MIN_SCALE or factor>MAX_SCALE:return false
	if _identity_locked(group,factor,angle):return false
	var next:=_normalized_transform(offset,factor,angle)
	if transform_for(group)==next:return false
	if record:checkpoint()
	if offset.is_zero_approx() and is_equal_approx(factor,1.0) and is_zero_approx(angle):edits.erase(group)
	else:edits[group]=next
	return true

func change_shared(groups:Array,offset:Vector2,factor:float,angle:float,record:bool=true) -> bool:
	var next_edits:=edits.duplicate(true)
	var changed:=false
	for group in groups:
		if group=="crop" or not GROUPS.has(group):continue
		var use_scale:=factor if allows_scale(group) else 1.0
		var use_angle:=angle if allows_scale(group) else 0.0
		if not offset.is_finite() or not is_finite(use_scale) or not is_finite(use_angle):return false
		if absf(offset.x)>MOVE_LIMIT or absf(offset.y)>MOVE_LIMIT:return false
		if use_scale<MIN_SCALE or use_scale>MAX_SCALE or absf(use_angle)>180:return false
		var next:=_normalized_transform(offset,use_scale,use_angle)
		if transform_for(group)==next:continue
		if offset.is_zero_approx() and is_equal_approx(use_scale,1.0) and is_zero_approx(use_angle):next_edits.erase(group)
		else:next_edits[group]=next
		changed=true
	if not changed:return false
	if record:checkpoint()
	edits=next_edits
	return true

func nudge_shared(groups:Array,delta:Vector2,record:bool=true) -> bool:
	var next_edits:=edits.duplicate(true)
	var changed:=false
	for group in groups:
		if group=="crop" or not GROUPS.has(group):continue
		var t:=transform_for(group)
		var offset:=(Vector2(t.offset[0],t.offset[1])+delta).clamp(Vector2(-MOVE_LIMIT,-MOVE_LIMIT),Vector2(MOVE_LIMIT,MOVE_LIMIT))
		if not offset.is_finite():return false
		var next:=_normalized_transform(offset,t.scale,t.angle)
		if t==next:continue
		if offset.is_zero_approx() and is_equal_approx(t.scale,1.0) and is_zero_approx(t.angle):next_edits.erase(group)
		else:next_edits[group]=next
		changed=true
	if not changed:return false
	if record:checkpoint()
	edits=next_edits
	return true

func rotate_shared(groups:Array,angle:float,record:bool=true) -> bool:
	var next_edits:=edits.duplicate(true)
	var changed:=false
	if not is_finite(angle) or absf(angle)>180:return false
	for group in groups:
		if not allows_scale(group):continue
		var t:=transform_for(group)
		var next:=_normalized_transform(Vector2(t.offset[0],t.offset[1]),t.scale,angle)
		if t==next:continue
		if Vector2(t.offset[0],t.offset[1]).is_zero_approx() and is_equal_approx(t.scale,1.0) and is_zero_approx(angle):next_edits.erase(group)
		else:next_edits[group]=next
		changed=true
	if not changed:return false
	if record:checkpoint()
	edits=next_edits
	return true

func _crop_matches_default(spec:Dictionary) -> bool:
	var current:=default_crop()
	return is_equal_approx(spec.center[0],current.center[0]) and is_equal_approx(spec.center[1],current.center[1]) \
		and is_equal_approx(spec.radius[0],current.radius[0]) and is_equal_approx(spec.radius[1],current.radius[1]) \
		and is_equal_approx(spec.top,current.top)

func _valid_crop(spec:Dictionary) -> bool:
	if not spec.has("center") or not spec.has("radius") or not spec.has("top"):return false
	if not spec.center is Array or spec.center.size()!=2 or not spec.radius is Array or spec.radius.size()!=2:return false
	for number in [spec.center[0],spec.center[1],spec.radius[0],spec.radius[1],spec.top]:
		if not (number is int or number is float) or not is_finite(float(number)):return false
	var origin:=Vector2(default_crop().center[0],default_crop().center[1])
	if Vector2(spec.center[0],spec.center[1]).distance_to(origin)>CROP_CENTER_LIMIT:return false
	if spec.radius[0]<MIN_CROP_RADIUS.x or spec.radius[1]<MIN_CROP_RADIUS.y:return false
	if spec.radius[0]>MAX_CROP_RADIUS.x or spec.radius[1]>MAX_CROP_RADIUS.y:return false
	if spec.top<MIN_CROP_TOP or spec.top>MAX_CROP_TOP:return false
	return true

func change_crop(center:Vector2,radius:Vector2,top:float,record:bool=true) -> bool:
	if not center.is_finite() or not radius.is_finite() or not is_finite(top):return false
	var spec:={"center":[snappedf(center.x,.000001),snappedf(center.y,.000001)],
		"radius":[snappedf(radius.x,.000001),snappedf(radius.y,.000001)],"top":snappedf(top,.001)}
	if not _valid_crop(spec):return false
	if crop.is_empty() and _crop_matches_default(spec):return false
	if not crop.is_empty() and crop==spec:return false
	if record:checkpoint()
	if _crop_matches_default(spec):crop={}
	else:crop=spec
	return true

func set_action(weapon:String,value:Dictionary,record:bool=true) -> bool:
	var normalized:=Motion.normalize_action(weapon,value)
	if normalized.is_empty():return false
	if Motion.actions_equal(normalized,Motion.normalize_action(weapon,Motion.default_action(weapon))):
		if not actions.has(weapon):return false
		if record:checkpoint()
		actions.erase(weapon)
		return true
	if actions.get(weapon,{})==normalized:return false
	if record:checkpoint()
	actions[weapon]=normalized
	return true

func reset_action(weapon:String,record:bool=true) -> bool:
	if not actions.has(weapon):return false
	if record:checkpoint()
	actions.erase(weapon)
	return true

func set_appearance(key:String,value:Variant) -> bool:
	if not DEFAULT_APPEARANCE.has(key) or appearance[key]==value:return false
	if key=="head":
		if value not in ["legacy","modular"]:return false
	elif not value is bool:return false
	checkpoint();appearance[key]=value;return true

func undo() -> void:
	if history.is_empty():return
	future.append(snapshot());restore(history.pop_back())

func redo() -> void:
	if future.is_empty():return
	history.append(snapshot());restore(future.pop_back())

func reset_all() -> void:
	if not edits.is_empty() or appearance!=DEFAULT_APPEARANCE or not crop.is_empty() or not actions.is_empty():
		checkpoint();edits.clear();appearance=DEFAULT_APPEARANCE.duplicate(true);crop={};actions={}

func composed() -> Dictionary:
	var result:=baseline.duplicate(true)
	# Own transform, parent transform, then bust translation. No limb hierarchy.
	for group in GROUPS:
		if group=="bust":continue
		var t:=transform_for(group)
		for id in GROUPS[group]:
			var part:Dictionary=result.parts[id]
			for axis in range(2):
				part.position[axis]+=t.offset[axis]
				part.size[axis]*=t.scale
			if not is_zero_approx(t.angle):part.rotation=deg_to_rad(t.angle)
	for id in ["hair","beard","scar","bandage","blood"]:
		var part:Dictionary=result.parts[id]
		var parent:String=part.parent
		var t:=transform_for(parent)
		var anchor:=Vector2(baseline.parts[parent].position[0],baseline.parts[parent].position[1])
		var pos:=Vector2(part.position[0],part.position[1])
		pos=anchor+((pos-anchor)*t.scale).rotated(deg_to_rad(t.angle))+Vector2(t.offset[0],t.offset[1])
		part.position=[pos.x,pos.y];part.size=[part.size[0]*t.scale,part.size[1]*t.scale]
		if not is_zero_approx(t.angle):part.rotation=part.get("rotation",0.0)+deg_to_rad(t.angle)
	var bust:=transform_for("bust")
	for id in GROUPS.bust:
		for axis in range(2):result.parts[id].position[axis]+=bust.offset[axis]
	result.assembly=appearance.duplicate(true)
	if not crop.is_empty():result.bust_crop=crop.duplicate(true)
	if not actions.is_empty():result.actions=actions.duplicate(true)
	return result

func uses_authoring() -> bool:
	return not crop.is_empty() or not actions.is_empty()

func payload() -> Dictionary:
	var data:={"schema":2,"kind":"fantasy-brothers-paperdoll","baseline_sha256":fingerprint,
		"modules_sha256":modules_fingerprint,"edits":edits.duplicate(true),"appearance":appearance.duplicate(true)}
	if uses_authoring():
		data.schema=3
		if not crop.is_empty():data.crop=crop.duplicate(true)
		if not actions.is_empty():data.actions=actions.duplicate(true)
	return data

func validate(value:Variant) -> Array[String]:
	var errors:Array[String]=[]
	if not value is Dictionary:return ["文件必须是装配配置对象。"]
	var schema:int=int(value.get("schema",0))
	if schema not in [1,2,3] or value.get("kind")!="fantasy-brothers-paperdoll":errors.append("不是支持的装配配置版本。")
	if schema>=2:
		if value.get("modules_sha256")!=modules_fingerprint:errors.append("拆件样板版本不同，未盲目套用调整。")
		var a:Variant=value.get("appearance")
		if not a is Dictionary:errors.append("缺少部件启用配置。")
		else:
			for key in DEFAULT_APPEARANCE:
				if not a.has(key):errors.append("缺少部件："+key)
				elif key=="head":
					if a[key] not in ["legacy","modular"]:errors.append("未知头部样板。")
				elif not a[key] is bool:errors.append("部件开关必须为布尔值："+key)
			for key in a:
				if not DEFAULT_APPEARANCE.has(key):errors.append("未知部件："+str(key))
	if value.get("baseline_sha256")!=fingerprint and value.get("baseline_sha256") not in baseline.get("compatible_draft_baselines",[]):errors.append("参考资产已变化，请先对照原基准；未套用旧调整。")
	var allowed:Array=SCHEMA_FIELDS.get(schema, [])
	for key in value:
		if key not in allowed:errors.append("未知字段："+str(key))
	if schema==3:
		if value.has("crop"):
			if not value.crop is Dictionary:errors.append("裁取配置必须是对象。")
			elif not _valid_crop(value.crop):errors.append("裁取范围超出工具限制。")
			else:
				for key in value.crop:
					if key not in ["center","radius","top"]:errors.append("未知裁取字段："+str(key))
		if value.has("actions"):
			if not value.actions is Dictionary:errors.append("动作配置必须是对象。")
			else:
				for weapon in value.actions:
					if weapon not in Motion.DEFAULT_ACTIONS:errors.append("未知武器动作："+str(weapon));continue
					if Motion.normalize_action(str(weapon),value.actions[weapon]).is_empty():
						errors.append("武器动作无效："+str(weapon))
	if not value.get("edits") is Dictionary:return errors+["缺少 edits 配置。"]
	for group in value.edits:
		if not GROUPS.has(group):errors.append("不允许调整："+str(group));continue
		var t:Variant=value.edits[group]
		if not t is Dictionary or not t.has("offset") or not t.has("scale"):
			errors.append("调整字段不完整："+group);continue
		for key in t:
			if key not in (["offset","scale"] if schema==1 else ["offset","scale","angle"]):errors.append("未知调整字段："+str(key))
		if not t.offset is Array or t.offset.size()!=2:errors.append("位移必须有两个数值："+group);continue
		var valid:=true
		for number in [t.offset[0],t.offset[1],t.scale,t.get("angle",0)]:
			if not (number is int or number is float) or not is_finite(float(number)):valid=false
		if not valid:errors.append("存在无效数值："+group);continue
		if absf(t.offset[0])>MOVE_LIMIT or absf(t.offset[1])>MOVE_LIMIT or t.scale<MIN_SCALE or t.scale>MAX_SCALE or absf(t.get("angle",0))>180:errors.append("调整超出工具范围："+group)
		if group in ["bust","base"] and (not is_equal_approx(t.scale,1.0) or not is_zero_approx(t.get("angle",0))):
			errors.append("人物整体与底座只允许平移，规格保持固定。" if group=="bust" else "底座只允许移动锚点，不缩放或旋转。")
	return errors

func load_project(path:String) -> String:
	if not FileAccess.file_exists(path):return "配置文件不存在。"
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return "配置 JSON 格式有误，未改变当前调整。"
	var value:Variant=parser.data
	var errors:=validate(value)
	if not errors.is_empty():return "\n".join(errors)
	checkpoint();edits=value.edits.duplicate(true);appearance=value.get("appearance",DEFAULT_APPEARANCE).duplicate(true)
	crop=value.get("crop",{}).duplicate(true);actions=value.get("actions",{}).duplicate(true)
	saved_text=JSON.stringify(snapshot())
	migrated_v3=value.baseline_sha256!=fingerprint or value.schema==1
	return ""

static func output_path_error(path:String) -> String:
	if not path.is_absolute_path():return "请选择完整路径；相对路径可能指向程序资源。"
	var absolute:=ProjectSettings.globalize_path(path).simplify_path().replace("\\","/").to_lower()
	var resource_root:=ProjectSettings.globalize_path("res://").simplify_path().replace("\\","/").to_lower().trim_suffix("/")+"/"
	if path.begins_with("res://") or absolute.begins_with(resource_root):return "请保存到工程 game 目录之外；运行资产保持只读。"
	var executable_root:=OS.get_executable_path().get_base_dir().simplify_path().replace("\\","/").to_lower()+"/"
	if absolute.begins_with(executable_root):return "请勿将配置写入程序目录，请选择文档或评审目录。"
	# Exported tools live under builds/, so res:// is no longer the source root.
	var cursor:=OS.get_executable_path().get_base_dir()
	for _level in range(7):
		if FileAccess.file_exists(cursor.path_join("game/project.godot")):
			var source_root:=cursor.path_join("game").simplify_path().replace("\\","/").to_lower()+"/"
			if absolute.begins_with(source_root):return "请保存到工程 game 目录之外；运行资产保持只读。"
		var parent:=cursor.get_base_dir()
		if parent==cursor:break
		cursor=parent
	return ""

static func write_json(path:String,value:Dictionary) -> String:
	if path.get_extension().to_lower()!="json":return "请选择 .json 文件。"
	var path_error:=output_path_error(path)
	if not path_error.is_empty():return path_error
	var temp:=path+".tmp"
	var file:=FileAccess.open(temp,FileAccess.WRITE)
	if file==null:return "无法写入所选位置。"
	file.store_string(JSON.stringify(value,"\t",true)+"\n");file.flush()
	var write_error:=file.get_error();file.close()
	if write_error!=OK:return "写入失败，原文件未改变。"
	if FileAccess.file_exists(path):
		if DirAccess.copy_absolute(path,path+".bak")!=OK:return "无法备份原文件，已取消保存。"
	if DirAccess.rename_absolute(temp,path)!=OK:return "无法替换文件，备份已保留。"
	return ""

func save_project(path:String) -> String:
	var error:=write_json(path,payload())
	if error.is_empty():saved_text=JSON.stringify(snapshot());migrated_v3=false
	return error

func dirty() -> bool:
	return migrated_v3 or JSON.stringify(snapshot())!=saved_text

func warnings() -> Array[String]:
	var result:Array[String]=[]
	var data:=composed()
	for id in ["bust","head","body","linen","padded","mail"]:
		var t:=transform_for(id)
		if absf(t.offset[0])>5 or absf(t.offset[1])>5 or absf(t.scale-1)>0.12:result.append(LABELS[id]+"：调整较大，请复看领口与盘面。")
	if edits.has("base"):result.append("底座锚点已移动，请复看盘面贴合。")
	if not crop.is_empty():result.append("盘面裁取已改，超出范围的衣甲会按新边界显示。")
	if not actions.is_empty():result.append("武器动作已改写，预览与结算共用同一路径，不决定伤害。")
	var bow:Dictionary=data.parts.bow
	var sz:=Vector2(bow.size[0],bow.size[1]);var pivot:=Vector2(bow.pivot[0],bow.pivot[1])*sz
	var bow_action:=action_for("bow")
	for i in range(101):
		var pose:=Actor.Motion.sample("bow",i/100.0,"hit",bow_action)
		var offset:Vector2=Vector2(bow.position[0],bow.position[1])+pose.position
		for corner in [Vector2.ZERO,Vector2(sz.x,0),sz,Vector2(0,sz.y)]:
			if ((corner-pivot).rotated(pose.angle+bow.get("rotation",0.0))+offset).y>0:
				result.append("弓在动作中可能越过地面，请调整位置或大小。");return result
	return result
