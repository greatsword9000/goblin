extends Node3D
## TaskMarkerRenderer — draws a persistent translucent plane at every
## cell that has a pending MineTask. Lets the player see their queue
## while it's being worked.
##
## Listens:
##   EventBus.task_created     → add a marker at the task's cell
##   EventBus.tile_mined       → remove marker for that cell
##   EventBus.task_failed      → remove marker if the task was dropped
##                               (not re-queued)
##   EventBus.task_invalidated → remove marker (player cancel / world change)
##
## Markers are pooled — one MeshInstance3D per cell. Cheap at Phase 1 scale.

class_name TaskMarkerRenderer

# Floor-cell marker (currently unused in Phase 1 but reserved for future
# walk-to / build / haul task markers).
const FLOOR_MARKER_COLOR: Color = Color(1.0, 0.55, 0.15, 0.45)
# Wall-cell marker — distinct from hover's orange (COLOR_MINEABLE) and the
# ring avatar's pink so queued-for-mining reads as its own state.
const WALL_MARKER_COLOR: Color = Color(0.3, 0.85, 1.0, 0.35)

var _markers: Dictionary = {}   # Vector3i cell -> MeshInstance3D
var _floor_material: StandardMaterial3D
var _wall_material: StandardMaterial3D
var _floor_mesh: PlaneMesh
var _wall_mesh: BoxMesh


func _ready() -> void:
	_floor_material = _make_unshaded_alpha(FLOOR_MARKER_COLOR)
	_wall_material = _make_unshaded_alpha(WALL_MARKER_COLOR)

	_floor_mesh = PlaneMesh.new()
	_floor_mesh.size = Vector2(GridWorld.CELL_SIZE * 0.95, GridWorld.CELL_SIZE * 0.95)

	# Wall wrap slightly larger than the cube so the tint sits just outside
	# the opaque rock surface (avoids z-fighting with the cube's own mesh).
	_wall_mesh = BoxMesh.new()
	_wall_mesh.size = Vector3(
		GridWorld.CELL_SIZE * 1.04,
		GridWorld.CELL_SIZE * 1.04,
		GridWorld.CELL_SIZE * 1.04,
	)

	EventBus.task_created.connect(_on_task_created)
	EventBus.tile_mined.connect(_on_tile_mined)
	EventBus.task_failed.connect(_on_task_failed)
	EventBus.task_invalidated.connect(_on_task_invalidated)


func _make_unshaded_alpha(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 0.5
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Draw transparent without writing depth, so it doesn't z-fight against
	# the opaque cube underneath.
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	return m


func _on_task_created(task: TaskResource) -> void:
	if task == null or task.task_type != TaskResource.TaskType.MINE:
		return
	_add_marker(task.grid_position)


func _on_tile_mined(grid_pos: Vector3i, _tile: TileResource) -> void:
	_remove_marker(grid_pos)


func _on_task_failed(task: TaskResource, _reason: String) -> void:
	# task_failed fires whether the task was re-queued or dropped. We only
	# want to remove markers when no other task for the cell exists.
	if task == null or task.task_type != TaskResource.TaskType.MINE:
		return
	# Check: is there still a pending task at this cell? If so, leave marker.
	for t in TaskQueue.all_tasks():
		if t.task_type == TaskResource.TaskType.MINE and t.grid_position == task.grid_position:
			return
	_remove_marker(task.grid_position)


func _on_task_invalidated(task: TaskResource, _reason: String) -> void:
	# Invalidated tasks are erased from the queue by TaskQueue, so no
	# re-queue check needed — just drop the marker.
	if task == null or task.task_type != TaskResource.TaskType.MINE:
		return
	_remove_marker(task.grid_position)


func _add_marker(cell: Vector3i) -> void:
	if _markers.has(cell):
		return  # one marker per cell
	var tile: TileResource = GridWorld.get_tile(cell)
	var is_wall: bool = tile != null and tile.is_mineable
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var world_pos: Vector3 = GridWorld.grid_to_world(cell)
	if is_wall:
		# Wrap the 2x2x2 wall cube so the tint sits over its sides + top.
		# Cube spans Y=[0, CELL_SIZE]; its center is at Y = CELL_SIZE/2.
		mi.mesh = _wall_mesh
		mi.material_override = _wall_material
		mi.global_position = Vector3(world_pos.x, GridWorld.CELL_SIZE * 0.5, world_pos.z)
	else:
		mi.mesh = _floor_mesh
		mi.material_override = _floor_material
		mi.global_position = Vector3(world_pos.x, 0.07, world_pos.z)
	_markers[cell] = mi


func _remove_marker(cell: Vector3i) -> void:
	var mi: MeshInstance3D = _markers.get(cell, null)
	if mi == null:
		return
	mi.queue_free()
	_markers.erase(cell)
