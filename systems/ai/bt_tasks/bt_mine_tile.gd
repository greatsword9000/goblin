@tool
extends BTAction
## BTMineTile — damages the target tile until its mining_hp is met, then SUCCESS.
##
## Mirrors `Minion._mine_tick` / `_finish_mine` so the new Agent produces
## identical mining semantics (tile replacement, EventBus.tile_mined emit).
## Fails if tile is no longer mineable (someone else finished it) or if
## task_valid flips false mid-swing.

@export var target_cell_key: StringName = &"target_cell"
@export var damage_per_sec: float = 4.0
## Max distance (cells) from target before we bail and re-path.
@export var range_cells: float = 1.6

var _accum: float = 0.0


func _generate_name() -> String:
	return "MineTile"


func _enter() -> void:
	_accum = 0.0


func _tick(delta: float) -> Status:
	if not bool(blackboard.get_var(&"task_valid", true)):
		return FAILURE
	var target_v: Variant = blackboard.get_var(target_cell_key, Vector3i.ZERO)
	var cell: Vector3i = target_v if target_v is Vector3i else Vector3i.ZERO
	var tile: Resource = GridWorld.get_tile(cell)
	if tile == null or not tile.is_mineable:
		# Somebody else mined it, or tile destroyed — goal "achieved" in spirit.
		return SUCCESS

	# Shoved out of range? Bail so the outer sequence re-paths. Parent sequence
	# will drop us but since we FAIL, FinishTask(false) releases the claim.
	var target_world: Vector3 = GridWorld.grid_to_world(cell)
	if agent.global_position.distance_to(target_world) > range_cells * GridWorld.CELL_SIZE:
		return FAILURE

	_accum += delta * damage_per_sec
	var hp: float = float(tile.get("mining_hp")) if tile.get("mining_hp") != null else 1.0
	if _accum >= hp:
		# Tile broken — replace with `replaces_with` (floor) or clear.
		var replacement: Resource = null
		if tile.get("replaces_with") != null:
			replacement = tile.get("replaces_with")
		if replacement != null:
			GridWorld.set_tile(cell, replacement)
		else:
			GridWorld.clear_tile(cell)
		EventBus.tile_mined.emit(cell, tile)
		return SUCCESS
	return RUNNING
