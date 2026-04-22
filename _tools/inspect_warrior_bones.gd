@tool
extends SceneTree
func _init() -> void:
	var ps: PackedScene = load("res://assets/synty/PolygonGoblinWarCamp/Prefabs/SM_Chr_Warrior_Male_01.tscn")
	var inst: Node = ps.instantiate()
	self.root.add_child(inst)
	for s in inst.find_children("*", "Skeleton3D", true, false):
		var sk: Skeleton3D = s
		print("Skeleton3D bones=", sk.get_bone_count())
		for i in range(min(20, sk.get_bone_count())):
			print("  ", i, ": ", sk.get_bone_name(i))
	quit()
