extends SceneTree
const Document=preload("res://presentation/paperdoll_document.gd")
func _initialize() -> void:
	var input:="";var output:="";var starter:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):input=arg.trim_prefix("--input=")
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--new="):starter=arg.trim_prefix("--new=")
	var document=Document.new()
	var error:String=""
	if not starter.is_empty():error=document.save_project(starter)
	elif input.is_empty():error="Use --new=project.json or --input=project.json [--output=candidate.json]"
	else:
		error=document.load_project(input)
		if error.is_empty() and not output.is_empty():error=Document.write_json(output,document.composed())
	print(JSON.stringify({"ok":error.is_empty(),"error":error,"warnings":document.warnings(),"baseline_sha256":document.fingerprint,"changed_groups":document.edits.keys()}))
	quit(0 if error.is_empty() else 1)
