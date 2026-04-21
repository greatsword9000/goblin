# GOBLIN — Setup

First-time setup for the Godot project. Run through this once after cloning.

## 1. Prerequisites

- **Godot 4.6+** (Forward+ renderer). Design docs originally specced 4.4.x; project was imported on 4.6 and `config/features` bumped accordingly.
- **Git LFS** (`brew install git-lfs`, then `git lfs install` once).

## 2. Open the project

1. Launch Godot 4.4.x.
2. **Import** → select `~/Documents/Goblin/project.godot`.
3. Let the editor run its first import pass. Expect no errors.

## 3. Install LimboAI

Behavior-tree plugin. Required from M04 onward.

1. In Godot: **AssetLib** tab → search `LimboAI` → Download → Install.
2. **Project → Project Settings → Plugins** → enable `LimboAI`.
3. Restart the editor if prompted.
4. Installed and enabled 2026-04-21.

## 4. Verify M00 acceptance

Open the project and click the **Play** button (top-right of the editor) — or Cmd+B to run the current scene.

- [ ] Project runs without errors.
- [ ] A gray plane + angled camera renders.
- [ ] **Backtick** (`` ` ``) toggles the debug overlay.
- [ ] Overlay shows FPS, frame ms, mouse viewport position.
- [ ] All 7 autoloads load (Project → Project Settings → Autoload).
- [ ] No warnings in the Output panel.

## 5. Autoload order

Order matters. Verify in `Project Settings → Autoload`:

1. EventBus
2. TimeManager
3. SaveManager
4. DebugOverlay
5. TaskQueue
6. RuckusManager
7. RaidDirector

EventBus must load first (everything depends on it). RaidDirector last (depends on Ruckus).

## 6. Input map

Configured in `project.godot`. Spot-check in `Project Settings → Input Map`:

| Action | Binding |
|---|---|
| `ring_primary` | Left mouse |
| `ring_secondary` | Right mouse |
| `ring_slap` | Left mouse double-click |
| `camera_pan` | Middle mouse |
| `ready_button` | Space |
| `debug_toggle` | Backtick `` ` `` |
| `quick_save` / `quick_load` | Ctrl+S / Ctrl+L |
| `move_forward/back/left/right` | W/S/A/D |

## 7. Physics layers

Configured in `project.godot` under `[layer_names]`. Verify in `Project Settings → Layer Names → 3D Physics`:

1 World · 2 Minions · 3 Adventurers · 4 RingAvatar · 5 Pickups · 6 Traps · 7 TendrilTargets · 8 Projectiles

## 8. Synty assets (blocked until M01)

M01 requires at least **POLYGON Dungeons** (and optionally Dungeon Realms for variety). Stage the `POLYGON_*_SourceFiles_*.zip` files in `~/Desktop/synty_staging_assets/` — the `synty-converter` skill handles import when we get there.

## 9. Related projects

- **Physics Survivors** (`~/Documents/PhysicsSurvivors_Proto`) — patterns harvested from here (EventBus, DebugOverlay, NodePool, ragdoll, Synty converter pipeline).
