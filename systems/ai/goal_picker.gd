class_name GoalPicker extends Node
## GoalPicker — the "decide what to do" layer.
##
## Iterates the archetype's goals, applies each one's scorer + gate flags,
## picks the highest, and swaps that goal's BehaviorTree onto the BTPlayer.
##
## Runs on event — not per-tick — so we don't burn CPU on 30 agents every
## frame. Events that should trigger a re-pick:
##   - BT finished (succeeded or failed)
##   - Blackboard flag changed (carried, alarm, task_valid, …)
##   - task_created / task_completed (new work available, current gone)
##   - a 2s watchdog tick (catches bugs where a relevant event was missed)
##
## The only thing allowed to call `bt_player.behavior_tree = X` is this node.
## That's the architectural rule that kills ad-hoc interruption hacks.

signal goal_changed(old_id: String, new_id: String)

@export var archetype: AgentArchetype

@onready var _bt_player: Node = _find_bt_player()
@onready var _sync: BlackboardSync = _find_sync()

var _agent: Node3D
var _current_goal: GoalDef = null
var _tree_cache: Dictionary = {}  # goal_id → BehaviorTree

## Watchdog: re-pick if no event has fired in this long. Catches missed events.
const WATCHDOG_INTERVAL: float = 2.0
var _watchdog_accum: float = 0.0


func _ready() -> void:
	_agent = get_parent() as Node3D
	if archetype == null:
		push_error("[GoalPicker] no archetype assigned")
		set_process(false)
		return
	if _bt_player == null:
		push_error("[GoalPicker] no BTPlayer sibling")
		set_process(false)
		return
	# React to events that should trigger re-pick
	EventBus.task_created.connect(_on_event_reassess)
	EventBus.task_completed.connect(_on_event_reassess)
	EventBus.task_invalidated.connect(_on_event_reassess)
	EventBus.task_failed.connect(_on_event_reassess)
	EventBus.minion_picked_up.connect(_on_event_reassess)
	EventBus.minion_dropped.connect(_on_event_reassess)
	EventBus.alarm_raised.connect(_on_event_reassess)
	EventBus.alarm_cleared.connect(_on_event_reassess)
	if _bt_player.has_signal("behavior_tree_finished"):
		_bt_player.connect("behavior_tree_finished", _on_bt_finished)
	# Initial pick
	call_deferred("reassess")


func _process(delta: float) -> void:
	_watchdog_accum += delta
	if _watchdog_accum >= WATCHDOG_INTERVAL:
		_watchdog_accum = 0.0
		reassess()


func _find_bt_player() -> Node:
	for c in get_parent().get_children():
		if c.get_class() == "BTPlayer":
			return c
	return null


func _find_sync() -> BlackboardSync:
	for c in get_parent().get_children():
		if c is BlackboardSync:
			return c
	return null


func _on_event_reassess(_a = null, _b = null, _c = null) -> void:
	reassess()


func _on_bt_finished(_agent_node: Variant = null, _status: int = 0) -> void:
	# Current goal's BT wrapped up. Immediately pick again.
	reassess()


## Score every goal, pick the winner, swap BTs if it differs. Cheap to call
## spuriously; idempotent if the winner is the same as current.
func reassess() -> void:
	_watchdog_accum = 0.0
	var best: GoalDef = null
	var best_score: float = -INF
	for g in archetype.goals:
		if g == null: continue
		if not _flags_allow(g): continue
		var s: float = _score_goal(g)
		if s > best_score:
			best_score = s
			best = g
	if best == null:
		return
	if _current_goal != null and _current_goal.id == best.id:
		return
	var old_id: String = _current_goal.id if _current_goal != null else ""
	_current_goal = best
	_apply_goal(best)
	goal_changed.emit(old_id, best.id)


func _flags_allow(g: GoalDef) -> bool:
	if _sync == null: return true
	if g.requires_flag != &"":
		if not bool(_sync.get_flag(g.requires_flag, false)):
			return false
	if g.forbids_flag != &"":
		if bool(_sync.get_flag(g.forbids_flag, false)):
			return false
	return true


func _score_goal(g: GoalDef) -> float:
	if g.scorer_method == &"": return g.weight
	if not GoalScorers.has_method(g.scorer_method):
		return g.weight
	var raw: Variant = GoalScorers.call(g.scorer_method, _agent, _sync)
	var score: float = float(raw) if raw is float or raw is int else 0.0
	return score * g.weight


func _apply_goal(g: GoalDef) -> void:
	var tree: Resource = _tree_cache.get(g.id, null)
	if tree == null:
		if g.tree_builder_method == &"" or not GoalTrees.has_method(g.tree_builder_method):
			push_warning("[GoalPicker] goal '%s' has no valid tree_builder_method" % g.id)
			return
		tree = GoalTrees.call(g.tree_builder_method, _agent)
		_tree_cache[g.id] = tree
	_bt_player.set("behavior_tree", tree)


## Debug.
func current_goal_id() -> String:
	return _current_goal.id if _current_goal != null else ""
