extends Node3D
## HoverHighlighter — shows a translucent box at whatever the cursor would
## hit if clicked right now. Same raycast rules as PickupSystem and the
## same cell lookup as MiningSystem, so what you see is what you'll act on.
##
## Priority (first match wins):
##   1. Grabbable entity (Minion, OrePickup) → green box at entity center
##   2. Mineable grid cell (ore/stone wall) → amber box at cell center
##   3. Walkable grid cell under cursor     → faint blue box (info only)
##
## Runs every frame. Toggles visibility as the priority changes.

class_name HoverHighlighter

const RAY_LENGTH: float = 80.0
const GRABBABLE_MASK: int = 2 | 16  # Minions + Pickups
const COLOR_GRABBABLE: Color = Color(0.35, 1.0, 0.45, 0.55)
const COLOR_MINEABLE: Color = Color(1.0, 0.72, 0.25, 0.55)
const COLOR_WALKABLE: Color = Color(0.45, 0.75, 1.0, 0.20)

@export var camera_source: Node

var _highlight: MeshInstance3D
var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = COLOR_MINEABLE
	_material.emission_enabled = true
	_material.emission = COLOR_MINEABLE
	_material.emission_energy_multiplier = 0.6
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(GridWorld.CELL_SIZE, GridWorld.CELL_SIZE * 0.1, GridWorld.CELL_SIZE)

	_highlight = MeshInstance3D.new()
	_highlight.mesh = box
	_highlight.material_override = _material
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_highlight.visible = false


func _process(_delta: float) -> void:
	if camera_source == null or not camera_source.has_method("cursor_world_position"):
		_highlight.visible = false
		return

	# First: physics raycast for a grabbable entity under the cursor.
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam != null:
		var mouse: Vector2 = get_viewport().get_mouse_position()
		var from: Vector3 = cam.project_ray_origin(mouse)
		var dir: Vector3 = cam.project_ray_normal(mouse)
		var params := PhysicsRayQueryParameters3D.create(from, from + dir * RAY_LENGTH, GRABBABLE_MASK)
		var hit := cam.get_world_3d().direct_space_state.intersect_ray(params)
		if not hit.is_empty():
			var collider: Object = hit.get("collider")
			var target: Node3D = _resolve_highlight_target(collider as Node)
			if target != null:
				_show_at(target.global_position, COLOR_GRABBABLE)
				return

	# Otherwise: the cell under the ground-plane hit.
	var world_pos: Vector3 = camera_source.call("cursor_world_position")
	var grid_pos: Vector3i = GridWorld.tile_at_world(world_pos)
	var tile: TileResource = GridWorld.get_tile(grid_pos)
	if tile != null and tile.is_mineable:
		_show_at(GridWorld.grid_to_world(grid_pos), COLOR_MINEABLE)
		return
	if tile != null and tile.is_walkable:
		_show_at(GridWorld.grid_to_world(grid_pos), COLOR_WALKABLE)
		return
	_highlight.visible = false


func _show_at(world_pos: Vector3, color: Color) -> void:
	_highlight.global_position = Vector3(world_pos.x, 0.05, world_pos.z)
	_material.albedo_color = color
	_material.emission = color
	_highlight.visible = true


func _resolve_highlight_target(node: Node) -> Node3D:
	# Walk up from a collision hit to find the owning Minion or OrePickup.
	var cursor: Node = node
	for _i in range(4):
		if cursor == null:
			break
		if cursor is Minion or cursor is OrePickup:
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null
