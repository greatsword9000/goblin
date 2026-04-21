class_name LootEntry extends Resource
## LootEntry — one potential drop from a mined tile.
##
## Attached to TileResource.drops as an array; when a tile is mined,
## GridWorld rolls each entry and spawns pickups accordingly.

@export var item_id: String = ""
@export var amount_min: int = 1
@export var amount_max: int = 1
@export_range(0.0, 1.0) var chance: float = 1.0
