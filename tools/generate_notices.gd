extends SceneTree

func _initialize() -> void:
	var output: String = "Godot Engine notices\n\n" + Engine.get_license_text() + "\n\nTHIRD-PARTY COPYRIGHT\n"
	output += JSON.stringify(Engine.get_copyright_info(), "  ")
	output += "\n\nTHIRD-PARTY LICENSE TEXTS\n" + JSON.stringify(Engine.get_license_info(), "  ")
	var file: FileAccess = FileAccess.open("res://assets/godot-notices.txt", FileAccess.WRITE)
	if file == null:
		quit(1)
		return
	file.store_string(output)
	file.close()
	print("Engine notices generated from the pinned engine runtime.")
	quit(0)
