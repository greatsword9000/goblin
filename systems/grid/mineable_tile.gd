class_name MineableTile extends TileResource
## Mineable wall — minions can harvest and it yields loot.
##
## Set `mining_hp`, `required_tool_tier`, `drops` on the .tres instance.
## Typically `is_walkable = false` until destroyed.

## What to place in the cell after the wall is mined out. Usually a floor
## tile so there's walkable ground where the wall stood. If null, the cell
## is left empty (non-walkable, non-rendered) — useful for edge-of-world rocks.
@export var replaces_with: TileResource
