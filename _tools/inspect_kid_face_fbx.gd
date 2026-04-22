@tool
extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://assets/synty/PolygonKids/Models/SM_Chr_Kid_Face_01.fbx")
	var inst: Node = ps.instantiate()
	self.root.add_child(inst)
	print("=== Tree ===")
	_dump(inst, 0)
	for vi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = vi
		var aabb: AABB = m.global_transform * m.get_aabb()
		print("Mesh ", m.name, " surfaces=", m.mesh.get_surface_count() if m.mesh else 0, " aabb=", aabb)
	quit()

func _dump(n: Node, d: int) -> void:
	print("  ".repeat(d) + n.name + " (" + n.get_class() + ")")
	for c in n.get_children(): _dump(c, d+1)
