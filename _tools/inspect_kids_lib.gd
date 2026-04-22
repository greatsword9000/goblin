@tool
extends SceneTree
func _init() -> void:
	var lib: AnimationLibrary = load("res://assets/synty/PolygonKids/Animations/_library.tres")
	if lib == null: print("no lib"); quit(); return
	for name in lib.get_animation_list():
		var a: Animation = lib.get_animation(name)
		print("=== ", name, " tracks=", a.get_track_count())
		for i in range(min(6, a.get_track_count())):
			print("  ", a.track_get_path(i))
		if a.get_track_count() > 6:
			print("  ...")
		break
	quit()
