extends RefCounted
## Closed static bust, fixed clothing registration, separately moving weapons.
## No borrowed shoulder/collar patches, limb sprites or gameplay state writes.
const Motion = preload("res://presentation/static_bust_motion.gd")
const CATALOG := "res://assets/art/static-bust/catalog.json"
static var _catalog: Dictionary = {}
static var _previous_catalog: Dictionary = {}
static var _textures: Dictionary = {}

static func parts() -> Dictionary:
	if _catalog.is_empty():_catalog = JSON.parse_string(FileAccess.get_file_as_string(CATALOG))
	return _catalog.parts

static func previous_parts() -> Dictionary:
	if _previous_catalog.is_empty():
		_previous_catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/art/static-bust/catalog-v1.json"))
	return _previous_catalog.parts

static func body_layers(armor: String, damaged: bool, wounded: bool) -> Array[String]:
	var layers: Array[String] = ["base", "body"]
	if armor != "bare":layers.append("linen")
	if armor in ["padded", "mail"]:layers.append("padded_damaged" if damaged else "padded")
	if armor == "mail":layers.append("mail_damaged" if damaged else "mail")
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
		armor: String = "mail", damaged: bool = false, wounded: bool = false) -> void:
	for part in body_layers(armor,damaged,wounded):draw_part(c,part,origin,scale_value)

static func draw_weapon(c: CanvasItem, weapon: String, origin: Vector2, scale_value: float,
		p: float = 0.0, outcome: String = "hit", with_shield: bool = true) -> void:
	if weapon == "none":return
	if weapon == "sword" and with_shield:draw_part(c,"shield",origin,scale_value)
	var state := Motion.sample(weapon,p,outcome)
	draw_part(c,weapon,origin,scale_value,state.position,state.angle)
	if weapon == "bow" and (p < Motion.release(weapon) or p > .94):
		var pull := 5.0*smoothstep(0.0,Motion.release(weapon),p) if p < .94 else 0.0
		draw_part(c,"arrow",origin,scale_value,Vector2(57-pull,-42),PI/2)

static func draw_actor(c: CanvasItem, origin: Vector2, scale_value: float,
		armor: String = "mail", weapon: String = "sword", damaged: bool = false,
		wounded: bool = false, p: float = 0.0, outcome: String = "hit") -> void:
	draw_body(c,origin,scale_value,armor,damaged,wounded)
	draw_weapon(c,weapon,origin,scale_value,p,outcome)

static func contact_point(weapon: String) -> Vector2:
	if weapon == "bow":return Vector2(111,-42)
	var part: Dictionary = parts()[weapon]
	var state := Motion.sample(weapon,Motion.contact(weapon))
	return state.position+Vector2(0,-float(part.size[1])*float(part.pivot[1])).rotated(state.angle)

## Read-only U46 reference at identical camera scale; no temporary catalog swap.
static func draw_previous(c: CanvasItem, origin: Vector2, scale_value: float, armor: String,
		weapon: String, damaged: bool = false, wounded: bool = false) -> void:
	var old:=previous_parts()
	for id in body_layers(armor,damaged,wounded):
		draw_part(c,id,origin,scale_value,Vector2.ZERO,0,Color.WHITE,old)
	if weapon=="none":return
	if weapon=="sword":draw_part(c,"shield",origin,scale_value,Vector2.ZERO,0,Color.WHITE,old)
	var rest:Dictionary={"sword":[Vector2(8,-12),.62],"spear":[Vector2(20,-19),.52],"bow":[Vector2(40,-31),0]}
	draw_part(c,weapon,origin,scale_value,rest[weapon][0],rest[weapon][1],Color.WHITE,old)
	if weapon=="bow":draw_part(c,"arrow",origin,scale_value,Vector2(49,-35),PI/2,Color.WHITE,old)
