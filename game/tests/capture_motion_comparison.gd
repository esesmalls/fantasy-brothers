extends SceneTree
## Captures the actual renderer, not simulated screenshots or repainted artwork.
const Actor = preload("res://presentation/modular_actor.gd")

class Comparison extends Control:
	var clock := 0.0
	var action := "slash"
	var font := SystemFont.new()
	func _init() -> void:
		font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC"])
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1080, 410), Color("eee8d8"))
		var unit := {"id":"crew_1", "hp":38, "max_hp":38, "visual_loadout":{"weapon":"weapon_guard_sword", "armor":"armor_mail"}}
		var ids := ["a", "b", "c"]
		for index in range(3):
			var id: String = ids[index]
			var info: Dictionary = Actor.template_info(id)
			var duration := float(info.get("motion", {}).get(action, 0.6))
			var progress := clampf((clock - 0.30) / duration, 0, 1)
			var x := float(index * 360)
			draw_string(font, Vector2(x + 24, 42), str(info.get("name", id)), HORIZONTAL_ALIGNMENT_LEFT, 320, 22, Color("363d35"))
			draw_string(font, Vector2(x + 24, 76), ("挥击" if action == "slash" else "盾击") + " · %.2f 秒" % duration, HORIZONTAL_ALIGNMENT_LEFT, 320, 17, Color("62675b"))
			Actor.draw_actor(self, unit, Vector2(x + 134, 304), 2.8, {"template":id, "action":action, "progress":progress, "clock":0})
			Actor.draw_actor(self, unit, Vector2(x + 288, 376), 1.0, {"template":id, "action":action, "progress":progress, "clock":0})
			draw_string(font, Vector2(x + 24, 381), "右向样板 / 实机渲染", HORIZONTAL_ALIGNMENT_LEFT, 220, 15, Color("62675b"))

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.content_scale_size = Vector2i(1080, 410)
	root.size = Vector2i(1080, 410)
	var sheet := Comparison.new()
	root.add_child(sheet)
	var output := ProjectSettings.globalize_path("res://../builds/motion-review/comparison-frames")
	DirAccess.make_dir_recursive_absolute(output)
	for action in ["slash", "shield_bash"]:
		sheet.action = action
		for frame in range(36):
			sheet.clock = float(frame) / 24.0
			sheet.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(output.path_join("%s-%02d.png" % [action, frame]))
	print(output)
	quit()
