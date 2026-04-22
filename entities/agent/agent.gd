class_name Agent extends CharacterBody3D
## Agent — unified base for Minion and Adventurer under the new BT architecture.
##
## Architecture (see PHASE_1_PLAN notes + research dump):
##   Agent (this)
##   ├── StatsComponent      ← HP / dies
##   ├── MovementComponent   ← AStar3D path + move_and_slide
##   ├── TaskComponent       ← current_task holder (wraps TaskQueue)
##   ├── GrabbableComponent  ← ring picks us up
##   ├── BTPlayer (LimboAI)  ← runs the currently-active BehaviorTree
##   ├── GoalPicker          ← picks the goal → swaps BT on BTPlayer
##   ├── BlackboardSync      ← EventBus → blackboard flag writes
##   └── Visual (optional)   ← archetype.visual_scene instance for mesh/anim
##
## Replaces the monolithic `Minion` FSM. Minion and Adventurer now diverge
## only via their AgentArchetype.tres (different goals + stats + mesh).

signal died

@export var archetype: AgentArchetype

@onready var _stats: StatsComponent = $StatsComponent
@onready var _movement: MovementComponent = $MovementComponent
@onready var _task: TaskComponent = $TaskComponent
@onready var _grabbable: GrabbableComponent = $GrabbableComponent
@onready var _bt_player: Node = $BTPlayer
@onready var _goal_picker: GoalPicker = $GoalPicker
@onready var _sync: BlackboardSync = $BlackboardSync

## For debug overlay — matches Minion's surface.
var agent_name: String = "Agent"


func _ready() -> void:
	if archetype == null:
		push_error("[Agent] no archetype assigned — agent will be inert")
		return

	# Apply archetype to components
	_stats.max_hp = archetype.max_hp
	_stats.attack = archetype.attack
	_stats.defense = archetype.defense
	_stats.move_speed = archetype.move_speed
	_movement.speed = archetype.move_speed
	# group_name is typed StringName; convert to String for .split()
	for g in String(archetype.group_name).split(","):
		add_to_group(g.strip_edges())

	# Wire goal picker
	_goal_picker.archetype = archetype

	# Seed blackboard with initial flags so picker's flag checks work
	# before any event fires.
	for key in archetype.initial_blackboard:
		_sync.set_flag(key, archetype.initial_blackboard[key])

	# Grab stops in-flight pathing; drop re-assess is automatic via EventBus.
	if _grabbable != null:
		_grabbable.grabbed.connect(_movement.stop)

	# Hook vital death
	_stats.died.connect(_on_died)

	# Spawn visuals (optional)
	if archetype.visual_scene != null:
		var vis := archetype.visual_scene.instantiate()
		add_child(vis)

	EventBus.minion_spawned.emit(self)


## Called by TaskQueue during utility scoring — archetype-configurable multiplier.
func get_task_proficiency(task_type: int) -> float:
	if archetype == null: return 1.0
	var v: Variant = archetype.proficiency.get(task_type, 1.0)
	return float(v) if (v is float or v is int) else 1.0


func _on_died(_killer: Node) -> void:
	EventBus.minion_died.emit(self)
	died.emit()
	queue_free()


## Public — called by GrabbableComponent.on_released. Mirrors Minion.enter_falling
## so ring drop behavior is identical. No state machine here; the picker sees
## carried=false on drop and picks a new goal.
func enter_falling() -> void:
	# Quick pin to ground so we don't hover. Picker+BT will handle what next.
	var start_y := global_position.y
	var tween := create_tween()
	tween.tween_property(self, "global_position:y", 0.0, 0.45).from(start_y)
