extends Node
class_name GoalTrees
## GoalTrees — programmatic BehaviorTree builders.
##
## Each static method returns a freshly-constructed BehaviorTree for one goal.
## GoalPicker calls `GoalTrees.call(def.tree_builder_method, agent)` and caches
## the result per-agent.
##
## Why programmatic (vs. .tres authored in the LimboAI editor)?
##   - Version-controllable as plain GDScript (diffable).
##   - No editor round-trip to tweak a sequence.
##   - Phase 1 scope doesn't need visual authoring; we have 5 goals total.
##   - Can still port to .tres later — the BTAction scripts are unchanged.

const BTClaimTask   = preload("res://systems/ai/bt_tasks/bt_claim_task.gd")
const BTPathToTask  = preload("res://systems/ai/bt_tasks/bt_path_to_target.gd")
const BTMineTile    = preload("res://systems/ai/bt_tasks/bt_mine_tile.gd")
const BTFinishTask  = preload("res://systems/ai/bt_tasks/bt_finish_task.gd")
const BTPickWander  = preload("res://systems/ai/bt_tasks/bt_pick_wander_cell.gd")
const BTPathToCell  = preload("res://systems/ai/bt_tasks/bt_path_to_cell.gd")
const BTWait        = preload("res://systems/ai/bt_tasks/bt_wait_duration.gd")


## Sequence: claim → path → mine → finish(true).
## On ANY failure, finish(false) releases the claim so another agent can try.
static func build_mine_tree(_agent: Node3D) -> Resource:
	var bt := ClassDB.instantiate("BehaviorTree") as Resource
	var root: Object = ClassDB.instantiate("BTSequence")
	# On failure, report failure (finish_task with success=false)
	var claim := BTClaimTask.new()
	claim.task_type_filter = 0  # MINE
	root.call("add_child", claim)
	var path := BTPathToTask.new()
	root.call("add_child", path)
	var mine := BTMineTile.new()
	root.call("add_child", mine)
	var finish := BTFinishTask.new()
	finish.success = true
	root.call("add_child", finish)
	bt.set("root_task", root)
	return bt


## Sequence: pick random nearby walkable cell → path to it → short rest.
static func build_wander_tree(_agent: Node3D) -> Resource:
	var bt := ClassDB.instantiate("BehaviorTree") as Resource
	var root: Object = ClassDB.instantiate("BTSequence")
	var pick := BTPickWander.new()
	pick.radius = 4
	root.call("add_child", pick)
	var path := BTPathToCell.new()
	root.call("add_child", path)
	var rest := BTWait.new()
	rest.duration = 1.5
	root.call("add_child", rest)
	bt.set("root_task", root)
	return bt


## Hang while carried — just waits. The picker swaps back to mine/wander
## the moment `carried` flips false.
static func build_idle_carried_tree(_agent: Node3D) -> Resource:
	var bt := ClassDB.instantiate("BehaviorTree") as Resource
	var wait := BTWait.new()
	wait.duration = 0.25  # short tick so picker gets a chance to re-pick on drop
	bt.set("root_task", wait)
	return bt


## Stub flee — Phase 1 placeholder. Picks a wander cell to simulate running off.
## M09 (adventurer AI) replaces with actual distance-from-raider logic.
static func build_flee_tree(agent: Node3D) -> Resource:
	return build_wander_tree(agent)
