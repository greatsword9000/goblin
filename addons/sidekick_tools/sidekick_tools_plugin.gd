@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_tool_menu_item("Sidekick: Bake Thumbnails (Missing)", _bake_missing)
	add_tool_menu_item("Sidekick: Bake Thumbnails (All)", _bake_all)
	add_tool_menu_item("Sidekick: Open Customizer", _open_customizer)


func _exit_tree() -> void:
	remove_tool_menu_item("Sidekick: Bake Thumbnails (Missing)")
	remove_tool_menu_item("Sidekick: Bake Thumbnails (All)")
	remove_tool_menu_item("Sidekick: Open Customizer")


func _bake_missing() -> void:
	_run_bake(false)


func _bake_all() -> void:
	_run_bake(true)


func _open_customizer() -> void:
	EditorInterface.play_custom_scene("res://ui/character_customizer/character_customizer.tscn")


func _run_bake(force: bool) -> void:
	var script: GDScript = load("res://addons/sidekick_tools/thumbnail_baker_core.gd")
	if script == null:
		push_error("[Sidekick] baker script failed to load")
		return
	var baker: Node = script.new()
	add_child(baker)
	var host: Node = EditorInterface.get_edited_scene_root()
	if host == null:
		host = self
	await baker.run(host, force)
	baker.queue_free()
