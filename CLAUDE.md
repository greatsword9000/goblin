# GOBLIN — Claude Code Project Context

**Working title:** GOBLIN (placeholder, to be replaced once real name is chosen)

**Engine:** Godot 4.4.x stable
**Current phase:** Phase 1 (mechanical spine prototype)
**Related project:** Physics Survivors ("Trucker") — shares EventBus pattern, debug overlay, AI Director concept, procedural generation philosophy. See "Harvestable" section below.

---

## What we're building

A 3D dungeon management sim where the player is a young goblin kid wielding a powerful ring. The kid's parents — who raised them in a cozy underground home — were murdered by adventurers seeking riches. Now alone, the kid uses the ring's telekinetic power to direct surviving goblin minions, expand the dungeon through mining, and defend their home from ongoing adventurer raids.

**Core loop:** Direct minions (mine, haul, build, defend) → accumulate gold and infrastructure → accumulate "Ruckus" (noise/notoriety) → raids arrive → survive → expand further.

**Genre:** Management sim + dark-cozy aesthetic + Dungeon Keeper godlike-hand control scheme.

**Differentiators** (what makes this not another dungeon keeper clone):
1. **The Ring Avatar** — player never directly mines, fights, or hauls. They are a telekinetic overseer using verlet-rope tendrils to pick up minions, mark tasks, and slap creatures into action.
2. **The Ruckus system** — raids are triggered by noise the player generates, not a wall-clock timer. Quiet play = cozy pace. Aggressive play = escalating threat. Players control their own tension.
3. **Dark-cozy emotional framing** — the dungeon is a loving home defended from violent invaders, not a generic evil lair.
4. **Goblin-Ork patois** — all UI text, minion barks, and systems named in comically grimdark goblin voice (not implemented in Phase 1; placeholder English text is fine).

---

## Architectural principles (non-negotiable)

1. **Event-driven over reference-driven.** Systems communicate through `EventBus` signals, not direct references. Mining doesn't know Ruckus exists — it emits `ore_mined`. Ruckus listens. This is the single most important pattern for solo-dev velocity on a multi-year project.

2. **Data-driven content.** Every piece of content (tiles, minions, enemies, buildables, items) is a Godot `Resource` (`.tres` file), not hardcoded. Adding content should be "drop a `.tres` in a folder." If it requires editing a script, the pattern is wrong.

3. **Grid is source of truth.** All position logic consumes grid coordinates first. Visual position is derived. Pathfinding, mining, building, room detection — all grid-space. Makes save serialization trivial and debugging tractable.

4. **Behavior trees over state machines.** Every AI entity runs on a LimboAI behavior tree composed from small reusable actions. No state-machine spaghetti. BTs are resources, authored in-editor.

5. **Tooling-first.** Before hand-authoring N of anything, build the editor tool. In-editor plugins pay for themselves within weeks.

6. **Save/load from day one.** Versioned save format. Every entity, every resource value, every world flag serializable from Milestone 2 onward. Retrofitting saves is how indie projects die.

7. **Debug overlay from day one.** F1 toggles live stats panel (FPS, entity counts, Ruckus value, selected-entity inspector). Copy the pattern from Physics Survivors.

---

## Tech stack

- **Godot 4.4.x** stable, Forward+ renderer (we need real lighting in caves)
- **GDScript** primary language (not C#)
- **LimboAI plugin** for behavior trees — install from AssetLib as first step
- **Synty assets** — heavy use for rapid prototyping. POLYGON Dungeons, POLYGON Dungeon Realms, POLYGON Knights, POLYGON Fantasy Kingdom. Import via existing Synty converter pipeline (check with user for pipeline details).
- **Git + LFS** for version control. Use the user's existing branching strategy from Physics Survivors.

**Explicitly NOT using:**
- No C# (GDScript sufficient, faster iteration)
- No third-party ECS frameworks (native Node architecture with composition is enough)
- No external save systems (roll our own versioned format)

---

## Directory structure

```
res://
├── project.godot
├── CLAUDE.md                       # this file
├── ARCHITECTURE.md                 # technical patterns and system design
├── PHASE_1_PLAN.md                 # milestone-by-milestone implementation plan
├── autoloads/
│   ├── event_bus.gd
│   ├── time_manager.gd
│   ├── save_manager.gd
│   ├── debug_overlay.gd
│   ├── ruckus_manager.gd
│   ├── task_queue.gd
│   └── raid_director.gd
├── systems/                        # systems that don't need autoload but own logic
│   ├── grid/
│   ├── building/
│   ├── mining/
│   ├── combat/
│   └── ai/
├── entities/                       # scenes + scripts for spawned things
│   ├── ring_avatar/
│   ├── minion/
│   ├── adventurer/
│   └── interactables/
├── components/                     # reusable components for entity composition
│   ├── stats_component.gd
│   ├── movement_component.gd
│   ├── personality_component.gd
│   ├── reaction_component.gd
│   └── task_component.gd
├── resources/                      # data definitions (.tres)
│   ├── tiles/
│   ├── minions/
│   ├── adventurers/
│   ├── buildables/
│   ├── items/
│   └── behavior_trees/
├── ui/
│   ├── hud/
│   ├── build_menu/
│   └── debug/
├── world/                          # hand-authored prototype scenes
│   └── starter_dungeon.tscn
├── assets/
│   ├── synty/                      # imported Synty packs
│   ├── audio/
│   ├── shaders/
│   └── materials/
└── addons/
    └── limboai/                    # installed plugin
```

---

## Naming conventions

- **Files:** `snake_case.gd` / `snake_case.tscn` / `snake_case.tres`
- **Classes:** `PascalCase` via `class_name` directive on every significant script
- **Functions:** `snake_case()`. Private functions prefixed with `_underscore()`
- **Signals:** `snake_case_past_tense` for events that already happened (`ore_mined`), `snake_case_imperative` for requests (`request_pause`)
- **Constants:** `SCREAMING_SNAKE_CASE`
- **Resources:** `.tres` file basename matches content (`goblin_brute.tres` not `minion_01.tres`)
- **Scenes:** scene file matches root node (`ring_avatar.tscn` has `RingAvatar` root)

---

## Coding conventions

- Use `@export` liberally — anything tunable needs to be inspector-editable
- Every autoload has a comment header stating what it owns and what it listens to
- No file over 200 lines without explicit justification. Split into components instead.
- No hardcoded strings for node paths. Use `@onready var foo = $Path/To/Node` or scene-unique references.
- Prefer composition (components attached to entities) over inheritance chains
- Every `Resource` subclass has `@export` properties, never hardcoded values
- Document public API with `## triple-slash` comments — these show in editor tooltips

---

## Signal routing rules

**Use EventBus for cross-system events:**
- `ore_mined`, `raid_spawned`, `minion_died`, `ruckus_changed`, etc.

**Use local signals for intra-entity events:**
- `HealthComponent.damaged`, `TaskComponent.task_completed`

**Never:**
- Hold direct references to other autoloads from entity scripts if a signal would work
- Call across system boundaries through singletons when an event would suffice

---

## Scope discipline — what NOT to build in Phase 1

Phase 1 is a **mechanical spine prototype**, not a complete game. The hypothesis being tested is: "Is this fun. Do I want to keep playing. I want more."

**DO NOT build in Phase 1:**
- No cutscenes, no dialogue, no narrative
- No goblin-Ork voice pass (placeholder English is fine)
- No full art pass, no custom shaders beyond basic cel-shading
- No procedural dungeon generation (architecture supports it; Phase 1 uses one hand-authored dungeon)
- No skill growth, full stat system, or equipment
- No reputation or encounter system
- No pet, no curious child, no random NPCs
- No multi-day run structure
- No boss enemies
- No champion recruitment quests
- No rooms-affect-skills system
- No co-op / multiplayer
- No endless mode

**These are all planned for later phases.** If you find yourself designing one of them, stop — note the idea in a `BACKLOG.md` and move on.

---

## Harvestable from Physics Survivors

Substantial infrastructure already exists in the PS codebase. When implementing a system, check if a PS equivalent exists first:

- **EventBus autoload pattern** — already proven in PS, lift directly and extend with dungeon-specific events
- **Debug overlay (F11 in PS, F1 here)** — copy scaffolding, swap panels
- **AI Director concept** — PS has intensity curves, spawn debt, cluster sizing, pursuit flags. Maps 1:1 onto `RaidDirector` for this project. Same tuning knobs, different inputs (Ruckus instead of wave number).
- **Plug/Socket procedural system** — not used in Phase 1 but the architecture exists in PS. Will be ported in Phase 3+ for procedural dungeon generation.
- **NodePool pattern** — critical for minions, adventurers, projectiles, particles. Copy from PS.
- **Ragdoll system** — inherently funny with low-poly goblins. Copy pattern from PS enemy death sequence.
- **Synty import pipeline** — user has working Unity/Unreal → Godot converter. Use it for all Synty packs.
- **Save format versioning** — if PS has it, match the pattern. If not, establish it here.

When in doubt, ask the user: "Does Physics Survivors have a pattern for this?"

---

## Working style with Claude Code

- **Work milestone by milestone** from `PHASE_1_PLAN.md`. Do not skip ahead.
- **Commit after every milestone** with clear message: `feat: M05 - verlet tendril system`
- **After completing a milestone**, update `PHASE_1_PLAN.md` with a checkmark and the commit hash.
- **Write a SETUP.md in each feature folder** explaining Godot editor steps (per godot skill).
- **Test before moving on.** Each milestone has acceptance criteria. Run them.
- **Ask when blocked**, don't guess. If you hit a Synty import issue or LimboAI question, stop and ask.
- **Do not add features beyond the current milestone.** Scope creep kills prototypes.

---

## Next action

Read `PHASE_1_PLAN.md`. Start at Milestone 0. Build milestone by milestone. Do not skip.
