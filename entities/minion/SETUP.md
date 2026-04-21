# Minion — Setup

Goblin worker entity. Claims tasks from TaskQueue, executes via a small
state machine in `minion.gd` (MINE only for M04; HAUL, BUILD, DEFEND
land in M06/M08/M10).

| File | Role |
|---|---|
| `minion.gd` | `class_name Minion extends CharacterBody3D` — state machine glue |
| `minion.tscn` | CharacterBody3D + CollisionShape3D + Synty goblin mesh + Stats/Movement/Task components |

## Behavior loop

1. `IDLE` — polls `TaskQueue.claim_next(self)` every 0.5s
2. `MOVING_TO_TASK` — MovementComponent pathfinds to the cell adjacent to the target
3. `MINING` — ticks `mining_hp` down at 4 dmg/s; on completion clears tile, emits `tile_mined`, credits loot to ResourceManager
4. `IDLE` — returns to polling

## Utility scoring

Minion exposes `get_task_proficiency(task_type) -> float`. TaskQueue reads
this when scoring a task's utility for a given minion. Goblin worker's
`.tres` sets `{"mining": 1.2, "hauling": 1.1, "combat": 0.7}`.

## Tuning knobs

Edit `resources/minions/goblin_worker.tres` in the inspector:
- `base_stats` — HP, attack, defense, move_speed
- `proficiency_modifiers` — multiplier per task type
- `idle_behavior_pool` — (M11) pool of idle actions

Or on the Minion scene's MovementComponent:
- `speed` (3.5 m/s) — tune if goblins feel too fast/slow

## Known placeholder

Animations aren't playing — Synty Dungeon Pack goblin ships with an
`AnimationPlayer` aliased to BaseLocomotion. Wiring animation state to
the minion state machine is M11+ polish.
