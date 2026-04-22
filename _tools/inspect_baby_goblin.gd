@tool
extends SceneTree
func _init() -> void:
	for path in [
		"res://assets/synty/PolygonKids/Models/SM_Chr_Baby_Goblin_Crying_01.fbx",
		"res://assets/synty/PolygonKids/Prefabs/SM_Chr_Baby_Goblin_01.tscn",
	]:
		print("=== ", path)
		var ps: PackedScene = load(path)
		if ps == null:
			print("  failed"); continue
		var inst: Node = ps.instantiate()
		self.root.add_child(inst)
		var aabb: AABB = AABB(); var first := true
		for vi in inst.find_children("*", "MeshInstance3D", true, false):
			var m: MeshInstance3D = vi
			var w: AABB = m.global_transform * m.get_aabb()
			print("  Mesh: ", m.name, " surfaces=", m.mesh.get_surface_count() if m.mesh else 0, " visible=", m.visible)
			aabb = w if first else aabb.merge(w); first = false
		print("  Combined AABB size=", aabb.size, " pos=", aabb.position)
		var ap: AnimationPlayer = _find_ap(inst)
		if ap:
			print("  Anims: ", ap.get_animation_list())
	quit()

func _find_ap(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer: return n
	for c in n.get_children():
		var r = _find_ap(c)
		if r: return r
	return null
