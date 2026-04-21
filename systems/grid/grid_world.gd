extends Node
## GridWorld — authoritative spatial service. All position logic flows through here.
##
## Owns: the tile dictionary (grid_pos -> TileResource), visual instance registry,
##       the AStar3D pathfinder, and cell-size constants.
## Listens to: nothing directly — systems call set_tile() / clear_tile().
## Emits (via EventBus): tile_changed, tile_mined, tile_built.
##
## Coordinate system: Vector3i where Y is elevation. Phase 1 content is Y=0.
## World position for a cell: cell * CELL_SIZE (cell-corner origin; visuals
## are centered via visual_y_offset per tile type).

const CELL_SIZE: float = 2.0

# Scene tree parent into which tile visuals are instanced. Set by the starter
# dungeon scene (or any scene that owns the world) on _ready().
var visual_root: Node3D = null

var _tiles: Dictionary = {}          # Vector3i -> TileResource
var _visuals: Dictionary = {}        # Vector3i -> Node3D (mesh instance)

var _astar: AStar3D = AStar3D.new()
var _cell_to_astar_id: Dictionary = {} # Vector3i -> int (AStar3D node id)
var _next_astar_id: int = 0


## Set the world-visual root. Must be called before placing tiles.
func register_visual_root(root: Node3D) -> void:
	visual_root = root


## Convert a grid position to world-space (cell center at Y=0 unless offset).
func grid_to_world(grid_pos: Vector3i) -> Vector3:
	return Vector3(grid_pos.x, grid_pos.y, grid_pos.z) * CELL_SIZE


## Convert a world-space XZ position to the grid cell containing it (Y floored).
func world_to_grid(world_pos: Vector3) -> Vector3i:
	return Vector3i(
		int(floor(world_pos.x / CELL_SIZE + 0.5)),
		int(floor(world_pos.y / CELL_SIZE + 0.5)),
		int(floor(world_pos.z / CELL_SIZE + 0.5)),
	)


func get_tile(grid_pos: Vector3i) -> TileResource:
	return _tiles.get(grid_pos, null)


func has_tile(grid_pos: Vector3i) -> bool:
	return _tiles.has(grid_pos)


## Visual Node3D that represents the tile at `grid_pos` in the scene.
## Returns null if no tile (or no visual was instanced, e.g. if mesh_scene
## was null AND no primitive fallback ran — shouldn't happen in practice).
func get_visual(grid_pos: Vector3i) -> Node3D:
	return _visuals.get(grid_pos, null)


func is_walkable(grid_pos: Vector3i) -> bool:
	var t: TileResource = _tiles.get(grid_pos, null)
	if t == null:
		return false
	return t.is_walkable


## Place a tile at grid_pos, replacing any existing tile there. Instances the
## tile's mesh_scene at the cell's world position; falls back to a primitive
## tinted by placeholder_color when mesh_scene is null.
##
## `yaw_override_deg` (NAN = unset) rotates the placed visual around Y. Use
## this for per-cell orientation (e.g. border walls facing inward) without
## creating a separate TileResource per direction.
func set_tile(grid_pos: Vector3i, tile: TileResource, yaw_override_deg: float = NAN) -> void:
	if tile == null:
		clear_tile(grid_pos)
		return
	_remove_visual(grid_pos)
	_tiles[grid_pos] = tile
	_sync_astar_for_cell(grid_pos, tile)
	var visual: Node3D = _instance_visual(tile)
	if visual != null:
		if visual_root != null:
			visual_root.add_child(visual)
		else:
			push_warning("GridWorld: visual_root not registered; tile %s has no parent" % [grid_pos])
			add_child(visual)
		visual.position = grid_to_world(grid_pos) + Vector3(0.0, tile.visual_y_offset, 0.0)
		visual.scale = Vector3.ONE * tile.visual_scale
		var yaw_deg: float = yaw_override_deg if not is_nan(yaw_override_deg) else tile.visual_yaw_deg
		visual.rotation.y = deg_to_rad(yaw_deg)
		# Auto-center the mesh XZ so assets with corner-origin pivots (Synty)
		# and center-origin pivots (primitive boxes) both align to the cell
		# center. Y is left alone so walls sit on the ground, not half sunk.
		if tile.mesh_scene != null:
			_center_mesh_xz(visual)
		# Synty auto-collision runs in _ready (fired on add_child). Rewrite
		# layers now that the StaticBody3Ds exist.
		call_deferred("_rewrite_collision_layers", visual, tile)
		_visuals[grid_pos] = visual
	EventBus.tile_changed.emit(grid_pos, tile)


func clear_tile(grid_pos: Vector3i) -> void:
	if not _tiles.has(grid_pos):
		return
	_remove_visual(grid_pos)
	_tiles.erase(grid_pos)
	_remove_astar_for_cell(grid_pos)
	EventBus.tile_changed.emit(grid_pos, null)


func _remove_visual(grid_pos: Vector3i) -> void:
	var v: Node3D = _visuals.get(grid_pos, null)
	if v != null:
		v.queue_free()
		_visuals.erase(grid_pos)


func _instance_visual(tile: TileResource) -> Node3D:
	if tile.mesh_scene != null:
		var inst: Node = tile.mesh_scene.instantiate()
		if inst is Node3D:
			return inst
		push_warning("GridWorld: mesh_scene for %s did not produce a Node3D" % tile.id)
		inst.queue_free()
	return _make_primitive(tile)


## Synty prefabs ship with StaticBody3Ds on collision_layer=8 (their "static
## world" convention). Our project uses layer 1 for World so the Ring Avatar's
## mask=1 can collide. Walk the tree and rewrite layers on every StaticBody3D.
## Walkable tiles (floors) get collision_layer=0 so they don't block movement.
func _rewrite_collision_layers(root: Node, tile: TileResource) -> void:
	var target_layer: int = 0 if tile.is_walkable else 1
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is StaticBody3D:
			(n as StaticBody3D).collision_layer = target_layer
			(n as StaticBody3D).collision_mask = 0
		for c in n.get_children():
			stack.append(c)


## Code-generated placeholder — BoxMesh for walls, PlaneMesh for floors,
## CylinderMesh for throne-ish decorative. Used until Synty imports land.
func _make_primitive(tile: TileResource) -> Node3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = tile.placeholder_color
	mat.roughness = 0.85

	if tile is FloorTile:
		var plane: PlaneMesh = PlaneMesh.new()
		plane.size = Vector2(CELL_SIZE, CELL_SIZE)
		mi.mesh = plane
	elif tile is DecorativeTile:
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = CELL_SIZE * 0.4
		cyl.bottom_radius = CELL_SIZE * 0.45
		cyl.height = CELL_SIZE * 0.6
		mi.mesh = cyl
		mi.position.y = cyl.height * 0.5
	else:
		# Wall box: cell-sized cube. Positioned via visual_y_offset in the
		# wall .tres so the bottom sits on the ground (y=0) and top at y=CELL_SIZE.
		var box: BoxMesh = BoxMesh.new()
		box.size = Vector3(CELL_SIZE, CELL_SIZE, CELL_SIZE)
		mi.mesh = box
	mi.material_override = mat
	mi.name = "Tile_" + tile.id
	# The primitive-based wall needs a collision body so the kid can't walk
	# through it. Add a matching StaticBody3D + CollisionShape3D.
	if not tile.is_walkable:
		_attach_primitive_collision(mi)
	return mi


## Compute the combined AABB of all MeshInstance3D descendants in `visual`
## (in visual-local space) and shift `visual.position` so the AABB's XZ
## center aligns with the cell center. Y is untouched.
func _center_mesh_xz(visual: Node3D) -> void:
	var combined: AABB = AABB()
	var first: bool = true
	for mi in visual.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var local_aabb: AABB = m.mesh.get_aabb()
		# Transform into visual-local space (includes the MeshInstance3D's
		# own offset/rotation relative to the visual root).
		var rel_xform: Transform3D = visual.global_transform.affine_inverse() * m.global_transform
		local_aabb = rel_xform * local_aabb
		if first:
			combined = local_aabb
			first = false
		else:
			combined = combined.merge(local_aabb)
	if first:
		return
	# AABB is computed in visual-LOCAL space (pre-scale). The shift we
	# apply is in PARENT space, so scale by visual.scale to convert.
	var center_x: float = (combined.position.x + combined.size.x * 0.5) * visual.scale.x
	var center_z: float = (combined.position.z + combined.size.z * 0.5) * visual.scale.z
	visual.position -= Vector3(center_x, 0.0, center_z)


func _attach_primitive_collision(wall_visual: MeshInstance3D) -> void:
	var mesh: Mesh = wall_visual.mesh
	if mesh == null:
		return
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	if mesh is BoxMesh:
		box_shape.size = (mesh as BoxMesh).size
	else:
		box_shape.size = mesh.get_aabb().size
	shape.shape = box_shape
	body.add_child(shape)
	wall_visual.add_child(body)


## Raycast-style query for "what cell is under this world XZ?" Returns the
## highest Y tile at that column, or the ground-level cell if none exists.
func tile_at_world(world_pos: Vector3) -> Vector3i:
	return world_to_grid(Vector3(world_pos.x, 0.0, world_pos.z))


# ─── AStar3D pathfinding ─────────────────────────────────────────────────
#
# Cells are added/removed from AStar3D as they become walkable (floors)
# or blocked (walls, decor). Neighbor connections are recomputed when a
# cell toggles walkability. Phase 1 is single-floor (Y=0) but the 3D AStar
# supports multi-level lookups when we get there.


## Pathfind from `start_grid` to `goal_grid`. Returns a PackedVector3Array
## of world-space waypoints (cell centers). Empty array = no path.
func find_path(start_grid: Vector3i, goal_grid: Vector3i) -> PackedVector3Array:
	var start_id: int = int(_cell_to_astar_id.get(start_grid, -1))
	var goal_id: int = int(_cell_to_astar_id.get(goal_grid, -1))
	if start_id < 0 or goal_id < 0:
		return PackedVector3Array()
	var point_path: PackedVector3Array = _astar.get_point_path(start_id, goal_id)
	return point_path


## Scan neighbors and return the first walkable cell within `radius` cells.
## Used when a drop target is itself blocked (e.g. drop minion on a wall).
func find_nearest_walkable(grid_pos: Vector3i, radius: int = 3) -> Vector3i:
	if is_walkable(grid_pos):
		return grid_pos
	# At each ring radius, try the 4 cardinal neighbors first so minions
	# park directly in front of walls (N/S/E/W), not diagonally. Fall back
	# to diagonals only if no cardinal is walkable.
	for r in range(1, radius + 1):
		for offset in [
			Vector3i(r, 0, 0), Vector3i(-r, 0, 0),
			Vector3i(0, 0, r), Vector3i(0, 0, -r),
		]:
			var candidate: Vector3i = grid_pos + offset
			if is_walkable(candidate):
				return candidate
		# Diagonals this ring
		for dx in [-r, r]:
			for dz in [-r, r]:
				var cd: Vector3i = grid_pos + Vector3i(dx, 0, dz)
				if is_walkable(cd):
					return cd
	return grid_pos


func _sync_astar_for_cell(grid_pos: Vector3i, tile: TileResource) -> void:
	var walkable: bool = tile.is_walkable
	var existing_id: int = int(_cell_to_astar_id.get(grid_pos, -1))
	if walkable:
		var id: int = existing_id
		if id < 0:
			id = _next_astar_id
			_next_astar_id += 1
			_astar.add_point(id, grid_to_world(grid_pos))
			_cell_to_astar_id[grid_pos] = id
		# Connect to walkable 4-neighbors (XZ only for Phase 1).
		for offset in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
			var nbr: Vector3i = grid_pos + offset
			var nbr_id: int = int(_cell_to_astar_id.get(nbr, -1))
			if nbr_id >= 0 and not _astar.are_points_connected(id, nbr_id):
				_astar.connect_points(id, nbr_id, true)
	else:
		if existing_id >= 0:
			_astar.remove_point(existing_id)
			_cell_to_astar_id.erase(grid_pos)


func _remove_astar_for_cell(grid_pos: Vector3i) -> void:
	var id: int = int(_cell_to_astar_id.get(grid_pos, -1))
	if id >= 0:
		_astar.remove_point(id)
		_cell_to_astar_id.erase(grid_pos)
