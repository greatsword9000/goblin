extends Node3D
## HoverHighlighter — attaches a translucent highlight to whatever node
## the cursor targets (floor visual / wall visual / grabbable entity).
## The highlight is REPARENTED each frame so its transform is inherited
## directly from the target. No Y math, no drift.
##
## Modes:
##   Wall cell     → amber box wrapping the wall visual
##   Floor cell    → blue flat plane flush with floor's top surface
##   Grabbable     → green flat plane on the cell under the entity

class_name HoverHighlighter

const RAY_LENGTH: float = 80.0
const PHYSICS_MASK: int = 1 | 2 | 16  # World + Minions + Pickups

const COLOR_GRABBABLE: Color = Color(0.35, 1.0, 0.45, 0.45)
const COLOR_MINEABLE:  Color = Color(1.0, 0.72, 0.25, 0.40)
const COLOR_WALKABLE:  Color = Color(0.45, 0.75, 1.0, 0.30)

@export var camera_source: Node

# A floor/grabbable highlight is a flat plane; wall highlight wraps with
# a box. Two separate meshes, one at a time visible.
var _plane: MeshInstance3D
var _box: MeshInstance3D
var _plane_material: StandardMaterial3D
var _box_material: StandardMaterial3D

# Track current parent so we can unparent when moving to a new target.
var _current_parent: Node = null
var _current_mesh: MeshInstance3D = null


func _ready() -> void:
	_plane_material = _make_material(COLOR_WALKABLE)
	_box_material = _make_material(COLOR_MINEABLE)

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(GridWorld.CELL_SIZE, GridWorld.CELL_SIZE)
	_plane = MeshInstance3D.new()
	_plane.mesh = plane
	_plane.material_override = _plane_material
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane.visible = false
	add_child(_plane)  # starts parented to self; reparented on first show

	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(GridWorld.CELL_SIZE * 1.02, GridWorld.CELL_SIZE * 2.0, GridWorld.CELL_SIZE * 1.02)
	_box = MeshInstance3D.new()
	_box.mesh = box
	_box.material_override = _box_material
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box.visible = false
	add_child(_box)


func _make_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 0.5
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
		var grabbable: Node3D = _resolve_highlight_target(collider as Node)
		if grabbable != null:
			# Parent flat plane to the entity; offset up so it doesn't clip into mesh.
			_attach_plane(grabbable, Vector3(0.0, 1.5, 0.0), COLOR_GRABBABLE)
			return

		# Static world hit: find the GridWorld cell and its visual, parent
		# the highlight to it so Y is automatic.
		var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
		var grid_pos: Vector3i = GridWorld.tile_at_world(hit_pos)
		var tile: TileResource = GridWorld.get_tile(grid_pos)
		var visual: Node3D = GridWorld.get_visual(grid_pos)
		if tile != null and visual != null:
			if tile.is_mineable:
				# Wall: box wraps the visual. Offset so box bottom sits on ground.
				_attach_box(visual, Vector3(0.0, GridWorld.CELL_SIZE, 0.0), COLOR_MINEABLE)
				return
			if tile.is_walkable:
				# Floor: plane on top of the floor visual. Tiny offset to
				# avoid z-fight with the floor's surface.
				_attach_plane(visual, Vector3(0.0, 0.02, 0.0), COLOR_WALKABLE)
				return

	# Fallback: past-edge or empty tile — math y=0 intersection.
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		var fallback_pos: Vector3 = camera_source.call("cursor_world_position")
		var cell2: Vector3i = GridWorld.tile_at_world(fallback_pos)
		var visual2: Node3D = GridWorld.get_visual(cell2)
		var tile2: TileResource = GridWorld.get_tile(cell2)
		if visual2 != null and tile2 != null:
			if tile2.is_mineable:
				_attach_box(visual2, Vector3(0.0, GridWorld.CELL_SIZE, 0.0), COLOR_MINEABLE)
				return
			if tile2.is_walkable:
				_attach_plane(visual2, Vector3(0.0, 0.02, 0.0), COLOR_WALKABLE)
				return
	_hide_all()


func _attach_plane(parent: Node, local_offset: Vector3, color: Color) -> void:
	_reparent(_plane, parent)
	_plane.position = local_offset
	_plane_material.albedo_color = color
	_plane_material.emission = color
	_plane.visible = true
	_box.visible = false
	_current_mesh = _plane


func _attach_box(parent: Node, local_offset: Vector3, color: Color) -> void:
	_reparent(_box, parent)
	_box.position = local_offset
	_box_material.albedo_color = color
	_box_material.emission = color
	_box.visible = true
	_plane.visible = false
	_current_mesh = _box


func _reparent(node: MeshInstance3D, new_parent: Node) -> void:
	if node.get_parent() == new_parent:
		return
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	new_parent.add_child(node)
	# Clear any transform inherited from previous reparenting.
	node.position = Vector3.ZERO
	node.rotation = Vector3.ZERO
	node.scale = Vector3.ONE


func _hide_all() -> void:
	_plane.visible = false
	_box.visible = false


func _resolve_highlight_target(node: Node) -> Node3D:
	var cursor: Node = node
	for _i in range(4):
		if cursor == null:
			break
		if cursor is Minion or cursor is OrePickup:
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null
