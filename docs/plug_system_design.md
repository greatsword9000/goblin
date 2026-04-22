# Plug System — Design Proposal

**Status:** draft, pre-implementation. Redline this doc before I build.

## 1. What a "plug" is

A **plug** is a hand-authored, reusable composition of Synty pieces (or any
`PackedScene`s) pinned to a grid-cell footprint. Examples:

- A 1×1 cell patch of cave floor = 4 rock chunks + 2 pebbles + 1 mushroom,
  arranged nicely, saved as `plug_cave_floor_patch_01.tres`.
- A 1×1 cave wall section = 1 slab + 1 rock spike in front + 1 floor
  rubble piece, saved as `plug_cave_wall_straight_01.tres`.
- A 2×2 crystal shrine = 1 obelisk + 4 crystal clusters + 2 mushroom
  clusters, saved as `plug_crystal_shrine_01.tres`.

The authoring app gives you a 3D viewport to hand-place Synty prefabs
inside a cell-boundary box. When you save, the tool records each piece's
transform relative to the plug origin. Procgen then instantiates the
whole composition at a grid cell, with optional rotation / jitter /
subset-selection for variation.

**Why this architecture:** I've been guessing what pieces go together.
Asset names lie (`SM_Env_Cave_01` turned out to be a curved slab, not
a tileable wall). Your eye for what reads as "cave floor" vs "dungeon
ground" is the ground truth. Plugs make that ground truth a
data-driven resource that procgen samples from.

---

## 2. Data model

### `PlugPiece` (value object)

```gdscript
class_name PlugPiece extends Resource

@export var prefab_path: String           # res:// path — serialized as string so it survives rename
@export var position: Vector3             # relative to the plug origin
@export var rotation_deg: Vector3         # Euler, degrees
@export var scale: Vector3 = Vector3.ONE
@export var jitter_rotation_deg: float = 0.0   # at spawn time, ±this
@export var jitter_scale: float = 0.0          # at spawn time, ±this (as fraction)
@export var spawn_chance: float = 1.0          # 0..1 — allows optional pieces
```

### `PlugTemplate` (the unit of authored work)

```gdscript
class_name PlugTemplate extends Resource

@export var template_id: String = ""          # unique, e.g. "cave_floor_patch_01"
@export var display_name: String = ""         # "Cave Floor Patch — Small"
@export var thumbnail: Texture2D = null       # pre-rendered preview

# Grid contract — procgen queries by these.
@export var footprint_cells: Vector2i = Vector2i.ONE   # (1,1) or (2,2) or (3,1) etc.
@export var role: String = ""                          # "env_floor", "env_wall_straight", "env_wall_corner", "decor_cluster"
@export var aesthetic: String = ""                     # "cave", "dungeon", "crystal", "hell", "mushroom_grove"
@export var tags: Array[String] = []                   # free-form: "wet", "overgrown", "ruined", "small", etc.

# Orientation contract — does procgen need to face-align this plug?
# "omni" = rotation-symmetric (floors, clusters). "facing" = has a front
# (walls, corners). The spawner's yaw logic uses this.
@export var orientation_mode: String = "omni"          # "omni" | "facing" | "corner"

# Variation knobs — per-template defaults the spawner can override.
@export var spawn_yaw_snap: int = 90                   # 0 = any, 90 = 4 quadrants, 180 = 2, 360 = locked
@export var allow_mirror: bool = true                  # flip on X for more variety

# The pieces.
@export var pieces: Array[PlugPiece] = []
```

### `PlugLibrary` (autoload, analogous to `AssetTags`)

```gdscript
# Loads every PlugTemplate.tres under res://resources/plugs/ on _ready().
# Exposes query() analogous to AssetTags:
PlugLibrary.query({
    "role": "env_wall_straight",
    "aesthetic": "cave",
    "footprint_cells": Vector2i(1, 1),
})
# → Array[PlugTemplate] matching, sorted by … let's say spawn_weight later.
```

Resources live at `res://resources/plugs/<template_id>.tres`. Thumbnails
cached at `res://resources/plugs/_thumbnails/<template_id>.png`.

---

## 3. Authoring tool — `tools/plug_creator.tscn`

Opened in Godot's editor (not shipped with the game). Full-window layout:

```
┌─────────────────────────────────────────────────────────────────────┐
│  [ Load ▼ ]  [ New ] [ Save ]     Template: cave_floor_patch_01     │
├───────────────────┬─────────────────────────────────┬───────────────┤
│                   │                                 │               │
│  ASSET BROWSER    │        3D VIEWPORT              │  PIECE LIST   │
│  (collapsible)    │                                 │               │
│                   │   ┌─────────────┐               │  [x] rock_01  │
│  aesthetic ▼      │   │             │               │  [x] rock_03  │
│  role ▼           │   │  [grid]     │               │  [ ] pebble_1 │
│  shape ▼          │   │  [origin]   │               │               │
│  size range [ ]   │   │  [cell box] │               │  ──── props   │
│                   │   └─────────────┘               │  pos  (0,0,0) │
│  ┌──┐┌──┐┌──┐     │                                 │  rot  (0,0,0) │
│  │🪨││🪨││🪨│     │    (drag gizmo to move/rotate) │  scale  1.0   │
│  └──┘└──┘└──┘     │                                 │  jitter_rot 0 │
│  ┌──┐┌──┐┌──┐     │                                 │  spawn_chance │
│  │🪨││🪨││🪨│     │                                 │     1.0       │
│  └──┘└──┘└──┘     │                                 │               │
│  (click = place)  │                                 │  [Duplicate]  │
│                   │                                 │  [Delete]     │
├───────────────────┴─────────────────────────────────┴───────────────┤
│  TEMPLATE META:  id[cave_floor_patch_01] role[env_floor▼]           │
│                  aesthetic[cave▼] footprint[1×1▼] orientation[omni▼]│
│                  tags[small, wet]              [Generate thumbnail] │
└─────────────────────────────────────────────────────────────────────┘
```

### Asset browser (left panel)

- Populates from `AssetTags.query({...})` using dropdown filters.
- Each card: **preview thumbnail** + name + size. Click to place at
  viewport origin; it becomes a new piece attached to the plug root.
- Thumbnails are rendered **on demand, once per asset, cached to disk**
  (see §4).
- Fly-out behavior: the browser is a collapsible sidebar. A "＋" button
  at the viewport edge can pop it out as a floating palette if you want
  more viewport space. (Godot's docking makes this easy.)

### 3D viewport (center)

- A `SubViewport`-based editor viewport with standard Godot gizmos
  (translate, rotate, scale on selected piece).
- Renders a **cell-boundary box** sized to `footprint_cells × 2m` so you
  see exactly the space the plug occupies.
- Renders a **grid floor** and a **"front face" arrow** when
  `orientation_mode = facing` so it's obvious which direction is forward.
- Selected piece shows transform handles. Arrow keys nudge by 0.1m;
  Shift-arrow nudges by 1m.

### Piece list (right panel)

- Ordered list of every piece in the plug. Click = select (syncs with
  viewport selection). Drag to reorder (affects spawn order only — later
  pieces can occlude earlier ones but the spawn_chance makes order
  matter for optional pieces).
- Per-piece properties panel below the list: position / rotation / scale
  / jitter values / spawn_chance. Edit inline, viewport updates live.

### Template meta (bottom bar)

- Template ID (used as filename), display_name, role dropdown,
  aesthetic dropdown, footprint (1×1 / 2×1 / 2×2 / 3×1 / 3×3),
  orientation_mode, free-form tags.
- **Generate thumbnail** button: renders the current plug from a fixed
  3/4 isometric angle to `_thumbnails/<template_id>.png`, assigns it to
  the template's `thumbnail` field.

---

## 4. Preview / thumbnail system

You flagged this as the most important UI bit. Here's how it works,
mirroring the Sidekick character-preview pattern:

### 4.1 Per-asset thumbnails (the left-panel browser cards)

- On first request, a hidden `SubViewport` instantiates the asset,
  frames it to fit the AABB, renders with a fixed camera + 3-point
  light, and grabs the viewport texture.
- Cached to disk at `res://resources/asset_thumbnails/<pack>/<name>.png`
  so subsequent loads are instant.
- A background task (a `ThumbnailQueue` node) regenerates missing ones
  in idle frames so the browser fills progressively instead of freezing
  on first open.
- Thumbnail cards are `TextureRect` in a `GridContainer`; the card is a
  `Button` child that emits a signal to place the asset.

### 4.2 Plug thumbnails (for the Load menu)

- Generated on Save — the plug creator takes one snapshot of the
  authored composition and writes it next to the `.tres`.
- Load menu shows these as a 6×N grid of thumbnails. Click = load into
  the viewport.

### 4.3 Consistency with Sidekick

- Both systems reuse a single `ThumbnailRenderer` service (autoload or
  tool script) that takes `(scene: PackedScene, frame_mode, lighting)`
  and returns a `Texture2D`. One renderer, two consumers.

```gdscript
# pseudocode
ThumbnailRenderer.render_async(asset_path, FRAME_FIT, LIGHT_3POINT) \
    .finished.connect(func(tex): card.texture = tex)
```

---

## 5. Tagging model

We already have **`AssetTags`** — observable-property tags on raw Synty
prefabs (shape / aesthetic / role / tileable / dimensions). That system
stays unchanged; it's what the plug creator's asset browser queries.

We add a second layer: **`PlugLibrary`** — semantic tags on *authored
compositions*. These are fundamentally different in kind:

| Tag source   | Generated how    | Describes                                 | Used by               |
|--------------|------------------|-------------------------------------------|-----------------------|
| `AssetTags`  | Automated scan   | Individual mesh: shape, size, aesthetic   | Plug creator browser  |
| `PlugTags`   | Hand-authored    | Composition: role, footprint, orientation | Procgen placer        |

Procgen doesn't talk to `AssetTags` directly. It asks `PlugLibrary` for
"a cave floor 1×1 plug" and trusts that whatever you hand-authored for
that slot is stylistically correct.

**Biome routing.** When we add biomes later, the plug's `aesthetic`
field drives selection: a "cave" biome queries `aesthetic=cave`, a "hell"
biome queries `aesthetic=hell`. Same roles, different aesthetics —
swapping biomes is a filter change, not new procgen code.

---

## 6. Runtime — how plugs get placed

Replaces the current `CaveWallSpawner` logic with a more general
`PlugSpawner`:

```gdscript
# pseudocode per revealed cell:
var cell = grid.cell_at(pos)
var role = classify_cell(cell)  # env_floor / env_wall_straight / env_wall_corner / …
var candidates = PlugLibrary.query({
    "role": role,
    "aesthetic": current_biome.aesthetic,
    "footprint_cells": Vector2i(1, 1),
})
var plug = weighted_pick(candidates, seed_from(cell))
var root = plug.instantiate_at(grid.world_pos(cell), compute_yaw(cell))
```

`PlugTemplate.instantiate_at(world_pos, yaw)` does:
1. Spawn a `Node3D` parent at `world_pos` with the given yaw.
2. For each `PlugPiece` where `spawn_chance ≥ random()`:
   - Instance its `prefab_path`.
   - Apply piece transform + jitter.
   - Parent to the plug root.
3. Return the root.

Key properties:
- **Deterministic given a seed** — same cell always gets the same plug
  and the same jitter, so regeneration is consistent.
- **Fog-of-war compatible** — plugs spawn on cell reveal, despawn on
  hide (same lifecycle as current cave_wall_spawner).
- **Mining-compatible** — when a cell's tile changes (rock → floor),
  fire `tile_changed`, the spawner despawns the old plug and spawns a
  new one for the new role.

### Orientation logic

- `omni` plugs: yaw snapped to `spawn_yaw_snap` (usually 90° for floors
  so adjacent cells look different but grid-aligned).
- `facing` plugs: yaw set so the plug's +Z faces the floor neighbor
  (for walls; same neighbor-scan as current `CaveWallSpawner`).
- `corner` plugs: yaw set to the bisector of the two floor-neighbor
  sides (same logic as current corner detection).

---

## 7. Pre-population (seed content)

I'll ship an initial library of **~12 plugs** covering the most common
needs so the system has something to demonstrate from day one, and so
you can use them as starting points for your own edits (Duplicate →
Tweak is faster than From Scratch).

Proposed seeds:

**Floors (role=env_floor, footprint 1×1, omni):**
- `plug_cave_floor_patch_01` — simple rocky ground (4 rocks + 2 pebbles)
- `plug_cave_floor_patch_02` — slightly mossier (rocks + ground-cover)
- `plug_cave_floor_with_stalagmite_01` — 1 center stalagmite + rubble
- `plug_cave_floor_crystal_01` — rare: floor + small crystal cluster

**Walls (role=env_wall_straight, footprint 1×1, facing):**
- `plug_cave_wall_straight_01` — 1 cave slab + 1 foreground rock
- `plug_cave_wall_straight_02` — cave slab + stalactites above
- `plug_cave_wall_mushroom_01` — cave slab + mushroom cluster

**Corners (role=env_wall_corner, footprint 1×1, corner):**
- `plug_cave_wall_corner_01` — the curved corner piece + base rubble

**Decor (role=decor_cluster, footprint 1×1, omni):**
- `plug_crystal_cluster_01` — 3 crystals of different sizes
- `plug_mushroom_cluster_01` — 3-5 mushrooms clustered
- `plug_stalagmite_trio_01`

These get hand-authored using the tool *after* the tool ships — I can't
pre-bake your style. But I can seed with minimal "spawn one piece"
plugs so the query→spawn path is exercised end to end on day one, and
you replace/edit them as you go.

---

## 8. Open questions for you

1. **Where does the plug creator live?**
   - Option A: standalone scene you open from the editor's file browser.
   - Option B: a real `@tool` EditorPlugin that docks into the Godot
     editor as a custom bottom panel (more work, more native-feeling).
   - Suggest A for MVP, upgrade to B later.

2. **Should plug pieces snap to a sub-grid?**
   - E.g. 25cm grid when moving pieces. Helps alignment between plugs.
   - Suggest yes, with Shift to disable.

3. **Variants within a template vs separate templates?**
   - E.g. "cave_floor_patch" could be *one* template with 8 optional
     pieces (`spawn_chance < 1.0`), or 8 separate templates procgen
     picks from.
   - The former gives more per-spawn variety per template. The latter
     gives more control over distribution.
   - Suggest: support both — `PlugPiece.spawn_chance` lets a single
     template self-vary, AND `PlugLibrary` picks among templates with a
     `spawn_weight` field per template.

4. **Mining-through-plugs:**
   - Currently a rock cell = one wall slab. If a rock cell becomes a
     plug of 3-4 pieces, what happens on mine?
   - Simplest: the whole plug disappears and the floor plug spawns.
   - More interesting: individual pieces get mined (each becomes a
     mineable entity). Defer that until after MVP.

5. **Preview pipeline engine:**
   - Does the `ThumbnailRenderer` live in this project or in the
     `synty-to-godot` repo as a pre-bake step (running at pack-import
     time, writing `.png`s next to the prefabs)?
   - Suggest: in-project, on-demand with disk cache. Keeps the
     converter single-purpose.

6. **Any concerns / changes to the data model before I build?**

---

## 9. Save / name flow

### 9.1 Naming convention

Every `PlugTemplate` has two human-facing fields plus a filesystem ID:

- **`template_id`** — stable, kebab-case, used as filename and as the key
  in `PlugLibrary` lookups. Example: `cave-floor-patch-01`. Once saved,
  renaming changes the filename AND updates any existing references.
- **`display_name`** — free-form, what shows in Load / Library menus.
  Example: "Cave Floor Patch — small, wet". Changes don't affect the ID.

When you hit **Save**:

1. If `template_id` is blank, a dialog pops asking for it, pre-filled
   with a suggestion derived from `role + aesthetic + index`.
2. The tool validates:
   - must match `^[a-z0-9][a-z0-9-_]*$` (no spaces, no uppercase —
     filesystem-safe)
   - must not collide with an existing template ID unless you confirm
     overwrite (a "Save as new copy" button also offered)
3. Writes to `res://resources/plugs/<template_id>.tres` and generates
   `res://resources/plugs/_thumbnails/<template_id>.png`.
4. A toast confirms: "Saved cave-floor-patch-01 · 7 pieces · 1×1".

**Save As** duplicates the current plug with a new ID (handy for
variants — edit plug 01, Save As 02, tweak).

**Rename** is a dedicated menu item that moves both the `.tres` and
thumbnail, and — for later — scans `PlugLibrary` consumers for broken
references and prompts to fix.

### 9.2 Load menu

- Opens as a modal grid of thumbnail cards.
- Filter bar at top: role / aesthetic / footprint / free-text search on
  `display_name` + `tags`.
- Cards show: thumbnail (128×128), display_name, footprint badge (1×1),
  piece count.
- Click = load into viewport (prompts to discard if unsaved changes).
- Right-click card = Duplicate / Rename / Delete (with confirm).

### 9.3 Autosave + undo

- Every edit pushes to an in-memory undo stack (Ctrl+Z / Ctrl+Shift+Z).
- Every 30s of idle the tool writes an autosave to
  `res://resources/plugs/_autosave/<template_id>.tres`. Cleared on
  successful Save. On tool re-open, if an autosave exists newer than
  the saved file, offers to recover.

---

## 10. Main menu / entry point

On game launch the player sees a small title-screen menu instead of
dropping straight into `starter_dungeon.tscn`:

```
┌──────────────────────────────────────┐
│                                      │
│             GOBLIN                   │
│        (big logo / title art)        │
│                                      │
│        [  Start Game  ]              │
│        [  Plug Editor  ]             │
│        [  Options       ]            │
│        [  Quit         ]             │
│                                      │
│     v0.x.y · build hash              │
└──────────────────────────────────────┘
```

### 10.1 Wiring

- New scene `res://ui/main_menu.tscn` with `main_menu.gd`.
- `project.godot`'s `run/main_scene` changes from
  `starter_dungeon.tscn` → `main_menu.tscn`.
- "Start Game" calls `get_tree().change_scene_to_file(STARTER_DUNGEON)`.
- "Plug Editor" calls `get_tree().change_scene_to_file(PLUG_CREATOR)`.
- "Options" — placeholder for now (audio/video/controls later).
- "Quit" — `get_tree().quit()`.

The Plug Editor itself is a full-screen scene (not just an editor
plugin), so it runs in the same binary as the game. Benefits:

- No need to open the Godot editor to iterate on plugs.
- You can ship the editor in a dev build and strip it from release
  builds via a feature flag or alternate export preset.
- Runtime preview of plugs in-editor uses the SAME code path as the
  shipping game — what you see is what you get.

### 10.2 Returning from Plug Editor

- The plug editor has an **Exit to Menu** button (top-right) that
  confirms unsaved changes before leaving.
- From the main menu you can re-enter the editor indefinitely. State
  (last-opened plug, viewport camera) persists in
  `user://plug_editor_state.cfg` so re-opening drops you back where
  you were.

### 10.3 Keyboard shortcut

- Ctrl+Shift+P anywhere in the main menu jumps directly to the plug
  editor (power-user shortcut).
- Escape in either scene returns to main menu (confirm if game has
  autosave-worthy state).

---

## 11. Build order, if approved

1. **Main menu** — `ui/main_menu.tscn` + swap `run/main_scene`. Smallest,
   testable immediately (Start Game routes to the existing dungeon). This
   goes first because it unblocks iterating on the Plug Editor without
   touching dungeon code.
2. **`PlugPiece` + `PlugTemplate` + `PlugLibrary`** — resources + autoload
   (~120 lines).
3. **`ThumbnailRenderer`** service — shared with sidekick preview system
   (~150 lines). Proves the preview pipeline with a unit test that
   renders one Synty prefab to PNG.
4. **`tools/plug_creator.tscn`** — the authoring UI, built incrementally:
   - 4a. Bare viewport + empty-state "New Plug" button.
   - 4b. Asset browser (left panel) with filter dropdowns + thumbnail
     cards from `ThumbnailRenderer`.
   - 4c. Click-to-place + piece list (right panel).
   - 4d. Transform gizmo + inline piece properties.
   - 4e. Save / Load / Rename modals + meta bar.
   - 4f. Autosave + undo stack.
5. **Seed plugs** — 3 minimal plugs (floor patch, wall straight, corner)
   authored in the new editor so the end-to-end path is provable.
6. **`PlugSpawner`** runtime — replaces `CaveWallSpawner` (~150 lines).
   Handles cell-changed events, instantiates plugs per cell with the
   orientation logic from §6.
7. **Wire into `StarterDungeon`** — swap the current spawner for
   `PlugSpawner`; retire `CaveWallSpawner`'s single-mesh path.

Each stage is independently testable. Stop-at-any-stage if the output
doesn't match your mental model.
