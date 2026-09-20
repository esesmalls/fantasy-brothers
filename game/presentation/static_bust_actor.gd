extends RefCounted
## Closed static bust, fixed clothing registration, separately moving weapons.
## No borrowed shoulder/collar patches, limb sprites or gameplay state writes.
const Motion = preload("res://presentation/static_bust_motion.gd")
const CATALOG := "res://assets/art/static-bust/catalog.json"
const V3_CATALOG := "res://assets/art/static-bust/catalog-v3.json"
static var _catalog: Dictionary = {}
static var _previous_catalog: Dictionary = {}
static var _textures: Dictionary = {}
static var _v3:Dictionary={}

static func v3_catalog() -> Dictionary:
	if _v3.is_empty():_v3=JSON.parse_string(FileAccess.get_file_as_string(V3_CATALOG))
	return _v3

static func catalog() -> Dictionary:
	parts()
	return _catalog

static func parts() -> Dictionary:
	if _catalog.is_empty():_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return _catalog.parts

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
	var part:Dictionary=(parts() if catalog_data.is_empty() else catalog_data.parts)[id]
	var path:String=part.atlas
	if not _textures.has(path):_textures[path]=load(path)
	var texture:Texture2D=_textures[path]
	var sz:=Vector2(part.size[0],part.size[1])
	var top_left:=Vector2(part.position[0],part.position[1])-Vector2(part.pivot[0],part.pivot[1])*sz
	var rectangle:=PackedVector2Array([top_left,top_left+Vector2(sz.x,0),top_left+sz,top_left+Vector2(0,sz.y)])
	var source:Array=part.rect
	for region:PackedVector2Array in Geometry2D.intersect_polygons(rectangle,bust_window(catalog_data)):
		var points:=PackedVector2Array()
		var uvs:=PackedVector2Array()
		for point in region:
			points.append(origin+point*scale_value)
			uvs.append((Vector2(source[0],source[1])+(point-top_left)/sz*Vector2(source[2],source[3]))/texture.get_size())
		c.draw_polygon(points,PackedColorArray([tint]),uvs,texture)

static func body_layers(armor: String, damaged: bool, wounded: bool,wear_damage:Dictionary={}) -> Array[String]:
	var layers: Array[String] = ["base", "body"]
	if armor != "bare":layers.append("linen")
	if armor in ["padded", "mail"]:layers.append("padded_damaged" if wear_damage.get("padded",damaged) else "padded")
	if armor == "mail":layers.append("mail_damaged" if wear_damage.get("mail",damaged) else "mail")
	layers.append("wounded" if wounded else "head")
	return layers

static func draw_part(c: CanvasItem, id: String, origin: Vector2, scale_value: float,
		offset: Vector2 = Vector2.ZERO, angle: float = 0.0, tint: Color = Color.WHITE,
		catalog_parts: Dictionary = {}) -> void:
	var part: Dictionary = (parts() if catalog_parts.is_empty() else catalog_parts)[id]
	var path: String = part.atlas
	if not _textures.has(path):_textures[path]=load(path)
	var texture: Texture2D = _textures[path]
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
	for part in body_layers(armor,damaged,wounded,catalog_data.get("wear_damage",{})):
		if part in hidden:continue
		if part in ["base","head","wounded"]:draw_part(c,part,origin,scale_value,Vector2.ZERO,0,tint,data)
		else:draw_bust_part(c,part,origin,scale_value,tint,catalog_data)

static func draw_weapon(c: CanvasItem, weapon: String, origin: Vector2, scale_value: float,
		p: float = 0.0, outcome: String = "hit", with_shield: bool = true,
		catalog_data:Dictionary={},hidden:Array=[],tint:Color=Color.WHITE) -> void:
	if weapon == "none":return
	var data:Dictionary=parts() if catalog_data.is_empty() else catalog_data.parts
	if weapon == "sword" and with_shield and not "shield" in hidden:draw_part(c,"shield",origin,scale_value,Vector2.ZERO,0,tint,data)
	if weapon in hidden:return
	var state := Motion.sample(weapon,p,outcome)
	draw_part(c,weapon,origin,scale_value,state.position,state.angle,tint,data)
	if weapon == "bow" and p < Motion.release(weapon):
		var arrow:=nocked_arrow(p,catalog_data)
		draw_part(c,"arrow",origin,scale_value,arrow.position,arrow.angle,Color(tint,tint.a*arrow.opacity),data)

static func draw_actor(c: CanvasItem, origin: Vector2, scale_value: float,
		armor: String = "mail", weapon: String = "sword", damaged: bool = false,
		wounded: bool = false, p: float = 0.0, outcome: String = "hit",
		catalog_data:Dictionary={},hidden:Array=[],tint:Color=Color.WHITE) -> void:
	draw_body(c,origin,scale_value,armor,damaged,wounded,catalog_data,hidden,tint)
	draw_weapon(c,weapon,origin,scale_value,p,outcome,true,catalog_data,hidden,tint)

## A fitted bow carries its nocked arrow with it. No gameplay state is involved.
static func nocked_arrow(p:float,catalog_data:Dictionary={}) -> Dictionary:
	var arrow:=Motion.nocked_arrow(p)
	if catalog_data.is_empty():return arrow
	var base:Dictionary=parts().bow
	var bow:Dictionary=catalog_data.parts.bow
	var pose:=Motion.sample("bow",p)
	var delta:=Vector2(bow.position[0]-base.position[0],bow.position[1]-base.position[1])
	arrow.position=pose.position+delta+(arrow.position-pose.position)*(float(bow.size[0])/float(base.size[0]))
	return arrow

static func arrow_sample(p:float,outcome:String="hit",catalog_data:Dictionary={}) -> Dictionary:
	return Motion.arrow_sample(p,outcome,nocked_arrow(Motion.release("bow"),catalog_data))

static func contact_point(weapon: String,catalog_data:Dictionary={}) -> Vector2:
	if weapon == "bow":return Motion.ARROW_TARGET
	var part: Dictionary = (parts() if catalog_data.is_empty() else catalog_data.parts)[weapon]
	var state := Motion.sample(weapon,Motion.contact(weapon))
	return Vector2(part.position[0],part.position[1])+state.position+Vector2(0,-float(part.size[1])*float(part.pivot[1])).rotated(state.angle)

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
