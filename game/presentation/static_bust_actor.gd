extends RefCounted
## Closed static bust, fixed clothing registration, separately moving weapons.
## No borrowed shoulder/collar patches, limb sprites or gameplay state writes.
const Motion = preload("res://presentation/static_bust_motion.gd")
const CATALOG := "res://assets/art/static-bust/catalog.json"
const V3_CATALOG := "res://assets/art/static-bust/catalog-v3.json"
const MODULES := "res://assets/art/static-bust/modules.json"
const RUNTIME_PROFILE := "res://assets/art/static-bust/runtime-profile.json"
## Higher rank draws later. Defaults match the historical paint order; overrides come from a draft.
const DRAW_RANK := {
	"base":0,"skin":10,"blood":20,"body":30,"linen":40,"padded":50,"mail":60,
	"head":70,"scar":80,"beard":90,"hair":100,"bandage":110,
	"shield":120,"sword":130,"spear":140,"bow":150}
const PART_GROUP := {
	"base":"base","body":"body","linen":"linen","padded":"padded","padded_damaged":"padded",
	"mail":"mail","mail_damaged":"mail","head":"head","wounded":"head","face":"head",
	"skin":"skin","blood":"blood","hair":"hair","beard":"beard","scar":"scar","bandage":"bandage",
	"shield":"shield","sword":"sword","spear":"spear","bow":"bow","arrow":"bow"}
static var _catalog: Dictionary = {}
static var _previous_catalog: Dictionary = {}
static var _textures: Dictionary = {}
static var _v3:Dictionary={}
static var _outlines:Dictionary={}
static var _runtime:Dictionary={}

static func v3_catalog() -> Dictionary:
	if _v3.is_empty():_v3=JSON.parse_string(FileAccess.get_file_as_string(V3_CATALOG))
	return _v3

static func catalog() -> Dictionary:
	parts()
	return _catalog

static func parts() -> Dictionary:
	if _catalog.is_empty():_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return _catalog.parts

static func runtime_catalog() -> Dictionary:
	if not _runtime.is_empty():return _runtime
	var result:Dictionary=catalog().duplicate(true)
	var modules:Variant=JSON.parse_string(FileAccess.get_file_as_string(MODULES))
	if modules is Dictionary:
		result.parts.merge(modules.get("parts", {}), true)
	var profile:Variant=JSON.parse_string(FileAccess.get_file_as_string(RUNTIME_PROFILE))
	if not profile is Dictionary:return result
	var groups:Dictionary={
		"bust":["body","linen","padded","padded_damaged","mail","mail_damaged","head","wounded","skin","face","hair","beard","scar","bandage","blood"],
		"base":["base"],"head":["head","wounded","face"],"skin":["skin"],"body":["body"],"linen":["linen"],
		"padded":["padded","padded_damaged"],"mail":["mail","mail_damaged"],
		"sword":["sword"],"spear":["spear"],"bow":["bow"],"shield":["shield"]}
	var edits:Dictionary=profile.get("edits", {})
	for group in edits:
		if group == "bust":continue
		if not groups.has(group):continue
		var transform:Dictionary=edits[group]
		var offset:=Vector2(float(transform.offset[0]),float(transform.offset[1]))
		var scale:=float(transform.get("scale",1.0))
		var angle:=deg_to_rad(float(transform.get("angle",0.0)))
		for id in groups[group]:
			if not result.parts.has(id):continue
			var part:Dictionary=result.parts[id]
			var pos:=Vector2(float(part.position[0]),float(part.position[1]))
			part.position=[pos.x+offset.x,pos.y+offset.y]
			part.size=[float(part.size[0])*scale,float(part.size[1])*scale]
			if not is_zero_approx(angle):part.rotation=angle
	for id in ["hair","beard","scar","bandage","blood"]:
		if not result.parts.has(id):continue
		var part:Dictionary=result.parts[id]
		var parent:=str(part.get("parent", ""))
		if not edits.has(parent):continue
		var transform:Dictionary=edits[parent]
		var anchor:=Vector2(float(catalog().parts[parent].position[0]),float(catalog().parts[parent].position[1]))
		var pos:=Vector2(float(part.position[0]),float(part.position[1]))
		var scale:=float(transform.get("scale",1.0))
		var angle:=deg_to_rad(float(transform.get("angle",0.0)))
		pos=anchor+((pos-anchor)*scale).rotated(angle)+Vector2(float(transform.offset[0]),float(transform.offset[1]))
		part.position=[pos.x,pos.y];part.size=[float(part.size[0])*scale,float(part.size[1])*scale]
		if not is_zero_approx(angle):part.rotation=part.get("rotation",0.0)+angle
	var bust:Dictionary=edits.get("bust", {})
	var bust_offset:=Vector2(float(bust.get("offset",[0,0])[0]),float(bust.get("offset",[0,0])[1]))
	for id in groups.bust:
		if result.parts.has(id):
			var p:Dictionary=result.parts[id];p.position=[float(p.position[0])+bust_offset.x,float(p.position[1])+bust_offset.y]
	result.assembly=profile.get("appearance", {}).duplicate(true)
	if profile.has("crop"):result.bust_crop=profile.crop.duplicate(true)
	_runtime=result
	return _runtime

static func previous_parts() -> Dictionary:
	if _previous_catalog.is_empty():
		_previous_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/static-bust/catalog-v2.json"))
	return _previous_catalog.parts

## One base-driven footprint shared by every torso layer/state. This is a
## visibility boundary, not a painted replacement edge or a sleeve patch.
static func bust_window(catalog_data:Dictionary={}) -> PackedVector2Array:
	parts()
	var spec:Dictionary=(_catalog if catalog_data.is_empty() else catalog_data).bust_crop
	var center:=Vector2(spec.center[0],spec.center[1])
	var radius:=Vector2(spec.radius[0],spec.radius[1])
	var polygon:=PackedVector2Array([Vector2(center.x-radius.x,spec.top),Vector2(center.x+radius.x,spec.top)])
	for i in range(65):
		var angle:=PI*float(i)/64
		polygon.append(center+Vector2(cos(angle)*radius.x,sin(angle)*radius.y))
	return polygon

static func draw_bust_part(c:CanvasItem,id:String,origin:Vector2,scale_value:float,
		tint:Color=Color.WHITE,catalog_data:Dictionary={}) -> void:
	draw_clipped_part(c,id,origin,scale_value,tint,catalog_data,true)

static func part_point(part:Dictionary,point:Vector2) -> Vector2:
	var sz:=Vector2(part.size[0],part.size[1])
	return (point-Vector2(part.pivot[0],part.pivot[1])*sz).rotated(part.get("rotation",0.0))+Vector2(part.position[0],part.position[1])

static func part_uv(part:Dictionary,point:Vector2) -> Vector2:
	var sz:=Vector2(part.size[0],part.size[1])
	return ((point-Vector2(part.position[0],part.position[1])).rotated(-part.get("rotation",0.0))+Vector2(part.pivot[0],part.pivot[1])*sz)/sz

## Owner silhouettes mask skin details. Cached source alpha is used only for
## display clipping; generated pixels and reference atlases are never rewritten.
static func owner_regions(part:Dictionary) -> Array[PackedVector2Array]:
	var key:String=part.atlas+str(part.rect)
	if not _outlines.has(key):
		if not ResourceLoader.exists(part.atlas):
			_outlines[key]=[]
			return []
		var texture:Texture2D=load(part.atlas)
		if texture==null:
			_outlines[key]=[]
			return []
		var source:Array=part.rect
		var region:=texture.get_image().get_region(Rect2i(source[0],source[1],source[2],source[3]))
		var bitmap:=BitMap.new();bitmap.create_from_image_alpha(region,.3)
		_outlines[key]=bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO,region.get_size()),1.0)
	var result:Array[PackedVector2Array]=[]
	for outline:PackedVector2Array in _outlines[key]:
		var polygon:=PackedVector2Array()
		for p in outline:polygon.append(part_point(part,p/Vector2(part.rect[2],part.rect[3])*Vector2(part.size[0],part.size[1])))
		result.append(polygon)
	return result

static func draw_clipped_part(c:CanvasItem,id:String,origin:Vector2,scale_value:float,
		tint:Color,catalog_data:Dictionary,clip_bust:bool) -> void:
	var data:Dictionary=parts() if catalog_data.is_empty() else catalog_data.parts
	var part:Dictionary=data[id]
	var path:String=part.atlas
	if not _textures.has(path):_textures[path]=load(path) if ResourceLoader.exists(path) else null
	var texture:Texture2D=_textures[path]
	if texture==null:return
	var sz:=Vector2(part.size[0],part.size[1])
	var rectangle:=PackedVector2Array()
	for p in [Vector2.ZERO,Vector2(sz.x,0),sz,Vector2(0,sz.y)]:rectangle.append(part_point(part,p))
	var regions:Array[PackedVector2Array]=[rectangle]
	if clip_bust:regions=Geometry2D.intersect_polygons(rectangle,bust_window(catalog_data))
	if part.has("clip_to"):
		var owner:String=part.clip_to
		if owner=="face" and catalog_data.get("assembly",{}).get("head","legacy")=="legacy":owner="head"
		var clipped:Array[PackedVector2Array]=[]
		for region in regions:
			for silhouette in owner_regions(data[owner]):clipped.append_array(Geometry2D.intersect_polygons(region,silhouette))
		regions=clipped
	var source:Array=part.rect
	for region:PackedVector2Array in regions:
		var points:=PackedVector2Array()
		var uvs:=PackedVector2Array()
		for point in region:
			points.append(origin+point*scale_value)
			uvs.append((Vector2(source[0],source[1])+part_uv(part,point)*Vector2(source[2],source[3]))/texture.get_size())
		c.draw_polygon(points,PackedColorArray([tint]),uvs,texture)

static func body_layers(armor: String, damaged: bool, wounded: bool,wear_damage:Dictionary={}) -> Array[String]:
	var layers: Array[String] = ["base", "body"]
	if armor != "bare":layers.append("linen")
	if armor in ["padded", "mail"]:layers.append("padded_damaged" if wear_damage.get("padded",damaged) else "padded")
	if armor == "mail":layers.append("mail_damaged" if wear_damage.get("mail",damaged) else "mail")
	layers.append("wounded" if wounded else "head")
	return layers

static func assembly_layers(armor: String, damaged: bool, wounded: bool, catalog_data: Dictionary = {}) -> Array:
	var layers: Array = body_layers(armor, damaged, wounded, catalog_data.get("wear_damage", {}))
	var assembly: Dictionary = catalog_data.get("assembly", {})
	if assembly.is_empty(): return layers
	if armor == "nude": layers = ["base", "wounded" if wounded else "head"]
	if assembly.get("skin", true):
		layers.insert(1, "skin")
		if assembly.get("blood", false): layers.insert(2, "blood")
	if assembly.get("head", "legacy") == "modular":
		layers[-1] = "face"
		if assembly.get("scar", false) or wounded: layers.append("scar")
		if assembly.get("beard", true): layers.append("beard")
		if assembly.get("hair", true): layers.append("hair")
	elif assembly.get("scar", false): layers.append("scar")
	if assembly.get("bandage", false): layers.append("bandage")
	return layers

static func rank_of(id: String, overrides: Dictionary) -> int:
	var group := str(PART_GROUP.get(id, id))
	if overrides.has(group): return int(overrides[group])
	return int(DRAW_RANK.get(group, 0))

static func sort_draw_ids(ids: Array, overrides: Dictionary) -> Array:
	var decorated: Array = []
	for index in range(ids.size()):
		decorated.append({"id":ids[index],"rank":rank_of(str(ids[index]), overrides),"index":index})
	decorated.sort_custom(func(a, b):
		if int(a.rank) == int(b.rank): return int(a.index) < int(b.index)
		return int(a.rank) < int(b.rank))
	var ordered: Array = []
	for item in decorated: ordered.append(item.id)
	return ordered

static func visible_draw_ids(armor: String, damaged: bool, wounded: bool, weapon: String,
		catalog_data: Dictionary = {}, hidden: Array = [], p: float = 0.0, outcome: String = "hit") -> Array:
	var ids: Array = []
	for part in assembly_layers(armor, damaged, wounded, catalog_data):
		if part in hidden: continue
		if part in ["face", "hair", "beard", "scar", "bandage"] and "head" in hidden: continue
		if part == "blood" and "skin" in hidden: continue
		ids.append(part)
	if weapon == "none": return ids
	if weapon == "sword" and "shield" not in hidden: ids.append("shield")
	if weapon in hidden: return ids
	ids.append(weapon)
	var action := motion_action(weapon, catalog_data)
	if weapon == "bow" and p < Motion.release(weapon, action): ids.append("arrow")
	return ids

static func draw_part(c: CanvasItem, id: String, origin: Vector2, scale_value: float,
		offset: Vector2 = Vector2.ZERO, angle: float = 0.0, tint: Color = Color.WHITE,
		catalog_parts: Dictionary = {}) -> void:
	var part: Dictionary = (parts() if catalog_parts.is_empty() else catalog_parts)[id]
	angle+=part.get("rotation",0.0)
	var path: String = part.atlas
	if not _textures.has(path):_textures[path]=load(path) if ResourceLoader.exists(path) else null
	var texture: Texture2D = _textures[path]
	if texture == null:return
	var sz := Vector2(part.size[0],part.size[1])
	var pivot := Vector2(part.pivot[0],part.pivot[1])*sz
	var pos := Vector2(part.position[0],part.position[1])+offset
	var source: Array = part.rect
	var uv := Vector2(source[0],source[1])/texture.get_size()
	var uv_size := Vector2(source[2],source[3])/texture.get_size()
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO,Vector2(sz.x,0),sz,Vector2(0,sz.y)]:
		points.append(origin+((corner-pivot).rotated(angle)+pos)*scale_value)
	c.draw_polygon(points,PackedColorArray([tint]),PackedVector2Array([
		uv,uv+Vector2(uv_size.x,0),uv+uv_size,uv+Vector2(0,uv_size.y)]),texture)

static func draw_body(c: CanvasItem, origin: Vector2, scale_value: float,
		armor: String = "mail", damaged: bool = false, wounded: bool = false,
		catalog_data:Dictionary={},hidden:Array=[],tint:Color=Color.WHITE) -> void:
	var data:Dictionary=parts() if catalog_data.is_empty() else catalog_data.parts
	for part in assembly_layers(armor,damaged,wounded,catalog_data):
		if part in hidden:continue
		if part in ["face","hair","beard","scar","bandage"] and "head" in hidden:continue
		if part=="blood" and "skin" in hidden:continue
		if part=="scar":draw_clipped_part(c,part,origin,scale_value,tint,catalog_data,false)
		elif part in ["base","head","wounded","face","hair","beard","bandage"]:draw_part(c,part,origin,scale_value,Vector2.ZERO,0,tint,data)
		else:draw_bust_part(c,part,origin,scale_value,tint,catalog_data)

static func motion_action(weapon: String, catalog_data: Dictionary = {}) -> Dictionary:
	return catalog_data.get("actions", {}).get(weapon, {})

static func draw_weapon(c: CanvasItem, weapon: String, origin: Vector2, scale_value: float,
		p: float = 0.0, outcome: String = "hit", with_shield: bool = true,
		catalog_data:Dictionary={},hidden:Array=[],tint:Color=Color.WHITE) -> void:
	if weapon == "none":return
	var data:Dictionary=parts() if catalog_data.is_empty() else catalog_data.parts
	var action:=motion_action(weapon,catalog_data)
	if weapon == "sword" and with_shield and not "shield" in hidden:draw_part(c,"shield",origin,scale_value,Vector2.ZERO,0,tint,data)
	if weapon in hidden:return
	var state := Motion.sample(weapon,p,outcome,action)
	draw_part(c,weapon,origin,scale_value,state.position,state.angle,tint,data)
	if weapon == "bow" and p < Motion.release(weapon,action):
		var arrow:=nocked_arrow(p,catalog_data)
		draw_part(c,"arrow",origin,scale_value,arrow.position,arrow.angle,Color(tint,tint.a*arrow.opacity),data)

static func draw_actor(c: CanvasItem, origin: Vector2, scale_value: float,
		armor: String = "mail", weapon: String = "sword", damaged: bool = false,
		wounded: bool = false, p: float = 0.0, outcome: String = "hit",
		catalog_data:Dictionary={},hidden:Array=[],tint:Color=Color.WHITE) -> void:
	var ranks: Variant = catalog_data.get("layer_ranks", {})
	if not ranks is Dictionary or ranks.is_empty():
		draw_body(c,origin,scale_value,armor,damaged,wounded,catalog_data,hidden,tint)
		draw_weapon(c,weapon,origin,scale_value,p,outcome,true,catalog_data,hidden,tint)
		return
	var data: Dictionary = parts() if catalog_data.is_empty() else catalog_data.parts
	var action := motion_action(weapon, catalog_data)
	for id in sort_draw_ids(visible_draw_ids(armor, damaged, wounded, weapon, catalog_data, hidden, p, outcome), ranks):
		_draw_listed_part(c, str(id), origin, scale_value, p, outcome, action, catalog_data, data, tint)

static func _draw_listed_part(c: CanvasItem, id: String, origin: Vector2, scale_value: float,
		p: float, outcome: String, action: Dictionary, catalog_data: Dictionary, data: Dictionary, tint: Color) -> void:
	if id == "shield":
		draw_part(c, "shield", origin, scale_value, Vector2.ZERO, 0, tint, data)
	elif id in ["sword", "spear", "bow"]:
		var state: Dictionary = Motion.sample(id, p, outcome, action)
		draw_part(c, id, origin, scale_value, state.position, state.angle, tint, data)
	elif id == "arrow":
		var arrow: Dictionary = nocked_arrow(p, catalog_data)
		draw_part(c, "arrow", origin, scale_value, arrow.position, arrow.angle, Color(tint, tint.a * arrow.opacity), data)
	elif id == "scar":
		draw_clipped_part(c, id, origin, scale_value, tint, catalog_data, false)
	elif id in ["base", "head", "wounded", "face", "hair", "beard", "bandage"]:
		draw_part(c, id, origin, scale_value, Vector2.ZERO, 0, tint, data)
	else:
		draw_bust_part(c, id, origin, scale_value, tint, catalog_data)

static func draw_runtime_actor(c: CanvasItem, origin: Vector2, scale_value: float,
		armor: String = "mail", weapon: String = "sword", damaged: bool = false,
		wounded: bool = false, p: float = 0.0, outcome: String = "hit",
		hidden:Array=[],tint:Color=Color.WHITE) -> void:
	draw_actor(c,origin,scale_value,armor,weapon,damaged,wounded,p,outcome,runtime_catalog(),hidden,tint)

## A fitted bow carries its nocked arrow with it. No gameplay state is involved.
static func nocked_arrow(p:float,catalog_data:Dictionary={}) -> Dictionary:
	var action:=motion_action("bow",catalog_data)
	var arrow:=Motion.nocked_arrow(p,action)
	if catalog_data.is_empty():return arrow
	var base:Dictionary=parts().bow
	var bow:Dictionary=catalog_data.parts.bow
	var pose:=Motion.sample("bow",p,"hit",action)
	var delta:=Vector2(bow.position[0]-base.position[0],bow.position[1]-base.position[1])
	var rotation:float=bow.get("rotation",0.0)
	arrow.position=pose.position+delta+((arrow.position-pose.position)*(float(bow.size[0])/float(base.size[0]))).rotated(rotation)
	arrow.angle+=rotation
	return arrow

static func arrow_sample(p:float,outcome:String="hit",catalog_data:Dictionary={}) -> Dictionary:
	var action:=motion_action("bow",catalog_data)
	return Motion.arrow_sample(p,outcome,nocked_arrow(Motion.release("bow",action),catalog_data),action)

static func contact_point(weapon: String,catalog_data:Dictionary={}) -> Vector2:
	if weapon == "bow":return Motion.ARROW_TARGET
	var action:=motion_action(weapon,catalog_data)
	var part: Dictionary = (parts() if catalog_data.is_empty() else catalog_data.parts)[weapon]
	var state := Motion.sample(weapon,Motion.contact(weapon,action),"hit",action)
	return Vector2(part.position[0],part.position[1])+state.position+Vector2(0,-float(part.size[1])*float(part.pivot[1])).rotated(state.angle+part.get("rotation",0.0))

## Read-only U47 reference at identical camera scale; no temporary catalog swap.
static func draw_previous(c: CanvasItem, origin: Vector2, scale_value: float, armor: String,
		weapon: String, damaged: bool = false, wounded: bool = false) -> void:
	var old:=previous_parts()
	for id in body_layers(armor,damaged,wounded):
		draw_part(c,id,origin,scale_value,Vector2.ZERO,0,Color.WHITE,old)
	if weapon=="none":return
	if weapon=="sword":draw_part(c,"shield",origin,scale_value,Vector2.ZERO,0,Color.WHITE,old)
	var rest:Dictionary={"sword":[Vector2(8,-12),.62],"spear":[Vector2(23,-26),.52],"bow":[Vector2(48,-38),0]}
	draw_part(c,weapon,origin,scale_value,rest[weapon][0],rest[weapon][1],Color.WHITE,old)
	if weapon=="bow":draw_part(c,"arrow",origin,scale_value,Vector2(57,-42),PI/2,Color.WHITE,old)
