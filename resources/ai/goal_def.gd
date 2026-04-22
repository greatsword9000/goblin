class_name GoalDef extends Resource
## GoalDef — one goal an Agent can pursue.
##
## Authored as .tres. The `GoalPicker` iterates an archetype's goal list,
## scores each via `score()`, and runs the BT built by `tree_builder_method`
## on the winner.
##
## Keep this data-only. The scorer is a method name, not a Callable, so
## `.tres` files remain serializable.

## Stable id ("mine", "haul", "wander", "idle_carried", "flee").
## Used by save/load, debug overlay, and goal-swap comparison.
@export var id: String = ""

## Static method on GoalTrees that returns a BehaviorTree for this goal.
## e.g. "build_mine_tree". Called ONCE per agent on first pick; cached.
@export var tree_builder_method: StringName = &""

## Static method on GoalScorers that returns a float utility given (agent, bb).
## Higher = more preferred. Return -INF to hard-reject.
@export var scorer_method: StringName = &""

## Base weight applied to the scorer result. Lets archetypes emphasize/suppress
## goals without changing scorer code.
@export var weight: float = 1.0

## If non-empty, this blackboard key MUST be true for the goal to be considered.
## e.g. "carried" for idle_carried, "alarm" for flee. One-hot gate.
@export var requires_flag: StringName = &""

## If non-empty, this blackboard key must be FALSE for the goal to be considered.
## Mirror of requires_flag. e.g. wander requires NOT carried.
@export var forbids_flag: StringName = &""
