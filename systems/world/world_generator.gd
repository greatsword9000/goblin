class_name WorldGenerator extends RefCounted
## WorldGenerator — fills GridWorld with tile data for a large play area.
##
## Layout:
##   - A large outer square of CAVE_ROCK tiles (mineable) covers most of the
##     world, forming the dig-outable mass.
##   - A pre-carved rectangular "home" in the middle has floor tiles (walkable).
##   - A throne dais + throne prop sit inside the home.
##   - Tile DATA is set for all cells up front so pathfinding + systems can
##     query anywhere, but VISUALS stay unspawned until the FogOfWar system
##     reveals a cell. Keeps 100x100 worlds cheap.

static func generate(
	rock_tile: TileResource,
	floor_tile: TileResource,
	throne_base_tile: TileResource,
	world_radius: int,
	home_min: Vector2i,
	home_max: Vector2i,
	throne_cell: Vector2i,
) -> void:
	# Fill the whole world bounds with cave rock (data only, no visuals).
	for x in range(-world_radius, world_radius + 1):
		for z in range(-world_radius, world_radius + 1):
			var cell := Vector3i(x, 0, z)
			var is_home: bool = (
				x >= home_min.x and x <= home_max.x
				and z >= home_min.y and z <= home_max.y
			)
			if is_home:
				GridWorld.set_tile(cell, floor_tile, NAN, false)
			else:
				GridWorld.set_tile(cell, rock_tile, NAN, false)
	# Throne dais replaces the floor at the throne cell.
	var throne_v3 := Vector3i(throne_cell.x, 0, throne_cell.y)
	GridWorld.set_tile(throne_v3, throne_base_tile, NAN, false)


## Reveal all cells in a rectangular region — used to make the home visible
## at game start before fog-of-war has run its first pass.
static func reveal_rect(mn: Vector2i, mx: Vector2i) -> void:
	for x in range(mn.x, mx.x + 1):
		for z in range(mn.y, mx.y + 1):
			GridWorld.reveal_cell(Vector3i(x, 0, z))
