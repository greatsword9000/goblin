class_name AgentArchetype extends Resource
## AgentArchetype — defines one kind of Agent (goblin_worker, raider, etc.).
##
## Authored as .tres. Agent nodes load an archetype on _ready() and apply
## it to their components. Switching archetypes is how minion vs adventurer
## diverges without forking the Agent scene.

## Display name for debug overlays.
@export var display_name: String = "Agent"

## Stats
@export var max_hp: float = 10.0
@export var attack: float = 2.0
@export var defense: float = 0.0
@export var move_speed: float = 3.0

## Goals this archetype considers, in no particular order. GoalPicker scores
## and picks the top. Must include at least one fallback (wander or idle).
@export var goals: Array[GoalDef] = []

## Initial blackboard values copied into the BTPlayer's blackboard on spawn.
## Keys like "energy": 1.0, "alarm": false, "carried": false.
@export var initial_blackboard: Dictionary = {}

## Group to add to (minions, adventurers, …). Phase 1 uses this for broad
## selection (ring picks up anything in `minions`); later combat will use it
## for faction filtering.
@export var group_name: StringName = &"minions"

## Mesh scene to instantiate and parent to the Agent for visuals. If null,
## Agent spawns with no visible body (debug-only).
@export var visual_scene: PackedScene = null

## Optional proficiency modifiers: task_type (int) → multiplier.
## E.g. goblin_worker: {TaskType.MINE: 1.5, TaskType.HAUL: 1.0}
@export var proficiency: Dictionary = {}
