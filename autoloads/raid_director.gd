extends Node
## RaidDirector — decides when and what adventurer squads spawn.
##
## Owns: the spawn cell (entry corridor), the throne cell (rogue target).
## Listens to: `ready_button` input (Space). Ruckus-threshold auto-trigger
## lands in piece 6.
## Emits (via EventBus): raid_spawned.
##
## M09 piece 4b: pressing Space spawns a 3-adventurer squad — one warrior,
## one rogue, one archer — all at `spawn_cell`, with raid context wired so
## rogue knows where to steal and where to flee.

const WARRIOR_DEF: AdventurerDefinition = preload("res://resources/adventurers/warrior.tres")
const ROGUE_DEF: AdventurerDefinition = preload("res://resources/adventurers/rogue.tres")
const ARCHER_DEF: AdventurerDefinition = preload("res://resources/adventurers/archer.tres")

## Set by StarterDungeon._ready once the layout is built. Fallbacks keep
## the autoload functional even if nobody registered.
var spawn_cell: Vector3i = Vector3i(15, 0, 4)
var throne_cell: Vector3i = Vector3i(5, 0, 5)

## True between the first spawn of a squad and the raid_defeated emit. Keeps
## us from firing raid_defeated on, say, the rogue despawning via "escaped"
## before the whole squad is resolved.
var _raid_active: bool = false

## Player-issued attack priority queue (AttackOrderInput writes, Minions
## read). Front is the current focus target; when it dies the next entry
## becomes active. Dead/invalid entries prune lazily on read.
var _priority_targets: Array[Node3D] = []


func _ready() -> void:
	EventBus.adventurer_died.connect(_on_adventurer_died)
	EventBus.ruckus_threshold_crossed.connect(_on_threshold_crossed)


## M09 piece 6 — Ruckus 1.0 auto-spawn. The meter emits thresholds at
## 0.25 / 0.5 / 0.75 / 0.9 / 1.0 per ruckus_weights.tres; we only care
## about the top threshold. Guarded by _raid_active so a manual Space/
## Ready press during a live raid doesn't double-spawn.
func _on_threshold_crossed(threshold: float) -> void:
	if threshold < 1.0:
		return
	if _raid_active:
		return
	spawn_squad()


# ── Attack priority API (called by AttackOrderInput + Minion) ─────────

func set_priority(target: Node3D) -> void:
	_priority_targets.clear()
	if target != null and is_instance_valid(target):
		_priority_targets.append(target)


func add_priority(target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if _priority_targets.has(target):
		return
	_priority_targets.append(target)


func clear_priority() -> void:
	_priority_targets.clear()


## Return the first alive target in the queue, pruning dead ones from
## the front. Returns null when the queue is empty or all targets died.
func get_priority_target() -> Node3D:
	while not _priority_targets.is_empty():
		var t: Node3D = _priority_targets[0]
		if t != null and is_instance_valid(t):
			return t
		_priority_targets.pop_front()
	return null


func register_spawn_cell(cell: Vector3i) -> void:
	spawn_cell = cell


func register_throne_cell(cell: Vector3i) -> void:
	throne_cell = cell


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ready_button"):
		spawn_squad()
		get_viewport().set_input_as_handled()


## Spawn a 3-adventurer squad — one of each archetype. Piece 6 will call
## this on Ruckus=1.0 instead of only on Space.
func spawn_squad() -> void:
	var squad: Array[Adventurer] = []
	# Stack along the entry corridor (west of spawn, toward the home) so all
	# three spawn on walkable floor, not in the rock either side of the
	# 1-cell-wide corridor.
	var offsets: Array[Vector3i] = [
		Vector3i(0, 0, 0),    # warrior at spawn cell
		Vector3i(-1, 0, 0),   # rogue one cell west
		Vector3i(-2, 0, 0),   # archer two cells west
	]
	var defs: Array[AdventurerDefinition] = [WARRIOR_DEF, ROGUE_DEF, ARCHER_DEF]
	for i in range(3):
		var adv: Adventurer = _spawn_one(defs[i], spawn_cell + offsets[i])
		if adv != null:
			squad.append(adv)
	if squad.is_empty():
		return
	_raid_active = true
	EventBus.raid_spawned.emit(squad)
	print("[RaidDirector] spawned squad of %d at %s" % [squad.size(), spawn_cell])


## Fired by EventBus.adventurer_died. When the last raider falls, emit
## raid_defeated — RuckusManager listens and resets the meter to its
## residual value (0.1) so the next raid needs fresh ruckus to spawn.
func _on_adventurer_died(_adv: Node3D) -> void:
	if not _raid_active:
		return
	# Wait one frame so the dying adventurer's queue_free completes before
	# we count who's left.
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("adventurers").is_empty():
		_raid_active = false
		EventBus.raid_defeated.emit()
		print("[RaidDirector] raid defeated — resetting ruckus")


func _spawn_one(def: AdventurerDefinition, at_cell: Vector3i) -> Adventurer:
	if def == null or def.scene == null:
		push_warning("[RaidDirector] definition or scene missing; cannot spawn")
		return null
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		push_warning("[RaidDirector] no current scene to parent adventurer under")
		return null
	var adv: Node3D = def.scene.instantiate()
	var typed: Adventurer = adv as Adventurer
	if typed == null:
		adv.queue_free()
		push_warning("[RaidDirector] scene didn't produce an Adventurer")
		return null
	typed.definition = def
	scene_root.add_child(typed)
	typed.global_position = GridWorld.grid_to_world(at_cell)
	# Wire raid context AFTER adding to tree so _ready has already run.
	typed.set_raid_context(spawn_cell, throne_cell)
	return typed
