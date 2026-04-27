extends Node
## PostRaidController — M14 demo flow glue.
##
## On the first raid_defeated:
##   - If any minion died during the raid, spawn a "survivor" goblin at
##     the entry corridor cell and send them walking toward the kid.
##     They join the roster as a normal worker.
##   - After a short beat, fade in the end screen.
##
## One-shot only. Subsequent raids don't retrigger ending.

class_name PostRaidController

const END_SCREEN_SCENE: PackedScene = preload("res://ui/hud/end_screen.tscn")
const SURVIVOR_WALK_DELAY: float = 1.5   # wait after raid end before the survivor arrives
const ENDSCREEN_DELAY: float = 6.0       # total delay before endscreen fades in

@export var minion_definition: MinionDefinition
@export var ring_avatar: Node3D = null

var _casualties_this_raid: int = 0
var _ending_triggered: bool = false


func _ready() -> void:
	EventBus.minion_died.connect(_on_minion_died)
	EventBus.raid_spawned.connect(_on_raid_spawned)
	EventBus.raid_defeated.connect(_on_raid_defeated)


func _on_raid_spawned(_squad: Array) -> void:
	_casualties_this_raid = 0


func _on_minion_died(_m: Node3D) -> void:
	_casualties_this_raid += 1


func _on_raid_defeated() -> void:
	if _ending_triggered:
		return
	_ending_triggered = true
	if _casualties_this_raid > 0:
		_spawn_survivor()
	_queue_endscreen()


func _spawn_survivor() -> void:
	if minion_definition == null or minion_definition.scene == null:
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	# Wait a beat so the raid's chaos clears before the survivor walks in.
	await get_tree().create_timer(SURVIVOR_WALK_DELAY).timeout
	if not is_inside_tree():
		return
	var m: Node3D = minion_definition.scene.instantiate()
	if m is Minion:
		(m as Minion).definition = minion_definition
	scene_root.add_child(m)
	var spawn_cell: Vector3i = RaidDirector.spawn_cell
	m.global_position = GridWorld.grid_to_world(spawn_cell)
	# Nudge them toward the ring avatar so they walk into the home.
	if m is Minion and ring_avatar != null:
		var movement: MovementComponent = m.get_node_or_null("MovementComponent") as MovementComponent
		if movement != null:
			var target_cell: Vector3i = GridWorld.tile_at_world(ring_avatar.global_position)
			movement.move_to(GridWorld.find_nearest_walkable(target_cell, 3))
	EventBus.minion_spawned.emit(m)
	print("[PostRaid] survivor joined")


func _queue_endscreen() -> void:
	await get_tree().create_timer(ENDSCREEN_DELAY).timeout
	if not is_inside_tree():
		return
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var endscreen: CanvasLayer = END_SCREEN_SCENE.instantiate()
	endscreen.name = "EndScreen"
	scene_root.add_child(endscreen)
