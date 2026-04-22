class_name CaveWallSpawner extends Node
## CaveWallSpawner — places cave-wall meshes on ROCK→FLOOR boundaries.
##
## The cave_rock tile is data-only (no mesh). When a rock cell is revealed,
## this spawner inspects its 4 orthogonal neighbors, and for each floor
## neighbor, instantiates a flat cave slab flush against that edge —
## oriented so its carved face points into the room. If two perpendicular
## sides both have floor neighbors, the cell becomes a convex corner and
## a corner piece is placed covering both edges at once.
##
## Usage (in starter_dungeon.gd _ready or similar):
##   var spawner := CaveWallSpawner.new()
##   spawner.straight_manifest = load("res://resources/tiles/wall_cave_straight.tres")
##   spawner.corner_manifest = load("res://resources/tiles/wall_cave_corner.tres")
##   spawner.visual_root = $WorldVisuals
##   add_child(spawner)
##   spawner.bind()

@export var straight_manifest: CaveWallManifest = null
@export var corner_manifest: CaveWallManifest = null
@export var visual_root: Node3D = null

const CELL := 2.0  # duplicated from GridWorld.CELL_SIZE; kept local to avoid autoload coupling
# Offsets for N, E, S, W in cell space. Order matters — rotation yaw is
# (index * 90) for straight pieces so each orientation faces its floor
# neighbor. 0=N(-Z), 1=E(+X), 2=S(+Z), 3=W(-X).
const NEIGHBORS: Array[Vector3i] = [
	Vector3i(0, 0, -1),
	Vector3i(1, 0, 0),
	Vector3i(0, 0, 1),
	Vector3i(-1, 0, 0),
]

# Bookkeeping so re-reveal (or tile mutations) doesn't stack duplicate walls.
var _spawned_walls: Dictionary = {} # Vector3i -> Array[Node3D]


func bind() -> void:
	EventBus.tile_changed.connect(_on_tile_changed)
	for cell in GridWorld.get_all_cells():
		_maybe_spawn_for_cell(cell)


func _on_tile_changed(cell: Vector3i, _tile) -> void:
	# A cell changing type (mined → floor) may create new wall edges on
	# adjacent rock cells, and remove the need for walls on this cell.
	_despawn_for_cell(cell)
	_maybe_spawn_for_cell(cell)
	for n in NEIGHBORS:
		_despawn_for_cell(cell + n)
		_maybe_spawn_for_cell(cell + n)


func _maybe_spawn_for_cell(cell: Vector3i) -> void:
	var tile: TileResource = GridWorld.get_tile(cell)
	if tile == null or tile.is_walkable:
		return
	# Identify which neighbor indices are floor (walkable).
	var floor_sides: Array[int] = []
	for i in range(NEIGHBORS.size()):
		if GridWorld.is_walkable(cell + NEIGHBORS[i]):
			floor_sides.append(i)
	if floor_sides.is_empty():
		return  # Interior rock — hidden by fog anyway, no wall needed.
	# L-shape: two adjacent perpendicular edges → single corner piece.
	var corner_idx: int = _find_corner(floor_sides)
	var spawned: Array[Node3D] = []
	if corner_idx >= 0 and corner_manifest != null and corner_manifest.prefab != null:
		spawned.append(_spawn_corner(cell, corner_idx))
	else:
		for side in floor_sides:
			if straight_manifest == null or straight_manifest.prefab == null:
				continue
			spawned.append(_spawn_straight(cell, side))
	if not spawned.is_empty():
		_spawned_walls[cell] = spawned


func _find_corner(sides: Array[int]) -> int:
	# Return the start side of an adjacent pair (0→1, 1→2, 2→3, 3→0) or -1.
	# The "corner_idx" returned is the counterclockwise-most of the two sides,
	# so yaw = corner_idx * 90 orients the corner's concave bend outward.
	for i in range(NEIGHBORS.size()):
		var nxt: int = (i + 1) % NEIGHBORS.size()
		if sides.has(i) and sides.has(nxt):
			return i
	return -1


func _spawn_straight(cell: Vector3i, side: int) -> Node3D:
	var inst: Node3D = straight_manifest.prefab.instantiate()
	visual_root.add_child(inst)
	# Scale so the slab's natural width fits the cell width (2m), with a
	# slight overlap so adjacent slabs don't show vertical seams.
	var scale: float = (CELL * 1.05) / straight_manifest.natural_width
	inst.scale = Vector3.ONE * scale
	# Position: slab sits on the rock-cell center, shifted half a cell
	# toward the floor neighbor so its back is on the rock-floor edge.
	var cell_world: Vector3 = Vector3(cell.x, cell.y, cell.z) * CELL
	var to_floor: Vector3 = Vector3(NEIGHBORS[side].x, 0, NEIGHBORS[side].z)
	inst.position = cell_world + to_floor * (CELL * 0.5)
	# Rotation: SM_Env_Cave_01 face-direction + side's outward normal.
	# Side 0 = -Z (N), so yaw=0 faces -Z. Side 1 = +X (E), yaw=-90. Etc.
	inst.rotation.y = deg_to_rad(straight_manifest.face_align_yaw_deg - side * 90.0)
	_rewrite_collision_layers(inst, false)
	return inst


func _spawn_corner(cell: Vector3i, corner_idx: int) -> Node3D:
	var inst: Node3D = corner_manifest.prefab.instantiate()
	visual_root.add_child(inst)
	var scale: float = (CELL * 1.05) / corner_manifest.natural_width
	inst.scale = Vector3.ONE * scale
	var cell_world: Vector3 = Vector3(cell.x, cell.y, cell.z) * CELL
	# Shift corner outward toward the bisector of the two floor sides.
	var a: Vector3i = NEIGHBORS[corner_idx]
	var b: Vector3i = NEIGHBORS[(corner_idx + 1) % NEIGHBORS.size()]
	var bisect: Vector3 = Vector3(a.x + b.x, 0, a.z + b.z).normalized()
	inst.position = cell_world + bisect * (CELL * 0.35)
	inst.rotation.y = deg_to_rad(corner_manifest.face_align_yaw_deg - corner_idx * 90.0)
	_rewrite_collision_layers(inst, false)
	return inst


func _despawn_for_cell(cell: Vector3i) -> void:
	if not _spawned_walls.has(cell):
		return
	for n in _spawned_walls[cell]:
		if is_instance_valid(n):
			n.queue_free()
	_spawned_walls.erase(cell)


## Same layer rewrite used for the primitive rock placeholder — World layer 1.
func _rewrite_collision_layers(root: Node, walkable: bool) -> void:
	var target: int = 0 if walkable else 1
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody3D:
			(n as StaticBody3D).collision_layer = target
			(n as StaticBody3D).collision_mask = 0
		for c in n.get_children():
			stack.append(c)
