# NPC Behavior System — Setup

3-layer AI stack replacing the monolithic `minion.gd` FSM.

```
Agent (CharacterBody3D)
  ├── StatsComponent
  ├── MovementComponent
  ├── TaskComponent
  ├── GrabbableComponent
  ├── BTPlayer (LimboAI)          ← runs the currently-active tree
  ├── GoalPicker                  ← picks the goal; swaps BT on BTPlayer
  └── BlackboardSync               ← EventBus → blackboard flag writes
```

- **GoalPicker**: iterates `archetype.goals`, runs each scorer, swaps BT on event (task_created, picked_up/dropped, alarm, BT finished, 2s watchdog).
- **BlackboardSync**: listens to global signals, writes `carried`, `alarm`, `task_valid` flags into the BTPlayer's blackboard. Adding a new "reactive" behavior = add one entry to `_EVENT_MAP`.
- **BTActions** (in `bt_tasks/`): small, reusable `_tick()` functions. A goal's tree is composed of them.

## Architectural rule (non-negotiable)

> **Only `GoalPicker` swaps BTs. Everything else writes blackboard flags.**

No `force_stop()`, no `if is_held: return` scattered through `_physics_process`, no manual state pokes. Every "interrupt X when Y happens" = one event → one blackboard flag → one goal preconfigured with `requires_flag`/`forbids_flag`.

## File map

| Path | What |
|---|---|
| `resources/ai/goal_def.gd` | `GoalDef` Resource — id, tree_builder_method, scorer, weight, flag gates |
| `resources/ai/agent_archetype.gd` | `AgentArchetype` Resource — stats, list[GoalDef], initial blackboard |
| `resources/ai/goals/*.tres` | One per goal: `goal_mine`, `goal_wander`, `goal_idle_carried` |
| `resources/ai/archetypes/goblin_worker_archetype.tres` | Minion v1 archetype |
| `systems/ai/goal_picker.gd` | Scorer + BT swapper node |
| `systems/ai/blackboard_sync.gd` | EventBus → blackboard bridge |
| `systems/ai/goal_scorers.gd` | `static func score_X(agent, sync) -> float` |
| `systems/ai/goal_trees.gd` | `static func build_X_tree(agent) -> BehaviorTree` — programmatic tree builders |
| `systems/ai/bt_tasks/bt_claim_task.gd` | Claim task from TaskQueue |
| `systems/ai/bt_tasks/bt_path_to_target.gd` | Move to `target_cell` via MovementComponent (aborts on `!task_valid`) |
| `systems/ai/bt_tasks/bt_path_to_cell.gd` | Same but no task gate (for wander/flee) |
| `systems/ai/bt_tasks/bt_mine_tile.gd` | Mine until `mining_hp`, emits `tile_mined` — mirrors old `_mine_tick` |
| `systems/ai/bt_tasks/bt_finish_task.gd` | Calls `TaskComponent.finish_task(success)` |
| `systems/ai/bt_tasks/bt_pick_wander_cell.gd` | Random walkable cell within radius |
| `systems/ai/bt_tasks/bt_wait_duration.gd` | Wait N seconds (local copy of LimboAI's BTWait for programmatic tree-building) |
| `entities/agent/agent.gd` | Unified runtime script |
| `entities/agent/agent.tscn` | Agent scene wiring all components |

## A/B testing (Phase 1 — safe)

The new system coexists with the old `minion.gd` / `minion.tscn`. To spawn an Agent next to your existing minions for comparison:

1. Open `world/starter_dungeon.tscn` in the editor.
2. Drag `entities/agent/agent.tscn` into the scene at any walkable cell (e.g. `(3, 0, 3)`).
3. Select the Agent → Inspector → `Archetype` → drag in `resources/ai/archetypes/goblin_worker_archetype.tres`.
4. Run the scene. Watch:
   - Agent claims mine tasks same as old Minion.
   - Ring pickup: Agent's `carried` flag flips, picker swaps to `idle_carried` tree, agent just waits.
   - Drop: `carried` flips false, picker swaps back to `mine` or `wander` based on scorer. **No slide-back** because there's no hidden `_path` to resume — the new mine BT re-paths from the drop spot.

## Adding a new goal (5-step template)

1. Add a scorer method to `systems/ai/goal_scorers.gd`.
2. Add a tree-builder method to `systems/ai/goal_trees.gd` composing existing or new BTActions.
3. (If new BTActions needed) Create `bt_tasks/bt_X.gd` — `@tool extends BTAction`, implement `_tick(delta)`.
4. Create `resources/ai/goals/goal_X.tres` pointing at the scorer + builder.
5. Add the `GoalDef.tres` to the archetype's `goals` array.

No changes needed in Agent, GoalPicker, BlackboardSync, or any existing goal. That's the contract.

## Adding a new reactive interrupt

1. Define the signal in `autoloads/event_bus.gd`.
2. Add one entry to `BlackboardSync._EVENT_MAP`: `{"signal": &"my_signal", "key": &"my_flag", ...}`.
3. In the GoalDef for goals that should preempt when the flag is set: `requires_flag = &"my_flag"`.
4. In the GoalDef for goals that should NOT run while the flag is set: `forbids_flag = &"my_flag"`.

Done. No `_physics_process` edits, no state-machine surgery.

## Explicitly deferred

- **Real BehaviorTree authoring in the LimboAI editor** — trees are currently built in GDScript via `goal_trees.gd`. Switch to `.tres` when we have more than ~6 goals.
- **Needs system** (hunger/sleep/mood) — add a single `bb.energy` field + one `rest` goal when M11+ needs it.
- **Perception / FOV** — direct distance queries in scorers. Add a `PerceptionComponent` when combat (M10) requires it.
- **Save/load of mid-BT state** — on save, blackboard + current goal id; on load, rerun picker. Agent "forgets" half-mined ore and re-picks. RimWorld strategy.
- **Squad coordination** — individual BTs only.

## Changelog

- **2026-04-22** — initial build. Agent + 3 goals (mine, wander, idle_carried). `minion.gd` still in place for A/B. Next: verify Agent produces identical mining behavior to Minion in `starter_dungeon.tscn`, then retire Minion.
