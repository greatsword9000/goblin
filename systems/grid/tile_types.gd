## Tile-type registry marker. Subtype classes live in sibling files:
##   - floor_tile.gd          (FloorTile)
##   - mineable_tile.gd       (MineableTile)
##   - special_wall_tile.gd   (SpecialWallTile)
##   - decorative_tile.gd     (DecorativeTile)
##   - hazard_tile.gd         (HazardTile)
##
## Each subclass exists only to let systems branch on type (is MineableTile)
## and to narrow @export types in editor-authored scenes/resources. All
## shared data lives on TileResource.
##
## This file is intentionally empty — kept as a placeholder so the directory
## listing lines up with the documented set.
class_name TileTypes extends RefCounted
