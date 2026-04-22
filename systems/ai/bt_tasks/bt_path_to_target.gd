@tool
extends BTAction
## BTPathToTask — moves the agent to the task's target cell via MovementComponent.
##
## Reads blackboard `target_cell_key` (Vector3i). Calls MovementComponent.move_to().
## Monitors `reached_destination` / `path_blocked` signals via polling on the
## MovementComponent's internal flags.
##
## Returns RUNNING while in motion, SUCCESS when arrived, FAILURE on blocked
## or if `task_valid` flips false mid-path.

@export var target_cell_key: StringName = &"target_cell"
@export var adjacent_walkable: bool = true  ## Move to a walkable neighbor, not into the wall

var _requested: bool = false
var _blocked: bool = false
var _arrived: bool = false


func _generate_name() -> String:
	return "PathToTask"


func _enter() -> void:
	_requested = false
	_blocked = false
	_arrived = false
	var mv: Node = agent.get_node_or_null("MovementComponent")
	if mv == null: return
	# Bind signals once per _enter. Using bound handlers so re-entry works.
	if not mv.reached_destination.is_connected(_on_reached):
		mv.reached_destination.connect(_on_reached)
	if not mv.path_blocked.is_connected(_on_blocked):
		mv.path_blocked.connect(_on_blocked)


func _exit() -> void:
	var mv: Node = agent.get_node_or_null("MovementComponent")
	if mv == null: return
	if mv.reached_destination.is_connected(_on_reached):
		mv.reached_destination.disconnect(_on_reached)
	if mv.path_blocked.is_connected(_on_blocked):
		mv.path_blocked.disconnect(_on_blocked)


func _on_reached() -> void: _arrived = true
func _on_blocked(_reason: String) -> void: _blocked = true


func _tick(_delta: float) -> Status:
	# Fast-abort: flag-driven interruption.
	if not bool(blackboard.get_var(&"task_valid", true)):
		return FAILURE
	var target_v: Variant = blackboard.get_var(target_cell_key, Vector3i.ZERO)
	var target: Vector3i = target_v if target_v is Vector3i else Vector3i.ZERO
	var mv: Node = agent.get_node_or_null("MovementComponent")
	if mv == null: return FAILURE
	if not _requested:
		var dest: Vector3i = target
		if adjacent_walkable:
			dest = GridWorld.find_nearest_walkable(target, 3)
		mv.call("move_to", dest)
		_requested = true
	if _blocked: return FAILURE
	if _arrived: return SUCCESS
	return RUNNING
