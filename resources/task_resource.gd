class_name TaskResource extends Resource
## TaskResource — one unit of work in the TaskQueue.
##
## Created by systems (MiningSystem click, BuildingSystem place, HaulSystem
## ore-pickup detect). Picked up by idle minions via TaskQueue.claim_next()
## based on utility score. Completed by the minion's behavior tree, which
## calls TaskQueue.complete_task() on finish.
##
## Keep this class data-only — no runtime behavior. The BT reads fields
## here and dispatches to the appropriate sub-tree.

enum TaskType { MINE, HAUL, BUILD, DEFEND, IDLE }

@export var task_type: TaskType = TaskType.IDLE
@export var grid_position: Vector3i = Vector3i.ZERO
@export var priority: float = 1.0
@export var required_tool_tier: int = 0
## Free-form bag for task-specific data (ore pickup reference, build resource
## dict, defend target, etc.). Keep keys documented per task type:
##   MINE:  {}
##   HAUL:  {"item": Node3D, "destination": Vector3i}
##   BUILD: {"buildable": BuildableDefinition, "costs_paid": bool}
##   DEFEND:{"target": Node3D}
##   IDLE:  {}
@export var payload: Dictionary = {}

## Path to the minion that claimed this task — empty until claimed. Set by
## TaskQueue.claim_next(). Cleared on complete_task() / task_failed.
@export var assigned_to: NodePath = NodePath("")

## Whether the task is currently claimed. Source of truth; `assigned_to`
## may be empty briefly between assign and BT start.
@export var claimed: bool = false

## Whether the task is completed. Queue keeps completed tasks briefly for
## debugging; they're purged in the next tick.
@export var completed: bool = false


## Utility score for this task when considered by `minion` at `minion_pos`.
## Higher = more preferred. Baseline = priority; penalty by distance; bonus
## by proficiency when MinionDefinition declares matching proficiency.
## Keep this pure — no side effects, no logging.
func utility_for(minion_pos: Vector3i, proficiency_mul: float = 1.0) -> float:
	if claimed or completed:
		return -INF
	var dist: float = float((grid_position - minion_pos).length())
	# Distance penalty falls off linearly; far tasks never get picked before
	# near ones of equal priority.
	var dist_penalty: float = dist * 0.1
	return priority * proficiency_mul - dist_penalty
