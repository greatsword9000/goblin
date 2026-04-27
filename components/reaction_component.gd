class_name ReactionComponent extends Node
## ReactionComponent — attach to a minion. Listens to EventBus events and
## flashes a short speech-bubble when the event happened close by.
##
## Bark lines come from an attached ReactionTable resource. Swap in
## different tables per archetype to change personality. If no table is
## assigned, falls back to the default shipped under
## res://resources/reactions/reactions_default.tres.

const NEARBY_RADIUS_CELLS: float = 8.0
const DEFAULT_TABLE_PATH: String = "res://resources/reactions/reactions_default.tres"

@export var table: ReactionTable


func _ready() -> void:
	if table == null:
		var res: Resource = load(DEFAULT_TABLE_PATH)
		if res is ReactionTable:
			table = res
	EventBus.tile_built.connect(_on_tile_built)
	EventBus.tile_mined.connect(_on_tile_mined)
	EventBus.adventurer_spawned.connect(_on_adventurer_spawned)
	EventBus.minion_died.connect(_on_minion_died)
	EventBus.minion_picked_up.connect(_on_minion_picked_up)


func _on_tile_built(grid_pos: Vector3i, _buildable: Resource) -> void:
	_react_if_nearby("tile_built", GridWorld.grid_to_world(grid_pos))


func _on_tile_mined(grid_pos: Vector3i, _tile: Resource) -> void:
	# Don't react to our own owner's mine — that's self-congratulation.
	var owner_node: Node3D = get_parent() as Node3D
	if owner_node != null:
		var owner_cell: Vector3i = GridWorld.tile_at_world(owner_node.global_position)
		if owner_cell == grid_pos:
			return
	_react_if_nearby("tile_mined", GridWorld.grid_to_world(grid_pos))


func _on_adventurer_spawned(adv: Node3D) -> void:
	if adv == null:
		return
	# Raid-spawn alerts fire everywhere — everyone sees a raider arrive.
	_react_if_nearby("adventurer_spawned", adv.global_position, 999.0)


func _on_minion_died(dead: Node3D) -> void:
	if dead == null or dead == get_parent():
		return
	_react_if_nearby("minion_died", dead.global_position)


func _on_minion_picked_up(victim: Node3D) -> void:
	if victim == null or victim == get_parent():
		return
	_react_if_nearby("minion_picked_up", victim.global_position)


func _react_if_nearby(key: String, event_pos: Vector3, radius_override: float = -1.0) -> void:
	var owner_node: Node3D = get_parent() as Node3D
	if owner_node == null or table == null:
		return
	var radius: float = NEARBY_RADIUS_CELLS * GridWorld.CELL_SIZE
	if radius_override > 0.0:
		radius = radius_override
	if owner_node.global_position.distance_to(event_pos) > radius:
		return
	var pool: Array[String] = table.lines_for(key)
	if pool.is_empty():
		return
	var line: String = pool[randi() % pool.size()]
	var pos: Vector3 = owner_node.global_position + Vector3(0.0, 1.8, 0.0)
	SpeechBubble.spawn(pos, line, get_tree().current_scene)
