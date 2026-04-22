# GOBLIN — Phase 1 Implementation Plan

Ordered milestones for building the Phase 1 prototype. Each milestone is a complete, testable increment. **Work through in order. Do not skip.**

Phase 1 goal: produce a 15-minute playable prototype that tests the hypothesis *"Is this fun. Do I want to keep playing. I want more."*

---

## How to use this document

1. Start with the first unchecked milestone.
2. Read the full milestone spec before writing code.
3. Build it. Test against acceptance criteria.
4. Commit: `feat: MXX - milestone name`
5. Mark the milestone complete below with `[x]` and commit hash.
6. Move to next milestone.

If you hit a blocker, stop and ask the user. Do not guess on:
- Synty asset import issues (user has a specific pipeline)
- Godot version-specific behavior
- Anything that might conflict with Physics Survivors patterns

---

## Progress tracker

- [x] M00 — Project skeleton (c2145f8, 2026-04-21)
- [x] M01 — 3D grid foundation (8128c1d, 2026-04-21)
- [x] M02 — Ring Avatar movement & camera (8128c1d, 2026-04-21)
- [~] M03 — Verlet rope tendril (8128c1d — physics landed; visual cut, BACKLOG)
- [x] M04 — First minion & task system (afcbc16, 2026-04-21)
- [x] M05 — Pick up & drop (8487a76, 2026-04-21 — no tendril visual; BACKLOG)
- [x] M06 — Mining & hauling loop (0094e58, 2026-04-21 — throne visual scale deferred)
- [x] M07 — Ruckus system (4a3cdcc, 2026-04-22)
- [ ] M08 — Building (wall + trap + nursery)
- [ ] M09 — Adventurer AI & raid spawn
- [ ] M10 — Combat resolution
- [ ] M11 — Personality system (light)
- [ ] M12 — Minion reactions
- [ ] M13 — Save/load full wiring
- [ ] M14 — Demo flow & horizon

---

## M00 — Project skeleton

**Goal:** Godot project exists with all autoloads stubbed, debug overlay running, no gameplay yet.

**Build:**
- Initialize Godot 4.4.x project, Forward+ renderer
- Configure input map per `ARCHITECTURE.md`
- Configure physics layers per `ARCHITECTURE.md`
- Install LimboAI plugin from AssetLib
- Create directory structure per `CLAUDE.md`
- Stub all 7 autoloads (empty scripts with class headers and TODO markers)
- Register autoloads in `Project Settings > Autoload`
- Implement `DebugOverlay` minimum viable: backtick toggles a panel showing FPS, frame time, and mouse world position
- Create a single test scene with a gray placeholder ground mesh and the default lighting
- Set up Git + LFS. Initial commit.

**Files to create:**
- `project.godot` (auto-generated, verify autoload order)
- `autoloads/event_bus.gd` (signal stubs per `ARCHITECTURE.md` catalog)
- `autoloads/time_manager.gd`
- `autoloads/save_manager.gd`
- `autoloads/debug_overlay.gd` (functional backtick toggle + FPS panel)
- `autoloads/task_queue.gd` (stub)
- `autoloads/ruckus_manager.gd` (stub)
- `autoloads/raid_director.gd` (stub)
- `world/test_scene.tscn` (gray ground, default light)
- `SETUP.md` in root

**Acceptance criteria:**
- Project runs from Godot editor without errors
- backtick toggles the debug overlay, which shows FPS
- Autoloads all load (check in remote debugger)
- No linter warnings on any script

---

## M01 — 3D grid foundation

**Goal:** A 3D grid of tiles exists. We can place Synty meshes on grid cells. Camera can fly around.

**Build:**
- `systems/grid/grid_world.gd` — singleton service (add as autoload too, or access via group)
- `systems/grid/tile_resource.gd` — base class
- `systems/grid/tile_types.gd` — subtypes: `FloorTile`, `MineableTile`, `SpecialWallTile`, `DecorativeTile`
- Cell size constant = 2.0 meters
- `GridWorld.set_tile(grid_pos: Vector3i, tile: TileResource)` instantiates the tile's mesh scene at world position
- `GridWorld.get_tile(grid_pos: Vector3i) -> TileResource`
- `GridWorld.clear_tile(grid_pos: Vector3i)`
- Camera rig: `RTSCameraController.gd` on a `Camera3D` + `Node3D` parent
  - Iso-ish angle (30-45° pitch)
  - WASD pans
  - Middle mouse drag pans
  - Right mouse drag rotates (when not on entity)
  - Mouse wheel zooms (clamped)
- Import first Synty pack (POLYGON Dungeons). Create 3-5 `TileResource` instances referencing Synty meshes:
  - `floor_stone.tres`
  - `wall_stone.tres` (mineable)
  - `wall_ore_copper.tres` (mineable, drops copper)
  - `throne_pile.tres` (decorative, placeholder large gold pile mesh)
- Hand-place a 10×10 starter dungeon in code at `_ready()` for now (procedural comes much later)

**Files to create:**
- `systems/grid/grid_world.gd`
- `systems/grid/tile_resource.gd`
- `systems/grid/tile_types.gd`
- `systems/grid/rts_camera_controller.gd`
- `resources/tiles/floor_stone.tres`
- `resources/tiles/wall_stone.tres`
- `resources/tiles/wall_ore_copper.tres`
- `resources/tiles/throne_pile.tres`
- `world/starter_dungeon.tscn` (replace `test_scene.tscn`)
- `systems/grid/SETUP.md`

**Acceptance criteria:**
- Running the project shows a 10×10 dungeon made of Synty tiles
- Camera can pan with WASD, rotate with right-mouse, zoom with wheel
- Debug overlay shows current tile under mouse cursor
- Adding a new tile definition is a matter of creating a `.tres` file, no code changes needed

---

## M02 — Ring Avatar movement & camera

**Goal:** The kid (Ring Avatar) exists in the dungeon, moves around, is visually anchored. No interactions yet.

**Build:**
- `entities/ring_avatar/ring_avatar.tscn` — `CharacterBody3D` root
  - Synty goblin kid mesh as visual child
  - Slight vertical bob animation (sine wave in `_process`)
  - Subtle emissive glow around the ring hand (placeholder — will become tendril origin in M03)
- `entities/ring_avatar/ring_avatar.gd`
  - WASD movement (drift-style, floating, not grounded)
  - Camera follows from above with smooth lerp
  - Faces movement direction
- Update camera rig: parent to RingAvatar but allow decoupled pan/rotate

**Files to create:**
- `entities/ring_avatar/ring_avatar.tscn`
- `entities/ring_avatar/ring_avatar.gd`
- `entities/ring_avatar/SETUP.md`

**Acceptance criteria:**
- Pressing WASD moves the kid smoothly through the dungeon
- The kid has a visible slight float/bob
- Camera follows the kid but can still be panned independently
- Cursor raycasts from camera to world — debug overlay shows which grid cell cursor is over

---

## M03 — Verlet rope tendril

**Goal:** The signature telekinetic tendril. When you hold left mouse, an energy tendril extends from the kid's hand toward the cursor. When you release, it retracts.

**Build:**
- `entities/ring_avatar/tendril_controller.gd`
  - Owns a verlet rope with N segments (start with 15)
  - Rope physics: gravity, damping, constraint iterations
  - Rope origin: anchored to kid's hand
  - Rope end: follows cursor world position when active, retracts when released
  - Visual: `ImmediateMesh` drawing tube geometry per-frame, emissive purple material
  - When extending: stretches from origin toward target. When released: segment endpoints pull back toward origin via spring force.
- Collision check: raycast from origin to current end, if it hits a wall, truncate the rope at hit point
- Smooth stretch interpolation — not instant

**Files to create:**
- `entities/ring_avatar/tendril_controller.gd`
- `assets/shaders/tendril_material.tres` (emissive, slight pulse)

**Acceptance criteria:**
- Holding left mouse extends a glowing purple tendril from the kid toward the cursor
- The tendril has visible physical sag and whip when the cursor moves quickly
- Releasing left mouse smoothly retracts the tendril
- The tendril is visually distinct and readable from any camera angle
- 60 FPS maintained even with tendril active

**Test scene:** `tests/tendril_test.tscn` — just the ring avatar on a flat plane. Isolate this system and make sure it feels good before moving on.

---

## M04 — First minion & task system

**Goal:** A goblin minion exists. The task queue works. Clicking a wall creates a mine task. The nearest idle minion walks over and mines it.

**Build:**
- `entities/minion/minion.tscn` — `CharacterBody3D` with Synty goblin mesh
- `entities/minion/minion.gd` — behavior tree driven via LimboAI
- `components/stats_component.gd`
- `components/movement_component.gd` — pathfinding via `AStar3D` managed by `GridWorld`
- `components/task_component.gd` — holds current task, executes via BT blackboard
- `resources/behavior_trees/minion_bt.tres` — root selector: [ExecuteTask, Idle]
  - `ExecuteTask` branch: read current task, dispatch to appropriate sub-tree
  - `Idle` branch: wander or stand
- `resources/behavior_trees/task_mine.tres` — MoveToGridPosition → MineTile → ClearTask
- `autoloads/task_queue.gd` full implementation:
  - `add_task(task: TaskResource)`
  - `claim_next(minion: Node3D) -> TaskResource` (utility-scored)
  - `complete_task(task: TaskResource)`
  - Utility scoring: distance + priority + skill proficiency
- `systems/mining/mining_system.gd` — click on mineable tile creates MineTask
- `resources/minions/goblin_worker.tres` — MinionDefinition
- Spawn 2 minions at game start (hand-placed in `starter_dungeon.tscn`)

**Files to create:**
- `entities/minion/minion.tscn`, `minion.gd`
- `components/stats_component.gd`, `movement_component.gd`, `task_component.gd`
- `resources/behavior_trees/minion_bt.tres`, `task_mine.tres`
- `systems/mining/mining_system.gd`
- `resources/minions/goblin_worker.tres`

**Acceptance criteria:**
- Click a mineable wall tile → a MineTask appears in the queue (visible in debug overlay)
- The nearest idle goblin walks over and begins mining
- Mining plays a SFX, spawns particles, decrements tile HP
- When tile HP reaches 0, tile clears, loot drops (gold pickup), EventBus emits `tile_mined`
- Minion returns to idle after task completes

---

## M05 — Pick up & drop

**Goal:** The Ring Avatar's first active verb. Left-click on a minion to lift them with the tendril. Move mouse. Release to drop.

**Build:**
- Extend `tendril_controller.gd`:
  - On left-click: raycast. If hit is on `TendrilTargets` layer (minions are), attach tendril end to minion
  - While held: lift minion up slightly (0.5-1m), follow cursor position on XZ plane, Y stays lifted
  - On release: drop minion at current ground position below cursor
  - Minion, once dropped, immediately re-pathfinds to new idle position (or current task if held one)
- `components/grabbable_component.gd` — marks entity as tendril-targetable. Has `on_grabbed()` / `on_released(grid_pos)` callbacks
- Minion scene gets `GrabbableComponent`

**Edge cases:**
- If dropping on non-walkable tile, minion finds nearest walkable and pathfinds there
- If minion was mid-task, task is paused on grab, resumed on drop (if still feasible)
- Multiple simultaneous grabs disallowed (tendril grabs one thing at a time)

**Files to create:**
- `components/grabbable_component.gd`
- Update `tendril_controller.gd` for grab logic

**Acceptance criteria:**
- Left-click a minion → they lift into the air, tendril attached
- Moving mouse swings the minion around, with slight physical lag (feels weighty)
- Releasing left-click drops them at the cursor's ground position
- Minion resumes sensible behavior (idle or prior task)
- Cannot grab multiple at once
- EventBus emits `minion_picked_up` and `minion_dropped` appropriately

**This is the first real "spirit beat." The interaction should feel satisfying and slightly silly. Spend time on feel.**

---

## M06 — Mining & hauling loop

**Goal:** The full resource loop. Mined ore drops as a pickup. A different idle minion picks up the ore and hauls it to the throne. Throne visual scales with stored gold.

**Build:**
- `entities/interactables/ore_pickup.tscn` — small mesh (Synty gem prop), `GrabbableComponent`, `ItemComponent`
- `resources/items/copper_ore.tres`, `gold_ore.tres`
- `systems/inventory/resource_manager.gd` — tracks stockpiles (autoload? or part of TaskQueue context)
  - `gain(type: String, amount: int)` — emits `resource_gained`
  - `spend(type: String, amount: int) -> bool`
- `resources/behavior_trees/task_haul.tres` — MoveToItem → PickUp → MoveToThrone → DropAt
- When `tile_mined` fires, spawn ore pickup at tile location
- HaulTask auto-created by system: scan for ungathered ores periodically, enqueue
- Throne is a specific grid cell marked `throne_pile`. On ore haul, ore despawns, ResourceManager updated, throne visual scales slightly
- Update starter dungeon to have a throne room with visible gold pile

**Visual feedback:**
- Gold pile has multiple visual tiers (tiny pile → small mound → big heap → overflowing) swapped based on gold count
- Ore pickups glint subtly so they're easy to spot

**Files to create:**
- `entities/interactables/ore_pickup.tscn`, `.gd`
- `components/item_component.gd`
- `systems/inventory/resource_manager.gd`
- `resources/behavior_trees/task_haul.tres`
- Updates to `starter_dungeon.tscn`

**Acceptance criteria:**
- Click mineable wall → goblin mines it → ore drops → another idle goblin hauls it to throne
- Gold counter in HUD increments
- Throne visual gets bigger as gold accumulates
- The whole loop runs without any player input after the initial mine click (minions self-direct)

---

## M07 — Ruckus system

**Goal:** The pacing mechanism. Actions generate Ruckus. Meter visible in HUD. Threshold triggers (visual only for now — raids come in M09).

**Build:**
- `autoloads/ruckus_manager.gd` full implementation:
  - Holds current Ruckus value (0.0 - 1.0)
  - Listens to tagged events on EventBus (`tile_mined`, `adventurer_died`, `tile_built`, etc.)
  - Has a tunable weights table as a Resource
  - `add_ruckus(amount: float, source: String)` — emits `ruckus_changed`
  - Thresholds at 0.25, 0.5, 0.75, 0.9, 1.0 emit `ruckus_threshold_crossed`
- `resources/ruckus_weights.tres` — dictionary of event → weight (editable without code)
  - `tile_mined`: 0.02
  - `tile_built`: 0.04
  - `adventurer_killed`: 0.15
  - `adventurer_spared`: 0.03
- HUD: Ruckus meter widget. Subtle color shift at thresholds (green → amber → red)
- At 75% threshold: distant torch VFX appears at entry corridor (placeholder — can be a simple glowing sphere). Remove at 100% when raid triggers.

**Files to create:**
- Full `ruckus_manager.gd`
- `resources/systems/ruckus_weights.tres`
- `ui/hud/ruckus_meter.tscn`, `.gd`
- `entities/effects/distant_torch_telegraph.tscn`

**Acceptance criteria:**
- Mining a tile ticks the Ruckus meter up by the configured amount
- Meter visibly fills in HUD
- At 75%, torch VFX appears at entry
- Debug overlay shows current Ruckus, rate of change, and top 3 contributors
- Changing weights in the `.tres` file changes behavior without code edits

---

## M08 — Building (wall + trap + nursery)

**Goal:** The second major player verb. Right-click opens a radial build menu. Place walls, traps, or a nursery to grow your workforce. Minions build them.

**Build:**
- `systems/building/building_system.gd`:
  - Right-click opens `build_menu.tscn` at cursor
  - Select buildable → enters placement mode
  - Ghost mesh follows cursor, snapping to grid
  - Red/green tint based on placement validity (checks cost, footprint, rules)
  - Left-click confirms: creates BuildTask
- `resources/buildables/basic_wall.tres`, `basic_trap_spikes.tres`, `nursery.tres`
- Trap entity: `entities/interactables/trap_spikes.tscn` — triggers on adventurer proximity, applies damage, resets cooldown
- Nursery entity: `entities/interactables/nursery.tscn` — once built, periodically hatches a `goblin_worker` at its cell while the global minion count is below the cap
- `resources/behavior_trees/task_build.tres` — MoveToPosition → HaulMaterials → ExecuteBuild → Complete
- Build consumes resources, generates Ruckus, takes time

**Nursery tuning (editable via `.tres`):**
- Cost: 40 gold (higher than a wall — strategic investment, not structural)
- Build time: ~2× wall
- Hatch cadence: one goblin_worker every 120s post-build
- Global cap: 8 minions — above this the nursery idles in a visible "full" state until count drops
- Visual: small hut/alcove mesh with placeholder eggs that glow while cooling toward next hatch
- On hatch: emit EventBus `minion_spawned`, play small SFX, minion enters idle state at nursery cell
- Resumes hatching automatically when active count drops below cap (minion death or being grabbed away does not count as permanent removal unless the minion is actually destroyed)

**UI:**
- `ui/build_menu/build_menu.tscn` — radial menu with icons for each buildable
- Ghost mesh for placement preview

**Files to create:**
- `systems/building/building_system.gd`
- `ui/build_menu/build_menu.tscn`, `.gd`
- `resources/buildables/basic_wall.tres`, `basic_trap_spikes.tres`, `nursery.tres`
- `entities/interactables/wall.tscn`, `trap_spikes.tscn`, `nursery.tscn`
- `resources/behavior_trees/task_build.tres`

**Acceptance criteria:**
- Right-click opens build menu
- Select wall → ghost mesh follows cursor, valid tiles glow green
- Click to place → BuildTask created, gold deducted, minion walks over and builds
- Completed wall blocks pathfinding (update AStar3D graph)
- Trap fires when adventurer walks over it (test with debug spawn command)
- Nursery, once built, hatches a new goblin_worker every 120s up to the global cap; resumes hatching when active count drops below cap
- Hatch cadence and cap are editable in `nursery.tres` without code change
- Ruckus tick from building

---

## M09 — Adventurer AI & raid spawn

**Goal:** At 100% Ruckus (or Ready button), a 3-adventurer squad spawns at the entry corridor and attacks. Each has distinct goal-directed behavior.

**Build:**
- `entities/adventurer/adventurer.tscn` — Synty fantasy hero mesh
- Three variants as `AdventurerDefinition` resources:
  - `warrior.tres` — engages nearest hostile
  - `rogue.tres` — beelines to treasury, ignores combat unless blocked
  - `archer.tres` — plants at optimal range, fires at priority targets
- Three behavior trees:
  - `warrior_bt.tres` — FindNearestHostile → MoveToAttackRange → AttackTarget (loop)
  - `rogue_bt.tres` — FindTreasury → MoveToTreasury → StealGold → FleeToEntry
  - `archer_bt.tres` — FindOptimalRange → PlantPosition → AttackPriority (loop with repositioning)
- `autoloads/raid_director.gd` full implementation:
  - Listens for Ruckus at 100% OR `ready_button` action
  - Composes squad based on Ruckus accumulation pattern (stubbed — just 1 of each for now)
  - Spawns at entry corridor (specific grid cell marked `enemy_spawn`)
  - Emits `raid_spawned`
- Ready button UI in HUD — fills remaining Ruckus to 100% when pressed

**Files to create:**
- `entities/adventurer/adventurer.tscn`, `.gd`
- `resources/adventurers/warrior.tres`, `rogue.tres`, `archer.tres`
- `resources/behavior_trees/warrior_bt.tres`, `rogue_bt.tres`, `archer_bt.tres`
- Full `autoloads/raid_director.gd`
- Update `starter_dungeon.tscn` to mark enemy spawn tile

**Acceptance criteria:**
- At 100% Ruckus, three adventurers spawn at entry
- Warrior engages the nearest minion visibly
- Rogue visibly runs toward the treasury, ignoring combat attempts on them unless blocked
- Archer plants at mid-range and shoots (placeholder projectile)
- Pressing Ready button before 100% triggers raid immediately

---

## M10 — Combat resolution

**Goal:** Combat actually resolves. Minions fight adventurers. Things die. Ragdolls fly.

**Build:**
- `systems/combat/combat_system.gd` — damage resolution
- `components/health_component.gd` — or extend StatsComponent
- Damage formula: `max(1, attacker.attack + skill_bonus - defender.defense)`
- On death: entity emits `entity_died`, spawns ragdoll, plays SFX, loot drops for adventurers
- Minions auto-assigned `DefendTask` when adventurers are within awareness range
- `resources/behavior_trees/task_defend.tres` — FindNearestEnemy → MoveToAttackRange → AttackTarget
- Ragdoll system — port from Physics Survivors or implement simple version

**Feedback:**
- Floating damage numbers
- Hit flash on damaged entities
- Screen shake on significant hits (configurable, can be disabled)
- Death SFX

**Files to create:**
- `systems/combat/combat_system.gd`
- `components/health_component.gd` (if separating from StatsComponent)
- `resources/behavior_trees/task_defend.tres`
- `systems/combat/ragdoll_spawner.gd`
- `ui/hud/damage_numbers.tscn`

**Acceptance criteria:**
- Adventurers attack minions (and vice versa) on contact/in range
- HP decrements visibly
- Death triggers ragdoll + SFX
- Adventurer deaths drop small loot pickups
- Minions auto-defend when enemies are present, without explicit player command
- At end of raid (all adventurers dead or fled), Ruckus resets to a small residual value

---

## M11 — Personality system (light)

**Goal:** Minions feel like individuals. Different idle behaviors, personality traits, simple flavor.

**Build:**
- `components/personality_component.gd`
- `resources/personality_profile.gd` (PersonalityProfile Resource)
- On minion spawn: randomize personality with normal distribution per axis
- Idle behavior pool — each minion has a subset they prefer based on personality:
  - Cheerful: hum to self, wave at other minions, dance briefly
  - Grumpy: kick stones, grumble, cross arms
  - Curious: peer around corners, stare at player
  - Lazy: lean against walls, take longer naps
- Behavior tree Idle branch becomes a selector with conditions reading personality values
- Minion inspection UI: click minion → shows name, stats, personality summary ("cheerful, curious, a bit of a coward")

**Naming:**
- Generate minion names on spawn from a pool (placeholder: `["Grobnar", "Ogwhack", "Snikk", "Dumper", "Lobblin"]`)
- Save name with minion across sessions

**Files to create:**
- `components/personality_component.gd`
- `resources/personality_profile.gd`
- `resources/idle_behaviors/*.tres` (5-10 varieties)
- `ui/hud/minion_inspector.tscn`, `.gd`

**Acceptance criteria:**
- Spawning 5 minions produces 5 visibly different idle behaviors
- Clicking a minion shows their personality in UI
- Personality persists across save/load
- Same-named minions never spawn in the same session

---

## M12 — Minion reactions

**Goal:** Minions notice and react to world events. This is the highest-ROI spirit beat in Phase 1.

**Build:**
- `components/reaction_component.gd` — listens for EventBus events within a radius
- Reaction table as Resource — maps event type to possible animations/barks
- Events that trigger reactions:
  - `tile_built` nearby → nearby minions look and nod approvingly
  - `tile_mined` nearby (by someone else) → nearby minions might wander over
  - `adventurer_spawned` → all minions visibly alert
  - `minion_died` → nearby minions pause, then continue
  - `minion_picked_up` → nearby minions watch with surprise
- Reaction animations are short (1-2 seconds) — play over current behavior, don't interrupt critical tasks
- Speech bubble stub: short text appears above minion's head briefly (placeholder text in English: "Ooh!", "Nice!", "Boss?", etc.)

**Files to create:**
- `components/reaction_component.gd`
- `resources/reactions/*.tres`
- `ui/world/speech_bubble.tscn`

**Acceptance criteria:**
- Build a wall while a minion is nearby → they visibly look and nod
- Mine a tile near an idle minion → they turn to watch
- Spawn a raid → every minion in the dungeon visibly alerts (animation + speech bubble)
- Reactions don't break ongoing critical tasks

---

## M13 — Save/load full wiring

**Goal:** You can save mid-game, quit, reload, and everything is exactly where it was.

**Build:**
- `autoloads/save_manager.gd` full implementation:
  - `save_to_slot(slot: int)` — gathers state from every subsystem via signal or direct call
  - `load_from_slot(slot: int)` — reconstructs world, entities, systems
  - Version field, migration stubs
- Every subsystem implements `get_save_data() -> Dictionary` and `load_save_data(data: Dictionary)`:
  - `GridWorld`: tile overrides from baseline
  - `ResourceManager`: stockpiles
  - `TaskQueue`: pending tasks
  - `RuckusManager`: current value, accumulation log
  - `RaidDirector`: current state, upcoming composition
  - Each entity: position, stats, component states, personality, task, held items
- Save format: `var_to_bytes` for compact binary, or JSON for Phase 1 readability
- Quicksave on Ctrl+S, quickload on Ctrl+L

**Files to create:**
- Full `save_manager.gd`
- `get_save_data` / `load_save_data` in every system + entity

**Acceptance criteria:**
- Quicksave mid-session with partial dungeon, 3 alive minions, some gold, some Ruckus
- Quit Godot entirely
- Restart Godot, load quicksave
- Dungeon state, minions (with personalities, positions, tasks), resources, and Ruckus all restored exactly

---

## M14 — Demo flow & horizon

**Goal:** Integrate everything into the 15-minute playable demo. Hand-polished starter dungeon. Horizon elements pointing to future content. Endscreen.

**Build:**
- Hand-author the final Phase 1 starter dungeon:
  - Throne room with gold pile
  - Entry corridor
  - 2 minions already present, idling
  - Kitchen area (cauldron placeholder, ambient SFX)
  - Sleeping area
  - 2 pre-excavated tunnels with mineable ore
  - One "special wall" deep in a tunnel — purple-cracked, unminable (shows `[pickaxe upgrade required]` tooltip)
  - Entry corridor view reveals distant silhouettes of future larger raids (static sprites for now)
- HUD polish pass:
  - Ruckus meter, resources, ready button all visible and readable
  - Minion count indicator
- Opening state:
  - Game starts on the throne, minions already idling. No tutorial. 4-second WASD hint fade-in.
- Ending:
  - After one successful raid + a post-raid exploration beat (discovery of the purple wall OR arrival of a survivor minion from the raid), fade to black
  - Text: "the demo ends here / more tomorrow." — hold 4 seconds — cut to quit screen.
- Endscreen is functional: quit button, feedback prompt (email/Discord link placeholder)

**Post-raid scripted events (one-time for the demo):**
- After first raid resolves, if at least 1 minion died: a limping new minion enters from the corridor (scripted spawn, not a random encounter yet). Walks to kid. Bows. Joins as third minion.
- This is the cheapest emergent-story beat and should make the cut.

**Polish:**
- Audio pass: mining, combat, ambient cave loop, raid tension music (layered)
- Lighting pass: warm tones in built areas, cool tones in unexcavated, magma glow in deep tunnels (hinting at future tiers)

**Files to modify:**
- `world/starter_dungeon.tscn` (major polish)
- `ui/hud/*` polish
- `world/demo_flow_controller.gd` (new — scripts the ending sequence)

**Acceptance criteria:**
- Game starts, runs 10-15 minutes of gameplay, ends on the fade card
- A stranger can pick up and play without external instruction
- Three distinct "wait what?" moments occur naturally during play (the trap firing, the raid adrenaline, the purple wall reveal)
- After playing, the user (you) still wants to play more

---

## Phase 1 exit criteria

Phase 1 is complete when ALL of the following are true:

1. All 14 milestones are checked off
2. The 15-minute demo runs end-to-end without critical bugs
3. You (the dev) can hand it to someone and they understand what to do without explanation beyond "click around and figure it out"
4. You personally want to keep playing your own prototype

**At that point, playtest with 8-12 strangers before committing to Phase 2.** The decision to proceed to Phase 2 is based on playtest signal, not feature completeness.

---

## Phase 2 preview (for awareness only — do not build)

Phase 2 adds the spirit: opening cutscene with parents, minion reactions expanded, goblin-Ork voice pass, pet system, one random encounter (lost adventurer), music layering, warm/cozy lighting pass, visual art pass on first biome. This is where the game goes from "interesting prototype" to "I want to tell people about this."

Do not build any Phase 2 content during Phase 1 work. Scope creep on a prototype is the #1 reason solo-dev projects die.
