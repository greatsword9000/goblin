class_name StarterDungeon extends Node3D
## StarterDungeon — hand-authored 10×10 Phase 1 prototype layout.
##
## Phase 1 spawns the layout in _ready(); procgen comes in Phase 3+.
## Also registers the visual root with GridWorld and the camera with
## DebugOverlay so overlay can report the tile under the cursor.

@export var floor_tile: TileResource
@export var cave_rock_tile: TileResource
@export var throne_base_tile: TileResource
@export var throne_tile: TileResource        # (decorative chest prop on top of base)
@export var ring_avatar_scene: PackedScene
@export var minion_definition: MinionDefinition

## World half-extent. world_radius = 50 means a 101×101 cell playfield
## centered on the origin (cells -50..+50 in X and Z).
@export var world_radius: int = 50
## Pre-carved rectangular "home" carved out of the rock on game start.
@export var home_min: Vector2i = Vector2i(0, 0)
@export var home_max: Vector2i = Vector2i(9, 9)
## Grid-coords (x, z) of the throne dais — must be inside the home area.
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
var _hover_highlighter: HoverHighlighter = null
var _task_marker_renderer: TaskMarkerRenderer = null
var _fog_of_war: FogOfWar = null

@export var ore_pickup_scene: PackedScene


func _ready() -> void:
	GridWorld.register_visual_root(_tile_root)
	DebugOverlay.register_camera(_camera_rig)
	_generate_world()
	_spawn_throne_prop()
	_spawn_ring_avatar()
	_attach_camera_to_avatar()
	_spawn_minions()
	_install_pickup_system()
	_install_mining_system()
	_install_haul_system()
	_install_hover_highlighter()
	_install_task_marker_renderer()
	_install_fog_of_war()


func _generate_world() -> void:
	# Tile data for the entire 101×101 world; visuals stay dormant until
	# fog-of-war reveals them. Home interior + throne dais carved out of rock.
	WorldGenerator.generate(
		cave_rock_tile,
		floor_tile,
		throne_base_tile,
		world_radius,
		home_min,
		home_max,
		throne_position,
	)
	# Reveal the home interior immediately so the player sees their starting
	# chamber even before they move. FogOfWar will extend reveal from there.
	WorldGenerator.reveal_rect(home_min, home_max)


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


func _install_fog_of_war() -> void:
	if _ring_avatar == null:
		return
	_fog_of_war = FogOfWar.new()
	_fog_of_war.name = "FogOfWar"
	add_child(_fog_of_war)
	_fog_of_war.sight_source_path = _fog_of_war.get_path_to(_ring_avatar)
	_fog_of_war.recompute_now()


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


func _install_hover_highlighter() -> void:
	_hover_highlighter = HoverHighlighter.new()
	_hover_highlighter.name = "HoverHighlighter"
	_hover_highlighter.camera_source = _camera_rig
	add_child(_hover_highlighter)


func _install_task_marker_renderer() -> void:
	_task_marker_renderer = TaskMarkerRenderer.new()
	_task_marker_renderer.name = "TaskMarkerRenderer"
	add_child(_task_marker_renderer)


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
		var cx: float = float(home_min.x + home_max.x) * 0.5 * GridWorld.CELL_SIZE
		var cz: float = float(home_min.y + home_max.y) * 0.5 * GridWorld.CELL_SIZE
		_camera_rig.global_position = Vector3(cx, 0.0, cz)
