@tool
extends SceneTree

func _init() -> void:
	var ps: PackedScene = load("res://assets/synty/PolygonKids/Prefabs/SM_Chr_Kid_Goblin_01.tscn")
	var inst: Node = ps.instantiate()
	self.root.add_child(inst)
	print("=== Tree dump (with transforms) ===")
	_dump(inst, 0)
	print("\n=== AABB ===")
	var first: bool = true
	var aabb: AABB = AABB()
	for vi in inst.find_children("*", "VisualInstance3D", true, false):
		var w: AABB = (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
		aabb = w if first else aabb.merge(w)
		first = false
	print("Combined: pos=%s size=%s" % [aabb.position, aabb.size])
	print("\n=== Mesh details ===")
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		print("MeshInstance3D: %s  visible=%s  layers=%d" % [m.name, m.visible, m.layers])
		var mesh: Mesh = m.mesh
		if mesh == null:
			print("  mesh = null")
			continue
		print("  surfaces: %d" % mesh.get_surface_count())
		for i in range(mesh.get_surface_count()):
			var mat: Material = m.get_active_material(i)
			var mname: String = "<none>"
			if mat != null:
				mname = mat.resource_path if mat.resource_path != "" else "<embedded>"
			print("    surf %d: material=%s" % [i, mname])
	quit()


func _dump(n: Node, depth: int) -> void:
	var line: String = "  ".repeat(depth) + "- " + n.name + " (" + n.get_class() + ")"
	if n is Node3D:
		var t: Transform3D = (n as Node3D).transform
		line += "  origin=%s scale=%s" % [t.origin, t.basis.get_scale()]
	print(line)
	for c in n.get_children():
		_dump(c, depth + 1)
