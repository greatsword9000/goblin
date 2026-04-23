class_name BuildingSystem extends Node
## BuildingSystem — right-click opens build menu → pick buildable → ghost
## follows cursor → left-click places. Creates a BuildTask; Minion picks it
## up and materializes on completion.
##
## Scene-owned (not autoload). StarterDungeon instantiates one, wires the
## camera reference and the list of buildables.

@export var camera_source: Node
@export var buildables: Array[BuildableDefinition] = []

const BUILD_MENU_SCENE: PackedScene = preload("res://ui/build_menu/build_menu.tscn")
const RAY_LENGTH: float = 80.0
const RAY_MASK: int = 1 | 16        # World + Pickups, same as MiningSystem
const GHOST_HEIGHT: float = 2.0

enum Mode { IDLE, PLACING }

var _mode: Mode = Mode.IDLE
var _current: BuildableDefinition = null
var _menu: BuildMenu = null
var _ghost: MeshInstance3D = null
var _ghost_material: StandardMaterial3D = null

## cell -> persistent marker node; amber box visible until the build task
## finishes or is cancelled. Key is Vector3i.
var _pending_markers: Dictionary = {}


func _ready() -> void:
	_menu = BUILD_MENU_SCENE.instantiate()
	add_child(_menu)
	_menu.buildable_chosen.connect(_on_buildable_chosen)
	_menu.cancelled.connect(_on_menu_cancelled)
	EventBus.task_completed.connect(_on_task_completed)
	EventBus.task_invalidated.connect(_on_task_invalidated)


func _unhandled_input(event: InputEvent) -> void:
	match _mode:
		Mode.IDLE:
			# B key opens the build menu. Right-click is reserved for camera rotate.
			if event.is_action_pressed("build_menu"):
				_open_menu()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ring_primary") and not Input.is_key_pressed(KEY_SHIFT):
				# Left-click on a cell with a pending build task cancels it.
				# Runs only if Shift isn't held (Shift+LMB belongs to area-select).
				var cell: Vector3i = _cursor_cell()
				if _pending_markers.has(cell):
					_cancel_pending_at(cell)
					get_viewport().set_input_as_handled()
		Mode.PLACING:
			if event.is_action_pressed("ring_primary"):
				_try_place()
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("build_menu") or event.is_action_pressed("ui_cancel"):
				_exit_placing()
				get_viewport().set_input_as_handled()
			elif event is InputEventMouseMotion:
				_update_ghost()


func _process(_delta: float) -> void:
	if _mode == Mode.PLACING:
		_update_ghost()


func _open_menu() -> void:
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	_menu.show_at(mouse_pos, buildables)


func _on_buildable_chosen(b: BuildableDefinition) -> void:
	_current = b
	_mode = Mode.PLACING
	_spawn_ghost()
	_update_ghost()


func _on_menu_cancelled() -> void:
	pass  # stay IDLE


func _spawn_ghost() -> void:
	if _ghost != null:
		_ghost.queue_free()
	_ghost = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(GridWorld.CELL_SIZE * 0.95, GHOST_HEIGHT, GridWorld.CELL_SIZE * 0.95)
	_ghost.mesh = box
	_ghost_material = StandardMaterial3D.new()
	_ghost_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_material.albedo_color = Color(0.3, 0.9, 0.3, 0.45)
	_ghost_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost.material_override = _ghost_material
	get_tree().current_scene.add_child(_ghost)


func _update_ghost() -> void:
	if _ghost == null:
		return
	var cell: Vector3i = _cursor_cell()
	_ghost.global_position = GridWorld.grid_to_world(cell) + Vector3(0.0, GHOST_HEIGHT * 0.5, 0.0)
	var valid: bool = _can_place_at(cell)
	_ghost_material.albedo_color = (
		Color(0.3, 0.9, 0.3, 0.45) if valid else Color(0.9, 0.3, 0.3, 0.45)
	)


func _can_place_at(cell: Vector3i) -> bool:
	if _current == null:
		return false
	if not GridWorld.is_walkable(cell):
		return false  # must place on a floor cell
	if not GridWorld.is_cell_revealed(cell):
		return false
	if not ResourceManager.can_afford(_current.costs):
		return false
	for t: TaskResource in TaskQueue.all_tasks():
		if t.task_type == TaskResource.TaskType.BUILD and t.grid_position == cell:
			return false
	return true


func _try_place() -> void:
	if _current == null:
		return
	var cell: Vector3i = _cursor_cell()
	if not _can_place_at(cell):
		return
	if not ResourceManager.spend_all(_current.costs):
		return
	var task := TaskResource.new()
	task.task_type = TaskResource.TaskType.BUILD
	task.grid_position = cell
	task.priority = 1.0
	task.payload = {"buildable": _current}
	TaskQueue.add_task(task)
	_spawn_pending_marker(cell)
	print("[BuildingSystem] queued BuildTask %s at %s" % [_current.id, cell])
	_exit_placing()


func _spawn_pending_marker(cell: Vector3i) -> void:
	# Amber translucent box at the cell. Stays until task completes or is
	# cancelled — signals "build queued here" without blocking the minion.
	var marker: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(GridWorld.CELL_SIZE * 0.95, GHOST_HEIGHT, GridWorld.CELL_SIZE * 0.95)
	marker.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.95, 0.70, 0.20, 0.35)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marker.material_override = mat
	get_tree().current_scene.add_child(marker)
	marker.global_position = GridWorld.grid_to_world(cell) + Vector3(0.0, GHOST_HEIGHT * 0.5, 0.0)
	_pending_markers[cell] = marker


func _remove_marker(cell: Vector3i) -> void:
	if not _pending_markers.has(cell):
		return
	var m: Node = _pending_markers[cell]
	if is_instance_valid(m):
		m.queue_free()
	_pending_markers.erase(cell)


func _on_task_completed(task: TaskResource) -> void:
	if task == null or task.task_type != TaskResource.TaskType.BUILD:
		return
	_remove_marker(task.grid_position)


func _on_task_invalidated(task: TaskResource, _reason: String) -> void:
	if task == null or task.task_type != TaskResource.TaskType.BUILD:
		return
	_remove_marker(task.grid_position)


func _cancel_pending_at(cell: Vector3i) -> void:
	var pending: TaskResource = null
	for t: TaskResource in TaskQueue.all_tasks():
		if t.task_type == TaskResource.TaskType.BUILD and t.grid_position == cell:
			pending = t
			break
	if pending == null:
		_remove_marker(cell)  # orphan marker — safety cleanup
		return
	# Full refund only if no minion has claimed it yet. Once claimed, the
	# minion's time is "spent" — no refund for Phase 1 (refund policy refine-
	# able later).
	var buildable: BuildableDefinition = pending.payload.get("buildable", null) as BuildableDefinition
	if not pending.claimed and buildable != null:
		for key: String in buildable.costs.keys():
			ResourceManager.gain(str(key), int(buildable.costs[key]))
	TaskQueue.invalidate_task(pending, "cancelled_by_player")
	print("[BuildingSystem] cancelled BuildTask at %s" % cell)


func _exit_placing() -> void:
	if _ghost != null:
		_ghost.queue_free()
		_ghost = null
	_ghost_material = null
	_mode = Mode.IDLE
	_current = null


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
