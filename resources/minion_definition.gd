class_name MinionDefinition extends Resource
## MinionDefinition — data definition for a minion archetype (e.g. worker,
## brute, shaman). The Minion scene reads this on spawn to configure
## stats, proficiencies, and appearance.

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
@export var base_stats: StatsProfile
## Per-task-type multiplier for utility scoring. Missing keys default to 1.0.
## Example: {"mining": 1.2, "combat": 0.8} = 20% faster at mining, 20%
## slower/less useful in combat.
@export var proficiency_modifiers: Dictionary = {}
@export var spawn_weight: float = 1.0
@export var idle_behavior_pool: Array[String] = []
## M11+ voice pack reference. Null in Phase 1 (placeholder English barks).
@export var voice_pack: Resource
