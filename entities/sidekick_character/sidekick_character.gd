class_name SidekickCharacter extends Node3D
## Runtime Sidekick-rigged character. Modular parts assembled onto one shared
## Skeleton3D via apply_preset().
##
## Architecture:
##   SidekickCharacter (Node3D) ← this script, height_scale applied here
##     └── Skeleton3D            ← canonical 88-bone rig (loaded from master FBX once)
##           ├── MeshInstance3D  ← one per visible slot, name == slot id
##           ├── MeshInstance3D
##           └── ...
##
## Part swap = queue_free() the old slot MeshInstance3D, instantiate the new
## part's FBX scene, extract its MeshInstance3D, reparent under our Skeleton3D.
## All Sidekick parts share bone names, so skin binding is automatic.
##
## Signals fire after apply, for UI refresh / debug overlay.

signal preset_applied(preset: CharacterPreset)
signal part_swapped(slot: String, part_name: String)
signal blend_shape_changed(slot: String, shape_name: String, value: float)

## The master FBX used to construct the canonical Skeleton3D on _ready().
## ANY Sidekick base FBX works (all share the 88-bone rig); we pick a base
## species torso because it's one of the largest meshes so the skeleton is
## guaranteed fully populated.
const MASTER_FBX_PATH := "res://assets/sidekick/goblin_fighters/base/SK_GOBL_BASE_01_10TORS_GO01.fbx"

## Source color-map textures per variant.
## File names follow the Synty convention:
##   SK_GOBL_BASE_<v>_…  → T_GoblinSpecies_<v>ColorMap.png
##   SK_GOBL_FIGT_<v>_…  → T_GoblinFighter_<v>ColorMap.png
const TEX_DIR := "res://assets/sidekick/goblin_fighters/textures"

## Cache of per-(pack, variant) StandardMaterial3D so every mesh of the same
## family shares one material (no per-mesh duplication). Tints clone on demand.
static var _material_cache: Dictionary = {}

## Slot-id → MeshInstance3D under Skeleton3D. Kept in sync with Skeleton3D children.
var _slot_nodes: Dictionary = {}

var _skeleton: Skeleton3D
var _current_preset: CharacterPreset


func _ready() -> void:
	_build_master_skeleton()


## Lazy-builds the canonical Skeleton3D on first use. Idempotent.
func _build_master_skeleton() -> void:
	if _skeleton != null and is_instance_valid(_skeleton):
		return
	# If the scene was authored with a Skeleton3D child, use it.
	for c in get_children():
		if c is Skeleton3D:
			_skeleton = c
			return
	# Otherwise instantiate from master FBX.
	if not ResourceLoader.exists(MASTER_FBX_PATH):
		push_error("[SidekickCharacter] master FBX missing: %s" % MASTER_FBX_PATH)
		return
	var master := (ResourceLoader.load(MASTER_FBX_PATH) as PackedScene).instantiate()
	var sk := _find_skeleton(master)
	if sk == null:
		push_error("[SidekickCharacter] no Skeleton3D found in master FBX")
		master.queue_free()
		return
	# Detach skeleton from master scene, drop the rest. Unset owner first
	# to silence "inconsistent owner" warnings after reparent.
	sk.owner = null
	sk.get_parent().remove_child(sk)
	sk.name = "Skeleton3D"
	add_child(sk)
	_skeleton = sk
	# Remove any mesh instances that came with the master — we're only keeping the rig.
	for child in _skeleton.get_children():
		if child is MeshInstance3D:
			child.queue_free()
	master.queue_free()


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D: return root
	for c in root.get_children():
		var r := _find_skeleton(c)
		if r != null: return r
	return null


## Returns the live Skeleton3D, building it lazily if needed.
func get_skeleton() -> Skeleton3D:
	_build_master_skeleton()
	return _skeleton


## Bone count of master rig. Used by validation smoke test (expect 88).
func bone_count() -> int:
	var sk := get_skeleton()
	return sk.get_bone_count() if sk else 0


## Primary entry point. Applies every field of a preset: clears existing parts,
## attaches new parts, sets blend shapes, tints, and height_scale.
## Silently skips invalid parts (pushes warnings) so one bad slot doesn't
## break the whole character.
func apply_preset(preset: CharacterPreset) -> void:
	if preset == null:
		push_warning("[SidekickCharacter] apply_preset(null) — ignored")
		return
	if preset.rig_target != "sidekick":
		push_warning("[SidekickCharacter] preset '%s' rig_target=%s, expected 'sidekick' — skipping" % [preset.display_name, preset.rig_target])
		return
	_build_master_skeleton()
	if _skeleton == null: return

	# Clear existing slot nodes
	for slot in _slot_nodes.keys():
		var n: Node = _slot_nodes[slot]
		if is_instance_valid(n): n.queue_free()
	_slot_nodes.clear()

	# Attach parts
	for slot in preset.parts:
		var part_name := String(preset.parts[slot])
		if part_name == "": continue  # intentionally hidden
		set_part(slot, part_name, false)  # skip signal until the end

	# Apply blend shapes (after parts exist to host them)
	for slot in preset.blend_shapes:
		var shapes: Dictionary = preset.blend_shapes[slot]
		for shape_name in shapes:
			set_blend_shape(slot, shape_name, float(shapes[shape_name]), false)

	# Apply tints
	for slot in preset.tint_overrides:
		var c: Color = preset.tint_overrides[slot]
		set_tint(slot, c)

	# Height scale
	scale = Vector3.ONE * clampf(preset.height_scale, 0.5, 1.5)

	_current_preset = preset
	preset_applied.emit(preset)


func current_preset() -> CharacterPreset: return _current_preset


## Swap a single slot. Emits part_swapped unless `quiet` is true (bulk apply).
## Passing "" as part_name hides the slot.
func set_part(slot: String, part_name: String, emit: bool = true) -> void:
	_build_master_skeleton()
	if _skeleton == null: return

	# Remove existing node for this slot
	if _slot_nodes.has(slot):
		var old: Node = _slot_nodes[slot]
		if is_instance_valid(old): old.queue_free()
		_slot_nodes.erase(slot)

	if part_name == "":
		if emit: part_swapped.emit(slot, "")
		return

	var lib: Node = get_node_or_null("/root/SidekickPartLibrary")
	if lib == null:
		push_error("[SidekickCharacter] SidekickPartLibrary autoload not registered")
		return
	var scene: PackedScene = lib.load_part_scene(slot, part_name)
	if scene == null:
		push_warning("[SidekickCharacter] could not load part '%s' for slot '%s'" % [part_name, slot])
		if emit: part_swapped.emit(slot, "")
		return

	var inst := scene.instantiate()
	var mesh := _extract_mesh_instance(inst)
	if mesh == null:
		push_warning("[SidekickCharacter] no MeshInstance3D in part scene '%s'" % part_name)
		inst.queue_free()
		if emit: part_swapped.emit(slot, "")
		return
	# Detach from original parent, drop the rest of the imported scene.
	# Unset owner first to silence "inconsistent owner" warnings.
	mesh.owner = null
	mesh.get_parent().remove_child(mesh)
	inst.queue_free()
	mesh.name = slot  # normalize so _slot_nodes[slot] lookup works later via get_node
	_skeleton.add_child(mesh)
	mesh.skeleton = NodePath("..")  # bind to our master skeleton
	_slot_nodes[slot] = mesh
	_apply_synty_material(mesh, part_name)
	if emit: part_swapped.emit(slot, part_name)


## Synty FBX files ship without usable material data for Godot (Unity .mat
## files we skip during extraction), so Godot slaps a default white material
## on each surface. This method parses the part name for its pack + variant,
## loads the matching color-map PNG, and builds a StandardMaterial3D wired
## to it. Cached per (pack, variant) so 50 parts of fighter-03 share one mat.
func _apply_synty_material(mesh: MeshInstance3D, part_name: String) -> void:
	if mesh == null or mesh.mesh == null: return
	# Parse: SK_GOBL_{BASE|FIGT}_{vv}_…
	var tokens := part_name.split("_")
	if tokens.size() < 4: return
	var pack: String = tokens[2]
	var variant: String = tokens[3]
	var cache_key := "%s_%s" % [pack, variant]
	var mat: StandardMaterial3D = _material_cache.get(cache_key, null)
	if mat == null:
		var tex_name := ""
		match pack:
			"BASE": tex_name = "T_GoblinSpecies_%sColorMap.png" % variant
			"FIGT": tex_name = "T_GoblinFighter_%sColorMap.png" % variant
			_: tex_name = ""
		var tex_path := "%s/%s" % [TEX_DIR, tex_name]
		mat = StandardMaterial3D.new()
		if tex_name != "" and ResourceLoader.exists(tex_path):
			mat.albedo_texture = load(tex_path)
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		else:
			push_warning("[SidekickCharacter] no color map for %s (expected %s)" % [part_name, tex_path])
		_material_cache[cache_key] = mat
	# Set on every surface so multi-surface meshes (eyes+eye-lights etc.) all pick it up.
	for i in range(mesh.mesh.get_surface_count()):
		mesh.set_surface_override_material(i, mat)


## Returns the MeshInstance3D for a slot, or null.
func get_slot_mesh(slot: String) -> MeshInstance3D:
	return _slot_nodes.get(slot, null)


func _extract_mesh_instance(root: Node) -> MeshInstance3D:
	if root is MeshInstance3D: return root
	for c in root.get_children():
		var r := _extract_mesh_instance(c)
		if r != null: return r
	return null


## Sets a blend shape on a specific slot's mesh. Silently skips if the shape
## doesn't exist on that mesh (Sidekick shape sets vary per outfit piece).
func set_blend_shape(slot: String, shape_name: String, value: float, emit: bool = true) -> void:
	var mesh := get_slot_mesh(slot)
	if mesh == null or mesh.mesh == null: return
	var idx := mesh.find_blend_shape_by_name(shape_name)
	if idx < 0:
		# Sidekick prefixes every shape with its mesh name ("HIPSBlends.defaultBuff").
		# Callers typically pass the unprefixed form ("defaultBuff") — suffix-match
		# it to the prefixed name so one global shape name drives every mesh.
		for i in range(mesh.mesh.get_blend_shape_count()):
			var n: String = mesh.mesh.get_blend_shape_name(i)
			if n == shape_name or n.ends_with("." + shape_name):
				idx = i
				break
	if idx < 0: return
	mesh.set_blend_shape_value(idx, value)
	if emit: blend_shape_changed.emit(slot, shape_name, value)


## Sets a blend shape on EVERY slot that has it. Used for body-morph sliders
## (masculineFeminine etc.) that want to drive multiple meshes together.
func set_blend_shape_global(shape_name: String, value: float) -> void:
	for slot in _slot_nodes.keys():
		set_blend_shape(slot, shape_name, value, false)
	blend_shape_changed.emit("<global>", shape_name, value)


## Color tint via StandardMaterial3D albedo multiplier.
##
## Multiplies `color` over the existing texture — does NOT replace it, so
## tinting "torso" only affects the torso surface (not other parts that share
## the same cached base material). We duplicate the cached material per-mesh
## on first tint so the change is local to this MeshInstance3D.
func set_tint(slot: String, color: Color) -> void:
	var mesh := get_slot_mesh(slot)
	if mesh == null or mesh.mesh == null: return
	for i in range(mesh.mesh.get_surface_count()):
		var current: Material = mesh.get_surface_override_material(i)
		var mat: StandardMaterial3D
		if current is StandardMaterial3D:
			# Clone only if this is the shared cached material; otherwise tint in place.
			if _material_cache.values().has(current):
				mat = (current as StandardMaterial3D).duplicate()
			else:
				mat = current
		else:
			mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mesh.set_surface_override_material(i, mat)


## Returns the union of blend-shape names across all currently-attached meshes.
## Used by the customizer to know which sliders to show.
func available_blend_shapes() -> Array[String]:
	var out: Dictionary = {}
	for slot in _slot_nodes.keys():
		var mesh: MeshInstance3D = _slot_nodes[slot]
		if mesh == null or mesh.mesh == null: continue
		var m := mesh.mesh
		for i in range(m.get_blend_shape_count()):
			out[m.get_blend_shape_name(i)] = true
	var keys: Array[String] = []
	for k in out.keys(): keys.append(k)
	keys.sort()
	return keys
