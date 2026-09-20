extends RefCounted
## Presentation-only weapon paths. The bust has no limb or body animation rig.
const ARROW_TARGET := Vector2(134,-27)
const ARROW_MISS := Vector2(118,-2)

static func duration(weapon: String) -> float:
	return {"sword":0.86, "spear":0.82, "bow":1.48}.get(weapon, 0.86)

static func contact(weapon: String) -> float:
	return 0.76 if weapon == "bow" else 0.42

static func release(weapon: String) -> float:
	return 0.44 if weapon == "bow" else 0.25

static func sample(weapon: String, progress: float, outcome: String = "hit") -> Dictionary:
	var p := clampf(progress, 0, 1)
	var frames: Array
	if weapon == "spear":
		frames = [[0.0,19.0,-26.0,1.30],[0.25,13.0,-25.0,1.35],
			[0.42,35.0,-31.0,PI/2],[0.53,35.0,-31.0,PI/2],
			[0.64,31.0,-31.0,PI/2],[1.0,19.0,-26.0,1.30]]
	elif weapon == "bow":
		frames = [[0.0,15.0,-12.0,1.45],[0.12,37.0,-19.0,1.30],
			[0.28,44.0,-42.0,.25],
			[0.34,40.0,-41.0,-.34],[0.44,40.0,-41.0,-.34],
			[0.49,42.0,-40.0,-.29],[0.62,40.0,-41.0,-.34],
			[0.80,44.0,-42.0,.25],[0.94,37.0,-19.0,1.30],
			[1.0,15.0,-12.0,1.45]]
	else:
		frames = [[0.0,8.0,-12.0,0.62],[0.25,26.0,-13.0,0.38],
			[0.42,22.0,-31.0,1.55],[0.53,22.0,-31.0,1.55],
			[0.64,20.0,-30.0,1.44],[1.0,8.0,-12.0,0.62]]
	if outcome == "miss" and weapon != "bow":
		frames[3][0] = 0.44
		frames[3][1] = float(frames[3][1]) + 3.0
		frames[3][3] = float(frames[3][3]) + 0.10
	for i in range(frames.size()-1):
		var a: Array = frames[i]
		var b: Array = frames[i+1]
		if p <= float(b[0]):
			var weight := smoothstep(float(a[0]), float(b[0]), p)
			return {"position":Vector2(lerpf(a[1],b[1],weight),lerpf(a[2],b[2],weight)),
				"angle":lerpf(a[3],b[3],weight)}
	return {"position":Vector2(frames[-1][1],frames[-1][2]),"angle":frames[-1][3]}

static func nocked_arrow(p:float) -> Dictionary:
	var bow:=sample("bow",p)
	var pull:=2.0*smoothstep(.14,.35,p)
	return {"position":bow.position+Vector2(12-pull,-2).rotated(bow.angle),
		"angle":bow.angle+PI/2,"opacity":smoothstep(.10,.19,p)}

## Fixed visual parabola: deterministic scrubbing, tip follows tangent. Rules
## still decide the result; the projectile never performs a gameplay collision.
static func arrow_sample(p:float,outcome:String="hit") -> Dictionary:
	var launch:=nocked_arrow(release("bow"))
	var start:Vector2=launch.position
	var finish:Vector2=ARROW_MISS if outcome=="miss" else ARROW_TARGET
	var span:=finish-start
	var t:=clampf(inverse_lerp(release("bow"),contact("bow"),p),0,1)
	var rise:float=(span.y-span.x*tan(launch.angle-PI/2))*.25
	var point:=start.lerp(finish,t)+Vector2(0,-4*rise*t*(1-t))
	var tangent:=Vector2(span.x,span.y-4*rise*(1-2*t))
	return {"position":point,"angle":tangent.angle()+PI/2,
		"visible":p>=release("bow") and p<.94,"flight":t,"rise":rise}

static func response(weapon: String, p: float, outcome: String) -> float:
	if outcome == "miss":return 0.0
	var at := contact(weapon)
	if p <= at:return 0.0
	if p < at+0.035:return smoothstep(at,at+0.035,p)
	return 1.0-smoothstep(at+0.10,1.0,p)

static func events_between(weapon: String, before: float, after: float, outcome: String) -> Array[String]:
	var events: Array[String] = []
	if after <= before:return events
	if before < release(weapon) and after >= release(weapon):events.append("release")
	if before < contact(weapon) and after >= contact(weapon):
		events.append("miss" if outcome == "miss" else ("block" if outcome == "block" else "impact"))
	return events

static func phase(weapon: String, p: float, outcome: String) -> String:
	if p <= 0 or p >= 1:return "就绪"
	if weapon=="bow" and p<release(weapon):
		return "下垂 · 提弓" if p<.16 else ("抬弓" if p<.34 else "瞄准")
	if p < release(weapon):return "预备"
	if p < contact(weapon):return "箭矢飞行" if weapon == "bow" else "出手"
	if outcome == "miss":return "落空 · 收回"
	if p < contact(weapon)+0.11:return "格挡" if outcome == "block" else "命中停顿"
	return "收回"
