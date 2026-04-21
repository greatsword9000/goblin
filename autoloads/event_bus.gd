extends Node
## EventBus — authoritative signal catalog for cross-system events.
##
## Owns: nothing. Pure signal relay.
## Listens to: nothing.
## Rule: if a signal crosses system boundaries, it lives here. Entity-local
##       signals (e.g. HealthComponent.damaged) stay on their component.
##
## All signals are declared here but emitted/connected from other scripts —
## suppress "unused_signal" warnings for the whole file.
@warning_ignore_start("unused_signal")

# ─── World events ────────────────────────────────
signal tile_mined(grid_pos: Vector3i, tile_resource: Resource)
signal tile_built(grid_pos: Vector3i, buildable: Resource)
signal tile_changed(grid_pos: Vector3i, tile_resource: Resource)
signal chamber_detected(chamber_id: int, chamber_type: String)
signal chamber_dissolved(chamber_id: int)

# ─── Resource events ─────────────────────────────
signal resource_gained(resource_type: String, amount: int)
signal resource_spent(resource_type: String, amount: int)
signal resource_hauled_to_throne(resource_type: String, amount: int)

# ─── Entity lifecycle ────────────────────────────
signal minion_spawned(minion: Node3D)
signal minion_died(minion: Node3D)
signal adventurer_spawned(adventurer: Node3D)
signal adventurer_died(adventurer: Node3D)

# ─── Task events ─────────────────────────────────
signal task_created(task: Resource)
signal task_assigned(task: Resource, minion: Node3D)
signal task_completed(task: Resource)
signal task_failed(task: Resource, reason: String)

# ─── Ring Avatar events ──────────────────────────
signal minion_picked_up(minion: Node3D)
signal minion_dropped(minion: Node3D, grid_pos: Vector3i)
signal tile_marked(grid_pos: Vector3i, mark_type: String)
signal minion_slapped(minion: Node3D)

# ─── Ruckus events ───────────────────────────────
signal ruckus_changed(new_value: float, delta: float, source: String)
signal ruckus_threshold_crossed(threshold: float)

# ─── Raid events ─────────────────────────────────
signal raid_imminent(countdown_seconds: float, composition: Array)
signal raid_spawned(squad: Array)
signal raid_defeated()

# ─── Combat events ───────────────────────────────
signal damage_dealt(attacker: Node3D, target: Node3D, amount: float)
signal entity_died(entity: Node3D, killer: Node3D)

# ─── System events ───────────────────────────────
signal game_paused()
signal game_resumed()
signal save_requested()
signal load_requested()
signal game_saved(slot: int)
signal game_loaded(slot: int)
