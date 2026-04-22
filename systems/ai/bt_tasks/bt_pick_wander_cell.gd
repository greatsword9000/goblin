@tool
extends BTAction
## BTPickWanderCell — pick a random walkable cell within `radius` of the agent.
## Writes result to `target_cell_key`. FAILURE if nothing walkable found.

@export var target_cell_key: StringName = &"target_cell"
@export var radius: int = 4


func _generate_name() -> String:
	return "PickWanderCell  r=%d" % radius


func _tick(_delta: float) -> Status:
	var here: Vector3i = GridWorld.tile_at_world(agent.global_position)
	var attempts: int = 8
	for _i in range(attempts):
		var offset := Vector3i(
			randi_range(-radius, radius), 0, randi_range(-radius, radius))
		var cand: Vector3i = here + offset
		if GridWorld.is_walkable(cand):
			blackboard.set_var(target_cell_key, cand)
			return SUCCESS
	# fallback: the nearest walkable
	var near := GridWorld.find_nearest_walkable(here, radius)
	blackboard.set_var(target_cell_key, near)
	return SUCCESS
