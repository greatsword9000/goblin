class_name GrabbableComponent extends Node
## GrabbableComponent — marker that makes an entity targetable by the ring.
##
## Attach as a child of any CharacterBody3D that the player should be able
## to pick up (minions now; pets, items, ragdolling adventurers later).
## The PickupSystem queries for this component when raycasting under the
## cursor on LMB.
##
## The component stashes the entity's pre-grab state so drop can restore
## it: whether it was physics-driven, its current task (so the minion
## doesn't forget what it was doing).

signal grabbed()
signal released(drop_pos: Vector3)

## How high above the floor to hover while held (meters).
@export var hold_height: float = 1.4

var is_held: bool = false

# Cached parent reference. Minions are CharacterBody3D; pickups are Area3D.
# Either is fine — PickupSystem only needs global_position + optional velocity.
var body: Node3D

# If the held entity had a task in progress, we pause it on grab and
# resume on drop. TaskComponent is optional — pets etc. have none.
var _paused_task: TaskResource = null


func _ready() -> void:
	var parent: Node = get_parent()
	if parent is Node3D:
		body = parent
	else:
		push_warning("GrabbableComponent: parent is not a Node3D")


## Called by PickupSystem on successful grab. Returns the lifted target
## Y so PickupSystem can position the body.
func on_grabbed() -> float:
	is_held = true
	_pause_task()
	grabbed.emit()
	return hold_height


## Called on release. `drop_pos` is the world-space floor position below
## the cursor; body Y is re-pinned to ground.
func on_released(drop_pos: Vector3) -> void:
	is_held = false
	_resume_task()
	released.emit(drop_pos)


func _pause_task() -> void:
	var tc: Node = body.get_node_or_null("TaskComponent") if body != null else null
	if tc == null:
		return
	var current: Variant = tc.get("current_task")
	if current is TaskResource and not current.completed:
		_paused_task = current
		# Don't call finish_task — just clear the reference so the minion
		# state machine sees "no task" and returns to IDLE on next poll.
		tc.set("current_task", null)


func _resume_task() -> void:
	if _paused_task == null:
		return
	if _paused_task.completed:
		_paused_task = null
		return
	# Release the claim so the queue can re-assign (could be this minion
	# again, could be a closer one).
	_paused_task.claimed = false
	_paused_task.assigned_to = NodePath("")
	_paused_task = null
