extends Node
## Autoload: the runtime counterpart to the plug editor.
## Queries PlugLibrary for matching templates, picks one via weighted
## random, and instantiates it at a world cell. Uses deterministic RNG
## seeded from cell coordinates so the same dungeon position always
## picks the same variant across reloads.
##
## Usage:
##   var plug = PlugSpawner.spawn_at(Vector3i(3, 0, 5), {
##       "role": "env_wall_straight",
##       "aesthetic": "cave",
##   }, 90.0)
##   get_tree().current_scene.add_child(plug)
##
## Or fire-and-forget:
##   PlugSpawner.spawn_into(parent_node, cell, filters, yaw_deg)

const CELL_SIZE: float = 2.0   # matches GridWorld.CELL_SIZE and the editor


## Pick a template matching `filters` from PlugLibrary and instantiate
## it at the grid cell. Returns the root Node3D (unparented) or null if
## no matching template exists. World position = cell * CELL_SIZE.
##
## `yaw_deg` is the base rotation. For orientation_mode = "omni", the
## spawner adds a deterministic random yaw snapped to spawn_yaw_snap.
func spawn_at(cell: Vector3i, filters: Dictionary, yaw_deg: float = 0.0) -> Node3D:
	var candidates: Array[PlugTemplate] = PlugLibrary.query(filters)
	if candidates.is_empty():
		push_warning("PlugSpawner: no templates match %s" % filters)
		return null
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _cell_seed(cell)
	var t: PlugTemplate = PlugLibrary.pick_weighted(candidates, rng)
	if t == null:
		return null
	var final_yaw: float = yaw_deg
	if t.orientation_mode == "omni" and t.spawn_yaw_snap > 0:
		# Quantize into N discrete rotations and pick one deterministically.
		var steps: int = maxi(1, int(360 / t.spawn_yaw_snap))
		final_yaw += float((rng.randi() % steps) * t.spawn_yaw_snap)
	var world_pos: Vector3 = Vector3(float(cell.x), float(cell.y), float(cell.z)) * CELL_SIZE
	# Pass a separate rng seed down so per-piece jitter is also deterministic.
	return t.instantiate_at(world_pos, final_yaw, rng.randi())


## Convenience: spawn AND parent. Returns the plug root (null on miss).
func spawn_into(parent: Node, cell: Vector3i, filters: Dictionary, yaw_deg: float = 0.0) -> Node3D:
	var root: Node3D = spawn_at(cell, filters, yaw_deg)
	if root != null:
		parent.add_child(root)
	return root


## Spawn a specific template by ID — bypasses the query / pick_weighted
## path. Useful for scripted encounters or tests.
func spawn_template_at(template_id: String, cell: Vector3i, yaw_deg: float = 0.0) -> Node3D:
	var t: PlugTemplate = PlugLibrary.get_by_id(template_id)
	if t == null:
		push_warning("PlugSpawner: unknown template '%s'" % template_id)
		return null
	var world_pos: Vector3 = Vector3(float(cell.x), float(cell.y), float(cell.z)) * CELL_SIZE
	var rng_seed: int = _cell_seed(cell)
	return t.instantiate_at(world_pos, yaw_deg, rng_seed)


## Deterministic seed from cell coords. Two primes xored gives sparse
## collisions at typical dungeon scales.
static func _cell_seed(cell: Vector3i) -> int:
	return (cell.x * 73856093) ^ (cell.y * 19349663) ^ (cell.z * 83492791)
