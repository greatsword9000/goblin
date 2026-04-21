class_name TileResource extends Resource
## TileResource — base data definition for a grid tile.
##
## Subtypes live in tile_types.gd (FloorTile, MineableTile, SpecialWallTile,
## DecorativeTile, HazardTile). Fields common to all tiles live here.
##
## Visual model: `mesh_scene` is the authoritative visual. If null, GridWorld
## falls back to a code-generated primitive tinted by `placeholder_color` so
## we can iterate before Synty imports land.

@export var id: String = ""
@export var display_name: String = ""

@export_group("Mechanics")
@export var is_mineable: bool = false
@export var is_walkable: bool = false
@export var mining_hp: float = 0.0
@export var required_tool_tier: int = 0
@export var drops: Array[LootEntry] = []

@export_group("Visuals")
@export var mesh_scene: PackedScene
@export var placeholder_color: Color = Color(0.6, 0.6, 0.6)
@export var visual_y_offset: float = 0.0
## Uniform scale applied to the instanced mesh_scene. Synty POLYGON Dungeon
## Realms tiles ship at ~4m per module; set 0.5 on those if cell size is 2m.
@export var visual_scale: float = 1.0
## Y-axis rotation in degrees applied to the instanced mesh_scene. Useful to
## face walls outward or vary floor tile orientation without duplicating meshes.
@export var visual_yaw_deg: float = 0.0

@export_group("FX")
@export var mine_particles: PackedScene
@export var mine_sfx: AudioStream
