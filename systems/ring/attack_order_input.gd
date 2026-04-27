extends Node
## AttackOrderInput — LMB / Shift+LMB on a raider to set a priority target.
##
## Plain LMB on adventurer → clears the queue and sets that adventurer as
## the single focus target. All minions in defend mode (or about to enter
## defend mode) override their nearest-threat lookup with this target.
##
## Shift+LMB on adventurer → append to the queue. When the current focus
## dies, the next queued target becomes active.
##
## Uses `_input` (runs before `_unhandled_input`) so we can consume clicks
## that hit adventurers before MiningSystem / BuildingSystem see them.
## Adventurers are on collision layer 4 — not in the ray masks those
## systems use — so our raycast can coexist without blocking their flow
## when the cursor is elsewhere.

class_name AttackOrderInput

@export var camera_source: Node

const RAY_LENGTH: float = 80.0
# Layer 4 = Adventurers only. We specifically don't want to hit walls or
# minions; if the click isn't on a raider, we do nothing and let other
# input handlers run normally.
const RAY_MASK: int = 4


func _input(event: InputEvent) -> void:
	# Shift+LMB — append to queue (exact_match requires shift held).
	if event.is_action_pressed("ring_multi_mark", false, true):
		if _try_order(true):
			get_viewport().set_input_as_handled()
		return
	# Plain LMB — replace focus (exact_match excludes shift-clicks).
	if event.is_action_pressed("ring_primary", false, true):
		if _try_order(false):
			get_viewport().set_input_as_handled()


func _try_order(append: bool) -> bool:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return false
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	var params := PhysicsRayQueryParameters3D.create(
		from, from + dir * RAY_LENGTH, RAY_MASK,
	)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return false
	var collider: Object = hit.get("collider")
	var adv: Adventurer = _resolve_adventurer(collider as Node)
	if adv == null:
		return false
	if append:
		RaidDirector.add_priority(adv)
		print("[AttackOrder] queued %s for attack" % adv.name)
	else:
		RaidDirector.set_priority(adv)
		print("[AttackOrder] focus-attack %s" % adv.name)
	return true


## Walk up from the collider to find the Adventurer root — collision
## shapes can be a few levels deep inside the CharacterBody3D.
func _resolve_adventurer(node: Node) -> Adventurer:
	var cursor: Node = node
	for _i in range(4):
		if cursor == null:
			break
		if cursor is Adventurer:
			return cursor as Adventurer
		cursor = cursor.get_parent()
	return null
