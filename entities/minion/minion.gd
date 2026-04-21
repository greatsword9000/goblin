class_name Minion extends CharacterBody3D
## Minion — goblin worker, the core laborer of the dungeon.
##
## Runs a simple code-built behavior loop:
##   1. If no task: ask TaskQueue for work.
##   2. If task.MINE: pathfind to the tile, mine it, clear task.
##   3. If no task available: wander briefly.
##
## Uses: StatsComponent (HP), MovementComponent (AStar3D pathing),
##       TaskComponent (task state). Minion.gd glues them together.

signal arrived_at(grid_pos: Vector3i)

enum State { IDLE, MOVING_TO_TASK, MINING, HAULING_TO_PICKUP, HAULING_TO_THRONE, WANDERING }

@export var definition: MinionDefinition

const MINE_RANGE_CELLS: float = 1.6   # how close is "adjacent enough to mine"
const MINE_DAMAGE_PER_SEC: float = 4.0
const IDLE_POLL_INTERVAL: float = 0.15
const PICKUP_REACH: float = 1.6  # cells — was 1.2 but exact-equal cases floated over
const THRONE_REACH: float = 1.6

var _carried_item_id: String = ""
var _carried_amount: int = 0
var _carried_pickup: Node = null

@onready var _stats: StatsComponent = $StatsComponent
@onready var _movement: MovementComponent = $MovementComponent
@onready var _task: TaskComponent = $TaskComponent
@onready var _grabbable: GrabbableComponent = $GrabbableComponent

var _state: State = State.IDLE
var _idle_poll_accum: float = 0.0
var _mine_accum: float = 0.0

var minion_name: String = "Grobnar"  # placeholder; M11 will name-generate


func _ready() -> void:
	EventBus.minion_spawned.emit(self)
	if definition != null:
		if definition.base_stats != null:
			_stats.max_hp = definition.base_stats.max_hp
			_stats.attack = definition.base_stats.attack
			_stats.defense = definition.base_stats.defense
			_stats.move_speed = definition.base_stats.move_speed
		_movement.speed = _stats.move_speed
	_stats.died.connect(_on_died)
	_movement.reached_destination.connect(_on_arrived)
	_movement.path_blocked.connect(_on_path_blocked)
	add_to_group("minions")
	# Proactive claim: when a new task appears, if we're idle, try now.
	# Avoids the race where the poll timer decides who gets the task.
	EventBus.task_created.connect(_on_task_created)


func _on_task_created(task_res: TaskResource) -> void:
	var held: bool = _grabbable != null and _grabbable.is_held
	print("[%s] task_created signal: type=%s at %s  my_state=%s  held=%s" % [
		name, TaskResource.TaskType.keys()[task_res.task_type],
		task_res.grid_position, State.keys()[_state], held,
	])
	if _state == State.IDLE and not held:
		_try_claim_task()


func _on_path_blocked(reason: String) -> void:
	print("[Minion %s] path blocked (%s) in state %s; returning to IDLE" % [
		name, reason, State.keys()[_state],
	])
	# Release the task so another minion or another pass can handle it.
	if _task.has_task():
		_task.finish_task(false)
	_state = State.IDLE


func _physics_process(delta: float) -> void:
	# While the ring is holding this minion, PickupSystem owns the transform;
	# skip the state machine so we don't pathfind while airborne.
	if _grabbable != null and _grabbable.is_held:
		return
	match _state:
		State.IDLE:
			_idle_poll_accum += delta
			if _idle_poll_accum >= IDLE_POLL_INTERVAL:
				_idle_poll_accum = 0.0
				_try_claim_task()
		State.MOVING_TO_TASK:
			# MovementComponent drives movement; we wait for reached_destination.
			pass
		State.MINING:
			_mine_tick(delta)
		State.WANDERING:
			pass


func _try_claim_task() -> void:
	var task: TaskResource = _task.try_claim_next()
	if task == null:
		return  # Silent — idle polls every 150ms would flood Output.
	print("[%s] CLAIMED task type=%s at %s" % [
		name, TaskResource.TaskType.keys()[task.task_type], task.grid_position,
	])
	match task.task_type:
		TaskResource.TaskType.MINE:
			_begin_mine(task)
		TaskResource.TaskType.HAUL:
			_begin_haul(task)
		_:
			# Unknown/unhandled task — fail so someone else can try
			_task.finish_task(false)


func _begin_mine(task: TaskResource) -> void:
	_state = State.MOVING_TO_TASK
	# Move to a walkable cell adjacent to the target, not into the wall itself.
	var target: Vector3i = GridWorld.find_nearest_walkable(task.grid_position, 3)
	_movement.move_to(target)


func _on_arrived() -> void:
	if not _task.has_task():
		_state = State.IDLE
		return
	if _state == State.MOVING_TO_TASK:
		match _task.current_task.task_type:
			TaskResource.TaskType.MINE:
				_state = State.MINING
				_mine_accum = 0.0
			TaskResource.TaskType.HAUL:
				_state = State.HAULING_TO_PICKUP
				_try_claim_pickup()
	elif _state == State.HAULING_TO_PICKUP:
		_try_claim_pickup()
	elif _state == State.HAULING_TO_THRONE:
		_deliver_to_throne()


func _begin_haul(task: TaskResource) -> void:
	_state = State.MOVING_TO_TASK
	var pickup_cell: Vector3i = task.grid_position
	var walkable: Vector3i = GridWorld.find_nearest_walkable(pickup_cell, 3)
	var my_cell: Vector3i = GridWorld.tile_at_world(global_position)
	print("[%s] begin_haul: pickup_cell=%s  walk_to=%s  my_cell=%s" % [
		name, pickup_cell, walkable, my_cell,
	])
	_movement.move_to(walkable)


func _try_claim_pickup() -> void:
	if not _task.has_task():
		_state = State.IDLE
		return
	var task: TaskResource = _task.current_task
	var payload: Dictionary = task.payload
	var pickup_path: NodePath = payload.get("pickup_path", NodePath(""))
	var pickup: Node = get_node_or_null(pickup_path)
	if pickup == null:
		# Pickup's gone for good (another minion grabbed it, or we consumed
		# a sibling task earlier). DROP the task — don't re-queue, or we get
		# an infinite loop of minions claiming a phantom task.
		print("[%s] pickup vanished; dropping task" % name)
		TaskQueue.fail_task(_task.current_task, "pickup_gone", true)
		_task.current_task = null
		_state = State.IDLE
		return
	var dist: float = global_position.distance_to(pickup.global_position)
	if dist > PICKUP_REACH * GridWorld.CELL_SIZE:
		# Too far — re-path toward the nearest walkable adjacent to the
		# pickup. Using the pickup's exact cell might be non-walkable (ore
		# cells lose their walkable status after mining too).
		var repath_target: Vector3i = GridWorld.find_nearest_walkable(
			GridWorld.tile_at_world(pickup.global_position), 3,
		)
		_movement.move_to(repath_target)
		_state = State.MOVING_TO_TASK
		return
	# Reparent the pickup onto the minion so it's visibly carried.
	_carried_item_id = str(payload.get("item_id", ""))
	_carried_amount = int(payload.get("amount", 0))
	_carried_pickup = pickup
	if pickup.has_method("claim"):
		pickup.call("claim", self)
	var dest: Vector3i = payload.get("destination", Vector3i.ZERO)
	_state = State.HAULING_TO_THRONE
	print("[Minion %s] hauling %d %s to throne at %s" % [name, _carried_amount, _carried_item_id, dest])
	_movement.move_to(GridWorld.find_nearest_walkable(dest, 3))


func _deliver_to_throne() -> void:
	if _carried_amount > 0 and _carried_item_id != "":
		ResourceManager.haul_to_throne(_carried_item_id, _carried_amount)
	if _carried_pickup != null and is_instance_valid(_carried_pickup):
		if _carried_pickup.has_method("consume"):
			_carried_pickup.call("consume")
		else:
			_carried_pickup.queue_free()
	_carried_pickup = null
	_carried_item_id = ""
	_carried_amount = 0
	_task.finish_task(true)
	_state = State.IDLE


func _mine_tick(delta: float) -> void:
	if not _task.has_task():
		_state = State.IDLE
		return
	var task: TaskResource = _task.current_task
	var tile: TileResource = GridWorld.get_tile(task.grid_position)
	if tile == null or not tile.is_mineable:
		# Someone else finished it, or tile gone.
		_task.finish_task(true)
		_state = State.IDLE
		return
	# Check we're still in range — minion might have been shoved.
	var target_world: Vector3 = GridWorld.grid_to_world(task.grid_position)
	if global_position.distance_to(target_world) > MINE_RANGE_CELLS * GridWorld.CELL_SIZE:
		_state = State.MOVING_TO_TASK
		_movement.move_to(GridWorld.find_nearest_walkable(task.grid_position, 3))
		return

	_mine_accum += delta * MINE_DAMAGE_PER_SEC
	if _mine_accum >= (tile as MineableTile).mining_hp:
		print("[Minion %s] mined %s at %s" % [name, tile.id, task.grid_position])
		_finish_mine(task, tile)


func _physics_state_tick(delta: float) -> void:
	# Hauling state tick — drives waypoint arrival handled by _on_arrived.
	# Carried transition is one-shot, so this is a no-op for M06.
	pass


func _finish_mine(task: TaskResource, tile: TileResource) -> void:
	# CRITICAL ORDER:
	#   1. Mark ourselves IDLE + release task first
	#   2. THEN clear the tile + emit tile_mined
	# Reason: HaulSystem listens to tile_mined, creates the haul task, and
	# fires task_created. Our _on_task_created checks `_state == IDLE` —
	# if we haven't transitioned yet, we miss our own haul opportunity and
	# the other minion claims it even though we're right next to the ore.
	var pos: Vector3i = task.grid_position
	_state = State.IDLE
	_task.finish_task(true)
	_mine_accum = 0.0
	GridWorld.clear_tile(pos)
	EventBus.tile_mined.emit(pos, tile)


func _on_died(_killer: Node) -> void:
	EventBus.minion_died.emit(self)
	queue_free()


## Utility hook consumed by TaskQueue when scoring — returns how proficient
## this minion is at a given task type. Reads definition.proficiency_modifiers.
func get_task_proficiency(task_type: int) -> float:
	if definition == null:
		return 1.0
	var key: String = _task_type_key(task_type)
	return float(definition.proficiency_modifiers.get(key, 1.0))


func _task_type_key(task_type: int) -> String:
	match task_type:
		TaskResource.TaskType.MINE: return "mining"
		TaskResource.TaskType.HAUL: return "hauling"
		TaskResource.TaskType.BUILD: return "building"
		TaskResource.TaskType.DEFEND: return "combat"
		_: return "idle"
