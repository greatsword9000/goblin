extends Node3D
## TaskMarkerRenderer — draws a persistent translucent plane at every
## cell that has a pending MineTask. Lets the player see their queue
## while it's being worked.
##
## Listens:
##   EventBus.task_created   → add a marker at the task's cell
##   EventBus.tile_mined     → remove marker for that cell
##   EventBus.task_failed    → remove marker if the task was dropped
##                             (not re-queued)
##
## Markers are pooled — one MeshInstance3D per cell. Cheap at Phase 1 scale.

class_name TaskMarkerRenderer

const MARKER_COLOR: Color = Color(1.0, 0.55, 0.15, 0.45)

var _markers: Dictionary = {}   # Vector3i cell -> MeshInstance3D
var _material: StandardMaterial3D
var _mesh: PlaneMesh


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.albedo_color = MARKER_COLOR
	_material.emission_enabled = true
	_material.emission = MARKER_COLOR
	_material.emission_energy_multiplier = 0.5
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_mesh = PlaneMesh.new()
	_mesh.size = Vector2(GridWorld.CELL_SIZE * 0.95, GridWorld.CELL_SIZE * 0.95)

	EventBus.task_created.connect(_on_task_created)
	EventBus.tile_mined.connect(_on_tile_mined)
	EventBus.task_failed.connect(_on_task_failed)


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


func _add_marker(cell: Vector3i) -> void:
	if _markers.has(cell):
		return  # one marker per cell
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = _mesh
	mi.material_override = _material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var world_pos: Vector3 = GridWorld.grid_to_world(cell)
	mi.global_position = Vector3(world_pos.x, 0.07, world_pos.z)
	_markers[cell] = mi


func _remove_marker(cell: Vector3i) -> void:
	var mi: MeshInstance3D = _markers.get(cell, null)
	if mi == null:
		return
	mi.queue_free()
	_markers.erase(cell)
