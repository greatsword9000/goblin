class_name HitFlash extends RefCounted
## HitFlash — brief white-tint overlay on a damaged entity.
##
## Walks every MeshInstance3D descendant, swaps in an unshaded flash
## material_override for FLASH_SECONDS, then restores the original.
## Works for both simple capsule entities (adventurers) and nested
## Synty character rigs (minions).

const FLASH_SECONDS: float = 0.1


static func flash_descendants(root: Node, tint: Color = Color(1.0, 1.0, 1.0)) -> void:
	if root == null or not is_instance_valid(root):
		return
	var flash_mat: StandardMaterial3D = StandardMaterial3D.new()
	flash_mat.albedo_color = tint
	flash_mat.emission_enabled = true
	flash_mat.emission = tint
	flash_mat.emission_energy_multiplier = 1.0
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var originals: Array = []  # Array of {mesh:MeshInstance3D, mat:Material}
	for m in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m
		originals.append({"mesh": mi, "mat": mi.material_override})
		mi.material_override = flash_mat
	# Timer-based restore — use scene tree's create_timer so we don't need
	# to own a Node here.
	var tree: SceneTree = root.get_tree()
	if tree == null:
		return
	var t: SceneTreeTimer = tree.create_timer(FLASH_SECONDS)
	t.timeout.connect(_restore.bind(originals))


static func _restore(originals: Array) -> void:
	for entry in originals:
		var mi: MeshInstance3D = entry["mesh"] as MeshInstance3D
		if mi != null and is_instance_valid(mi):
			mi.material_override = entry["mat"]
