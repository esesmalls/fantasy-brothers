extends RefCounted
## Turns one resolved_once assembly package into draw parts.
## Positions in the package are final. This does not add draft edits or fit_delta.

static func read_package(path:String) -> Dictionary:
	if not FileAccess.file_exists(path):return {}
	var parsed:Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:return {}
	if parsed.get("transform_policy")!="resolved_once":return {}
	return parsed

static func runtime_part(record:Dictionary) -> Dictionary:
	var fitted:Dictionary=record.resolved_transform
	return {
		"atlas":record.file,
		"rect":record.source_rect_px,
		"size":fitted.size,
		"position":fitted.position,
		"pivot":fitted.pivot_normalized,
		"rotation":float(fitted.get("rotation_rad",0.0)),
		"flip_y":bool(record.get("flip_y",false)),
		"parent_binding":str(record.get("parent_binding","")),
		"layer_relation":str(record.get("layer_relation","")),
	}

## Copy the catalog used for drawing and overlay package layers.
## parent_binding stays on the record; draw order is applied later by the actor.
static func attach(catalog_data:Dictionary,package:Dictionary) -> Dictionary:
	var copy:=catalog_data.duplicate(true)
	var resolved:Dictionary={}
	var layers:Dictionary=package.get("runtime_layers",{})
	for layer_id in layers:
		resolved[str(layer_id)]=runtime_part(layers[layer_id])
	copy.resolved_parts=resolved
	copy.transform_policy="resolved_once"
	return copy

static func layer_ids(package:Dictionary) -> Array:
	var layers:Dictionary=package.get("runtime_layers",{})
	var ids:Array=[]
	for layer_id in layers:ids.append(str(layer_id))
	return ids
