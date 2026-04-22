extends Node
## FogOfWar — reveals cells the player can see; walls block line of sight.
##
## Algorithm (floodfill):
##   1. Start from each sight source (the Ring Avatar for now).
##   2. Flood through walkable cells using 4-way connectivity.
##   3. Any mineable wall adjacent to a reached walkable cell is ALSO revealed,
##      but the flood does NOT pass through it — so digging one tile only
##      reveals that tile. Digging into a room reveals the whole room because
##      the flood propagates across its walkable interior.
##   4. Limit the flood to MAX_FLOOD_CELLS so a massive cavern doesn't scan
##      the whole world in one pass (safety).
##
## Trigger: avatar moves into a new cell, a wall is mined, or a manual
## recompute_now() call. Cheap enough to run per cell change.

class_name FogOfWar

const MAX_FLOOD_CELLS: int = 4000

@export var sight_source_path: NodePath

var _last_sight_cell: Vector3i = Vector3i(999999, 0, 999999)


func _ready() -> void:
	EventBus.tile_mined.connect(_on_tile_mined)


func _process(_delta: float) -> void:
	var source: Node3D = _resolve_source()
	if source == null:
		return
	var cell: Vector3i = GridWorld.tile_at_world(source.global_position)
	if cell == _last_sight_cell:
		return
	_last_sight_cell = cell
	_recompute_visibility(cell)


func recompute_now() -> void:
	var source: Node3D = _resolve_source()
	if source == null:
		return
	_last_sight_cell = GridWorld.tile_at_world(source.global_position)
	_recompute_visibility(_last_sight_cell)


func _on_tile_mined(_grid_pos: Vector3i, _tile: TileResource) -> void:
	# A wall came down — re-flood to pick up newly-visible regions.
	recompute_now()


func _resolve_source() -> Node3D:
	if sight_source_path.is_empty():
		return null
	var n: Node = get_node_or_null(sight_source_path)
	return n as Node3D


func _recompute_visibility(origin: Vector3i) -> void:
	# BFS over walkable cells; adjacent walls are revealed but don't propagate.
	var queue: Array = [origin]
	var seen: Dictionary = {}
	seen[origin] = true
	var processed: int = 0
	while not queue.is_empty() and processed < MAX_FLOOD_CELLS:
		processed += 1
		var cell: Vector3i = queue.pop_front()
		GridWorld.reveal_cell(cell)
		for offset in [Vector3i(1,0,0), Vector3i(-1,0,0), Vector3i(0,0,1), Vector3i(0,0,-1)]:
			var nbr: Vector3i = cell + offset
			if seen.has(nbr):
				continue
			seen[nbr] = true
			var tile: TileResource = GridWorld.get_tile(nbr)
			if tile == null:
				continue
			if tile.is_walkable:
				queue.append(nbr)       # keep flooding
			else:
				GridWorld.reveal_cell(nbr)   # reveal the wall surface but stop here
