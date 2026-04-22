@tool
extends BTAction
## BTClaimTask — claims a task from TaskQueue matching `task_type_filter`.
##
## On success: writes task ref to blackboard under `task_key`, writes the
## target grid_position to `target_cell_key`, returns SUCCESS.
## On no-task-available: returns FAILURE (GoalPicker will re-pick next event).

## TaskResource.TaskType enum value (0=MINE, 1=HAUL, 2=BUILD, 3=DEFEND, 4=IDLE).
@export var task_type_filter: int = 0

## Blackboard keys to write on success.
@export var task_key: StringName = &"task"
@export var target_cell_key: StringName = &"target_cell"


func _generate_name() -> String:
	return "ClaimTask  type=%d" % task_type_filter


func _tick(_delta: float) -> Status:
	# TaskComponent lives on the agent (parent of BTPlayer.agent)
	var tc: Node = agent.get_node_or_null("TaskComponent")
	if tc == null:
		return FAILURE
	var task: Resource = null
	if tc.get("current_task") != null and not tc.get("current_task").completed:
		task = tc.get("current_task")
	else:
		task = TaskQueue.claim_next(agent)
		if task != null:
			tc.set("current_task", task)
	if task == null:
		return FAILURE
	if int(task.task_type) != task_type_filter:
		# Wrong type for this goal — release and fail so picker can re-pick.
		TaskQueue.fail_task(task, "wrong_type_for_goal")
		tc.set("current_task", null)
		return FAILURE
	blackboard.set_var(task_key, task)
	blackboard.set_var(target_cell_key, task.grid_position)
	# Also mark task_valid=true in the blackboard so BlackboardSync's flip
	# via task_invalidated has a matching starting state.
	blackboard.set_var(&"task_valid", true)
	return SUCCESS
