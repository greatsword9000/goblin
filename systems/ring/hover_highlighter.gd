extends Node3D
## HoverHighlighter — translucent overlay at whatever the cursor targets.
## Positions the highlight meshes from the target's global_position so
## scale on the target (e.g. floor visual at scale 0.4) doesn't shrink
## the highlight. Y comes from the target's actual world position, not
## computed from guesses.

class_name HoverHighlighter

const RAY_LENGTH: float = 80.0
const PHYSICS_MASK: int = 1 | 2 | 16  # World + Minions + Pickups

const COLOR_GRABBABLE: Color = Color(0.35, 1.0, 0.45, 0.45)
const COLOR_MINEABLE:  Color = Color(1.0, 0.72, 0.25, 0.40)
const COLOR_WALKABLE:  Color = Color(0.45, 0.75, 1.0, 0.30)

@export var camera_source: Node

var _diagnostic_printed: Dictionary = {"floor": false, "wall": false}

var _plane: MeshInstance3D
var _box: MeshInstance3D
var _plane_material: StandardMaterial3D
var _box_material: StandardMaterial3D


func _ready() -> void:
	_plane_material = _make_material(COLOR_WALKABLE)
	_box_material = _make_material(COLOR_MINEABLE)

	var plane: PlaneMesh = PlaneMesh.new()
	plane.size = Vector2(GridWorld.CELL_SIZE * 0.98, GridWorld.CELL_SIZE * 0.98)
	_plane = MeshInstance3D.new()
	_plane.mesh = plane
	_plane.material_override = _plane_material
	_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_plane.top_level = true  # ignore our own transform
	_plane.visible = false
	add_child(_plane)

	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(
		GridWorld.CELL_SIZE * 1.02,
		GridWorld.CELL_SIZE * 2.02,
		GridWorld.CELL_SIZE * 1.02,
	)
	_box = MeshInstance3D.new()
	_box.mesh = box
	_box.material_override = _box_material
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box.top_level = true
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
			var pos: Vector3 = grabbable.global_position + Vector3(0.0, 1.5, 0.0)
			_show_plane(pos, COLOR_GRABBABLE)
			return

		var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
		var grid_pos: Vector3i = GridWorld.tile_at_world(hit_pos)
		var tile: TileResource = GridWorld.get_tile(grid_pos)
		var visual: Node3D = GridWorld.get_visual(grid_pos)
		if tile != null and visual != null:
			if tile.is_mineable:
				if not _diagnostic_printed["wall"]:
					_diagnostic_printed["wall"] = true
					var aabb := _measure_aabb(visual)
					print("[Hover DIAG wall] visual.gp=%s  scale=%s  aabb min=%s size=%s" % [
						visual.global_position, visual.scale, aabb.position, aabb.size,
					])
				_show_box(visual.global_position, COLOR_MINEABLE)
				return
			if tile.is_walkable:
				if not _diagnostic_printed["floor"]:
					_diagnostic_printed["floor"] = true
					var aabb := _measure_aabb(visual)
					print("[Hover DIAG floor] visual.gp=%s  scale=%s  aabb min=%s size=%s" % [
						visual.global_position, visual.scale, aabb.position, aabb.size,
					])
				# Plane sits on top of the visible floor mesh.
				var top_y: float = _top_world_y(visual)
				_show_plane(Vector3(visual.global_position.x, top_y + 0.02, visual.global_position.z), COLOR_WALKABLE)
				return

	# Fallback: past-edge — math y=0 intersection.
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		var fallback_pos: Vector3 = camera_source.call("cursor_world_position")
		var cell2: Vector3i = GridWorld.tile_at_world(fallback_pos)
		var visual2: Node3D = GridWorld.get_visual(cell2)
		var tile2: TileResource = GridWorld.get_tile(cell2)
		if visual2 != null and tile2 != null:
			if tile2.is_mineable:
				_show_box(visual2.global_position, COLOR_MINEABLE)
				return
			if tile2.is_walkable:
				var pos: Vector3 = visual2.global_position + Vector3(0.0, 0.03, 0.0)
				_show_plane(pos, COLOR_WALKABLE)
				return
	_hide_all()


func _show_plane(world_pos: Vector3, color: Color) -> void:
	_plane.global_position = world_pos
	_plane_material.albedo_color = color
	_plane_material.emission = color
	_plane.visible = true
	_box.visible = false


func _show_box(world_pos: Vector3, color: Color) -> void:
	_box.global_position = world_pos
	_box_material.albedo_color = color
	_box_material.emission = color
	_box.visible = true
	_plane.visible = false


func _hide_all() -> void:
	_plane.visible = false
	_box.visible = false


## Returns the top-Y of the visible mesh in world space. Walks every
## MeshInstance3D under `root`, converts its AABB to world via global_transform,
## and takes the max Y. Used so the floor plane sits on the actual mesh top
## regardless of Synty prefab internal transforms.
func _top_world_y(root: Node3D) -> float:
	var max_y: float = root.global_position.y
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var world_aabb: AABB = m.global_transform * m.mesh.get_aabb()
		var top: float = world_aabb.position.y + world_aabb.size.y
		if top > max_y:
			max_y = top
	return max_y


func _measure_aabb(root: Node3D) -> AABB:
	var first: bool = true
	var combined := AABB()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.mesh == null:
			continue
		var world_aabb: AABB = m.global_transform * m.mesh.get_aabb()
		if first:
			combined = world_aabb
			first = false
		else:
			combined = combined.merge(world_aabb)
	return combined


func _resolve_highlight_target(node: Node) -> Node3D:
	var cursor: Node = node
	for _i in range(4):
		if cursor == null:
			break
		if cursor is Minion or cursor is OrePickup:
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null
