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


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ring_primary"):
		return
	if camera_source == null or not camera_source.has_method("cursor_world_position"):
		return
	var world_pos: Vector3 = camera_source.call("cursor_world_position")
	var grid_pos: Vector3i = GridWorld.tile_at_world(world_pos)
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
