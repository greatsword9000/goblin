@tool
extends SceneTree
func _init() -> void:
	for path in [
		"res://assets/synty/PolygonKids/Models/SK_Chr_Kid_Goblin_01.fbx",
		"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Curved_01.tscn",
		"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_01.tscn",
	]:
		print("=== ", path)
		var ps: PackedScene = load(path)
		if ps == null: print("  FAIL"); continue
		var inst: Node = ps.instantiate()
		self.root.add_child(inst)
		_dump(inst, 1)
		var aabb: AABB = AABB(); var first := true
		for vi in inst.find_children("*", "VisualInstance3D", true, false):
			var w: AABB = (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
			aabb = w if first else aabb.merge(w); first = false
		print("  AABB size=%s pos=%s" % [aabb.size, aabb.position])
	quit()
func _dump(n: Node, d: int) -> void:
	var extra := ""
	if n is Node3D:
		var t: Transform3D = (n as Node3D).transform
		extra = " scale=%s pos=%s" % [t.basis.get_scale(), t.origin]
	print("  ".repeat(d) + n.name + " (" + n.get_class() + ")" + extra)
	for c in n.get_children(): _dump(c, d+1)
