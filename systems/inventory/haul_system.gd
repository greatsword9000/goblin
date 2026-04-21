extends Node
## HaulSystem — periodically scans for ungathered OrePickups and enqueues
## a HaulTask for each. The task payload carries the pickup's NodePath
## and the throne destination cell so any minion can execute it.
##
## Scene-owned — StarterDungeon adds one. Also listens for tile_mined to
## spawn the pickup entity at the cleared cell.

class_name HaulSystem

const SCAN_INTERVAL: float = 1.0

@export var ore_pickup_scene: PackedScene
@export var throne_cell: Vector3i = Vector3i(5, 0, 5)

var _scan_accum: float = 0.0
# Track pickups with pending haul tasks so we don't queue duplicates.
var _queued_pickups: Dictionary = {}  # NodePath -> true


func _ready() -> void:
	EventBus.tile_mined.connect(_on_tile_mined)


func _process(delta: float) -> void:
	_scan_accum += delta
	if _scan_accum < SCAN_INTERVAL:
		return
	_scan_accum = 0.0
	_scan_pickups()


func _on_tile_mined(grid_pos: Vector3i, tile: TileResource) -> void:
	if ore_pickup_scene == null or tile == null:
		return
	# Spawn a pickup per rolled loot entry AND enqueue its haul task now
	# so the just-finished miner (who's adjacent) gets first shot at it.
	for entry in tile.drops:
		if entry is LootEntry and randf() <= entry.chance:
			var amount: int = randi_range(entry.amount_min, entry.amount_max)
			var pickup: OrePickup = _spawn_pickup(grid_pos, entry.item_id, amount)
			if pickup != null:
				_enqueue_haul(pickup)


func _spawn_pickup(cell: Vector3i, item_id: String, amount: int) -> OrePickup:
	var pickup: Node3D = ore_pickup_scene.instantiate()
	pickup.set("item_id", item_id)
	pickup.set("amount", amount)
	get_parent().add_child(pickup)
	# Slight random offset so multiple drops don't z-fight.
	var jitter: Vector3 = Vector3(
		randf_range(-0.3, 0.3), 0.0, randf_range(-0.3, 0.3)
	)
	pickup.global_position = GridWorld.grid_to_world(cell) + jitter
	return pickup as OrePickup


func _scan_pickups() -> void:
	var scene_root: Node = get_parent()
	for p in scene_root.get_children():
		if p is OrePickup:
			var path: NodePath = p.get_path()
			if _queued_pickups.has(path):
				continue
			_queued_pickups[path] = true
			_enqueue_haul(p as OrePickup)


func _enqueue_haul(pickup: OrePickup) -> void:
	var cell: Vector3i = GridWorld.tile_at_world(pickup.global_position)
	var task: TaskResource = TaskResource.new()
	task.task_type = TaskResource.TaskType.HAUL
	task.grid_position = cell
	task.priority = 0.8  # slightly lower than mine so mining ticks first
	task.payload = {
		"pickup_path": pickup.get_path(),
		"item_id": pickup.item_id,
		"amount": pickup.amount,
		"destination": throne_cell,
	}
	TaskQueue.add_task(task)


## Called when a haul completes/fails so we can re-queue if the pickup
## still exists. Not currently hooked up — minion.gd does this inline.
func release_pickup(path: NodePath) -> void:
	_queued_pickups.erase(path)
