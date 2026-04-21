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
# World (1) + Minions (2) + Pickups (16) — walls, goblins, gems
const PHYSICS_MASK: int = 1 | 2 | 16
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

	# Flat quad so there's no thickness ledge sitting above the floor.
	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(GridWorld.CELL_SIZE, GridWorld.CELL_SIZE)

	_highlight = MeshInstance3D.new()
	_highlight.mesh = plane
	_highlight.material_override = _material
	_highlight.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_highlight)
	_highlight.visible = false


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_highlight.visible = false
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

		# 1. Grabbable entity? Put the slab above it.
		var grabbable: Node3D = _resolve_highlight_target(collider as Node)
		if grabbable != null:
			var above: float = grabbable.global_position.y + 1.4
			_show_at(grabbable.global_position, above, COLOR_GRABBABLE)
			return

		# 2. Static world hit → lookup cell. Slab sits AT the hit Y so the
		# floor hit shows on the floor, the wall hit shows on top of wall.
		var grid_pos: Vector3i = GridWorld.tile_at_world(hit_pos)
		var tile: TileResource = GridWorld.get_tile(grid_pos)
		var y: float = hit_pos.y + 0.05
		if tile != null and tile.is_mineable:
			_show_at(GridWorld.grid_to_world(grid_pos), y, COLOR_MINEABLE)
			return
		if tile != null and tile.is_walkable:
			_show_at(GridWorld.grid_to_world(grid_pos), y, COLOR_WALKABLE)
			return

	# Fallback: math intersection with Y=0 (only fires when no physics hit,
	# e.g. pointing past the dungeon edge into the void).
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		var world_pos: Vector3 = camera_source.call("cursor_world_position")
		var grid_pos2: Vector3i = GridWorld.tile_at_world(world_pos)
		var tile2: TileResource = GridWorld.get_tile(grid_pos2)
		if tile2 != null and tile2.is_mineable:
			_show_at(GridWorld.grid_to_world(grid_pos2), 0.05, COLOR_MINEABLE)
			return
		if tile2 != null and tile2.is_walkable:
			_show_at(GridWorld.grid_to_world(grid_pos2), 0.05, COLOR_WALKABLE)
			return
	_highlight.visible = false


func _show_at(world_pos: Vector3, y: float, color: Color) -> void:
	_highlight.global_position = Vector3(world_pos.x, y, world_pos.z)
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
