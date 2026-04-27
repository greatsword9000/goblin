class_name AdventurerDefinition extends Resource
## AdventurerDefinition — data definition for an adventurer archetype.
##
## Mirrors MinionDefinition but for the raid roster. RaidDirector picks
## from a pool of these when composing a squad. The Adventurer scene reads
## archetype + stats on spawn to configure behavior and appearance.
##
## Phase 1 has three fixed archetypes — warrior (engage), rogue (loot),
## archer (ranged). Scale later by adding more `.tres` files; no code
## changes needed for new archetypes unless they introduce a brand-new
## goal pattern.

enum Archetype {
	WARRIOR,  ## Melee engage — beelines nearest hostile, attacks in reach
	ROGUE,    ## Treasury runner — ignores combat, steals gold, flees to entry
	ARCHER,   ## Ranged planter — parks at optimal range, fires at priority targets
}

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
@export var base_stats: StatsProfile
@export var archetype: Archetype = Archetype.WARRIOR

## Attack range in cell units. Warrior/Rogue ~1.2 (adjacent), Archer 4.0+.
@export var attack_range_cells: float = 1.2
## Damage per attack — raw value, before defender defense reduction.
@export var attack_damage: float = 2.0
## Seconds between attack attempts while in range.
@export var attack_cooldown_seconds: float = 1.0

## Sampled by RaidDirector when composing a squad. Higher = shows up more.
@export var spawn_weight: float = 1.0
