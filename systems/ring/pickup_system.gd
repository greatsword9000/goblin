extends Node
## PickupSystem — LMB press grabs the minion under the cursor; release
## drops it at the cursor's ground position.
##
## Routes through EventBus (minion_picked_up / minion_dropped). Uses
## `_input` (not `_unhandled_input`) so MiningSystem only fires when this
## system didn't already consume the click as a grab/drop.

class_name PickupSystem

const PICKUP_RAY_LENGTH: float = 80.0
const PICKUP_MASK: int = 2   # physics layer 2 = "Minions"

@export var camera_source: Node   # needs cursor_world_position() -> Vector3

var _held: GrabbableComponent = null
var _held_body: CharacterBody3D = null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ring_primary"):
		if _try_grab_under_cursor():
			get_viewport().set_input_as_handled()
	elif event.is_action_released("ring_primary"):
		if _held != null:
			_drop()
			get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if _held == null or _held_body == null:
		return
	# Follow cursor on XZ, fix Y at hold height above the ground plane.
	if camera_source == null or not camera_source.has_method("cursor_world_position"):
		return
	var ground_pos: Vector3 = camera_source.call("cursor_world_position")
	_held_body.global_position = Vector3(ground_pos.x, _held.hold_height, ground_pos.z)
	_held_body.velocity = Vector3.ZERO


func _try_grab_under_cursor() -> bool:
	if _held != null:
		return false  # already holding something
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return false
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	var to: Vector3 = from + dir * PICKUP_RAY_LENGTH
	var space := cam.get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(from, to, PICKUP_MASK)
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	if collider == null:
		return false
	var grabbable: GrabbableComponent = _find_grabbable(collider as Node)
	if grabbable == null or grabbable.body == null:
		return false
	_held = grabbable
	_held_body = grabbable.body
	grabbable.on_grabbed()
	EventBus.minion_picked_up.emit(_held_body)
	print("[PickupSystem] grabbed %s" % _held_body.name)
	return true


func _drop() -> void:
	var body: CharacterBody3D = _held_body
	var grabbable: GrabbableComponent = _held
	_held = null
	_held_body = null
	# Find the floor position below the cursor (cursor_world_position returns
	# the XZ-plane intersection at Y=0).
	var drop_world: Vector3 = body.global_position
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		drop_world = camera_source.call("cursor_world_position")
	# Snap to nearest walkable cell so the minion lands somewhere legal.
	var target_cell: Vector3i = GridWorld.find_nearest_walkable(
		GridWorld.tile_at_world(drop_world), 4,
	)
	var snap_pos: Vector3 = GridWorld.grid_to_world(target_cell)
	body.global_position = Vector3(snap_pos.x, 0.0, snap_pos.z)
	body.velocity = Vector3.ZERO
	grabbable.on_released(body.global_position)
	EventBus.minion_dropped.emit(body, target_cell)
	print("[PickupSystem] dropped %s at %s" % [body.name, target_cell])


func _find_grabbable(node: Node) -> GrabbableComponent:
	# Walk up from a collision hit. The body is usually the collider's
	# parent's parent (CollisionShape3D inside CharacterBody3D), so check
	# a few levels up.
	var cursor: Node = node
	for _i in range(4):
		if cursor == null:
			break
		for child in cursor.get_children():
			if child is GrabbableComponent:
				return child
		cursor = cursor.get_parent()
	return null
