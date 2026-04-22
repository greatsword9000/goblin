@tool
extends SceneTree

const CANDIDATES: Array[String] = [
	# Modular cave walls — the ones from the user's reference screenshot
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_02.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Curved_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Curved_Corner_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Background_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Background_02.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Background_Corner_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Background_Corner_02.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Large_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Large_Corner_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Roof_01.tscn",
]


func _init() -> void:
	for path in CANDIDATES:
		var ps: PackedScene = load(path)
		if ps == null:
			print("[FAIL] %s" % path); continue
		var inst: Node = ps.instantiate()
		self.root.add_child(inst)
		var aabb: AABB = _compute_aabb(inst); var tri := _count_tris(inst)
		self.root.remove_child(inst); inst.queue_free()
		print("[%s] size=(%.2f, %.2f, %.2f) origin=(%.2f, %.2f, %.2f) tris=%d" % [
			path.get_file(), aabb.size.x, aabb.size.y, aabb.size.z,
			aabb.position.x, aabb.position.y, aabb.position.z, tri,
		])
	quit()


func _compute_aabb(node: Node) -> AABB:
	var out: AABB = AABB(); var first: bool = true
	for child in node.find_children("*", "VisualInstance3D", true, false):
		var vi: VisualInstance3D = child
		var world: AABB = vi.global_transform * vi.get_aabb()
		out = world if first else out.merge(world); first = false
	return out


func _count_tris(node: Node) -> int:
	var n: int = 0
	for child in node.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child
		if mi.mesh == null: continue
		for i in range(mi.mesh.get_surface_count()):
			var arr: Array = mi.mesh.surface_get_arrays(i)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr.size() > Mesh.ARRAY_INDEX else PackedInt32Array()
			if idx.size() > 0: n += idx.size() / 3
			else:
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				n += v.size() / 3
	return n
