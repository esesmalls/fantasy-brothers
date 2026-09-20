extends SceneTree
const Actor = preload("res://presentation/modular_actor.gd")

class Sheet extends Control:
	var template_id := "b"
	func _draw() -> void:
		var actions := ["idle", "slash", "slash", "shield_bash", "defend", "hit"]
		var contact := float(Actor.template_info(template_id).get("motion", {}).get("contact", .5))
		var phases := [0.0, contact - .14, contact, contact, 1.0, 0.4]
		# Paint all backgrounds first so a neighboring cell cannot erase a sword tip.
		draw_rect(Rect2(0, 0, 1320, 370), Color("eee6d4"))
		draw_rect(Rect2(0, 370, 1320, 370), Color("263c32"))
		for row in range(2):
			for column in range(6):
				var cell := Rect2(column * 220, row * 370, 220, 370)
				var unit := {"id":"crew_1", "hp":38, "max_hp":38, "visual_loadout":{"weapon":"weapon_guard_sword", "armor":"armor_padded" if row == 0 else "armor_mail"}}
				Actor.draw_actor(self, unit, cell.position + Vector2(105, 260), 2.3, {"template":template_id,"action":actions[column],"progress":phases[column],"show_anchors":false})
				draw_string(ThemeDB.fallback_font, cell.position + Vector2(10, 320), actions[column] + " %.2f" % phases[column], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("252a25") if row == 0 else Color.WHITE)
				Actor.draw_actor(self, unit, cell.position + Vector2(174, 356), .7, {"template":template_id,"action":actions[column],"progress":phases[column]})

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	root.content_scale_size = Vector2i(1320,740)
	root.size = Vector2i(1320,740)
	var sheet := Sheet.new()
	sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--template="):
			sheet.template_id = argument.get_slice("=", 1)
	root.add_child(sheet)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var output := ProjectSettings.globalize_path("res://../builds/motion-review/rig-" + sheet.template_id + ".png")
	root.get_texture().get_image().save_png(output)
	print(output)
	quit()
