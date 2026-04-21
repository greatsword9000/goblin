extends Node
## MiningSystem — handles LMB click on mineable tiles → creates MineTask.
##
## Listens to raw mouse input. Cast a ray from the camera through the cursor
## onto the XZ ground plane, snap to grid, check the tile at that cell is
## mineable, enqueue a MineTask. If the tile is NOT mineable, no-op.
##
## Scene-owned (not autoload) — StarterDungeon instantiates one and wires
## the camera reference.

class_name MiningSystem

@export var camera_source: Node  # must provide cursor_world_position() -> Vector3


const RAY_LENGTH: float = 80.0
# World (1) + Pickups (16) — hit walls, fall through for minions.
const RAY_MASK: int = 1 | 16


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ring_primary"):
		return
	var grid_pos: Vector3i = _cursor_cell()
	var tile: TileResource = GridWorld.get_tile(grid_pos)
	if tile == null or not tile.is_mineable:
		return
	# Don't enqueue duplicates — look for an existing MineTask at this cell.
	for t in TaskQueue.all_tasks():
		if t.task_type == TaskResource.TaskType.MINE and t.grid_position == grid_pos:
			return
	var task: TaskResource = TaskResource.new()
	task.task_type = TaskResource.TaskType.MINE
	task.grid_position = grid_pos
	task.priority = 1.0
	TaskQueue.add_task(task)
	print("[MiningSystem] queued MineTask at %s (%s)" % [grid_pos, tile.id])


## Return the grid cell under the cursor. Physics raycast against walls
## (layer 1) + pickups (layer 16); falls back to math Y=0 intersection
## only when nothing solid is hit. Fixes the "clicked wall, missed it"
## bug caused by elevated walls + camera-angle projection drift.
func _cursor_cell() -> Vector3i:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return Vector3i(999999, 0, 999999)  # impossible cell, get_tile → null
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	var params := PhysicsRayQueryParameters3D.create(
		from, from + dir * RAY_LENGTH, RAY_MASK,
	)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(params)
	if not hit.is_empty():
		return GridWorld.tile_at_world(hit.get("position", Vector3.ZERO))
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		return GridWorld.tile_at_world(camera_source.call("cursor_world_position"))
	return Vector3i(999999, 0, 999999)
