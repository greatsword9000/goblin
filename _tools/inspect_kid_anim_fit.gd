@tool
extends SceneTree
func _init() -> void:
	var ps: PackedScene = load("res://assets/synty/PolygonKids/Models/SK_Chr_Kid_Goblin_01.fbx")
	var inst: Node = ps.instantiate()
	self.root.add_child(inst)
	print("=== bones ===")
	for sk in inst.find_children("*", "Skeleton3D", true, false):
		var s: Skeleton3D = sk
		print("Skeleton3D: ", s.name, " bones=", s.get_bone_count())
		for i in range(s.get_bone_count()):
			print("  ", i, ": ", s.get_bone_name(i))
	print("=== anims in kids lib ===")
	var lib: AnimationLibrary = load("res://assets/synty/PolygonKids/Animations/_library.tres")
	if lib: print(lib.get_animation_list())
	quit()
