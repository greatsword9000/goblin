class_name StarterDungeon extends Node3D
## StarterDungeon — hand-authored 10×10 Phase 1 prototype layout.
##
## Phase 1 spawns the layout in _ready(); procgen comes in Phase 3+.
## Also registers the visual root with GridWorld and the camera with
## DebugOverlay so overlay can report the tile under the cursor.

@export var floor_tile: TileResource
@export var wall_tile: TileResource
@export var ore_tile: TileResource
@export var throne_tile: TileResource
@export var ring_avatar_scene: PackedScene
@export var minion_definition: MinionDefinition

@export var dungeon_size: Vector2i = Vector2i(10, 10)
## Grid-coords (x, z) of mineable ore veins. Interior cells count as ore
## candidates embedded in the interior walls; border cells become ore wall.
@export var ore_positions: Array[Vector2i] = [Vector2i(-1, 4), Vector2i(10, 5), Vector2i(3, -1)]
## Grid-coords (x, z) of the throne pile — must be inside the floor area.
@export var throne_position: Vector2i = Vector2i(5, 5)
## Grid-coords (x, z) where the Ring Avatar spawns on game start.
@export var ring_spawn_position: Vector2i = Vector2i(2, 2)
## Grid-coords where the initial minions spawn.
@export var minion_spawn_positions: Array[Vector2i] = [Vector2i(3, 3), Vector2i(7, 4)]

@onready var _tile_root: Node3D = $TileRoot
@onready var _camera_rig: RTSCameraController = $CameraRig

var _ring_avatar: Node3D = null
var _mining_system: MiningSystem = null
var _pickup_system: PickupSystem = null
var _haul_system: HaulSystem = null

@export var ore_pickup_scene: PackedScene


func _ready() -> void:
	GridWorld.register_visual_root(_tile_root)
	DebugOverlay.register_camera(_camera_rig)
	_spawn_dungeon()
	_spawn_ring_avatar()
	_attach_camera_to_avatar()
	_spawn_minions()
	_install_pickup_system()
	_install_mining_system()
	_install_haul_system()


func _spawn_dungeon() -> void:
	var w: int = dungeon_size.x
	var h: int = dungeon_size.y
	for x in range(-1, w + 1):
		for z in range(-1, h + 1):
			var grid_pos := Vector3i(x, 0, z)
			var is_border: bool = (x == -1 or x == w or z == -1 or z == h)
			var is_throne: bool = (x == throne_position.x and z == throne_position.y)
			var is_ore: bool = _is_ore_position(x, z)

			if is_border:
				# Wall ring around the 10x10 — swap ore walls where designated.
				var yaw: float = _border_wall_yaw(x, z, w, h)
				var chosen: TileResource = ore_tile if is_ore else wall_tile
				GridWorld.set_tile(grid_pos, chosen, yaw)
			else:
				# Always place floor on interior cells. Throne is a separate
				# decorative prop spawned on top so the cell stays walkable
				# and pathfinding works across the dungeon.
				GridWorld.set_tile(grid_pos, floor_tile)
	if is_throne_in_bounds(w, h):
		_spawn_throne_prop()


func is_throne_in_bounds(w: int, h: int) -> bool:
	return throne_position.x >= 0 and throne_position.x < w \
		and throne_position.y >= 0 and throne_position.y < h


func _spawn_throne_prop() -> void:
	if throne_tile == null or throne_tile.mesh_scene == null:
		return
	var prop: Node3D = throne_tile.mesh_scene.instantiate()
	_tile_root.add_child(prop)
	var cell := Vector3i(throne_position.x, 0, throne_position.y)
	var world_pos: Vector3 = GridWorld.grid_to_world(cell)
	prop.global_position = world_pos + Vector3(0.0, throne_tile.visual_y_offset, 0.0)
	prop.scale = Vector3.ONE * throne_tile.visual_scale
	# Center the gold pile mesh on the cell (its origin is at one corner).
	GridWorld._center_mesh_xz(prop)


func _is_ore_position(x: int, z: int) -> bool:
	for pos in ore_positions:
		if pos.x == x and pos.y == z:
			return true
	return false


func _on_border_edge(x: int, z: int, w: int, h: int) -> bool:
	return x == -1 or x == w or z == -1 or z == h


## Per-cell yaw for border walls so each side faces inward toward the floor.
## Assumes Synty wall default orientation faces -Z; tweak the per-side offset
## if your wall art faces a different default. Corners arbitrarily choose the
## N/S orientation over E/W.
func _border_wall_yaw(x: int, z: int, w: int, h: int) -> float:
	if z == -1:
		return 180.0  # north edge — face +Z toward room
	if z == h:
		return 0.0    # south edge — face -Z toward room
	if x == -1:
		return 90.0   # west edge — face +X toward room
	if x == w:
		return -90.0  # east edge — face -X toward room
	return 0.0


func _spawn_ring_avatar() -> void:
	if ring_avatar_scene == null:
		push_warning("StarterDungeon: ring_avatar_scene not assigned")
		return
	_ring_avatar = ring_avatar_scene.instantiate()
	add_child(_ring_avatar)
	var spawn_cell := Vector3i(ring_spawn_position.x, 0, ring_spawn_position.y)
	_ring_avatar.global_position = GridWorld.grid_to_world(spawn_cell)


func _spawn_minions() -> void:
	if minion_definition == null or minion_definition.scene == null:
		push_warning("StarterDungeon: minion_definition (or its scene) not assigned")
		return
	for cell in minion_spawn_positions:
		var m: Node3D = minion_definition.scene.instantiate()
		if m is Minion:
			(m as Minion).definition = minion_definition
		add_child(m)
		m.global_position = GridWorld.grid_to_world(Vector3i(cell.x, 0, cell.y))


func _install_mining_system() -> void:
	_mining_system = MiningSystem.new()
	_mining_system.name = "MiningSystem"
	_mining_system.camera_source = _camera_rig
	add_child(_mining_system)


func _install_pickup_system() -> void:
	_pickup_system = PickupSystem.new()
	_pickup_system.name = "PickupSystem"
	_pickup_system.camera_source = _camera_rig
	# Added BEFORE MiningSystem so _input fires here first; if the click
	# grabs a minion, we set_input_as_handled so mining doesn't also fire.
	add_child(_pickup_system)


func _install_haul_system() -> void:
	_haul_system = HaulSystem.new()
	_haul_system.name = "HaulSystem"
	_haul_system.ore_pickup_scene = ore_pickup_scene
	_haul_system.throne_cell = Vector3i(throne_position.x, 0, throne_position.y)
	add_child(_haul_system)


## Point the camera rig at the ring avatar. Without a follow_target, the rig
## stays at its initial position; with one, it lerps and WASD drives the kid
## instead of the camera.
func _attach_camera_to_avatar() -> void:
	if _camera_rig == null:
		return
	if _ring_avatar != null:
		_camera_rig.follow_target = _ring_avatar
		_camera_rig.global_position = _ring_avatar.global_position
		if _ring_avatar.has_method("set_cursor_source"):
			_ring_avatar.call("set_cursor_source", _camera_rig)
	else:
		var cx: float = float(dungeon_size.x - 1) * 0.5 * GridWorld.CELL_SIZE
		var cz: float = float(dungeon_size.y - 1) * 0.5 * GridWorld.CELL_SIZE
		_camera_rig.global_position = Vector3(cx, 0.0, cz)
