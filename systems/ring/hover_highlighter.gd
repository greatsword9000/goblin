extends Node3D
## HoverHighlighter — shows a flat translucent plane at the target cell,
## color-coded by what would happen on click. Physics raycast drives
## detection so any visible surface of a wall / entity / floor counts.
##
##   Amber = mineable wall cell  (clicks send a mine task)
##   Blue  = walkable floor cell (click has no effect right now)
##   Green = grabbable entity    (click lifts it)

class_name HoverHighlighter

const RAY_LENGTH: float = 80.0
# World (1) + Minions (2) + Pickups (16)
const PHYSICS_MASK: int = 1 | 2 | 16

const COLOR_GRABBABLE: Color = Color(0.35, 1.0, 0.45, 0.55)
const COLOR_MINEABLE:  Color = Color(1.0, 0.72, 0.25, 0.55)
const COLOR_WALKABLE:  Color = Color(0.45, 0.75, 1.0, 0.35)

@export var camera_source: Node

var _plane: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR_MINEABLE
	_material.emission_enabled = true
	_material.emission = COLOR_MINEABLE
	_material.emission_energy_multiplier = 0.7
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# No_depth_test so it draws over the floor mesh even with minor z-overlap
	_material.no_depth_test = false

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(GridWorld.CELL_SIZE, GridWorld.CELL_SIZE)

	_plane = MeshInstance3D.new()
	_plane.mesh = plane
	_plane.material_override = _material
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_plane)
	_plane.visible = false


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_plane.visible = false
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
			# Flat plane on the floor at the grabbable's cell.
			var cell: Vector3i = GridWorld.tile_at_world(grabbable.global_position)
			_show_at_cell(cell, COLOR_GRABBABLE)
			return

		var grid_pos: Vector3i = GridWorld.tile_at_world(hit_pos)
		var tile: TileResource = GridWorld.get_tile(grid_pos)
		if tile != null and tile.is_mineable:
			_show_at_cell(grid_pos, COLOR_MINEABLE)
			return
		if tile != null and tile.is_walkable:
			_show_at_cell(grid_pos, COLOR_WALKABLE)
			return

	# Fallback: past the edge — math y=0 intersection.
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		var fallback_pos: Vector3 = camera_source.call("cursor_world_position")
		var cell2: Vector3i = GridWorld.tile_at_world(fallback_pos)
		var tile2: TileResource = GridWorld.get_tile(cell2)
		if tile2 != null and tile2.is_mineable:
			_show_at_cell(cell2, COLOR_MINEABLE)
			return
		if tile2 != null and tile2.is_walkable:
			_show_at_cell(cell2, COLOR_WALKABLE)
			return
	_plane.visible = false


func _show_at_cell(cell: Vector3i, color: Color) -> void:
	var world_pos: Vector3 = GridWorld.grid_to_world(cell)
	# Just above the floor surface. Floor top is at ~y=0; 0.06 avoids
	# z-fighting without looking like a ledge.
	_plane.global_position = Vector3(world_pos.x, 0.06, world_pos.z)
	_material.albedo_color = color
	_material.emission = color
	_plane.visible = true


func _resolve_highlight_target(node: Node) -> Node3D:
	var cursor: Node = node
	for _i in range(4):
		if cursor == null:
			break
		if cursor is Minion or cursor is OrePickup:
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null
