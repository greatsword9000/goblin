class_name BlackboardSync extends Node
## BlackboardSync — one-way bridge from EventBus → LimboAI blackboard.
##
## Every Agent has one. Listens to global signals (picked_up, alarm_raised,
## task_invalidated, etc.) and writes flag values into its BTPlayer's
## blackboard. BTs read those flags via BTConditions.
##
## **This is THE place** where "reactive behavior" is wired. If you find
## yourself writing `if is_held: return` in game code, add a flag here instead.
##
## Event-driven → no per-tick cost. If you add a new event, extend
## `_EVENT_MAP` below; no other code changes.

@export var bt_player_path: NodePath

## agent we belong to (for filtering signals that carry a node reference)
var _agent: Node3D
var _bt_player: Node  # BTPlayer (GDExtension, no static type)

## Map of EventBus signal → (blackboard_key, value_transform).
## value_transform: Callable(args...) -> Variant. null means set `true`.
## Signals that carry a minion/agent reference filter on `_agent`.
const _EVENT_MAP := [
	{"signal": &"minion_picked_up", "key": &"carried", "filter_agent_arg": 0, "value": true},
	{"signal": &"minion_dropped",   "key": &"carried", "filter_agent_arg": 0, "value": false},
	{"signal": &"alarm_raised",     "key": &"alarm", "value": true},
	{"signal": &"alarm_cleared",    "key": &"alarm", "value": false},
	{"signal": &"task_invalidated", "key": &"task_valid", "filter_task": true, "value": false},
]


func _ready() -> void:
	_agent = get_parent() as Node3D
	if bt_player_path != NodePath(""):
		_bt_player = get_node_or_null(bt_player_path)
	# Fall back: look for a BTPlayer sibling
	if _bt_player == null:
		for c in get_parent().get_children():
			if c.get_class() == "BTPlayer":
				_bt_player = c
				break
	if _bt_player == null:
		push_warning("[BlackboardSync] no BTPlayer found; sync disabled")
		return
	for entry in _EVENT_MAP:
		var sig: StringName = entry["signal"]
		if EventBus.has_signal(sig):
			EventBus.connect(sig, _on_event.bind(entry))


func _on_event(a0 = null, a1 = null, a2 = null, entry: Dictionary = {}) -> void:
	# Filter by agent-arg if configured (events that carry node refs)
	if entry.has("filter_agent_arg"):
		var which: int = entry["filter_agent_arg"]
		var ref: Variant = [a0, a1, a2][which]
		if ref != _agent:
			return
	# Filter by task-claimed-by-me (task_invalidated fires globally)
	if entry.get("filter_task", false):
		var task: Resource = a0 as Resource
		if task == null: return
		var tc: Node = _agent.get_node_or_null("TaskComponent")
		if tc == null or tc.get("current_task") != task:
			return
	_write(entry["key"], entry.get("value", true))


## Write a flag into the BTPlayer's blackboard. Swallows errors so a missing
## BTPlayer / key doesn't crash the game; prints a one-time warning.
func _write(key: StringName, value: Variant) -> void:
	if _bt_player == null: return
	var bb: Object = _bt_player.get("blackboard")
	if bb == null: return
	bb.call("set_var", key, value)


## Manually set a blackboard flag. Used by components that don't have a
## matching EventBus signal (e.g. MovementComponent reports path_blocked
## by calling sync.set_flag("path_blocked", true)).
func set_flag(key: StringName, value: Variant) -> void:
	_write(key, value)


func get_flag(key: StringName, default: Variant = null) -> Variant:
	if _bt_player == null: return default
	var bb: Object = _bt_player.get("blackboard")
	if bb == null: return default
	return bb.call("get_var", key, default)
