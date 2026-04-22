@tool
extends SceneTree
const CANDIDATES: Array[String] = [
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_GroundCover_01.tscn",
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_GroundCover_02.tscn",
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_GroundCover_03.tscn",
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_Ground_Mound_Large_01.tscn",
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_Rock_Rough_01.tscn",
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_Rock_Rough_02.tscn",
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_Rock_River_01.tscn",
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_Rock_River_02.tscn",
	"res://assets/synty/PNB_Alpine_Mountain/Prefabs/SM_Env_Rock_Pebbles_01.tscn",
]
func _init() -> void:
	for path in CANDIDATES:
		var ps: PackedScene = load(path)
		if ps == null: print("[FAIL] ", path); continue
		var inst: Node = ps.instantiate()
		self.root.add_child(inst)
		var aabb: AABB = AABB(); var first := true
		for vi in inst.find_children("*", "VisualInstance3D", true, false):
			var w: AABB = (vi as VisualInstance3D).global_transform * (vi as VisualInstance3D).get_aabb()
			aabb = w if first else aabb.merge(w); first = false
		self.root.remove_child(inst); inst.queue_free()
		print("[%s] size=(%.2f, %.2f, %.2f) pos=(%.2f, %.2f, %.2f)" % [
			path.get_file(), aabb.size.x, aabb.size.y, aabb.size.z,
			aabb.position.x, aabb.position.y, aabb.position.z,
		])
	quit()
