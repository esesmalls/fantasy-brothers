extends SceneTree
const Actor = preload("res://presentation/static_bust_actor.gd")
const Motion = preload("res://presentation/static_bust_motion.gd")
const Review = preload("res://presentation/static_bust_review.gd")
var passed := 0
var failed := 0

func check(value:bool,message:String) -> void:
	if value:passed+=1
	else:failed+=1;printerr(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var parts:Dictionary=Actor.parts()
	var original:=JSON.stringify(parts)
	for name in parts:
		var part:Dictionary=parts[name]
		check(ResourceLoader.exists(part.atlas),name+": source available")
		check(absf(float(part.size[0])/float(part.rect[2])-float(part.size[1])/float(part.rect[3]))<.00001,name+": no stretched geometry")
	for pair in [["head","wounded"],["padded","padded_damaged"],["mail","mail_damaged"]]:
		check(parts[pair[0]].size==parts[pair[1]].size and parts[pair[0]].position==parts[pair[1]].position,"state changes preserve anchor and scale")
	check(Actor.body_layers("bare",false,false)==["base","body","head"],"foundation body remains beneath clothes")
	check(Actor.body_layers("mail",false,false)==["base","body","linen","padded","mail","head"],"layer stack and face occlusion")
	check(Actor.body_layers("mail",true,false).has("head"),"armor damage does not injure face")
	check(Actor.body_layers("mail",false,true).has("mail"),"face injury does not damage armor")
	var plain:=["base","body","linen","padded","mail","face","scar","beard","hair","bandage"]
	check(Actor.headgear_layer_order(plain,{})==plain,"missing headgear does not change draw order")
	var stacked:=Actor.headgear_layer_order(plain,{
		"headgear_back":{},"headgear_main":{},"headgear_front":{}})
	check(stacked==["base","body","linen","padded","mail","headgear_back","face","scar","beard","hair","bandage","headgear_main","headgear_front"],
		"headgear back is behind the head and front follows the bandage")
	var legacy:=Actor.headgear_layer_order(["base","body","head"],{"headgear_back":{},"headgear_main":{}})
	check(legacy==["base","body","headgear_back","head","headgear_main"],"headgear back stays behind a legacy head")
	for weapon in ["sword","spear","bow"]:
		for outcome in ["hit","block","miss"]:
			var first:=Motion.sample(weapon,0,outcome)
			var last:=Motion.sample(weapon,1,outcome)
			check(first.position.distance_to(last.position)<.0001 and absf(first.angle-last.angle)<.0001,weapon+": closes to rest")
			var previous:=first
			var largest_position_step:=0.0
			var largest_angle_step:=0.0
			for i in range(1,10001):
				var state:=Motion.sample(weapon,float(i)/10000,outcome)
				largest_position_step=maxf(largest_position_step,state.position.distance_to(previous.position))
				largest_angle_step=maxf(largest_angle_step,absf(state.angle-previous.angle))
				previous=state
			check(largest_position_step<.1 and largest_angle_step<.01,weapon+": no hard pose jumps")
			for step in [.008,.016,.032,.12,1.0]:
				var events:Array[String]=[]
				var before:=0.0
				while before<1.0:
					var after:=minf(1.0,before+step)
					events.append_array(Motion.events_between(weapon,before,after,outcome))
					before=after
				check(events==["release",{"hit":"impact","block":"block","miss":"miss"}[outcome]],weapon+": exactly one release/result across speed/skip")
			check(Motion.events_between(weapon,.9,.2,outcome).is_empty(),"backward scrub silent")
		check(Motion.response(weapon,Motion.contact(weapon)-.01,"hit")==0,"no response before contact")
		check(Motion.response(weapon,.8,"miss")==0,"miss does not hit target")
		check(Actor.contact_point(weapon).x>60,"weapon reaches target outside own silhouette")
		if weapon=="bow":check(Motion.release(weapon)<Motion.contact(weapon),"arrow flight precedes impact")
	check(JSON.stringify(parts)==original,"sampling cannot mutate layer catalog")
	# The base drives one shared footprint, including every damage variant.
	var crop:=Actor.bust_window()
	var inside_base:=true
	for point in crop:inside_base=inside_base and absf(point.x)<float(parts.base.size[0])*.5
	check(inside_base,"clipped bodies and clothes remain inside fixed base width")
	check(not Geometry2D.is_point_in_polygon(Vector2(0,3),crop),"lower torso/cuffs are outside bust display")
	check(Geometry2D.is_point_in_polygon(Vector2(0,-20),crop),"chest above base remains visible")
	check(Motion.sample("spear",0).angle>1.2,"spear rests close to horizontal")
	check(Motion.sample("bow",0).position.x<25 and Motion.sample("bow",0).angle>.8,"rest bow lowered near chest")
	check(Motion.sample("bow",.4).angle<0,"bow raises to an upward aim")
	var bow_size:=Vector2(parts.bow.size[0],parts.bow.size[1])
	var bow_pivot:=Vector2(parts.bow.pivot[0],parts.bow.pivot[1])*bow_size
	var lowest_bow:float=-INF
	for i in range(1001):
		var bow_pose:=Motion.sample("bow",float(i)/1000)
		for corner:Vector2 in [Vector2.ZERO,Vector2(bow_size.x,0),bow_size,Vector2(0,bow_size.y)]:
			lowest_bow=maxf(lowest_bow,((corner-bow_pivot).rotated(bow_pose.angle)+bow_pose.position).y)
	check(lowest_bow<=0,"bow never passes below the ground while lifting/lowering")
	var launch:=Motion.nocked_arrow(Motion.release("bow"))
	for result in ["hit","block","miss"]:
		var first_arrow:=Motion.arrow_sample(Motion.release("bow"),result)
		var middle_arrow:=Motion.arrow_sample((Motion.release("bow")+Motion.contact("bow"))*.5,result)
		var last_arrow:=Motion.arrow_sample(Motion.contact("bow"),result)
		check(first_arrow.position.distance_to(launch.position)<.0001,"no nock-to-flight positional jump")
		check(absf(first_arrow.angle-launch.angle)<.0001,"arrow tangent matches release aim")
		check(middle_arrow.position.y<(first_arrow.position.y+last_arrow.position.y)*.5-1,"arrow follows elevated parabola")
		check(last_arrow.position.distance_to(Motion.ARROW_MISS if result=="miss" else Motion.ARROW_TARGET)<.0001,"arrow tip lands at declared result")
		check(first_arrow.angle<last_arrow.angle,"arrow turns along flight tangent")
	check(not Motion.arrow_sample(Motion.release("bow")-.001).visible,"no projectile before release")
	check(not Motion.arrow_sample(.95).visible,"projectile removed before next shot")
	var review:=Review.new();root.add_child(review)
	await process_frame
	review.paused=true;review.mode="motion";review.weapon="bow";review.progress=.3
	review._refresh();review._process(.5)
	check(review.progress==.3,"pause freezes playback")
	review.replay();check(review.progress==0 and not review.paused,"replay restores stable initial state")
	review.paused=true;review._slider.value=.61
	check(is_equal_approx(review.progress,.61) and review.paused,"scrubbing shows requested frame")
	review.queue_free();await process_frame
	print("Static bust checks: %d passed, %d failed"%[passed,failed])
	quit(1 if failed else 0)
