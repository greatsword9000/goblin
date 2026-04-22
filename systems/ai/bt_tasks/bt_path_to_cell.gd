@tool
extends BTAction
## BTPathToCell — same as BTPathToTask but without the task-valid gate (used
## by wander / flee where there's no task to invalidate).

@export var target_cell_key: StringName = &"target_cell"

var _requested: bool = false
var _blocked: bool = false
var _arrived: bool = false


func _generate_name() -> String:
	return "PathToCell"


func _enter() -> void:
	_requested = false
	_blocked = false
	_arrived = false
	var mv: Node = agent.get_node_or_null("MovementComponent")
	if mv == null: return
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
	var target_v: Variant = blackboard.get_var(target_cell_key, Vector3i.ZERO)
	var target: Vector3i = target_v if target_v is Vector3i else Vector3i.ZERO
	var mv: Node = agent.get_node_or_null("MovementComponent")
	if mv == null: return FAILURE
	if not _requested:
		mv.call("move_to", target)
		_requested = true
	if _blocked: return FAILURE
	if _arrived: return SUCCESS
	return RUNNING
