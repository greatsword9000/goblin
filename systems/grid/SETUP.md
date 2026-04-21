# Grid System — Setup

Authoritative spatial service and tile-data layer. Files here:

| File | Role |
|---|---|
| `grid_world.gd` | **Autoload** (`GridWorld`). Tile dictionary, visual instancing, coord conversion. |
| `tile_resource.gd` | `class_name TileResource` — base data definition for any grid tile. |
| `floor_tile.gd` | `class_name FloorTile` — walkable ground. |
| `mineable_tile.gd` | `class_name MineableTile` — harvestable wall with HP + drops. |
| `special_wall_tile.gd` | `class_name SpecialWallTile` — story-gated (M14 purple wall). |
| `decorative_tile.gd` | `class_name DecorativeTile` — throne pile, scenery. |
| `hazard_tile.gd` | `class_name HazardTile` — lava / spikes, damage per second. |
| `loot_entry.gd` | `class_name LootEntry` — one potential drop from a mined tile. |
| `tile_types.gd` | Directory marker only (`class_name TileTypes`). Real subtypes live in sibling files above. |
| `rts_camera_controller.gd` | `class_name RTSCameraController` — iso-ish pan/rotate/zoom rig. |

## Editor steps (one-time)

1. `GridWorld` is registered in `project.godot` autoload order between `SaveManager` and `DebugOverlay`. No action needed.
2. Tile resources live in `res://resources/tiles/`. To add a new tile: create a new `.tres` resource with the appropriate script (e.g. `MineableTile`), set `id`, `display_name`, `placeholder_color`, and (once Synty meshes are imported) `mesh_scene` pointing at the prefab.
3. The starter dungeon spawns from `world/starter_dungeon.gd` `_ready()`. To reshape the Phase 1 layout, edit `dungeon_size`, `ore_positions`, and `throne_position` on the scene root in the inspector, OR hand-author `set_tile` calls in `_spawn_dungeon()`.

## Adding a new tile type in code

1. Create `res://systems/grid/<your_tile>.gd` with `class_name YourTile extends TileResource`.
2. (Optional) Add type-specific `@export` fields if systems need to branch.
3. Create `res://resources/tiles/<your_tile>.tres` with the new script.
4. Reference the `.tres` from wherever it's placed (starter_dungeon inspector fields, builder scripts, etc.).

No edits to `grid_world.gd` are needed unless the new type requires a unique primitive fallback visual — which you probably don't want, since primitives are temporary.

## Debug overlay integration

`DebugOverlay.register_camera(rig)` is called from `starter_dungeon._ready()`. The overlay asks the registered camera for `cursor_world_position()`, converts via `GridWorld.tile_at_world()`, and reports the cell + tile id under the cursor. Any scene can register its own camera the same way.

## Acceptance (M01)

See `PHASE_1_PLAN.md` M01 — essentially: 10×10 dungeon renders, camera controls work, backtick overlay shows tile under cursor, adding a new tile is a `.tres` drop with no code changes.
