extends RefCounted
## Presentation-only weapon paths. The bust has no limb or body animation rig.
## Authored actions share this sampler with preview; they never write rules.
const ARROW_TARGET := Vector2(134,-27)
const ARROW_MISS := Vector2(118,-2)
const DEFAULT_ACTIONS := {
	"sword": {
		"id": "sword", "weapon": "sword", "duration": 0.86, "contact": 0.42, "release": 0.25,
		"keyframes": [
			{"id": "sword.rest", "t": 0.0, "x": 8.0, "y": -12.0, "angle": 0.62},
			{"id": "sword.windup", "t": 0.25, "x": 26.0, "y": -13.0, "angle": 0.38},
			{"id": "sword.contact", "t": 0.42, "x": 22.0, "y": -31.0, "angle": 1.55},
			{"id": "sword.hold", "t": 0.53, "x": 22.0, "y": -31.0, "angle": 1.55},
			{"id": "sword.recover", "t": 0.64, "x": 20.0, "y": -30.0, "angle": 1.44},
			{"id": "sword.return", "t": 1.0, "x": 8.0, "y": -12.0, "angle": 0.62}]},
	"spear": {
		"id": "spear", "weapon": "spear", "duration": 0.82, "contact": 0.42, "release": 0.25,
		"keyframes": [
			{"id": "spear.rest", "t": 0.0, "x": 19.0, "y": -26.0, "angle": 1.30},
			{"id": "spear.chamber", "t": 0.25, "x": 13.0, "y": -25.0, "angle": 1.35},
			{"id": "spear.contact", "t": 0.42, "x": 35.0, "y": -31.0, "angle": PI/2},
			{"id": "spear.hold", "t": 0.53, "x": 35.0, "y": -31.0, "angle": PI/2},
			{"id": "spear.recover", "t": 0.64, "x": 31.0, "y": -31.0, "angle": PI/2},
			{"id": "spear.return", "t": 1.0, "x": 19.0, "y": -26.0, "angle": 1.30}]},
	"bow": {
		"id": "bow", "weapon": "bow", "duration": 1.48, "contact": 0.76, "release": 0.44,
		"keyframes": [
			{"id": "bow.rest", "t": 0.0, "x": 15.0, "y": -12.0, "angle": 1.45},
			{"id": "bow.draw", "t": 0.12, "x": 37.0, "y": -19.0, "angle": 1.30},
			{"id": "bow.raise", "t": 0.28, "x": 44.0, "y": -42.0, "angle": .25},
			{"id": "bow.aim", "t": 0.34, "x": 40.0, "y": -41.0, "angle": -.34},
			{"id": "bow.release", "t": 0.44, "x": 40.0, "y": -41.0, "angle": -.34},
			{"id": "bow.recoil", "t": 0.49, "x": 42.0, "y": -40.0, "angle": -.29},
			{"id": "bow.hold", "t": 0.62, "x": 40.0, "y": -41.0, "angle": -.34},
			{"id": "bow.lower", "t": 0.80, "x": 44.0, "y": -42.0, "angle": .25},
			{"id": "bow.drop", "t": 0.94, "x": 37.0, "y": -19.0, "angle": 1.30},
			{"id": "bow.return", "t": 1.0, "x": 15.0, "y": -12.0, "angle": 1.45}]}}

static func default_action(weapon: String) -> Dictionary:
	return DEFAULT_ACTIONS.get(weapon, DEFAULT_ACTIONS.sword).duplicate(true)

static func spec(weapon: String, action: Dictionary = {}) -> Dictionary:
	if action is Dictionary and action.get("keyframes") is Array and not action["keyframes"].is_empty():
		return action
	return default_action(weapon)

static func duration(weapon: String, action: Dictionary = {}) -> float:
	return float(spec(weapon, action).get("duration", {"sword":0.86, "spear":0.82, "bow":1.48}.get(weapon, 0.86)))

static func contact(weapon: String, action: Dictionary = {}) -> float:
	return float(spec(weapon, action).get("contact", 0.76 if weapon == "bow" else 0.42))

static func release(weapon: String, action: Dictionary = {}) -> float:
	return float(spec(weapon, action).get("release", 0.44 if weapon == "bow" else 0.25))

static func _frames(weapon: String, action: Dictionary, outcome: String) -> Array:
	var frames: Array = []
	for key in spec(weapon, action)["keyframes"]:
		frames.append([float(key.t), float(key.x), float(key.y), float(key.angle)])
	if outcome == "miss" and weapon != "bow" and frames.size() > 3:
		frames[3][0] = 0.44
		frames[3][1] = float(frames[3][1]) + 3.0
		frames[3][3] = float(frames[3][3]) + 0.10
	return frames

static func sample(weapon: String, progress: float, outcome: String = "hit", action: Dictionary = {}) -> Dictionary:
	var p := clampf(progress, 0, 1)
	var frames := _frames(weapon, action, outcome)
	for i in range(frames.size()-1):
		var a: Array = frames[i]
		var b: Array = frames[i+1]
		if p <= float(b[0]):
			var weight := smoothstep(float(a[0]), float(b[0]), p)
			return {"position":Vector2(lerpf(a[1],b[1],weight),lerpf(a[2],b[2],weight)),
				"angle":lerpf(a[3],b[3],weight)}
	return {"position":Vector2(frames[-1][1],frames[-1][2]),"angle":frames[-1][3]}

static func nocked_arrow(p:float, action: Dictionary = {}) -> Dictionary:
	var bow:=sample("bow",p,"hit",action)
	var pull:=2.0*smoothstep(.14,.35,p)
	return {"position":bow.position+Vector2(12-pull,-2).rotated(bow.angle),
		"angle":bow.angle+PI/2,"opacity":smoothstep(.10,.19,p)}

## Fixed visual parabola: deterministic scrubbing, tip follows tangent. Rules
## still decide the result; the projectile never performs a gameplay collision.
static func arrow_sample(p:float,outcome:String="hit",launch_override:Dictionary={},action:Dictionary={}) -> Dictionary:
	var launch:=nocked_arrow(release("bow",action),action) if launch_override.is_empty() else launch_override
	var start:Vector2=launch.position
	var finish:Vector2=ARROW_MISS if outcome=="miss" else ARROW_TARGET
	var span:=finish-start
	var t:=clampf(inverse_lerp(release("bow",action),contact("bow",action),p),0,1)
	# Free editor rotations can aim vertically/backwards. Keep the departure
	# continuous without tan(90deg) or an instantaneous flip to the target.
	var direction:=Vector2.UP.rotated(launch.angle)
	if absf(direction.x)<.2 or span.x*direction.x<=0:
		var control:=start+direction*maxf(span.length()*.55,12)
		var curved:=start*(1-t)*(1-t)+control*2*(1-t)*t+finish*t*t
		var velocity:Vector2=(control-start)*2*(1-t)+(finish-control)*2*t
		return {"position":curved,"angle":velocity.angle()+PI/2,"visible":p>=release("bow",action) and p<.94,"flight":t,"rise":start.y-control.y}
	var rise:float=(span.y-span.x*tan(launch.angle-PI/2))*.25
	var point:=start.lerp(finish,t)+Vector2(0,-4*rise*t*(1-t))
	var tangent:=Vector2(span.x,span.y-4*rise*(1-2*t))
	return {"position":point,"angle":tangent.angle()+PI/2,
		"visible":p>=release("bow",action) and p<.94,"flight":t,"rise":rise}

static func response(weapon: String, p: float, outcome: String, action: Dictionary = {}) -> float:
	if outcome == "miss":return 0.0
	var at := contact(weapon, action)
	if p <= at:return 0.0
	if p < at+0.035:return smoothstep(at,at+0.035,p)
	return 1.0-smoothstep(at+0.10,1.0,p)

static func events_between(weapon: String, before: float, after: float, outcome: String, action: Dictionary = {}) -> Array[String]:
	var events: Array[String] = []
	if after <= before:return events
	if before < release(weapon, action) and after >= release(weapon, action):events.append("release")
	if before < contact(weapon, action) and after >= contact(weapon, action):
		events.append("miss" if outcome == "miss" else ("block" if outcome == "block" else "impact"))
	return events

static func phase(weapon: String, p: float, outcome: String, action: Dictionary = {}) -> String:
	if p <= 0 or p >= 1:return "就绪"
	if weapon=="bow" and p<release(weapon, action):
		return "下垂 · 提弓" if p<.16 else ("抬弓" if p<.34 else "瞄准")
	if p < release(weapon, action):return "预备"
	if p < contact(weapon, action):return "箭矢飞行" if weapon == "bow" else "出手"
	if outcome == "miss":return "落空 · 收回"
	if p < contact(weapon, action)+0.11:return "格挡" if outcome == "block" else "命中停顿"
	return "收回"

static func next_key_id(weapon: String, keyframes: Array) -> String:
	var used:={}
	for key in keyframes:used[str(key.get("id",""))]=true
	var index:=1
	while used.has("%s.key-%d"%[weapon,index]):index+=1
	return "%s.key-%d"%[weapon,index]

static func normalize_action(weapon: String, value: Variant) -> Dictionary:
	if not value is Dictionary:return {}
	if weapon not in DEFAULT_ACTIONS:return {}
	var frames_value:Variant=value.get("keyframes")
	if not frames_value is Array or frames_value.size()<2:return {}
	var keyframes:Array=[]
	var used:={}
	for item in frames_value:
		if not item is Dictionary:return {}
		for field in item:
			if field not in ["id","t","x","y","angle"]:return {}
		for number in [item.get("t"),item.get("x"),item.get("y"),item.get("angle")]:
			if not (number is int or number is float) or not is_finite(float(number)):return {}
		var t:=clampf(float(item.t),0,1)
		var key_id:=str(item.get("id",""))
		if key_id.is_empty() or used.has(key_id) or not key_id.begins_with(weapon+"."):
			key_id=next_key_id(weapon,keyframes)
		used[key_id]=true
		keyframes.append({"id":key_id,"t":snappedf(t,.001),"x":snappedf(float(item.x),.01),
			"y":snappedf(float(item.y),.01),"angle":snappedf(float(item.angle),.001)})
	keyframes.sort_custom(func(a,b):return float(a.t)<float(b.t) or (is_equal_approx(float(a.t),float(b.t)) and str(a.id)<str(b.id)))
	keyframes[0].t=0.0;keyframes[-1].t=1.0
	var duration:=float(value.get("duration",default_action(weapon).duration))
	var contact_at:=float(value.get("contact",default_action(weapon).contact))
	var release_at:=float(value.get("release",default_action(weapon).release))
	if not is_finite(duration) or duration<.2 or duration>4:return {}
	if not is_finite(contact_at) or not is_finite(release_at):return {}
	if release_at<0.02 or contact_at>0.98 or release_at>=contact_at:return {}
	var action_id:=str(value.get("id",weapon))
	if action_id.is_empty():action_id=weapon
	var result:={"id":action_id,"weapon":weapon,"duration":snappedf(duration,.01),
		"contact":snappedf(contact_at,.001),"release":snappedf(release_at,.001),"keyframes":keyframes}
	for field in value:
		if field not in ["id","weapon","duration","contact","release","keyframes"]:return {}
	if value.get("weapon",weapon)!=weapon:return {}
	return result

static func actions_equal(a: Dictionary, b: Dictionary) -> bool:
	return JSON.stringify(a)==JSON.stringify(b)
