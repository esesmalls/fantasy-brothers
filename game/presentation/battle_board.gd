extends Control
## Read-only battle presentation. Rules own positions, damage and resources.

const CharacterPortrait = preload("res://presentation/character_portrait.gd")
const ModularActor = preload("res://presentation/modular_actor.gd")
const WeaponFeedback = preload("res://presentation/weapon_feedback.gd")

signal cell_clicked(q: int, r: int)
signal cell_hovered(q: int, r: int)
signal unit_hovered(unit_id: String)

const CANVAS := Vector2(800.0, 560.0)
const HEX_RADIUS := 34.0
const ORIGIN := Vector2(66.0, 138.0)
const INK := Color("172225")
const GOLD := Color("b79b64")
const IVORY := Color("e5dbc0")
const ALLY := Color("548f91")
const ENEMY := Color("a85945")
const MOVE_HINT := Color("79b9a5")
const RANGE_HINT := Color("d2ab58")
const BLOCKED_HINT := Color("8c7780")
const TARGET_HINT := Color("d87970")
const IMPACT_HINT := Color("b895cf")

var _battle: Dictionary = {}
var _selected: String = ""
var _preview: Dictionary = {}
var _action_overlay: Dictionary = {}
var _hover := Vector2i(-1, -1)
var _hover_unit: String = ""
var _playfield_rect := Rect2()
var _font: SystemFont
var _scale: float = 1.0
var _offset := Vector2.ZERO
var _clock: float = 0.0
var _animation_speed: float = 1.0
var _event_queue: Array = []
var _event_remaining: float = 0.0
var _motions: Dictionary = {}
var _flashes: Dictionary = {}
var _floating: Array = []
var _rings: Array = []
var _old_positions: Dictionary = {}
var _before_units: Dictionary = {}
var _display_units: Dictionary = {}
var _pending_impacts: Array = []
var _motion_template := "b"
var _motion_review_actor := "crew_1"
var _weapon_feedback := WeaponFeedback.new()
var _audio_queue: Array = []
var _audio_result: Dictionary = {}
var _ambient_animated := false
var _ambient_elapsed := 0.0

func _init() -> void:
	add_child(_weapon_feedback)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	# The owning HUD owns window constraints; this board adapts to its supplied safe area.
	custom_minimum_size = Vector2.ZERO
	_font = SystemFont.new()
	_font.font_names = PackedStringArray(["Microsoft YaHei", "Microsoft YaHei UI", "Noto Sans CJK SC", "Arial"])
	resized.connect(queue_redraw)
	mouse_exited.connect(_clear_hover)
	set_process(true)

func set_battle(state: Dictionary) -> void:
	_old_positions.clear()
	_before_units.clear()
	for item in _battle.get("units", []):
		var unit: Dictionary = item
		_old_positions[str(unit.get("id", ""))] = _hex_center(int(unit.get("q", 0)), int(unit.get("r", 0)))
		_before_units[str(unit.get("id", ""))] = unit.duplicate(true)
	_battle = state.duplicate(true)
	_ambient_animated = false
	for cell: Dictionary in _battle.get("cells", {}).values():
		if cell.get("field", "") in ["fire", "steam"]: _ambient_animated = true; break
	queue_redraw()

func set_selected(unit_id: String) -> void:
	_selected = unit_id
	queue_redraw()

func set_preview(info: Dictionary) -> void:
	_preview = info.duplicate(true)
	queue_redraw()

## Reserves the part of this full-viewport Control where units and cells may appear.
## Coordinates are local to this Control; HUDs may occupy all space outside this rectangle.
func set_playfield_rect(rect: Rect2) -> void:
	_playfield_rect = rect
	queue_redraw()

## Screen-local anchor for tooltips and UI callouts. It uses the same transform as input.
func cell_screen_position(q: int, r: int) -> Vector2:
	_layout()
	return _offset + _hex_center(q, r) * _scale

## Receives a rule-calculated action map. This view never derives range or targets.
## {range_cells, blocked_cells, valid_targets, action_name, action_id}
func set_action_overlay(info: Dictionary) -> void:
	_action_overlay = info.duplicate(true)
	queue_redraw()

func set_animation_speed(speed: float) -> void:
	_animation_speed = clampf(speed, 0.0, 8.0)
	if _animation_speed <= 0.001:
		skip_animations()
	queue_redraw()

func set_motion_template(template_id: String) -> void:
	_motion_template = template_id if template_id in ["a", "b", "c"] else "b"
	queue_redraw()

func set_motion_review_actor(unit_id: String) -> void:
	_motion_review_actor = unit_id
	queue_redraw()

func has_pending_animation() -> bool:
	return _event_remaining > 0.0 or not _event_queue.is_empty() or not _pending_impacts.is_empty() or not _motions.is_empty() or not _flashes.is_empty() or not _floating.is_empty() or not _rings.is_empty()

func skip_animations() -> void:
	# Flush the view to the already-settled snapshot. Never call a rules method here.
	_weapon_feedback.stop_process_sounds()
	if not _audio_result.is_empty():
		_weapon_feedback.skip_to_result(str(_audio_result.weapon), str(_audio_result.outcome), str(_audio_result.material))
	_audio_result.clear()
	_audio_queue.clear()
	_event_queue.clear()
	_pending_impacts.clear()
	_motions.clear()
	_display_units.clear()
	_flashes.clear()
	_floating.clear()
	_rings.clear()
	_event_remaining = 0.0
	queue_redraw()

func get_motion_pose(unit_id: String) -> Dictionary:
	var unit := _unit_by_id(unit_id)
	var action := "idle"
	var progress := 0.0
	var direction := Vector2.RIGHT
	var outcome := "hit"
	var visible: Dictionary = _display_units.get(unit_id, unit)
	if int(visible.get("hp", 1)) <= 0:
		action = "death"
		progress = 1.0
	elif visible.get("statuses", {}).has("defending"):
		action = "defend"
		progress = 1.0
	if _motions.has(unit_id):
		var motion: Dictionary = _motions[unit_id]
		action = str(motion.get("action", motion.get("kind", "idle")))
		progress = clampf(float(motion.time) / float(motion.duration), 0.0, 1.0)
		direction = motion.get("direction", Vector2.RIGHT)
		outcome = str(motion.get("outcome", "hit"))
	var pose := {"template": _motion_template, "action": action, "progress": progress, "direction": direction, "clock": _clock, "outcome": outcome}
	if _motions.has(unit_id) and _motions[unit_id].has("target_position"):
		pose.target_position = _motions[unit_id].target_position
	return pose

static func motion_duration(template_id: String, action: String) -> float:
	var timings := {"a": [0.42, 0.40], "b": [0.68, 0.60], "c": [0.92, 0.78]}
	var configured: Dictionary = ModularActor.template_info(template_id).get("motion", {})
	if action in ["slash", "shield_bash"]:
		var fallback: float = float(timings.get(template_id, timings.a)[1 if action == "shield_bash" else 0])
		return maxf(0.05, float(configured.get(action, fallback)))
	return {"move": 0.40, "hit": 0.34, "death": 0.72, "defend": 0.40}.get(action, 1.6)

static func motion_contact(template_id: String) -> float:
	var configured: Dictionary = ModularActor.template_info(template_id).get("motion", {})
	return clampf(float(configured.get("contact", {"a": 0.42, "b": 0.50, "c": 0.52}.get(template_id, 0.42))), 0.05, 0.95)

func _action_for_event(event: Dictionary) -> String:
	for index in range(_battle.get("action_log", []).size() - 1, -1, -1):
		var logged: Dictionary = _battle.action_log[index]
		if int(logged.get("id", -1)) == int(event.get("root_action", -2)) and str(logged.get("actor", "")) == str(event.get("actor", "")):
			return str(logged.get("action", "attack"))
	return "attack" # Reactive strikes share another actor's root action.

func play_events(events: Array, speed: float = 1.0) -> void:
	if speed <= 0.001 or _animation_speed <= 0.001:
		var result := _audio_from_events(events)
		if not result.is_empty(): _audio_result = result
	if speed <= 0.001:
		skip_animations()
		return
	# Logical durations stay in one time domain. `_process` applies the sole speed
	# multiplier, avoiding 2x becoming 4x when a caller supplies a batch speed.
	if not is_equal_approx(speed, 1.0):
		set_animation_speed(speed)
	if _animation_speed <= 0.001:
		skip_animations()
		return
	var attack: Dictionary = {}
	for item in events:
		if not item is Dictionary:
			continue
		var event: Dictionary = item.duplicate(true)
		var target := str(event.get("target", ""))
		if str(event.get("type", "")) in ["hit", "death", "incapacitated"] and not _unit_by_id(target).is_empty():
			event["_after_unit"] = _unit_by_id(target).duplicate(true)
			if not _display_units.has(target) and _before_units.has(target):
				_display_units[target] = _before_units[target].duplicate(true)
		if not attack.is_empty() and str(event.get("type", "")) in ["hit", "miss", "death", "incapacitated", "status"] and int(event.get("root_action", -1)) == int(attack.get("root_action", -2)) and str(event.get("actor", "")) == str(attack.get("actor", "")):
			attack._feedback.append(event)
			continue
		attack = {}
		if str(event.get("type", "")) == "attack":
			event["_action"] = _action_for_event(event)
			event["_feedback"] = []
			attack = event
		_event_queue.append(event)
	# The queue affects presentation only, and can always be discarded safely.
	if _event_queue.size() > 96:
		_event_queue = _event_queue.slice(_event_queue.size() - 96)
	queue_redraw()

func _process(delta: float) -> void:
	var was_animating := has_pending_animation()
	_clock += delta
	_ambient_elapsed += delta
	var elapsed: float = delta * maxf(_animation_speed, 0.01)
	for index in range(_audio_queue.size() - 1, -1, -1):
		_audio_queue[index].remaining -= elapsed
		if float(_audio_queue[index].remaining) <= 0:
			var cue: Dictionary = _audio_queue[index]
			_audio_queue.remove_at(index)
			_weapon_feedback.play_cue(str(cue.weapon), str(cue.phase), str(cue.outcome), str(cue.material), _animation_speed)
			if cue.phase == "contact": _audio_result.clear()
	_event_remaining -= elapsed
	if _event_remaining <= 0.0 and not _event_queue.is_empty():
		_begin_event(_event_queue.pop_front())
	for index in range(_pending_impacts.size() - 1, -1, -1):
		_pending_impacts[index].remaining -= elapsed
		if float(_pending_impacts[index].remaining) <= 0.0:
			var impact: Dictionary = _pending_impacts[index]
			_pending_impacts.remove_at(index)
			for feedback: Dictionary in impact.events:
				_show_feedback(feedback)
	for unit_id in _motions.keys():
		var motion: Dictionary = _motions[unit_id]
		motion["time"] = float(motion["time"]) + elapsed
		if float(motion["time"]) >= float(motion["duration"]):
			_motions.erase(unit_id)
	for unit_id in _flashes.keys():
		_flashes[unit_id] = float(_flashes[unit_id]) - elapsed
		if float(_flashes[unit_id]) <= 0.0:
			_flashes.erase(unit_id)
	for collection in [_floating, _rings]:
		for index in range(collection.size() - 1, -1, -1):
			collection[index]["time"] = float(collection[index]["time"]) + elapsed
			if float(collection[index]["time"]) >= float(collection[index]["duration"]):
				collection.remove_at(index)
	if not has_pending_animation():
		_display_units.clear()
	# Static board/units do not require rebuilding polygons at the monitor rate.
	if was_animating or has_pending_animation() or (_ambient_animated and _ambient_elapsed >= 0.05):
		_ambient_elapsed = 0.0
		queue_redraw()

func _begin_event(event: Dictionary) -> void:
	var kind: String = str(event.get("type", ""))
	var actor: String = str(event.get("actor", ""))
	var target: String = str(event.get("target", ""))
	var point: Vector2 = _event_position(event)
	_event_remaining = 0.12
	if kind == "move":
		var origin: Vector2 = _old_positions.get(actor, point)
		if event.has("from_q") and event.has("from_r"):
			origin = _hex_center(int(event["from_q"]), int(event["from_r"]))
		_motions[actor] = {"from": origin, "to": point, "time": 0.0, "duration": 0.40, "kind": "move", "action": "move", "direction": origin.direction_to(point)}
		_event_remaining = 0.40
	elif kind == "attack":
		var unit: Dictionary = _unit_by_id(actor)
		if not unit.is_empty():
			var origin: Vector2 = _hex_center(int(unit.get("q", 0)), int(unit.get("r", 0)))
			var reach: Vector2 = origin.direction_to(point) * 12.0
			var action := "shield_bash" if str(event.get("_action", "")) == "shield_bash" else "slash"
			var duration := motion_duration(_motion_template, action)
			var authored: Dictionary = ModularActor.AssetRuntime.action_for_unit(unit, action) if ModularActor.supports(unit) or unit.has("visual_assets") else {}
			var contact := duration * motion_contact(_motion_template)
			if not authored.is_empty():
				duration = float(authored.duration)
				contact = duration * 0.42
				for marker: Dictionary in authored.get("events", []):
					if marker.id == "contact": contact = float(marker.time)
			_motions[actor] = {"from": origin, "to": origin + reach, "time": 0.0, "duration": duration, "kind": "attack", "action": action, "direction": origin.direction_to(point)}
			var victim: Dictionary = _before_units.get(target, _unit_by_id(target))
			_motions[actor].target_position = point + ModularActor.AssetRuntime.impact_offset(victim)
			for feedback: Dictionary in event.get("_feedback", []):
				if feedback.get("type", "") == "miss": _motions[actor].outcome = str(feedback.get("outcome", "miss"))
			_pending_impacts.append({"remaining": contact, "events": event.get("_feedback", [])})
			_queue_weapon_audio(event, unit, authored, duration, contact)
			_event_remaining = duration
	else:
		_show_feedback(event)

func _show_feedback(event: Dictionary) -> void:
	var kind := str(event.get("type", ""))
	var target := str(event.get("target", ""))
	var point := _event_position(event)
	if event.has("_after_unit"):
		_display_units[target] = event._after_unit.duplicate(true)
	if kind == "hit":
		_flashes[target] = 0.30
		_float_text(point, "−%s" % str(event.get("amount", "")), Color("f2ae85"))
		_feedback_motion(target, "hit", point)
	elif kind == "miss":
		var blocked: bool = event.get("outcome", "") == "block"
		_float_text(point, "格挡" if blocked else "闪避", IVORY)
		if blocked: _feedback_motion(target, "defend", point)
	elif kind in ["death", "incapacitated"]:
		_float_text(point, "倒下", Color("c9826d"))
		_feedback_motion(target, "death", point)
	elif kind == "fire" or kind == "water":
		var color: Color = Color("e79b52") if kind == "fire" else Color("8fcbcc")
		_rings.append({"point": point, "color": color, "time": 0.0, "duration": 0.55})
	elif kind in ["status", "morale", "escape", "recover"]:
		var message: String = str(event.get("text", "状态变化"))
		if message.length() > 10:
			message = message.substr(0, 10) + "…"
		_float_text(point, message, Color("d8c583"))
		if _unit_by_id(target).get("statuses", {}).has("defending"):
			_feedback_motion(target, "defend", point)

func _audio_from_events(events: Array) -> Dictionary:
	var result := {}
	for event: Dictionary in events:
		if event.get("type", "") == "attack":
			var unit := _unit_by_id(str(event.get("actor", "")))
			if unit.is_empty() or unit.get("kind", "") == "dog": continue
			result = {"weapon": "shield_bash" if _action_for_event(event) == "shield_bash" else str(unit.get("visual_loadout", {}).get("weapon", "")), "outcome": "hit", "material": "flesh"}
		elif not result.is_empty() and event.get("type", "") == "miss": result.outcome = str(event.get("outcome", "miss"))
		elif not result.is_empty() and event.get("type", "") == "hit":
			result.material = "armor" if int(event.get("armor_damage", 0)) > 0 else "flesh"
	return result

func _queue_weapon_audio(event: Dictionary, unit: Dictionary, action: Dictionary, duration: float, contact: float) -> void:
	if unit.get("kind", "") == "dog": return
	var events: Array = [event]
	events.append_array(event.get("_feedback", []))
	var result := _audio_from_events(events)
	if result.is_empty(): return
	_audio_result = result.duplicate(true)
	var template := WeaponFeedback.action_template(str(result.weapon))
	var release := duration * float(template.release)
	for marker: Dictionary in action.get("events", []):
		if marker.id == "release": release = float(marker.time)
	for phase: String in ["prepare", "release", "contact", "recover"]:
		var cue := result.duplicate(true)
		cue.phase = phase
		cue.remaining = contact if phase == "contact" else (release if phase == "release" else duration * float(template[phase]))
		_audio_queue.append(cue)
	if WeaponFeedback.weapon_type(str(result.weapon)) == "bow":
		for phase: String in ["aim", "flight"]:
			var cue := result.duplicate(true)
			cue.phase = phase
			cue.remaining = release * 0.35 if phase == "aim" else lerpf(release, contact, 0.3)
			_audio_queue.append(cue)

func _feedback_motion(target: String, action: String, point: Vector2) -> void:
	if _unit_by_id(target).is_empty():
		return
	_motions[target] = {"from": point, "to": point, "time": 0.0, "duration": motion_duration(_motion_template, action), "kind": "pose", "action": action, "direction": Vector2.RIGHT}

func _float_text(point: Vector2, message: String, color: Color) -> void:
	_floating.append({"point": point, "text": message, "color": color, "time": 0.0, "duration": 0.85})

func _event_position(event: Dictionary) -> Vector2:
	if event.has("q") and event.has("r"):
		return _hex_center(int(event["q"]), int(event["r"]))
	var unit: Dictionary = _unit_by_id(str(event.get("target", event.get("actor", ""))))
	return _hex_center(int(unit.get("q", 4)), int(unit.get("r", 3)))

func _unit_by_id(unit_id: String) -> Dictionary:
	for item in _battle.get("units", []):
		if str(item.get("id", "")) == unit_id:
			return item
	return {}

func _layout() -> void:
	var safe := _resolved_playfield_rect()
	# These actual grid extents include high weapon/helmet silhouettes, rather than the
	# retired title and footer bands. A future scenario may change its grid dimensions.
	var width: int = int(_battle.get("width", 9))
	var height: int = int(_battle.get("height", 7))
	var far_center := _hex_center(maxi(0, width - 1), maxi(0, height - 1))
	var map_bounds := Rect2(Vector2(ORIGIN.x - 41.0, ORIGIN.y - 96.0), Vector2(far_center.x - ORIGIN.x + 83.0, far_center.y - ORIGIN.y + 134.0))
	_scale = maxf(0.01, minf(safe.size.x / map_bounds.size.x, safe.size.y / map_bounds.size.y))
	var content_size := map_bounds.size * _scale
	_offset = safe.position + (safe.size - content_size) * 0.5 - map_bounds.position * _scale

func _resolved_playfield_rect() -> Rect2:
	if _playfield_rect.size.x > 8.0 and _playfield_rect.size.y > 8.0:
		return _playfield_rect.intersection(Rect2(Vector2.ZERO, size))
	# Existing callers that have not yet supplied a rect still receive a legible full view.
	return Rect2(Vector2(18.0, 18.0), (size - Vector2(36.0, 36.0)).max(Vector2(1.0, 1.0)))

func _gui_input(event: InputEvent) -> void:
	_layout()
	if event is InputEventMouseMotion:
		_update_hover(event.position)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var point: Vector2 = (event.position - _offset) / _scale
			var unit: Dictionary = _unit_hit_at(point)
			var cell: Vector2i = _point_to_hex(point)
			if not unit.is_empty():
				cell = Vector2i(int(unit.get("q", -1)), int(unit.get("r", -1)))
			else:
				cell = _prop_hit_cell(point, cell)
			if _valid_cell(cell):
				cell_clicked.emit(cell.x, cell.y)
				accept_event()

func _update_hover(screen_point: Vector2) -> void:
	var point: Vector2 = (screen_point - _offset) / _scale
	var unit: Dictionary = _unit_hit_at(point)
	var unit_id: String = str(unit.get("id", ""))
	var cell: Vector2i = _point_to_hex(point)
	if not unit.is_empty():
		cell = Vector2i(int(unit.get("q", -1)), int(unit.get("r", -1)))
	else:
		cell = _prop_hit_cell(point, cell)
	if unit_id != _hover_unit:
		_hover_unit = unit_id
		unit_hovered.emit(unit_id)
	if cell != _hover:
		_hover = cell
		cell_hovered.emit(cell.x, cell.y)
	queue_redraw()

func _clear_hover() -> void:
	_hover = Vector2i(-1, -1)
	if not _hover_unit.is_empty():
		_hover_unit = ""
		unit_hovered.emit("")
	cell_hovered.emit(-1, -1)
	queue_redraw()

## Hit units in reverse painter order, so a front silhouette owns its visible pixels.
## Use the visible head, cloak and base rather than a transparent bounding rectangle.
func _unit_hit_at(point: Vector2) -> Dictionary:
	var drawables: Array = []
	for unit in _battle.get("units", []):
		if int(unit.get("hp", 0)) > 0:
			drawables.append(unit)
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _unit_display_point(a).y < _unit_display_point(b).y)
	for index in range(drawables.size() - 1, -1, -1):
		var unit: Dictionary = drawables[index]
		var delta := point - _unit_display_point(unit)
		var kind: String = str(unit.get("kind", "guard"))
		if kind == "dog":
			if _dog_hit(delta):
				return unit
		elif ModularActor.supports(unit):
			if _humanoid_hit(delta) or _modular_arm_hit(delta):
				return unit
		elif _humanoid_hit(delta):
			return unit
	return {}

func _modular_arm_hit(delta: Vector2) -> bool:
	# The reviewed shield and complete upper arms extend beyond the old cloak.
	var shield := delta - Vector2(-28, -13)
	if shield.x * shield.x / 169.0 + shield.y * shield.y / 196.0 <= 1.0:
		return true
	var sword_arm := delta - Vector2(22, -21)
	return sword_arm.x * sword_arm.x / 81.0 + sword_arm.y * sword_arm.y / 169.0 <= 1.0

func _humanoid_hit(delta: Vector2) -> bool:
	# Helmet/head: centred on the actual polygon, not the spear or empty shoulder space.
	var head := delta - Vector2(0.0, -48.0)
	if head.x * head.x / 144.0 + head.y * head.y / 196.0 <= 1.0:
		return true
	# Cloak silhouette is a tapered, low body shape from the program-drawn humanoid.
	if delta.y >= -37.0 and delta.y <= -2.0:
		var progress := (delta.y + 37.0) / 35.0
		var half_width := lerpf(22.0, 18.0, progress)
		if absf(delta.x) <= half_width:
			return true
	# The base is the precise grid anchor and remains convenient at normal zoom.
	return delta.x * delta.x / 676.0 + delta.y * delta.y / 100.0 <= 1.0

func _dog_hit(delta: Vector2) -> bool:
	# Body, head and base follow the compact drawn dog silhouette.
	var body := delta - Vector2(-2.0, -20.0)
	if body.x * body.x / 576.0 + body.y * body.y / 169.0 <= 1.0:
		return true
	var head := delta - Vector2(22.0, -27.0)
	if head.x * head.x / 100.0 + head.y * head.y / 81.0 <= 1.0:
		return true
	return delta.x * delta.x / 676.0 + delta.y * delta.y / 100.0 <= 1.0

func _prop_hit_cell(point: Vector2, fallback: Vector2i) -> Vector2i:
	var props: Array = []
	for prop in _battle.get("props", []):
		if int(prop.get("hp", 0)) > 0:
			props.append(prop)
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _hex_center(int(a.get("q", 0)), int(a.get("r", 0))).y < _hex_center(int(b.get("q", 0)), int(b.get("r", 0))).y)
	for index in range(props.size() - 1, -1, -1):
		var prop: Dictionary = props[index]
		var delta := point - _hex_center(int(prop.get("q", 0)), int(prop.get("r", 0)))
		var kind: String = str(prop.get("kind", "cover"))
		var bounds := Rect2(Vector2(-30.0, -35.0), Vector2(60.0, 48.0))
		if kind == "oil" or kind == "water":
			bounds = Rect2(Vector2(-18.0, -28.0), Vector2(36.0, 38.0))
		elif kind == "grain":
			bounds = Rect2(Vector2(-30.0, -52.0), Vector2(60.0, 67.0))
		if bounds.has_point(delta):
			return Vector2i(int(prop.get("q", -1)), int(prop.get("r", -1)))
	return fallback

func _valid_cell(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < int(_battle.get("width", 9)) and cell.y >= 0 and cell.y < int(_battle.get("height", 7))

func _point_to_hex(point: Vector2) -> Vector2i:
	var local: Vector2 = point - ORIGIN
	var raw_r: float = local.y / (1.5 * HEX_RADIUS)
	var raw_q: float = local.x / (sqrt(3.0) * HEX_RADIUS) - raw_r * 0.5
	var raw_s: float = -raw_q - raw_r
	var q: int = roundi(raw_q)
	var r: int = roundi(raw_r)
	var s: int = roundi(raw_s)
	var dq: float = absf(float(q) - raw_q)
	var dr: float = absf(float(r) - raw_r)
	var ds: float = absf(float(s) - raw_s)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	var cell := Vector2i(q, r)
	return cell if _valid_cell(cell) else Vector2i(-1, -1)

func _hex_center(q: int, r: int) -> Vector2:
	return ORIGIN + Vector2(sqrt(3.0) * HEX_RADIUS * (float(q) + float(r) * 0.5), 1.5 * HEX_RADIUS * float(r))

func _hex_points(point: Vector2, radius: float = HEX_RADIUS - 1.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(6):
		var angle: float = deg_to_rad(30.0 + 60.0 * index)
		points.append(point + Vector2(cos(angle), sin(angle)) * radius)
	return points

func _draw() -> void:
	if _font == null:
		return
	_layout()
	_draw_backdrop()
	draw_set_transform(_offset, 0.0, Vector2(_scale, _scale))
	_draw_world_decor()
	for r in range(int(_battle.get("height", 7))):
		for q in range(int(_battle.get("width", 9))):
			_draw_cell(q, r)
	_draw_preview()
	_draw_action_overlay_ground()
	var drawables: Array = []
	for prop in _battle.get("props", []):
		drawables.append({"value": prop, "type": "prop", "y": _hex_center(int(prop.get("q", 0)), int(prop.get("r", 0))).y})
	for unit in _battle.get("units", []):
		drawables.append({"value": unit, "type": "unit", "y": _hex_center(int(unit.get("q", 0)), int(unit.get("r", 0))).y + 0.5})
	drawables.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	for item in drawables:
		if str(item["type"]) == "prop":
			_draw_prop(item["value"])
		else:
			_draw_unit(item["value"])
	_draw_effects()
	_draw_action_overlay_foreground()
	_draw_active_indicator()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_backdrop() -> void:
	# A restrained hand-drawn ground field fills the viewport. It is visual atmosphere only:
	# every tactical property remains represented by a real cell, prop, or rule overlay.
	draw_rect(Rect2(Vector2.ZERO, size), Color("17231e"))
	var safe := _resolved_playfield_rect()
	draw_rect(safe.grow(24.0), Color("273326"))
	for index in range(26):
		var x := fmod(float(index * 137), maxf(1.0, size.x + 120.0)) - 48.0
		var y := fmod(float(index * 79 + 31), maxf(1.0, size.y + 70.0)) - 28.0
		var tuft := Color("38462e") if index % 2 == 0 else Color("303d2b")
		draw_line(Vector2(x, y), Vector2(x + 12.0, y - 5.0), tuft, 1.2, true)
		draw_line(Vector2(x + 6.0, y + 3.0), Vector2(x + 17.0, y - 2.0), tuft, 1.0, true)
	# Worn earth tracks give a route through the scene without pretending to be a game rule.
	var path := PackedVector2Array([
		Vector2(safe.position.x - 8.0, safe.position.y + safe.size.y * 0.73),
		Vector2(safe.position.x + safe.size.x * 0.24, safe.position.y + safe.size.y * 0.57),
		Vector2(safe.position.x + safe.size.x * 0.57, safe.position.y + safe.size.y * 0.52),
		Vector2(safe.end.x + 12.0, safe.position.y + safe.size.y * 0.29),
	])
	draw_polyline(path, Color("665b3d"), 42.0, true)
	draw_polyline(path, Color("87774e"), 1.2, true)
	draw_rect(safe.grow(20.0), Color("857a58", 0.34), false, 1.0)

func _draw_world_decor() -> void:
	# Kept below cells: shrubs and route markings support the place without competing with input.
	for index in range(11):
		var point := Vector2(42.0 + float((index * 71) % 704), 74.0 + float((index * 103) % 385))
		_ellipse(point, Vector2(10.0 + float(index % 3) * 3.0, 5.0 + float(index % 2) * 2.0), Color("263528", 0.58))
		for blade in range(3):
			draw_line(point + Vector2(float(blade * 5 - 5), 2.0), point + Vector2(float(blade * 4 - 4), -7.0 - blade), Color("526143", 0.65), 1.0)

func _draw_cell(q: int, r: int) -> void:
	var point: Vector2 = _hex_center(q, r)
	var cells: Dictionary = _battle.get("cells", {})
	var cell: Dictionary = cells.get("%d,%d" % [q, r], {})
	var color := Color("34413a") if (q + r) % 2 == 0 else Color("303d36")
	if cell.get("terrain", "flat") == "mud": color = Color("554638")
	elif cell.get("terrain", "flat") == "rubble": color = Color("555950")
	if int(cell.get("elevation", 0)) > 0: color = color.lightened(0.14)
	if bool(cell.get("blocked", false)):
		color = Color("30312c")
	var surface: String = str(cell.get("surface", "dry"))
	if surface == "oil":
		color = Color("242928")
	elif surface == "water":
		color = Color("2b4b50")
	var polygon: PackedVector2Array = _hex_points(point)
	draw_colored_polygon(polygon, color)
	polygon.append(polygon[0])
	draw_polyline(polygon, Color("718067", 0.44), 0.85, true)
	if _battle.get("objective", {}).get("kind", "") == "evacuation" and q == int(_battle.get("width", 9)) - 1:
		draw_polyline(polygon, Color("84c9ac"), 2.5, true)
		_text("撤出 →", point + Vector2(-22, 15), 10, Color("a3ddc1"))
	if int(cell.get("elevation", 0)) > 0:
		draw_polyline(PackedVector2Array([point + Vector2(-28, 18), point + Vector2(0, 34), point + Vector2(28, 18)]), Color("a5a889"), 2.5, true)
		_text("↑1", point + Vector2(-11, 25), 10, Color("d0ceb4"))
	if surface == "oil":
		_ellipse(point, Vector2(22, 13), Color("171e20"))
		draw_arc(point + Vector2(-2, 0), 14, 0.2, 2.7, 14, Color("8e794b"), 1.4, true)
		draw_arc(point + Vector2(5, -3), 8, 3.2, 5.9, 12, Color("5e6755"), 1.0, true)
	elif surface == "water":
		for index in range(3):
			var start := point + Vector2(-19 + index * 3, -7 + index * 7)
			draw_line(start, start + Vector2(29, -3), Color("759f9e"), 1.0, true)
	else:
		var shift: float = float((q * 13 + r * 7) % 9)
		draw_line(point + Vector2(-19, 11), point + Vector2(-11 + shift, 9), Color("647057"), 1.0)
		draw_line(point + Vector2(10, -11), point + Vector2(15, -14), Color("4a5744"), 1.0)
	var field: String = str(cell.get("field", ""))
	if field == "fire":
		for index in range(3):
			var flame := point + Vector2(-13 + index * 12, 7 + (index % 2) * 4)
			var flicker: float = sin(_clock * 6.0 + q + r + index) * 2.0
			_polygon([Vector2(-7, 4), Vector2(-10, -5), Vector2(-3, -17 - flicker), Vector2(1, -7), Vector2(6, -24 + flicker), Vector2(11, -5), Vector2(7, 4)], flame, Color("c46638"), Color("793d29"))
			_polygon([Vector2(-3, 3), Vector2(-4, -6), Vector2(2, -15), Vector2(5, -3), Vector2(3, 3)], flame, Color("edb25e"))
	elif field == "steam":
		for index in range(4):
			var drift: float = sin(_clock * 1.3 + index + q) * 2.0
			_ellipse(point + Vector2(-15 + index * 10, -6 + drift), Vector2(12, 9 + (index % 2) * 4), Color(0.69, 0.79, 0.74, 0.30))
		draw_arc(point + Vector2(2, -5), 19, 3.6, 5.9, 16, Color("9faea3"), 1.0, true)
	if q == _hover.x and r == _hover.y:
		var hover_points: PackedVector2Array = _hex_points(point, HEX_RADIUS - 2.0)
		hover_points.append(hover_points[0])
		draw_polyline(hover_points, Color("d0bd86"), 2.0, true)

func _draw_preview() -> void:
	for cell in _preview.get("reachable", []):
		if cell is Dictionary and cell.has("q") and cell.has("r"):
			var center: Vector2 = _hex_center(int(cell.q), int(cell.r))
			draw_colored_polygon(_hex_points(center, HEX_RADIUS - 5.0), Color(MOVE_HINT, 0.13))
			draw_circle(center, 2.1, MOVE_HINT)
	var valid: bool = bool(_preview.get("ok", false))
	var path := PackedVector2Array()
	for cell in _preview.get("path", []):
		if cell is Dictionary and cell.has("q") and cell.has("r"):
			path.append(_hex_center(int(cell["q"]), int(cell["r"])))
	if path.size() > 1:
		draw_polyline(path, MOVE_HINT if valid else Color("bc7864"), 2.5, true)
	for point in path:
		draw_circle(point, 3.5, Color("ded7a9"))

func _draw_action_overlay_ground() -> void:
	# Warm diamond marks communicate nominal attack reach, even across empty cells.
	for cell in _action_overlay.get("range_cells", []):
		if _is_cell_dictionary(cell):
			var center := _hex_center(int(cell["q"]), int(cell["r"]))
			draw_colored_polygon(_hex_points(center, HEX_RADIUS - 7.0), Color(RANGE_HINT, 0.10))
			_draw_diamond(center, 8.0, RANGE_HINT, 1.4)
	# A cross-hatched slate cell is geometrically in range, but line of sight is blocked.
	for cell in _action_overlay.get("blocked_cells", []):
		if _is_cell_dictionary(cell):
			var center := _hex_center(int(cell["q"]), int(cell["r"]))
			draw_colored_polygon(_hex_points(center, HEX_RADIUS - 6.0), Color(BLOCKED_HINT, 0.20))
			draw_line(center + Vector2(-11, -9), center + Vector2(11, 9), BLOCKED_HINT, 2.0, true)
			draw_line(center + Vector2(-11, 9), center + Vector2(11, -9), BLOCKED_HINT, 2.0, true)
	# Area tools can affect most open cells. Keep their legal centres understated and below
	# pieces, then reserve the full reticle for the one cell the player is inspecting.
	if _is_area_cell_action():
		for cell in _action_overlay.get("valid_targets", []):
			if _is_cell_dictionary(cell):
				_draw_target_reticle(_hex_center(int(cell["q"]), int(cell["r"])), 6.0, Color(TARGET_HINT, 0.62))

func _draw_action_overlay_foreground() -> void:
	# The preview is supplied by Battle.preview for the hovered cell. Draw its result above
	# units so an area action remains visible when its centre contains a character or prop.
	if bool(_preview.get("ok", false)) and str(_action_overlay.get("action_id", "")) != "move":
		for cell in _preview.get("affected", []):
			if _is_cell_dictionary(cell):
				var polygon: PackedVector2Array = _hex_points(_hex_center(int(cell["q"]), int(cell["r"])), HEX_RADIUS - 4.0)
				draw_colored_polygon(polygon, Color(IMPACT_HINT, 0.16))
				polygon.append(polygon[0])
				draw_polyline(polygon, IMPACT_HINT, 1.6, true)
	# Unit and prop attacks retain strong foreground reticles. An area tool only promotes
	# the currently legal hover centre, leaving the board and friendly pieces readable.
	if _is_area_cell_action():
		if bool(_preview.get("ok", false)) and _preview.has("q") and _preview.has("r"):
			_draw_target_reticle(_hex_center(int(_preview["q"]), int(_preview["r"])))
	else:
		for cell in _action_overlay.get("valid_targets", []):
			if _is_cell_dictionary(cell):
				_draw_target_reticle(_hex_center(int(cell["q"]), int(cell["r"])))

func _is_area_cell_action() -> bool:
	return str(_action_overlay.get("action_id", "")) in ["oil", "fire", "water"]

func _is_cell_dictionary(value: Variant) -> bool:
	return value is Dictionary and value.has("q") and value.has("r")

func _draw_diamond(center: Vector2, radius: float, color: Color, width: float = 1.0) -> void:
	var points := PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0), center + Vector2(0, -radius)])
	draw_polyline(points, color, width, true)

func _draw_target_reticle(center: Vector2, radius: float = 17.0, color: Color = TARGET_HINT) -> void:
	draw_arc(center, radius, 0.0, TAU, 20, color, maxf(1.0, radius * 0.12), true)
	for direction in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		draw_line(center + direction * radius * 1.24, center + direction * radius * 0.76, color, maxf(1.2, radius * 0.15), true)
	draw_circle(center, maxf(1.4, radius * 0.19), color)

func _draw_prop(prop: Dictionary) -> void:
	var point: Vector2 = _hex_center(int(prop.get("q", 0)), int(prop.get("r", 0)))
	var kind: String = str(prop.get("kind", "cover"))
	if int(prop.get("hp", 0)) <= 0:
		for index in range(4):
			draw_line(point + Vector2(-17 + index * 9, -3 + (index % 2) * 7), point + Vector2(-7 + index * 7, 3 + (index % 2) * 4), Color("827257"), 2.0, true)
		return
	_ellipse(point + Vector2(2, 6), Vector2(23, 8), Color(0.0, 0.0, 0.0, 0.30))
	if kind == "oil" or kind == "water":
		_polygon([Vector2(-13, -24), Vector2(13, -24), Vector2(16, -3), Vector2(11, 7), Vector2(-11, 7), Vector2(-16, -3)], point, Color("816247"), Color("282826"))
		for x in [-8, 0, 8]:
			draw_line(point + Vector2(x, -21), point + Vector2(x, 4), Color("4b4032"), 1.0, true)
		_ellipse(point + Vector2(0, -23), Vector2(13, 5), Color("b09a69"))
		_ellipse(point + Vector2(0, -24), Vector2(9, 3), Color("20282a") if kind == "oil" else Color("71a4a5"))
		draw_line(point + Vector2(-14, -15), point + Vector2(14, -15), Color("aaad9b"), 3.0, true)
		draw_line(point + Vector2(-14, 0), point + Vector2(14, 0), Color("aaad9b"), 3.0, true)
		_polygon([Vector2(0, -14), Vector2(-4, -7), Vector2(0, -4), Vector2(4, -7)], point, Color("e0c981") if kind == "oil" else Color("b6e0dc"))
	elif kind == "grain":
		_polygon([Vector2(-22, -30), Vector2(22, -30), Vector2(22, 8), Vector2(-22, 8)], point, Color("a08b66"), Color("303229"))
		for x in [-16, -5, 6, 17]:
			draw_line(point + Vector2(x, -27), point + Vector2(x, 5), Color("6c644c"), 2.0)
		_polygon([Vector2(-27, -28), Vector2(0, -49), Vector2(28, -28)], point, Color("776443"), Color("30332c"))
		for index in range(4):
			draw_line(point + Vector2(-19 + index * 6, -28), point + Vector2(0 + index * 5, -41 + index * 4), Color("b19b68"), 1.0)
		draw_rect(Rect2(point + Vector2(-6, -12), Vector2(13, 20)), Color("323c32"))
		_ellipse(point + Vector2(15, 5), Vector2(6, 9), Color("c4ae78"))
		draw_line(point + Vector2(11, -2), point + Vector2(18, -2), Color("695c40"), 1.5)
		_text("粮仓", point + Vector2(-18, -55), 12, IVORY)
	else:
		for index in range(4):
			var base := point + Vector2(-19 + index * 12, 0)
			_polygon([Vector2(-4, 5), Vector2(-4, -23), Vector2(0, -32), Vector2(4, -24), Vector2(4, 5)], base, Color("9e8058"), Color("3c3c30"))
			draw_line(base + Vector2(0, -21), base + Vector2(0, 3), Color("d0b082"), 1.0)
		draw_line(point + Vector2(-25, -9), point + Vector2(25, -18), Color("62573b"), 5.0, true)
	var ratio: float = clampf(float(prop.get("hp", 0)) / maxf(1.0, float(prop.get("max_hp", 1))), 0.0, 1.0)
	draw_rect(Rect2(point + Vector2(-17, 12), Vector2(34, 3)), Color("152020"))
	draw_rect(Rect2(point + Vector2(-17, 12), Vector2(34 * ratio, 3)), Color("af9662"))

func _draw_unit(unit: Dictionary) -> void:
	if bool(unit.get("escaped", false)): return
	var unit_id: String = str(unit.get("id", ""))
	var visible: Dictionary = _display_units.get(unit_id, unit)
	var point: Vector2 = _unit_display_point(visible)
	var selected: bool = unit_id == _selected
	var allied: bool = str(visible.get("team", "enemy")) == "player"
	var accent: Color = ALLY if allied else ENEMY
	if _flashes.has(unit_id):
		point.x += sin(_clock * 95.0) * 2.5
		accent = accent.lerp(IVORY, 0.45)
	var modular: bool = ModularActor.supports(visible)
	if int(visible.get("hp", 0)) <= 0:
		if modular and ModularActor.draw_actor(self, visible, point, 1.0, get_motion_pose(unit_id)):
			return
		_ellipse(point, Vector2(16, 6), Color("272b27"))
		draw_line(point + Vector2(-8, -7), point + Vector2(8, 5), Color("a28b69"), 3.0)
		draw_line(point + Vector2(8, -7), point + Vector2(-8, 5), Color("a28b69"), 3.0)
		return
	if modular:
		if selected:
			_ellipse(point + Vector2(0, 2), Vector2(26, 9), Color("a1d0c5", 0.25))
		modular = ModularActor.draw_actor(self, visible, point, 1.0, get_motion_pose(unit_id))
	if not modular:
		_ellipse(point + Vector2(2, 5), Vector2(25, 10), Color(0.0, 0.0, 0.0, 0.40))
		if selected:
			_ellipse(point + Vector2(0, 0), Vector2(27, 11), Color("a1d0c5"))
		_ellipse(point + Vector2(0, 2), Vector2(22, 9), Color("131d21"))
		_ellipse(point, Vector2(22, 8), accent.darkened(0.23))
		_ellipse(point + Vector2(0, -2), Vector2(19, 6), Color("6b7465"))
		var body: Vector2 = point + Vector2(0, -4)
		# Shared layers read only this battle snapshot. Effects and motion have already
		# adjusted `body`; equipment or injury drawing never changes combat results.
		CharacterPortrait.draw_character(self, visible, body, 1.0, allied, accent)
	_draw_bars(visible, point)
	if (not selected) and _hover.x == int(visible.get("q", -2)) and _hover.y == int(visible.get("r", -2)):
		var name_text: String = str(visible.get("name", "佣兵"))
		_text(name_text, point + Vector2(-49, -64), 12, IVORY, 98, HORIZONTAL_ALIGNMENT_CENTER)
	var statuses: Dictionary = visible.get("statuses", {})
	var status_index := 0
	for status in statuses:
		_draw_status_symbol(str(status), point + Vector2(27.0 + status_index * 13.0, -28.0))
		status_index += 1
	if _hover.x == int(visible.get("q", -2)) and _hover.y == int(visible.get("r", -2)):
		var cell: Dictionary = _battle.get("cells", {}).get("%d,%d" % [int(visible.get("q", 0)), int(visible.get("r", 0))], {})
		if str(cell.get("field", "")) == "fire":
			_text("脚下是火！", point + Vector2(-47, -77), 12, Color("f0b36b"), 94, HORIZONTAL_ALIGNMENT_CENTER)
		elif statuses.has("defending"):
			_text("守住阵线", point + Vector2(-47, -77), 12, Color("c8d4b0"), 94, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_status_symbol(status: String, center: Vector2) -> void:
	draw_circle(center, 7.2, Color("18211e", 0.92))
	if status == "defending":
		# A small shield says the unit is holding, without inventing a morale state.
		_polygon([Vector2(-4, -5), Vector2(4, -5), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)], center, Color("99b7a6"), IVORY)
		draw_line(center + Vector2(0, -4), center + Vector2(0, 3), Color("34585b"), 1.0)
	elif status == "exposed":
		# A split plate mirrors the actual `破绽` rule status.
		_polygon([Vector2(-4, -5), Vector2(4, -5), Vector2(5, 0), Vector2(0, 6), Vector2(-5, 0)], center, Color("bb806a"), Color("e6c289"))
		draw_line(center + Vector2(-1, -5), center + Vector2(1, -1), INK, 1.4)
		draw_line(center + Vector2(1, -1), center + Vector2(-1, 3), INK, 1.4)
	elif status == "marked":
		draw_arc(center, 4.0, 0.0, TAU, 12, Color("e1be6f"), 1.2, true)
		draw_circle(center, 1.6, Color("e1be6f"))
		draw_line(center + Vector2(-6, 0), center + Vector2(-3, 0), Color("e1be6f"), 1.0)
		draw_line(center + Vector2(3, 0), center + Vector2(6, 0), Color("e1be6f"), 1.0)
	elif status == "pinned":
		draw_arc(center + Vector2(-2, 0), 3.4, -1.4, 1.4, 8, Color("a8b9b5"), 1.4, true)
		draw_arc(center + Vector2(2, 0), 3.4, 1.7, 4.55, 8, Color("a8b9b5"), 1.4, true)
		draw_line(center + Vector2(-1, 0), center + Vector2(1, 0), Color("a8b9b5"), 1.4)
	else:
		_draw_diamond(center, 4.2, Color("d5bb77"), 1.3)

func _unit_display_point(unit: Dictionary) -> Vector2:
	var unit_id: String = str(unit.get("id", ""))
	var point: Vector2 = _hex_center(int(unit.get("q", 0)), int(unit.get("r", 0)))
	if not _motions.has(unit_id):
		return point
	var motion: Dictionary = _motions[unit_id]
	var progress: float = clampf(float(motion["time"]) / float(motion["duration"]), 0.0, 1.0)
	if str(motion["kind"]) == "attack":
		return (motion["from"] as Vector2).lerp(motion["to"], sin(progress * PI))
	point = (motion["from"] as Vector2).lerp(motion["to"], progress * progress * (3.0 - 2.0 * progress))
	point.y -= sin(progress * PI) * 5.0
	return point

func _draw_active_indicator() -> void:
	if not str(_battle.get("outcome", "")).is_empty():
		return
	var unit: Dictionary = _unit_by_id(_active_id())
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return
	var point := _unit_display_point(unit)
	# Deliberately drawn after depth-sorted pieces: a foreground unit cannot hide whose turn it is.
	if not ModularActor.supports(unit):
		_ellipse_outline(point + Vector2(0, 2), Vector2(33, 13), Color(GOLD, 0.86), 2.2)
		_ellipse_outline(point + Vector2(0, 2), Vector2(27, 10), Color(IVORY, 0.90), 1.2)
	for offset_x in [-31.0, 31.0]:
		_draw_diamond(point + Vector2(offset_x, 2), 4.0, GOLD, 1.5)
	var tag_top := clampf(point.y - 96.0, 63.0, 470.0)
	var arrow_origin := Vector2(point.x, tag_top + 22.0)
	_polygon([Vector2(-6, 0), Vector2(6, 0), Vector2(0, 10)], arrow_origin, GOLD, INK)
	draw_rect(Rect2(Vector2(point.x - 60, tag_top), Vector2(120, 19)), Color("162022"))
	draw_rect(Rect2(Vector2(point.x - 60, tag_top), Vector2(120, 19)), GOLD, false, 1.2)
	var role_names := {"guard": "盾卫", "spear": "长枪", "archer": "弓手", "hunter": "猎人", "skirmisher": "游击", "raider": "劫掠", "dog": "战犬"}
	var label := "%s · %s" % [str(unit.get("name", "佣兵")), str(role_names.get(str(unit.get("kind", "")), "佣兵"))]
	if label.length() > 13:
		label = label.substr(0, 12) + "…"
	_text(label, Vector2(point.x - 56, tag_top + 14), 12, IVORY, 112, HORIZONTAL_ALIGNMENT_CENTER)

func _ellipse_outline(center: Vector2, radius: Vector2, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index in range(25):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_polyline(points, color, width, true)

func _draw_bars(unit: Dictionary, point: Vector2) -> void:
	var hp: float = clampf(float(unit.get("hp", 0)) / maxf(1.0, float(unit.get("max_hp", 1))), 0.0, 1.0)
	var armor: float = clampf(float(unit.get("armor", 0)) / maxf(1.0, float(unit.get("max_armor", 1))), 0.0, 1.0)
	draw_rect(Rect2(point + Vector2(-20, 11), Vector2(40, 5)), Color("142020"))
	draw_rect(Rect2(point + Vector2(-19, 12), Vector2(38 * hp, 3)), Color("a8b889") if hp > 0.35 else Color("cf8061"))
	draw_rect(Rect2(point + Vector2(-20, 17), Vector2(40, 4)), Color("142020"))
	draw_rect(Rect2(point + Vector2(-19, 18), Vector2(38 * armor, 2)), Color("98b8bc"))
	if str(unit.get("id", "")) == _selected:
		for index in range(int(unit.get("max_ap", 6))):
			draw_circle(point + Vector2(-15 + index * 6, 26), 1.8, GOLD if index < int(unit.get("ap", 0)) else Color("454e43"))

func _active_id() -> String:
	var order: Array = _battle.get("order", [])
	var index: int = int(_battle.get("turn_index", 0))
	if index >= 0 and index < order.size():
		return str(order[index])
	return ""

func _draw_effects() -> void:
	for effect in _rings:
		var ratio: float = float(effect["time"]) / float(effect["duration"])
		var color: Color = effect["color"]
		color.a = 1.0 - ratio
		draw_arc(effect["point"], 8.0 + ratio * 33.0, 0.0, TAU, 32, color, 2.0, true)
	for effect in _floating:
		var ratio: float = float(effect["time"]) / float(effect["duration"])
		var point: Vector2 = effect["point"]
		point += Vector2(-70, -49 - ratio * 32.0)
		var color: Color = effect["color"]
		color.a = 1.0 - ratio * ratio
		_text(str(effect["text"]), point + Vector2(1, 1), 16, Color(0.05, 0.08, 0.08, color.a), 140, HORIZONTAL_ALIGNMENT_CENTER)
		_text(str(effect["text"]), point, 16, color, 140, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_legend() -> void:
	var items: Array = [["油", Color("b39a62")], ["水", Color("86b9bd")], ["火", Color("d88a51")], ["汽", Color("b2c8ba")]]
	for index in range(items.size()):
		var point := Vector2(37 + index * 43, 519)
		_polygon([Vector2(0, -7), Vector2(5, -2), Vector2(0, 3), Vector2(-5, -2)], point, items[index][1])
		_text(str(items[index][0]), point + Vector2(9, 3), 12, IVORY)
	_text("上条生命 · 下条护甲 · 双环/箭头=当前回合", Vector2(220, 522), 11, Color("a6ae98"))
	draw_circle(Vector2(37, 541), 2.2, MOVE_HINT)
	_text("移动", Vector2(44, 545), 11, IVORY)
	_draw_diamond(Vector2(92, 540), 5.0, RANGE_HINT, 1.2)
	_text("射程", Vector2(101, 545), 11, IVORY)
	draw_line(Vector2(151, 535), Vector2(161, 545), BLOCKED_HINT, 1.8, true)
	draw_line(Vector2(161, 535), Vector2(151, 545), BLOCKED_HINT, 1.8, true)
	_text("遮挡", Vector2(166, 545), 11, IVORY)
	_draw_target_reticle(Vector2(218, 540), 5.5)
	_text("合法", Vector2(242, 545), 11, IVORY)
	_text("▱ 波及", Vector2(291, 545), 11, IMPACT_HINT)
	_text(str(_action_overlay.get("action_name", "")), Vector2(558, 545), 11, RANGE_HINT, 210, HORIZONTAL_ALIGNMENT_RIGHT)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in range(24):
		var angle: float = TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func _polygon(vertices: Array, origin: Vector2, fill: Color, outline: Color = Color.TRANSPARENT) -> void:
	var points := PackedVector2Array()
	for vertex in vertices:
		points.append(origin + vertex)
	draw_colored_polygon(points, fill)
	if outline.a > 0.0:
		points.append(points[0])
		draw_polyline(points, outline, 1.3, true)

func _text(value: String, point: Vector2, font_size: int, color: Color, width: float = -1.0, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	draw_string(_font, point, value, alignment, width, font_size, color)
