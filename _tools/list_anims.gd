@tool
extends SceneTree

func _init() -> void:
	for path in [
		"res://assets/synty/PolygonDungeon/Prefabs/Character_Goblin_Male.tscn",
		"res://assets/synty/PolygonGoblinWarCamp/Prefabs/SM_Chr_Shaman_01.tscn",
		"res://assets/synty/Idles/Animations/_library.tres",
	]:
		print("=== ", path)
		if path.ends_with(".tres"):
			var lib: AnimationLibrary = load(path)
			if lib == null:
				print("  (failed)")
				continue
			for n in lib.get_animation_list():
				print("  ", n)
		else:
			var ps: PackedScene = load(path)
			if ps == null:
				print("  (failed)")
				continue
			var inst: Node = ps.instantiate()
			self.root.add_child(inst)
			var ap: AnimationPlayer = _find_ap(inst)
			if ap == null:
				print("  no AnimationPlayer")
				continue
			for libname in ap.get_animation_library_list():
				var lib: AnimationLibrary = ap.get_animation_library(libname)
				print("  lib '", libname, "':")
				for n in lib.get_animation_list():
					print("    ", n)
	quit()

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r: AnimationPlayer = _find_ap(c)
		if r: return r
	return null
