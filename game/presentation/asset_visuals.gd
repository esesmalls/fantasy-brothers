extends RefCounted
## Shared, presentation-only renderer and sampler. No editor or combat state.
static var textures: Dictionary = {}
static var images: Dictionary = {}
static var outlines_cache: Dictionary = {}
static var geometry_cache: Dictionary = {}
static var geometry_signature := 0
static var hit_signature := 0
static var hit_parts: Array = []
static var draw_cache: Dictionary = {}
static var compiled_draws := 0

static func vector(value: Array) -> Vector2:
	return Vector2(float(value[0]), float(value[1]))

static func resolve(data: Dictionary, id: String, adaptation: String = "") -> Dictionary:
	var result: Dictionary = data.get("assets", {}).get(id, {}).duplicate(true)
	result.merge(data.get("adaptations", {}).get(adaptation, {}).get(id, {}), true)
	return result

static func sample(action: Dictionary, id: String, time: float) -> Dictionary:
	var result := {}
	for track: Dictionary in action.get("tracks", []):
		if track.target != id or track.keys.is_empty(): continue
		var keys: Array = track.keys
		if time < float(keys[0].time): continue
		var value: Variant = keys[0].value
		for i in range(keys.size()):
			var a: Dictionary = keys[i]
			if time < float(a.time): break
			value = a.value
			if i + 1 < keys.size() and time < float(keys[i + 1].time):
				var b: Dictionary = keys[i + 1]
				var weight := inverse_lerp(float(a.time), float(b.time), time)
				var interpolation: String = a.get("interpolation", "linear")
				if track.property == "visible" or interpolation == "hold": break
				if interpolation == "smooth": weight = smoothstep(0.0, 1.0, weight)
				value = lerpf(float(a.value), float(b.value), weight)
				break
		result[track.property] = value
	return result

static func local_transform(asset: Dictionary, pose: Dictionary = {}) -> Transform2D:
	var position := vector(asset.get("position", [0, 0])) + Vector2(float(pose.get("x", 0)), float(pose.get("y", 0)))
	var rotation := deg_to_rad(float(asset.get("rotation", 0)) + float(pose.get("rotation", 0)))
	var scale := vector(asset.get("scale", [1, 1])) * Vector2(float(pose.get("scale_x", 1)), float(pose.get("scale_y", 1)))
	return Transform2D(rotation, scale, 0.0, position)

static func placement(data: Dictionary) -> Vector2:
	return vector(data.get("game", {}).get("placement", [0, 0]))

static func world_transform(data: Dictionary, id: String, adaptation: String = "", action: Dictionary = {}, time: float = 0, anchors: Dictionary = {}, root_mode: bool = false, trail: Array = []) -> Transform2D:
	# Supplied anchors are world-space (already placed); strip the frame once.
	var frame := Transform2D(0.0, placement(data))
	var local_anchors := {}
	for key in anchors: local_anchors[key] = frame.affine_inverse() * anchors[key]
	return frame * _world_transform(data, id, adaptation, action, time, local_anchors, root_mode, trail)

static func _world_transform(data: Dictionary, id: String, adaptation: String = "", action: Dictionary = {}, time: float = 0, anchors: Dictionary = {}, root_mode: bool = false, trail: Array = []) -> Transform2D:
	var asset := resolve(data, id, adaptation)
	var own := local_transform(asset, sample(action, id, time))
	if root_mode or id in trail: return own
	var parent: String = asset.get("parent", "")
	if parent.is_empty(): return own
	var anchor: String = asset.get("anchor", "origin")
	var key := parent + ":" + anchor
	if anchors.has(key): return anchors[key] * own
	if not data.assets.has(parent): return own
	var owner := resolve(data, parent, adaptation)
	var offset := vector(owner.get("anchors", {"origin": [0, 0]}).get(anchor, [0, 0]))
	return _world_transform(data, parent, adaptation, action, time, anchors, false, trail + [id]) * Transform2D(0.0, offset) * own

static func diagnostics(data: Dictionary, ids: Array, adaptation: String = "", anchors: Dictionary = {}, root_mode: bool = false) -> Array:
	var errors := []
	if not adaptation.is_empty() and not data.get("adaptations", {}).has(adaptation): errors.append("适配配置不存在: " + adaptation)
	for id: String in ids:
		var asset := resolve(data, id, adaptation)
		if asset.is_empty():
			errors.append("缺少资产: " + id)
			continue
		var parent: String = asset.get("parent", "")
		var anchor: String = asset.get("anchor", "origin")
		if not root_mode and not parent.is_empty() and not anchors.has(parent + ":" + anchor):
			if parent not in ids: errors.append(id + " 缺少附着上下文: " + parent + ":" + anchor)
			elif not resolve(data, parent, adaptation).get("anchors", {}).has(anchor): errors.append(id + " 缺少锚点: " + anchor)
	return errors

static func source_path(asset: Dictionary, base_dir: String) -> String:
	var path: String = asset.get("image", "")
	return path if path.is_absolute_path() or path.begins_with("res://") else base_dir.path_join(path)

static func texture(asset: Dictionary, base_dir: String) -> Texture2D:
	var path := source_path(asset, base_dir)
	if textures.has(path): return textures[path]
	var tex: Texture2D
	if path.begins_with("res://") and ResourceLoader.exists(path): tex = load(path)
	elif FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		if img != null: tex = ImageTexture.create_from_image(img)
	if tex != null:
		textures[path] = tex
		images[path] = tex.get_image()
	return tex

static func quad(asset: Dictionary, transform: Transform2D) -> PackedVector2Array:
	var size := vector(asset.get("size", [32, 32]))
	var pivot := vector(asset.get("pivot", [0.5, 0.5])) * size
	return transform * PackedVector2Array([-pivot, Vector2(size.x, 0) - pivot, size - pivot, Vector2(0, size.y) - pivot])

static func mask_polygon(mask: Dictionary) -> PackedVector2Array:
	if mask.get("type", "") == "rect":
		var r: Array = mask.get("rect", [0, 0, 1, 1])
		return PackedVector2Array([Vector2(r[0], r[1]), Vector2(r[0] + r[2], r[1]), Vector2(r[0] + r[2], r[1] + r[3]), Vector2(r[0], r[1] + r[3])])
	var center := vector(mask.get("center", [0, -17]))
	var radius := vector(mask.get("radius", [29, 7]))
	var top := float(mask.get("top", -120))
	var polygon := PackedVector2Array([Vector2(center.x - radius.x, top), Vector2(center.x + radius.x, top)])
	for i in range(65): polygon.append(center + Vector2(cos(PI * i / 64.0) * radius.x, sin(PI * i / 64.0) * radius.y))
	return polygon

static func mask_world_polygon(data: Dictionary, mask: Dictionary, adaptation: String = "", action: Dictionary = {}, time: float = 0, anchors: Dictionary = {}) -> PackedVector2Array:
	var follow: String = mask.get("follow", "assembly")
	var frame := Transform2D.IDENTITY
	if follow == "assembly": frame.origin = placement(data)
	elif follow != "grid": frame = world_transform(data, follow, adaptation, action, time, anchors)
	return frame * mask_polygon(mask)

static func regions(data: Dictionary, id: String, adaptation: String, action: Dictionary, time: float, base_dir: String, anchors: Dictionary = {}, root_mode: bool = false, trail: Array = []) -> Array:
	if root_mode:
		# Carry the calibrated clipping shape into the caller's independent root space.
		var world := world_transform(data, id, adaptation, action, time, anchors)
		var rebase := world_transform(data, id, adaptation, action, time, anchors, true) * world.affine_inverse()
		var independent := []
		for polygon: PackedVector2Array in regions(data, id, adaptation, action, time, base_dir, anchors, false, trail): independent.append(rebase * polygon)
		return independent
	var identity: Variant = data.get("_render_cache_key", [data.assets, data.get("adaptations", {}), data.get("masks", {}), data.get("game", {})])
	var signature := hash([identity, adaptation, action, time, base_dir, anchors, root_mode])
	if signature != geometry_signature:
		geometry_signature = signature; geometry_cache.clear()
	if geometry_cache.has(id): return geometry_cache[id]
	var result := _regions(data, id, adaptation, action, time, base_dir, anchors, root_mode, trail)
	geometry_cache[id] = result
	return result

static func _regions(data: Dictionary, id: String, adaptation: String, action: Dictionary, time: float, base_dir: String, anchors: Dictionary = {}, root_mode: bool = false, trail: Array = []) -> Array:
	if id in trail: return []
	var asset := resolve(data, id, adaptation)
	var transform := world_transform(data, id, adaptation, action, time, anchors, root_mode)
	var result: Array = [quad(asset, transform)]
	for mask_id: String in asset.get("masks", []):
		var mask: Dictionary = data.get("masks", {}).get(mask_id, {})
		if mask.is_empty(): continue
		var next := []
		for polygon: PackedVector2Array in result: next.append_array(Geometry2D.intersect_polygons(polygon, mask_world_polygon(data, mask, adaptation, action, time, anchors)))
		result = next
	var owner: String = asset.get("clip_to", "")
	if not owner.is_empty() and data.assets.has(owner):
		var other := resolve(data, owner, adaptation)
		var tex := texture(other, base_dir)
		if tex == null: return []
		var rect: Array = other.rect
		var img: Image = images[source_path(other, base_dir)]
		var outline_key := source_path(other, base_dir) + str(rect)
		if not outlines_cache.has(outline_key):
			var bitmap := BitMap.new()
			bitmap.create_from_image_alpha(img.get_region(Rect2i(rect[0], rect[1], rect[2], rect[3])), 0.1)
			outlines_cache[outline_key] = bitmap.opaque_to_polygons(Rect2i(0, 0, rect[2], rect[3]), 0.5)
		var owner_transform := world_transform(data, owner, adaptation, action, time, anchors, root_mode)
		var size := vector(other.size)
		var pivot := vector(other.pivot) * size
		var outlines := []
		for outline in outlines_cache[outline_key]:
			var points := PackedVector2Array()
			for point: Vector2 in outline:
				var uv := point / Vector2(rect[2], rect[3])
				if other.get("flip_h", false): uv.x = 1.0 - uv.x
				points.append(owner_transform * (uv * size - pivot))
			outlines.append(points)
		var next := []
		var owner_regions := regions(data, owner, adaptation, action, time, base_dir, anchors, root_mode, trail + [id])
		for polygon: PackedVector2Array in result:
			for outline: PackedVector2Array in outlines:
				for intersection in Geometry2D.intersect_polygons(polygon, outline):
					for owner_region: PackedVector2Array in owner_regions: next.append_array(Geometry2D.intersect_polygons(intersection, owner_region))
		result = next
	return result

static func ordered(data: Dictionary, ids: Array, adaptation: String = "") -> Array:
	var result := ids.duplicate()
	result.sort_custom(func(a, b):
		var x := float(resolve(data, a, adaptation).get("layer", 0))
		var y := float(resolve(data, b, adaptation).get("layer", 0))
		return x < y if x != y else str(a) < str(b))
	return result

static func draw(canvas: CanvasItem, data: Dictionary, ids: Array, origin: Vector2, zoom: float, base_dir: String, adaptation: String = "", action: Dictionary = {}, time: float = 0, anchors: Dictionary = {}, root_mode: bool = false, opacity: float = 1.0, presentation_transform: Transform2D = Transform2D.IDENTITY) -> Array:
	var batch := draw_packets(data, ids, base_dir, adaptation, action, time, anchors, root_mode)
	for part: Dictionary in batch.parts:
		var points := PackedVector2Array()
		for point: Vector2 in part.polygon: points.append(origin + (presentation_transform * point) * zoom)
		canvas.draw_polygon(points, PackedColorArray([Color(1, 1, 1, opacity)]), part.uvs, part.texture)
	return batch.errors

static func draw_packets(data: Dictionary, ids: Array, base_dir: String, adaptation: String = "", action: Dictionary = {}, time: float = 0, anchors: Dictionary = {}, root_mode: bool = false) -> Dictionary:
	# Runtime identity snapshots are immutable until a publication/equipment change.
	# Editor documents have no stamp and continue to reflect every unsaved edit.
	var cacheable := data.has("_render_cache_key") and action.is_empty()
	var key := hash([data.get("_render_cache_key", ""), ids, base_dir, adaptation, anchors, root_mode])
	if cacheable and draw_cache.has(key): return draw_cache[key]
	compiled_draws += 1
	var errors := diagnostics(data, ids, adaptation, anchors, root_mode)
	var batch := {"parts": [], "errors": errors}
	if not errors.is_empty(): return batch
	for id: String in ordered(data, ids, adaptation):
		var asset := resolve(data, id, adaptation)
		if not bool(sample(action, id, time).get("visible", true)): continue
		var tex := texture(asset, base_dir)
		if tex == null: continue
		var inverse := world_transform(data, id, adaptation, action, time, anchors, root_mode).affine_inverse()
		var rect: Array = asset.rect
		for polygon: PackedVector2Array in regions(data, id, adaptation, action, time, base_dir, anchors, root_mode):
			var uvs := PackedVector2Array()
			for point: Vector2 in polygon:
				var uv := (inverse * point) / vector(asset.size) + vector(asset.pivot)
				if asset.get("flip_h", false): uv.x = 1.0 - uv.x
				uvs.append((vector(rect.slice(0, 2)) + uv * Vector2(rect[2], rect[3])) / tex.get_size())
			batch.parts.append({"polygon": polygon, "uvs": uvs, "texture": tex})
	if cacheable:
		if draw_cache.size() >= 128: draw_cache.erase(draw_cache.keys()[0])
		draw_cache[key] = batch
	return batch

static func hits(data: Dictionary, ids: Array, point: Vector2, base_dir: String, adaptation: String = "", action: Dictionary = {}, time: float = 0) -> Array:
	var signature := hash([data.assets, data.get("adaptations", {}), data.get("masks", {}), data.get("game", {}), ids, base_dir, adaptation, action, time])
	if signature != hit_signature:
		hit_signature = signature; hit_parts.clear()
		var order := ordered(data, ids, adaptation); order.reverse()
		for id: String in order:
			if not bool(sample(action, id, time).get("visible", true)): continue
			var asset := resolve(data, id, adaptation)
			if texture(asset, base_dir) == null: continue
			hit_parts.append({"id": id, "asset": asset, "regions": regions(data, id, adaptation, action, time, base_dir), "inverse": world_transform(data, id, adaptation, action, time).affine_inverse(), "image": images[source_path(asset, base_dir)]})
	return hit_prepared(point)

static func hit_prepared(point: Vector2) -> Array:
	var result := []
	for part: Dictionary in hit_parts:
		var asset: Dictionary = part.asset
		var inside := false
		for polygon: PackedVector2Array in part.regions:
			if Geometry2D.is_point_in_polygon(point, polygon): inside = true; break
		if not inside: continue
		var local: Vector2 = part.inverse * point
		var uv := local / vector(asset.size) + vector(asset.pivot)
		if asset.get("flip_h", false): uv.x = 1.0 - uv.x
		var rect: Array = asset.rect
		var pixel := Vector2i(Vector2(rect[0], rect[1]) + uv * Vector2(rect[2], rect[3]))
		var img: Image = part.image
		if pixel.x >= 0 and pixel.y >= 0 and pixel.x < img.get_width() and pixel.y < img.get_height() and img.get_pixelv(pixel).a > 0.1: result.append(part.id)
	return result
