extends RefCounted
## Small, reviewable transform document. Never writes source textures/catalog.
const Actor = preload("res://presentation/static_bust_actor.gd")
const GROUPS = {
	"bust":["body","linen","padded","padded_damaged","mail","mail_damaged","head","wounded"],
	"head":["head","wounded"],"body":["body"],"linen":["linen"],
	"padded":["padded","padded_damaged"],"mail":["mail","mail_damaged"],
	"sword":["sword"],"spear":["spear"],"bow":["bow"],"shield":["shield"]}
const LABELS = {"bust":"人物整体","head":"头部 · 正常 / 受伤","body":"基础内衣", "linen":"亚麻内衬",
	"padded":"绗缝甲 · 完好 / 破损","mail":"链甲 · 完好 / 破损", "sword":"剑", "spear":"长矛", "bow":"弓", "shield":"盾"}
var baseline:Dictionary
var fingerprint:String
var edits:Dictionary={}
var history:Array=[]
var future:Array=[]
var saved_text:=""
var migrated_v3:=false

func _init() -> void:
	baseline=Actor.catalog().duplicate(true)
	fingerprint=FileAccess.get_sha256(Actor.CATALOG)
	saved_text=JSON.stringify(edits)

func transform_for(group:String) -> Dictionary:
	return edits.get(group,{"offset":[0.0,0.0],"scale":1.0}).duplicate(true)

func checkpoint() -> void:
	history.append(edits.duplicate(true))
	if history.size()>100:history.pop_front()
	future.clear()

func change(group:String,offset:Vector2,factor:float,record:bool=true) -> bool:
	if not GROUPS.has(group) or not offset.is_finite() or not is_finite(factor):return false
	if absf(offset.x)>20 or absf(offset.y)>20 or factor<.7 or factor>1.3:return false
	if group=="bust" and not is_equal_approx(factor,1.0):return false
	var next:={"offset":[snappedf(offset.x,.01),snappedf(offset.y,.01)],"scale":snappedf(factor,.001)}
	if transform_for(group)==next:return false
	if record:checkpoint()
	if offset.is_zero_approx() and is_equal_approx(factor,1.0):edits.erase(group)
	else:edits[group]=next
	return true

func undo() -> void:
	if history.is_empty():return
	future.append(edits.duplicate(true));edits=history.pop_back()

func redo() -> void:
	if future.is_empty():return
	history.append(edits.duplicate(true));edits=future.pop_back()

func reset_all() -> void:
	if not edits.is_empty():checkpoint();edits.clear()

func composed() -> Dictionary:
	var result:=baseline.duplicate(true)
	# Group movement is translation only; per-part scales stay anchored.
	for group in GROUPS:
		var t:=transform_for(group)
		for id in GROUPS[group]:
			var part:Dictionary=result.parts[id]
			for axis in range(2):
				part.position[axis]+=t.offset[axis]
				part.size[axis]*=t.scale
	return result

func payload() -> Dictionary:
	return {"schema":1,"kind":"fantasy-brothers-paperdoll","baseline_sha256":fingerprint,"edits":edits.duplicate(true)}

func validate(value:Variant) -> Array[String]:
	var errors:Array[String]=[]
	if not value is Dictionary:return ["文件必须是装配配置对象。"]
	if value.get("schema")!=1 or value.get("kind")!="fantasy-brothers-paperdoll":errors.append("不是支持的装配配置版本。")
	if value.get("baseline_sha256")!=fingerprint and value.get("baseline_sha256") not in baseline.get("compatible_draft_baselines",[]):errors.append("参考资产已变化，请先对照原基准；未套用旧调整。")
	for key in value:
		if key not in ["schema","kind","baseline_sha256","edits"]:errors.append("未知字段："+str(key))
	if not value.get("edits") is Dictionary:return errors+["缺少 edits 配置。"]
	for group in value.edits:
		if not GROUPS.has(group):errors.append("不允许调整："+str(group));continue
		var t:Variant=value.edits[group]
		if not t is Dictionary or t.size()!=2 or not t.has("offset") or not t.has("scale"):
			errors.append("调整字段不完整："+group);continue
		if not t.offset is Array or t.offset.size()!=2:errors.append("位移必须有两个数值："+group);continue
		var valid:=true
		for number in [t.offset[0],t.offset[1],t.scale]:
			if not (number is int or number is float) or not is_finite(float(number)):valid=false
		if not valid:errors.append("存在无效数值："+group);continue
		if absf(t.offset[0])>20 or absf(t.offset[1])>20 or t.scale<.7 or t.scale>1.3:errors.append("调整超出小样范围："+group)
		if group=="bust" and not is_equal_approx(t.scale,1.0):errors.append("人物整体只允许平移，底座规格固定。")
	return errors

func load_project(path:String) -> String:
	if not FileAccess.file_exists(path):return "配置文件不存在。"
	var parser:=JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path))!=OK:return "配置 JSON 格式有误，未改变当前调整。"
	var value:Variant=parser.data
	var errors:=validate(value)
	if not errors.is_empty():return "\n".join(errors)
	checkpoint();edits=value.edits.duplicate(true);saved_text=JSON.stringify(edits)
	migrated_v3=value.baseline_sha256!=fingerprint
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
	if error.is_empty():saved_text=JSON.stringify(edits);migrated_v3=false
	return error

func dirty() -> bool:
	return migrated_v3 or JSON.stringify(edits)!=saved_text

func warnings() -> Array[String]:
	var result:Array[String]=[]
	var data:=composed()
	for id in ["bust","head","body","linen","padded","mail"]:
		var t:=transform_for(id)
		if absf(t.offset[0])>5 or absf(t.offset[1])>5 or absf(t.scale-1)>0.12:result.append(LABELS[id]+"：调整较大，请复看领口与盘面。")
	var bow:Dictionary=data.parts.bow
	var sz:=Vector2(bow.size[0],bow.size[1]);var pivot:=Vector2(bow.pivot[0],bow.pivot[1])*sz
	for i in range(101):
		var pose:=Actor.Motion.sample("bow",i/100.0)
		var offset:Vector2=Vector2(bow.position[0],bow.position[1])+pose.position
		for corner in [Vector2.ZERO,Vector2(sz.x,0),sz,Vector2(0,sz.y)]:
			if ((corner-pivot).rotated(pose.angle)+offset).y>0:
				result.append("弓在动作中可能越过地面，请调整位置或大小。");return result
	return result
