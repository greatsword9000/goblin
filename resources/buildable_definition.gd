class_name BuildableDefinition extends Resource
## One placeable thing in the build menu. Data-only.
##
## Two completion paths:
##   - `tile_replacement` is set: BuildingSystem calls GridWorld.set_tile at
##     the target cell when the minion finishes. Used for walls — walkability
##     and AStar updates flow from the tile itself.
##   - `scene` is set: the entity scene is instantiated at the target cell's
##     world position. Used for traps, nurseries, anything that sits on top
##     of an existing floor.
##
## Exactly one of the two should be set per buildable.

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null          # null → text-label in menu for Phase 1

## Cost dict, e.g. {"gold": 40}. Keys must match ResourceManager stockpile IDs.
@export var costs: Dictionary = {}

@export var build_time_seconds: float = 4.0

@export_group("Completion path — set exactly one")
@export var tile_replacement: TileResource = null   # for walls
@export var scene: PackedScene = null               # for traps / nurseries etc.
