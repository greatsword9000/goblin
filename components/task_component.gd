class_name TaskComponent extends Node
## TaskComponent — holds the minion's current TaskResource.
##
## Claims tasks from TaskQueue, exposes them to the behavior tree, and
## reports completion back. Keep this thin — actual execution logic is
## in the BT, not here.

signal task_claimed(task: TaskResource)
signal task_finished(task: TaskResource, success: bool)

var current_task: TaskResource = null


func has_task() -> bool:
	return current_task != null and not current_task.completed


## Try to pull a new task from the queue. Returns the claimed task, or null.
func try_claim_next() -> TaskResource:
	if has_task():
		return current_task
	var minion: Node3D = get_parent() as Node3D
	if minion == null:
		return null
	var task: TaskResource = TaskQueue.claim_next(minion)
	if task != null:
		current_task = task
		task_claimed.emit(task)
	return task


## Called by the BT when a task finishes. `success` distinguishes completion
## from failure so the queue can re-enqueue or drop accordingly.
func finish_task(success: bool) -> void:
	if current_task == null:
		return
	var task: TaskResource = current_task
	current_task = null
	if success:
		TaskQueue.complete_task(task)
	else:
		TaskQueue.fail_task(task, "bt_reported_failure")
	task_finished.emit(task, success)
