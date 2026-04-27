extends Node
## MineAreaSelect — Shift+LMB input for cancel/toggle + drag-to-queue-area.
##
## Click path (press-release on the same cell):
##   - If the cell has a pending MineTask → cancel it via
##     TaskQueue.invalidate_task. BlackboardSync picks up task_invalidated
##     and aborts any minion currently working it.
##   - Else → enqueue a MineTask (same gating as MiningSystem: must be
##     mineable AND fog-revealed).
##
## Drag path (press on cell A, release on cell B):
##   - Enqueue every mineable+revealed cell in the XZ rectangle spanning
##     A→B. Already-queued cells in the rect are skipped.
##
## Uses action `ring_multi_mark` (Shift+LMB). Runs as its own system so
## MiningSystem's plain-LMB path stays narrow and readable.

class_name MineAreaSelect

@export var camera_source: Node

const RAY_LENGTH: float = 80.0
# Match MiningSystem: hit walls + pickups; fall through floors.
const RAY_MASK: int = 1 | 16

var _drag_active: bool = false
var _drag_start_cell: Vector3i = Vector3i.ZERO

# Live preview while dragging — one translucent cyan box covers the XZ
# rectangle between drag-start and cursor cell, so the player sees what
# they're about to queue.
var _preview: MeshInstance3D = null
var _preview_mesh: BoxMesh = null
var _preview_material: StandardMaterial3D = null


func _ready() -> void:
	_preview_material = StandardMaterial3D.new()
	_preview_material.albedo_color = Color(0.3, 0.85, 1.0, 0.22)
	_preview_material.emission_enabled = true
	_preview_material.emission = Color(0.3, 0.85, 1.0)
	_preview_material.emission_energy_multiplier = 0.3
	_preview_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_preview_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_preview_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_preview_mesh = BoxMesh.new()
	_preview = MeshInstance3D.new()
	_preview.mesh = _preview_mesh
	_preview.material_override = _preview_material
	_preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_preview.top_level = true
	_preview.visible = false
	add_child(_preview)


func _process(_delta: float) -> void:
	if not _drag_active:
		if _preview.visible:
			_preview.visible = false
		return
	_update_preview()


func _update_preview() -> void:
	var end_cell: Vector3i = _cursor_cell()
	var xmin: int = mini(_drag_start_cell.x, end_cell.x)
	var xmax: int = maxi(_drag_start_cell.x, end_cell.x)
	var zmin: int = mini(_drag_start_cell.z, end_cell.z)
	var zmax: int = maxi(_drag_start_cell.z, end_cell.z)
	var width_cells: int = xmax - xmin + 1
	var depth_cells: int = zmax - zmin + 1
	var cs: float = GridWorld.CELL_SIZE
	_preview_mesh.size = Vector3(
		width_cells * cs,
		cs,
		depth_cells * cs,
	)
	var center_x: float = (float(xmin + xmax) * 0.5) * cs
	var center_z: float = (float(zmin + zmax) * 0.5) * cs
	_preview.global_position = Vector3(center_x, cs * 0.5, center_z)
	_preview.visible = true


func _unhandled_input(event: InputEvent) -> void:
	# exact_match=true: require shift held. Without this, plain LMB also
	# matches ring_multi_mark (Godot's default ignores modifier state),
	# and a single plain click would first queue via MiningSystem and then
	# toggle-cancel here in the same event cycle.
	if event.is_action_pressed("ring_multi_mark", false, true):
		_on_press()
	elif event.is_action_released("ring_multi_mark", true):
		_on_release()


func _on_press() -> void:
	var cell: Vector3i = _cursor_cell()
	# Allow press even on non-mineable cells — drag may end on a mineable
	# one, and we can still walk the full rectangle. The guard is per-cell
	# at enqueue time, not at press time.
	_drag_start_cell = cell
	_drag_active = true


func _on_release() -> void:
	if not _drag_active:
		return
	_drag_active = false
	var end_cell: Vector3i = _cursor_cell()
	if _drag_start_cell == end_cell:
		_toggle_cell(end_cell)
	else:
		_queue_rect(_drag_start_cell, end_cell)


func _toggle_cell(cell: Vector3i) -> void:
	var existing: TaskResource = _find_mine_task(cell)
	if existing != null:
		TaskQueue.invalidate_task(existing, "cancelled_by_player")
		return
	_try_queue(cell)


func _queue_rect(a: Vector3i, b: Vector3i) -> void:
	var xmin: int = mini(a.x, b.x)
	var xmax: int = maxi(a.x, b.x)
	var zmin: int = mini(a.z, b.z)
	var zmax: int = maxi(a.z, b.z)
	for x in range(xmin, xmax + 1):
		for z in range(zmin, zmax + 1):
			_try_queue(Vector3i(x, 0, z))


func _try_queue(cell: Vector3i) -> void:
	var tile: TileResource = GridWorld.get_tile(cell)
	if tile == null or not tile.is_mineable:
		return
	if not GridWorld.is_cell_revealed(cell):
		return
	if _find_mine_task(cell) != null:
		return
	var task: TaskResource = TaskResource.new()
	task.task_type = TaskResource.TaskType.MINE
	task.grid_position = cell
	task.priority = 1.0
	TaskQueue.add_task(task)


func _find_mine_task(cell: Vector3i) -> TaskResource:
	for t in TaskQueue.all_tasks():
		if t.task_type == TaskResource.TaskType.MINE and t.grid_position == cell:
			return t
	return null


## Same cursor-to-cell path MiningSystem uses, including the Y=0 fallback.
## The fog-reveal gate in _try_queue handles the "fallback landed in
## unrevealed rock" case.
func _cursor_cell() -> Vector3i:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3i(999999, 0, 999999)
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	var params := PhysicsRayQueryParameters3D.create(
		from, from + dir * RAY_LENGTH, RAY_MASK,
	)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(params)
	if not hit.is_empty():
		return GridWorld.tile_at_ray_hit(hit)
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		return GridWorld.tile_at_world(camera_source.call("cursor_world_position"))
	return Vector3i(999999, 0, 999999)
