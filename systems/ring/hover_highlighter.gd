extends Node3D
## HoverHighlighter — shows a translucent overlay at whatever the cursor
## would target if clicked right now. Same raycast rules as PickupSystem
## and MiningSystem so WYSIWYG.
##
## Modes (first match wins):
##   Grabbable entity (Minion, OrePickup) → small green marker above entity
##   Mineable wall cell                   → full-height amber cube around the wall
##   Walkable floor cell                  → flat blue plane on the floor surface

class_name HoverHighlighter

const RAY_LENGTH: float = 80.0
# World (1) + Minions (2) + Pickups (16)
const PHYSICS_MASK: int = 1 | 2 | 16
# Walls are 2x CELL_SIZE tall (see GridWorld._make_primitive)
const WALL_HEIGHT_CELLS: float = 2.0

const COLOR_GRABBABLE: Color = Color(0.35, 1.0, 0.45, 0.45)
const COLOR_MINEABLE:  Color = Color(1.0, 0.72, 0.25, 0.35)
const COLOR_WALKABLE:  Color = Color(0.45, 0.75, 1.0, 0.35)

@export var camera_source: Node

# Two separate MeshInstance3Ds so we can swap between a tall wall-wrap box
# and a flat floor plane without rebuilding the mesh each frame.
var _wall_box: MeshInstance3D
var _floor_plane: MeshInstance3D
var _entity_box: MeshInstance3D

var _wall_material: StandardMaterial3D
var _floor_material: StandardMaterial3D
var _entity_material: StandardMaterial3D


func _ready() -> void:
	_wall_material = _make_material(COLOR_MINEABLE)
	_floor_material = _make_material(COLOR_WALKABLE)
	_entity_material = _make_material(COLOR_GRABBABLE)

	var cell: float = GridWorld.CELL_SIZE

	# Wall wrap — box matching wall visual dimensions.
	var wall_mesh: BoxMesh = BoxMesh.new()
	wall_mesh.size = Vector3(cell, cell * WALL_HEIGHT_CELLS, cell)
	_wall_box = MeshInstance3D.new()
	_wall_box.mesh = wall_mesh
	_wall_box.material_override = _wall_material
	_wall_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_wall_box)

	# Floor plane — flat quad, sits on the floor surface.
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(cell, cell)
	_floor_plane = MeshInstance3D.new()
	_floor_plane.mesh = plane
	_floor_plane.material_override = _floor_material
	_floor_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_floor_plane)

	# Entity marker — small box above the target.
	var ent_mesh: BoxMesh = BoxMesh.new()
	ent_mesh.size = Vector3(0.6, 0.2, 0.6)
	_entity_box = MeshInstance3D.new()
	_entity_box.mesh = ent_mesh
	_entity_box.material_override = _entity_material
	_entity_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_entity_box)

	_hide_all()


func _make_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.6
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_hide_all()
		return

	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	var params := PhysicsRayQueryParameters3D.create(
		from, from + dir * RAY_LENGTH, PHYSICS_MASK,
	)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(params)

	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)

		var grabbable: Node3D = _resolve_highlight_target(collider as Node)
		if grabbable != null:
			_show_entity(grabbable.global_position)
			return

		var grid_pos: Vector3i = GridWorld.tile_at_world(hit_pos)
		var tile: TileResource = GridWorld.get_tile(grid_pos)
		if tile != null and tile.is_mineable:
			_show_wall(grid_pos)
			return
		if tile != null and tile.is_walkable:
			_show_floor(grid_pos)
			return

	# Fallback: past-edge, use math y=0 intersection to still show floor hint.
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		var fallback_pos: Vector3 = camera_source.call("cursor_world_position")
		var cell: Vector3i = GridWorld.tile_at_world(fallback_pos)
		var tile2: TileResource = GridWorld.get_tile(cell)
		if tile2 != null and tile2.is_mineable:
			_show_wall(cell)
			return
		if tile2 != null and tile2.is_walkable:
			_show_floor(cell)
			return
	_hide_all()


func _show_wall(cell: Vector3i) -> void:
	_wall_box.visible = true
	_floor_plane.visible = false
	_entity_box.visible = false
	var world_pos: Vector3 = GridWorld.grid_to_world(cell)
	# Wall box is 4m tall, centered at box origin; sit it so its bottom
	# aligns with the ground.
	_wall_box.global_position = Vector3(
		world_pos.x, GridWorld.CELL_SIZE * WALL_HEIGHT_CELLS * 0.5, world_pos.z,
	)


func _show_floor(cell: Vector3i) -> void:
	_wall_box.visible = false
	_floor_plane.visible = true
	_entity_box.visible = false
	var world_pos: Vector3 = GridWorld.grid_to_world(cell)
	# Just above floor surface to prevent z-fighting with Synty floor mesh.
	_floor_plane.global_position = Vector3(world_pos.x, 0.06, world_pos.z)


func _show_entity(entity_pos: Vector3) -> void:
	_wall_box.visible = false
	_floor_plane.visible = false
	_entity_box.visible = true
	_entity_box.global_position = entity_pos + Vector3(0.0, 1.6, 0.0)


func _hide_all() -> void:
	_wall_box.visible = false
	_floor_plane.visible = false
	_entity_box.visible = false


func _resolve_highlight_target(node: Node) -> Node3D:
	var cursor: Node = node
	for _i in range(4):
		if cursor == null:
			break
		if cursor is Minion or cursor is OrePickup:
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null
