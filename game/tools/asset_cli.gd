extends SceneTree
const Document = preload("res://presentation/asset_document.gd")
const Visuals = preload("res://presentation/asset_visuals.gd")
const Runtime = preload("res://presentation/asset_runtime.gd")
var args := {}
var doc: RefCounted
var result := {"ok": true, "errors": []}

func _initialize() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--") and arg.contains("="):
			var pair := arg.trim_prefix("--").split("=", true, 1); args[pair[0]] = pair[1]
	doc = Document.new()
	if args.has("input"):
		var error: String = doc.load_project(args.input)
		if not error.is_empty(): finish([error]); return
	var command: String = args.get("command", "list")
	match command:
		"list":
			result.assets = []
			for id in doc.data.assets: result.assets.append({"id": id, "name": doc.data.assets[id].name, "category": doc.data.assets[id].category})
			result.adaptations = doc.data.adaptations.keys(); result.actions = doc.data.actions.keys()
		"read": result.data = doc.asset(args.id, args.get("adaptation", "")) if args.has("id") else doc.data
		"validate": finish(doc.validate()); return
		"diff": result.changes = doc.differences()
		"new": pass
		"update":
			if not args.has("operations"): finish(["需要 --operations=JSON文件（操作数组）"]); return
			var operations: Variant = JSON.parse_string(FileAccess.get_file_as_string(args.operations))
			if not operations is Array: finish(["操作必须为数组"]); return
			var errors: Array = doc.transact(operations)
			if not errors.is_empty(): finish(errors); return
			result.changes = operations
		"import":
			if not args.has("image") or not args.has("id"): finish(["需要 --image=PNG --id=稳定ID"]); return
			var region: Variant = JSON.parse_string(args.get("rect", "[]"))
			if not region is Array: finish(["rect 必须为 [x,y,w,h]"]); return
			var error: String = doc.import_png(args.image, args.id, args.get("name", args.id), args.get("category", "未分类"), region)
			if not error.is_empty(): finish([error]); return
		"apply", "rollback":
			if args.has("expected-revision"): doc.expected_revision = args["expected-revision"]
			var error: String = doc.apply() if command == "apply" else doc.rollback()
			result.revision = doc.expected_revision
			finish([] if error.is_empty() else [error]); return
		"preview":
			if DisplayServer.get_name() == "headless": finish(["截图需使用有显示的 Godot 进程（不加 --headless）"]); return
			call_deferred("preview"); return
		_: finish(["未知命令：" + command]); return
	if args.has("output"):
		var error: String = doc.save_project(args.output)
		if not error.is_empty(): finish([error]); return
	elif command in ["new", "update", "import"]: finish(["编辑操作需要 --output=工程JSON"]); return
	finish([])

func finish(errors: Array) -> void:
	result.ok = errors.is_empty(); result.errors = errors
	print(JSON.stringify(result)); quit(0 if errors.is_empty() else 1)

func preview() -> void:
	if not args.has("output"): finish(["预览需要 --output=PNG"]); return
	root.min_size = Vector2i.ZERO; root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED; root.content_scale_size = Vector2i.ZERO; root.size = Vector2i(640, 640)
	var canvas := Node2D.new(); root.add_child(canvas)
	var ids: Array = Array(str(args.id).split(",")) if args.has("id") else doc.data.editor.scene
	var adaptation: String = args.get("adaptation", "")
	var root_mode: bool = args.get("root", "false") == "true"
	var errors := Visuals.diagnostics(doc.data, ids, adaptation, {}, root_mode)
	if not errors.is_empty(): finish(errors); return
	canvas.draw.connect(func():
		var action: Dictionary = doc.data.actions.get(args.get("action", ""), {})
		Visuals.draw(canvas, doc.data, ids, Vector2(320, 470), float(args.get("zoom", 4)), doc.base_dir, adaptation, action, float(args.get("time", 0)), {}, root_mode)
		if not root_mode: Runtime.draw_arrow(canvas, doc.data, ids, Vector2(320, 470), float(args.get("zoom", 4)), doc.base_dir, adaptation, action, float(args.get("time", 0))))
	canvas.queue_redraw()
	await process_frame
	await RenderingServer.frame_post_draw
	var error := root.get_texture().get_image().save_png(args.output)
	finish([] if error == OK else ["截图写入失败"])
