class_name MovementComponent extends Node
## MovementComponent — pathfinding + smooth movement for a CharacterBody3D.
##
## Plan: consume grid coordinates via `move_to(grid_pos)`; internally ask
## GridWorld for an AStar3D path; interpolate the body toward each waypoint
## at `speed` meters/second. Emit `reached_destination` when done, or
## `path_blocked` if the path can't be computed.
##
## Keep this deliberately minimal — complex locomotion (jumping, climbing,
## avoidance) comes later.

signal reached_destination()
signal path_blocked(reason: String)

@export var speed: float = 3.0
@export var arrive_distance: float = 0.15  # meters to consider a waypoint reached

var body: CharacterBody3D
var _path: PackedVector3Array = PackedVector3Array()
var _next_index: int = 0
var _has_goal: bool = false


func _ready() -> void:
	var parent: Node = get_parent()
	if parent is CharacterBody3D:
		body = parent
	else:
		push_warning("MovementComponent: parent is not a CharacterBody3D; movement will no-op")


## Request a path to `grid_target`. Overwrites any in-progress path.
func move_to(grid_target: Vector3i) -> void:
	if body == null:
		path_blocked.emit("no_body")
		return
	var start: Vector3i = GridWorld.tile_at_world(body.global_position)
	# Same-cell request — we're already there. AStar3D returns an empty
	# path for this case, which would otherwise be treated as no_path and
	# fail the task. Fake an immediate arrival instead.
	if start == grid_target:
		_has_goal = false
		_path = PackedVector3Array()
		# Deferred so the caller's begin-of-state bookkeeping finishes first.
		call_deferred("emit_signal", "reached_destination")
		return
	var path: PackedVector3Array = GridWorld.find_path(start, grid_target)
	if path.is_empty():
		path_blocked.emit("no_path")
		_has_goal = false
		return
	_path = path
	_next_index = 0
	_has_goal = true


func stop() -> void:
	_has_goal = false
	_path = PackedVector3Array()
	if body != null:
		body.velocity = Vector3.ZERO


func _physics_process(delta: float) -> void:
	if not _has_goal or body == null:
		return
	if _next_index >= _path.size():
		_has_goal = false
		body.velocity = Vector3.ZERO
		reached_destination.emit()
		return

	var target: Vector3 = _path[_next_index]
	var to_target: Vector3 = target - body.global_position
	to_target.y = 0.0
	var dist: float = to_target.length()
	if dist < arrive_distance:
		_next_index += 1
		return

	body.velocity = to_target.normalized() * speed
	body.move_and_slide()
