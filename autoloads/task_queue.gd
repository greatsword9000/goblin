extends Node
## TaskQueue — central backlog of work for minions.
##
## Owns: array of pending TaskResources, utility-scored assignment.
## Emits (via EventBus): task_created, task_assigned, task_completed, task_failed.
##
## Systems call `add_task(task)` when work shows up. Minions call
## `claim_next(minion)` when idle. Tasks carry their state (`claimed`,
## `completed`) on the resource itself so BTs can query without casting.

signal queue_changed()  # local diagnostic; prefer EventBus for cross-system

var _tasks: Array[TaskResource] = []


func add_task(task: TaskResource) -> void:
	if task == null:
		return
	_tasks.append(task)
	EventBus.task_created.emit(task)
	queue_changed.emit()


## Find the highest-utility unclaimed task for `minion` and mark it claimed.
## Consults MinionDefinition.proficiency_modifiers if the minion exposes a
## `get_task_proficiency(task_type)` method; otherwise uses 1.0.
func claim_next(minion: Node3D) -> TaskResource:
	if minion == null:
		return null
	var minion_pos: Vector3i = GridWorld.tile_at_world(minion.global_position)
	var best: TaskResource = null
	var best_score: float = -INF
	for task in _tasks:
		if task.claimed or task.completed:
			continue
		var prof: float = _proficiency_for(minion, task.task_type)
		var score: float = task.utility_for(minion_pos, prof)
		if score > best_score:
			best_score = score
			best = task
	if best != null:
		best.claimed = true
		best.assigned_to = minion.get_path()
		EventBus.task_assigned.emit(best, minion)
	return best


func complete_task(task: TaskResource) -> void:
	if task == null:
		return
	task.completed = true
	_tasks.erase(task)
	EventBus.task_completed.emit(task)
	queue_changed.emit()


## Mark a task failed. By default the task is re-enqueued unmarked so
## another minion can pick it up; pass `drop=true` to remove entirely.
func fail_task(task: TaskResource, reason: String, drop: bool = false) -> void:
	if task == null:
		return
	EventBus.task_failed.emit(task, reason)
	if drop:
		_tasks.erase(task)
	else:
		task.claimed = false
		task.assigned_to = NodePath("")
	queue_changed.emit()


## Number of unclaimed, uncompleted tasks — for HUD + debug overlay.
func pending_count() -> int:
	var n: int = 0
	for task in _tasks:
		if not task.claimed and not task.completed:
			n += 1
	return n


## Everything, for debug overlay listing.
func all_tasks() -> Array[TaskResource]:
	return _tasks.duplicate()


func _proficiency_for(minion: Node3D, task_type: int) -> float:
	if not minion.has_method("get_task_proficiency"):
		return 1.0
	var prof: Variant = minion.call("get_task_proficiency", task_type)
	if prof is float:
		return float(prof)
	if prof is int:
		return float(prof)
	return 1.0
