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

	# Case A: agent already has a task (claimed by code state machine or
	# another BT goal). Never mutate it — only consume if it matches our
	# filter. Previous behavior called fail_task on mismatch, which aborted
	# in-flight BUILD tasks mid-build when a MINE goal reassessed.
	var existing: Variant = tc.get("current_task")
	if existing != null and not (existing as Resource).completed:
		if int((existing as Resource).task_type) != task_type_filter:
			return FAILURE
		_publish_to_blackboard(existing as Resource)
		return SUCCESS

	# Case B: no current task — peek the queue for one matching our filter.
	# Only claim if we'll actually use it; no claim-then-discard churn.
	var task: Resource = TaskQueue.claim_next_of_type(agent, task_type_filter)
	if task == null:
		return FAILURE
	tc.set("current_task", task)
	_publish_to_blackboard(task)
	return SUCCESS


func _publish_to_blackboard(task: Resource) -> void:
	blackboard.set_var(task_key, task)
	blackboard.set_var(target_cell_key, task.grid_position)
	# Also mark task_valid=true in the blackboard so BlackboardSync's flip
	# via task_invalidated has a matching starting state.
	blackboard.set_var(&"task_valid", true)
