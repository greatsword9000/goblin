# GOBLIN — Architecture

Companion document to `CLAUDE.md`. Covers system-level architecture, signal catalog, resource schemas, and component patterns.

---

## System map

Systems compose as follows:

```
┌────────────────────────────────────────────────────┐
│                   AUTOLOAD LAYER                   │
│  EventBus · TimeManager · SaveManager · DebugOverlay│
│  RuckusManager · TaskQueue · RaidDirector          │
└────────────────────────────────────────────────────┘
          ↑ signals             ↓ signals
┌────────────────────────────────────────────────────┐
│                   SYSTEM LAYER                     │
│  GridWorld · MiningSystem · BuildingSystem         │
│  CombatSystem · PathfindingSystem · AudioManager   │
└────────────────────────────────────────────────────┘
          ↑ signals             ↓ signals
┌────────────────────────────────────────────────────┐
│                   ENTITY LAYER                     │
│  RingAvatar · Minion · Adventurer · Interactable   │
│  (Composed from Components)                        │
└────────────────────────────────────────────────────┘
          ↑ data                ↓ data
┌────────────────────────────────────────────────────┐
│                  RESOURCE LAYER                    │
│  TileResource · MinionDefinition · BuildableDefinition│
│  TaskResource · PersonalityProfile · BehaviorTree  │
└────────────────────────────────────────────────────┘
```

**The rule:** higher layers know about lower layers, never the reverse. Entities know about their components but components don't know about entities. Systems emit signals; they don't hold entity references.

---

## Autoload registration

Add these to `Project Settings > Autoload` in order:

1. `EventBus` → `res://autoloads/event_bus.gd`
2. `TimeManager` → `res://autoloads/time_manager.gd`
3. `SaveManager` → `res://autoloads/save_manager.gd`
4. `DebugOverlay` → `res://autoloads/debug_overlay.gd`
5. `TaskQueue` → `res://autoloads/task_queue.gd`
6. `RuckusManager` → `res://autoloads/ruckus_manager.gd`
7. `RaidDirector` → `res://autoloads/raid_director.gd`

Order matters: EventBus must be first (everything depends on it). RaidDirector last (depends on Ruckus).

---

## EventBus signal catalog

This is the authoritative list. Add to `event_bus.gd`:

```gdscript
extends Node

# ─── World events ────────────────────────────────
signal tile_mined(grid_pos: Vector3i, tile_resource: TileResource)
signal tile_built(grid_pos: Vector3i, buildable: BuildableDefinition)
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
signal task_created(task: TaskResource)
signal task_assigned(task: TaskResource, minion: Node3D)
signal task_completed(task: TaskResource)
signal task_failed(task: TaskResource, reason: String)

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
signal raid_spawned(squad: Array[Node3D])
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
```

**Adding new signals:** append to this file. Never define signals on entity scripts that should be cross-system events. The EventBus is the only place cross-system signals live.

---

## Resource schemas

All content is defined as Godot `Resource` subclasses. Examples:

### TileResource (base class)

```gdscript
class_name TileResource extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var is_mineable: bool = false
@export var is_walkable: bool = false
@export var mining_hp: float = 0.0
@export var required_tool_tier: int = 0
@export var drops: Array[LootEntry] = []
@export var mesh_scene: PackedScene
@export var mine_particles: PackedScene
@export var mine_sfx: AudioStream
```

Subtypes: `FloorTile`, `MineableTile`, `SpecialWallTile`, `DecorativeTile`, `HazardTile`.

### MinionDefinition

```gdscript
class_name MinionDefinition extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
@export var base_stats: StatsProfile           # StatsProfile is its own Resource
@export var proficiency_modifiers: Dictionary  # {"mining": 1.2, "combat": 0.8}
@export var spawn_weight: float = 1.0
@export var idle_behavior_pool: Array[String]
@export var voice_pack: VoicePack              # for Phase 2+, can be null in Phase 1
```

### BuildableDefinition

```gdscript
class_name BuildableDefinition extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var scene: PackedScene
@export var grid_footprint: Vector3i = Vector3i(1, 1, 1)
@export var costs: Dictionary                  # {"gold": 10, "copper": 5}
@export var ruckus_to_build: float = 2.0
@export var build_time_seconds: float = 3.0
@export var placement_rules: Array[String]     # ["requires_floor_adjacent", "not_on_ore"]
```

### TaskResource

```gdscript
class_name TaskResource extends Resource

enum TaskType { MINE, HAUL, BUILD, DEFEND, IDLE }

@export var task_type: TaskType
@export var grid_position: Vector3i
@export var priority: float = 1.0
@export var required_tool_tier: int = 0
@export var payload: Dictionary = {}           # task-specific data
@export var assigned_to: NodePath = ""
```

### PersonalityProfile

```gdscript
class_name PersonalityProfile extends Resource

@export_range(-1.0, 1.0) var cheer: float = 0.0
@export_range(-1.0, 1.0) var curiosity: float = 0.0
@export_range(-1.0, 1.0) var gluttony: float = 0.0
@export_range(-1.0, 1.0) var courage: float = 0.0
@export_range(-1.0, 1.0) var industriousness: float = 0.0

# Generated randomly on minion spawn, persists for lifetime.
# Affects idle behavior weights, task scoring, reaction intensity.
```

---

## Component architecture

Entities are scenes composed of components. Components are scripts attached as child nodes OR `Resource`-based data holders, depending on whether they need per-frame logic.

### Core components (all entities)

**StatsComponent** — HP, max HP, attack, defense, move speed. Emits `damaged`, `died` signals locally.

**MovementComponent** — handles pathing and movement. Consumes grid coordinates, interpolates world position. Emits `reached_destination` locally.

**ReactionComponent** — listens for nearby EventBus events within radius, plays reaction animations. Data-driven: reaction table is a Resource.

### Minion-specific components

**TaskComponent** — current task reference, pulls from TaskQueue, executes via behavior tree.

**PersonalityComponent** — holds PersonalityProfile resource instance, exposes getters to behavior tree conditions.

**InventoryComponent** — what the minion is carrying. Used by HaulTask.

### Ring-Avatar-specific components

**TendrilController** — owns the verlet rope, handles attachment/release, updates rope endpoints per-frame.

**RingAbilityExecutor** — handles pickup/drop/mark/slap verbs. Routes to EventBus.

---

## Behavior tree organization

Using LimboAI plugin. Behavior trees are saved as `.tres` files in `resources/behavior_trees/`.

### Shared primitives (build once, reuse everywhere)

- `MoveToGridPosition` — takes a grid coord, pathfinds, moves
- `MoveToEntity` — takes an entity ref, pathfinds to its current position
- `PlayAnimation` — plays named animation, returns success when done
- `Wait` — delays for a duration
- `AttackTarget` — melee or ranged attack against target entity
- `PickUp` — picks up interactable item
- `DropAt` — drops held item at grid coord
- `CheckCondition` — generic condition check from blackboard

### Composite BTs (Phase 1)

- `MinionBT.tres` — root selector: [Emergency → Task → Idle]
- `WarriorBT.tres` — engage nearest hostile, respecting priority targets
- `RogueBT.tres` — bee-line to treasury, ignore combat unless blocked
- `ArcherBT.tres` — plant at optimal range, attack priority targets

---

## Save/load format

Save file is a dictionary serialized to JSON (or `var_to_bytes` for binary). Structure:

```
{
  "version": 1,
  "playtime_seconds": 1234,
  "timestamp": "2026-05-01T12:34:56",
  "world": {
    "grid_state": {...},           # tile overrides from baseline
    "chambers": [...],             # detected chambers
    "lighting_overrides": {...}
  },
  "entities": {
    "minions": [...],              # full state per minion
    "adventurers": [...],          # active adventurers if mid-raid
    "interactables": [...]
  },
  "resources": {
    "gold": 42,
    "copper": 7
  },
  "systems": {
    "ruckus_value": 0.35,
    "ruckus_accumulation_log": [...],
    "task_queue": [...],
    "raid_director_state": {...}
  },
  "flags": {...}                    # narrative flags
}
```

**Versioning:** every save has `version: int`. SaveManager owns migration functions `_migrate_v1_to_v2()` etc. Old saves never break silently — if no migration exists, load fails with a clear error.

---

## Grid system specifics

**Cell size:** 2m cubes (matches Synty POLYGON pack scale — verify on first asset import).

**Coordinate system:** Vector3i where Y is elevation. Most Phase 1 content will have Y=0 (single floor level), but system supports multi-level from day one.

**AStar3D:** use Godot's built-in `AStar3D`, manually managed. Connect cells when both become walkable. Disconnect when walls placed or tiles collapse.

**Chunking:** 16×1×16 tile chunks. Phase 1 dungeon fits in ~4 chunks. Chunks load/unload based on camera distance (even if unused in Phase 1, architecture present).

**Grid queries:** centralized in `GridWorld` service. Methods:
- `get_tile(grid_pos) -> TileResource`
- `set_tile(grid_pos, tile_resource)` — emits `tile_changed` signal
- `is_walkable(grid_pos) -> bool`
- `find_nearest_walkable(grid_pos) -> Vector3i`
- `find_path(start, end) -> PackedVector3Array`
- `get_chamber_at(grid_pos) -> ChamberId`

---

## Input map actions

Define these in `Project > Input Map`:

| Action | Default binding | Purpose |
|---|---|---|
| `ring_primary` | Left mouse button | Pick up / drop / mark |
| `ring_secondary` | Right mouse button | Open build menu / cancel |
| `ring_slap` | Left mouse double-click | Slap minion |
| `ring_multi_mark` | Shift + Left mouse drag | Mark multiple tiles |
| `camera_pan` | Middle mouse drag | Pan camera |
| `camera_rotate` | Right mouse drag (on empty space) | Rotate camera |
| `camera_zoom` | Mouse wheel | Zoom |
| `ready_button` | Space | Fill remaining Ruckus, trigger raid |
| `pause` | Escape | Pause menu |
| `debug_toggle` | Backtick (`` ` ``) | Toggle debug overlay |
| `quick_save` | Ctrl+S | Save game |
| `quick_load` | Ctrl+L | Load game |

---

## Physics layers

| Layer | Name | Purpose |
|---|---|---|
| 1 | World | Static dungeon geometry |
| 2 | Minions | Goblin minions |
| 3 | Adventurers | Hostile invaders |
| 4 | Ring Avatar | Player kid |
| 5 | Pickups | Ore, items, droppables |
| 6 | Traps | Trap triggers |
| 7 | TendrilTargets | Things the tendril can grab |
| 8 | Projectiles | Arrows, magic, etc. |

Configure in Project Settings > Layer Names > 3D Physics.

---

## Testing approach

No formal unit test harness in Phase 1 (too heavy). Instead:

- **Debug commands** via `DebugOverlay` — buttons to force-spawn raid, add gold, skip Ruckus to 100%, kill all adventurers, etc.
- **Isolated test scenes** for each system — e.g., `tests/tendril_test.tscn` for verlet rope alone, `tests/pathfinding_test.tscn` for A*.
- **Acceptance criteria per milestone** — see `PHASE_1_PLAN.md`. Every milestone ends with a specific, testable "can you do X" check.

Formal testing comes in Phase 4+ when systems interact in non-obvious ways.

---

## Performance targets (Phase 1)

- 60 FPS on mid-tier hardware (reference: GTX 1060, 16GB RAM)
- Up to 50 active entities simultaneously (10 minions + 10 adventurers + 30 props/projectiles)
- Pathfinding under 2ms per request at up to 4096 tiles
- Save/load under 500ms

If any of these slip by 2x or more during Phase 1, pause feature work and optimize. Don't let perf debt accumulate.
