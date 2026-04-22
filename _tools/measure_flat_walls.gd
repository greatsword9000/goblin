@tool
extends SceneTree
const CANDIDATES: Array[String] = [
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Wall_01_Alt.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Wall_01_Alt_Texture.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Wall_05.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Wall_Culled_04.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Wall_Rock_Blocked_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Background_01.tscn",
	"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Cave_Background_02.tscn",
	"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Env_Dwarf_Wall_01.tscn",
	"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Env_Dwarf_Wall_02.tscn",
	"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Env_Dwarf_Wall_Block_Cube_01.tscn",
]
func _init() -> void:
	for path in CANDIDATES:
		var ps: PackedScene = load(path)
		if ps == null: print("[FAIL]", path); continue
		var inst: Node = ps.instantiate()
		self.root.add_child(inst)
		var aabb: AABB = AABB(); var first := true; var tri_count := 0
		for vi in inst.find_children("*", "VisualInstance3D", true, false):
			var w: AABB = (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
			aabb = w if first else aabb.merge(w); first = false
			if vi is MeshInstance3D and (vi as MeshInstance3D).mesh:
				var m = (vi as MeshInstance3D).mesh
				for i in range(m.get_surface_count()):
					var a: Array = m.surface_get_arrays(i)
					var idx: PackedInt32Array = a[Mesh.ARRAY_INDEX] if a.size() > Mesh.ARRAY_INDEX else PackedInt32Array()
					tri_count += idx.size() / 3 if idx.size() > 0 else 0
		self.root.remove_child(inst); inst.queue_free()
		print("[%s] size=(%.2f, %.2f, %.2f) tris=%d" % [path.get_file(), aabb.size.x, aabb.size.y, aabb.size.z, tri_count])
	quit()
