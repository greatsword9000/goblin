class_name Adventurer extends CharacterBody3D
## Adventurer — hostile raid unit.
##
## Code-level state dispatch driven by `definition.archetype`:
##   WARRIOR — acquire nearest minion, path to melee range, attack on cooldown.
##   ROGUE   — beeline the throne, "steal" from stockpile, flee to spawn.
##   ARCHER  — acquire nearest minion, park at attack range, fire on cooldown.
##
## No TaskComponent — adventurers don't consume the player's task queue.
## Attack damage is applied one-directionally for now; minion defend behavior
## + Ruckus reset on raid_defeated arrive in M10.
##
## Raid context (spawn cell, throne cell) is supplied by RaidDirector when
## the adventurer is instantiated so rogues know where to run and all
## archetypes know where "home" is.

signal arrived_at(grid_pos: Vector3i)

enum State { SEEKING, DEAD }

const RETARGET_INTERVAL: float = 0.5
const ARRIVE_AT_CELL_DIST: float = 1.8  # cell units — close enough to trigger arrival logic
const STEAL_AMOUNT: int = 5

@export var definition: AdventurerDefinition

@onready var _stats: StatsComponent = $StatsComponent
@onready var _movement: MovementComponent = $MovementComponent

var _state: State = State.SEEKING
var _target: Node3D = null
var _attack_accum: float = 0.0
var _retarget_accum: float = 0.0
var _last_path_target: Vector3i = Vector3i(999999, 0, 999999)
var _spawn_cell: Vector3i = Vector3i.ZERO
var _throne_cell: Vector3i = Vector3i.ZERO
var _has_stolen: bool = false
var _last_block_print_sec: float = -999.0
var adventurer_name: String = "Raider"


func _ready() -> void:
	EventBus.adventurer_spawned.emit(self)
	if definition != null:
		if definition.base_stats != null:
			_stats.max_hp = definition.base_stats.max_hp
			_stats.attack = definition.base_stats.attack
			_stats.defense = definition.base_stats.defense
			_stats.move_speed = definition.base_stats.move_speed
		_movement.speed = _stats.move_speed
	_stats.died.connect(_on_died)
	_stats.damaged.connect(_on_damaged)
	_movement.reached_destination.connect(_on_arrived)
	_movement.path_blocked.connect(_on_path_blocked)
	add_to_group("adventurers")


## Called by RaidDirector right after instantiation so archetype behavior
## has everything it needs (rogue target + retreat destination).
func set_raid_context(spawn_cell: Vector3i, throne_cell: Vector3i) -> void:
	_spawn_cell = spawn_cell
	_throne_cell = throne_cell


func _physics_process(delta: float) -> void:
	if _state == State.DEAD or definition == null:
		return
	_retarget_accum += delta
	match definition.archetype:
		AdventurerDefinition.Archetype.WARRIOR:
			_tick_warrior(delta)
		AdventurerDefinition.Archetype.ROGUE:
			_tick_rogue(delta)
		AdventurerDefinition.Archetype.ARCHER:
			_tick_archer(delta)


# ── Archetype ticks ────────────────────────────────────────────────────

func _tick_warrior(delta: float) -> void:
	_refresh_target_if_due()
	if _target == null:
		_halt()
		return
	var target_world: Vector3 = (_target as Node3D).global_position
	var in_range: bool = global_position.distance_to(target_world) <= _attack_range_world()
	if in_range:
		_halt()
		_try_attack(delta, _target)
	else:
		_move_toward_cell(GridWorld.tile_at_world(target_world))


func _tick_rogue(delta: float) -> void:
	if not _has_stolen:
		var at_throne: bool = global_position.distance_to(GridWorld.grid_to_world(_throne_cell)) <= ARRIVE_AT_CELL_DIST * GridWorld.CELL_SIZE
		if at_throne:
			_steal()
		else:
			_move_toward_cell(_throne_cell)
	else:
		# Flee back to the entry. On arrival, despawn — rogue is "escaped".
		var at_spawn: bool = global_position.distance_to(GridWorld.grid_to_world(_spawn_cell)) <= ARRIVE_AT_CELL_DIST * GridWorld.CELL_SIZE
		if at_spawn:
			print("[Adventurer %s] escaped with loot" % adventurer_name)
			queue_free()
		else:
			_move_toward_cell(_spawn_cell)


func _tick_archer(delta: float) -> void:
	_refresh_target_if_due()
	if _target == null:
		_halt()
		return
	var target_world: Vector3 = (_target as Node3D).global_position
	var dist: float = global_position.distance_to(target_world)
	var range_world: float = _attack_range_world()
	if dist <= range_world:
		# Plant and shoot — don't close further, just fire on cooldown.
		_halt()
		_try_attack(delta, _target)
	else:
		_move_toward_cell(GridWorld.tile_at_world(target_world))


# ── Helpers ────────────────────────────────────────────────────────────

func _refresh_target_if_due() -> void:
	if _target != null and is_instance_valid(_target) and _retarget_accum < RETARGET_INTERVAL:
		return
	_retarget_accum = 0.0
	_target = _find_nearest_minion()


func _find_nearest_minion() -> Node3D:
	var best: Node3D = null
	var best_d2: float = INF
	for m in get_tree().get_nodes_in_group("minions"):
		if not (m is Node3D) or not is_instance_valid(m):
			continue
		var d2: float = global_position.distance_squared_to((m as Node3D).global_position)
		if d2 < best_d2:
			best_d2 = d2
			best = m as Node3D
	return best


func _attack_range_world() -> float:
	return definition.attack_range_cells * GridWorld.CELL_SIZE


## Idempotent path request — only calls _movement.move_to when the target
## cell has actually changed, so the pathfinder isn't recomputed every
## physics frame while chasing a moving minion.
func _move_toward_cell(cell: Vector3i) -> void:
	if _last_path_target == cell:
		return
	_last_path_target = cell
	var walkable: Vector3i = GridWorld.find_nearest_walkable(cell, 3)
	_movement.move_to(walkable)


## Stop moving AND clear the short-circuit sentinel so the next
## _move_toward_cell always repaths — prevents a stuck-at-range loop
## where the archer halts, the target drifts out of range, and
## _move_toward_cell short-circuits because _last_path_target is stale.
func _halt() -> void:
	_movement.stop()
	_last_path_target = Vector3i(999999, 0, 999999)


func _try_attack(delta: float, target: Node3D) -> void:
	_attack_accum += delta
	if _attack_accum < definition.attack_cooldown_seconds:
		return
	_attack_accum = 0.0
	var stats: StatsComponent = target.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
	stats.take_damage(definition.attack_damage, self)


func _steal() -> void:
	_halt()
	_has_stolen = true
	if ResourceManager.spend("Resource", STEAL_AMOUNT):
		print("[Adventurer %s] stole %d Resource from the throne" % [adventurer_name, STEAL_AMOUNT])
	else:
		print("[Adventurer %s] reached throne but stockpile was empty" % adventurer_name)


# ── Movement signal handlers ───────────────────────────────────────────

func _on_arrived() -> void:
	arrived_at.emit(GridWorld.tile_at_world(global_position))
	# The archetype ticks drive the next action on the next frame; nothing
	# to do here beyond the signal notification.


func _on_path_blocked(reason: String) -> void:
	# Throttle to 1 print/sec — adventurers retry paths every tick while
	# they can't reach a target, which used to flood the console.
	var now: float = Time.get_ticks_msec() / 1000.0
	if now - _last_block_print_sec >= 1.0:
		_last_block_print_sec = now
		print("[Adventurer %s] path blocked (%s)" % [adventurer_name, reason])
	# Clear last path target so the next tick will try a fresh route.
	_last_path_target = Vector3i(999999, 0, 999999)


func _on_damaged(amount: float, _attacker: Node) -> void:
	# Red numbers for raiders — contrasts with the minion yellow so the
	# player can parse "who hit whom" at a glance during a melee pile-up.
	var pos: Vector3 = global_position + Vector3(0.0, 1.4, 0.0)
	DamageNumber.spawn(pos, amount, Color(1.0, 0.35, 0.32), get_tree().current_scene)
	HitFlash.flash_descendants(self, Color(1.0, 0.9, 0.9))


func _on_died(_killer: Node) -> void:
	EventBus.adventurer_died.emit(self)
	_state = State.DEAD
	_drop_loot()
	_play_death_fall()


## Drop a small Resource pickup at the adventurer's feet. Gets HauledSystem
## scanned into the queue within ~1s. Phase 1 loot — just one pickup.
func _drop_loot() -> void:
	var scene: PackedScene = load("res://entities/interactables/ore_pickup.tscn")
	if scene == null:
		return
	var pickup: Node3D = scene.instantiate()
	pickup.set("item_id", "Resource")
	pickup.set("amount", 2)
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		pickup.queue_free()
		return
	scene_root.add_child(pickup)
	pickup.global_position = global_position + Vector3(0.0, 0.1, 0.0)


func _play_death_fall() -> void:
	# Exit the adventurers group immediately so minions stop swinging at
	# a corpse AND so RaidDirector._on_adventurer_died counts correctly
	# when it checks `get_nodes_in_group("adventurers").is_empty()`.
	if is_in_group("adventurers"):
		remove_from_group("adventurers")
	collision_layer = 0
	collision_mask = 0
	_movement.stop()
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "rotation:z", PI * 0.5, 0.45)
	tween.tween_property(self, "global_position:y", global_position.y - 0.3, 0.45)
	tween.chain().tween_interval(0.8)
	tween.chain().tween_callback(queue_free)
