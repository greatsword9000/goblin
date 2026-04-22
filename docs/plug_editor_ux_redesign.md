# Plug Editor — UX Redesign (grounded in real-world tool research)

**Status:** design proposal. Redline before I build.

## Research summary — what real tools do well

Findings from LDtk, Tiled, Dreams, Townscaper, Unreal PCG, TrenchBroom,
Houdini HDAs, ProBuilder/Polybrush, and Godot TileSet. Full research
doc in the agent-response archive. Sources listed at bottom.

**Cross-cutting principles that recurred across tools:**

1. **Viewport-centric, not dialog-centric.** Live gizmos and in-world
   preview replace modal property windows. (LDtk, Dreams, ProBuilder)
2. **Capture from the canvas; don't pre-define everything.** Right-
   click a placed thing → "save as stamp." Artists extract patterns
   on the fly rather than hunting a pre-authored palette. (Tiled,
   Townscaper)
3. **Gesture + modifier over mode toggles.** Muscle-memory shortcuts
   (Ctrl+click, number keys, drag with modifier) beat menu navigation.
   (Dreams, TrenchBroom, ProBuilder, Houdini)
4. **Constrain the verb set; let inference fill details.** Townscaper
   has three verbs (add, remove, color) and a WFC that infers
   everything else. Fewer choices, faster iteration.
5. **Group parameters by task stage, not alphabetically.** Houdini
   HDAs group by Visual → Simulation → Advanced. Godot's TileSet
   editor pain is cited explicitly as a counter-example (mixed tabs).

## Gap analysis — what my MVP does poorly

| UX principle                         | My MVP                                           | Problem                                             |
|--------------------------------------|--------------------------------------------------|-----------------------------------------------------|
| Viewport-centric                     | 8-spinbox inspector always on-screen             | Numeric fiddling dominates over direct manipulation |
| Capture-from-canvas                  | None — only pre-populated `AssetTags` browser    | No quick-reuse; every piece is hunted from library  |
| Gesture + modifier                   | Keyboard shortcuts but no snap-size hotkeys      | Snap is a single fixed 25cm step; no per-task sizes |
| Constrain verb set                   | ~20 controls always visible                      | High cognitive load; every spinbox competes         |
| Grouped by task                      | All properties flat in one panel                 | Advanced knobs (jitter) share billing with position |
| Live preview of procgen variation    | None — save + spawn to validate                  | Jitter values are guesswork                         |
| Ghost-at-cursor on placement         | Click → pops at (0,0,0)                          | No preview of where the stamp will land             |
| Grid overlay + snap visibility       | Plane mesh ground; no highlighted snap points    | Snap is invisible — user can't tell if it's active  |

## Proposed redesign

### Layout — after

```
┌──────────────────────────────────────────────────────────────────────┐
│  [≡ File▼]  [⬜ New]  [📂 Load]  [💾 Save]      cave-floor-patch-01 │
├──────────────────────────────────────────────────────┬───────────────┤
│                                                      │ STAMP LIBRARY │
│                                                      │               │
│                 3D VIEWPORT (dominant)               │ recent        │
│                                                      │ [🪨] [🪨] [🪨]│
│         ┌─────────────────────────┐                  │ [🪨] [🍄]    │
│         │   [2m × 2m cell box]   │                   │               │
│         │   (snap grid visible)   │                  │ pinned        │
│         │                         │                  │ [+]           │
│         │     [ghost piece at    ⬤│                  │               │
│         │      cursor, follow]    │                  ├───────────────┤
│         └─────────────────────────┘                  │ VARIATIONS    │
│                                                      │ [shuffle 🎲]  │
│  snap: [0.25m ▼] · orbit: RMB · pan: MMB · esc:exit  │ ▸▸▸▸▸ (5 rolls)│
├──────────────────────────────────────────────────────┴───────────────┤
│ ┌─ ASSET BROWSER (fly-out, tap 'A' to toggle) ──────────────────┐    │
│ │  [filter: cave ▼] [shape: slab ▼] [🔍 search…          ]      │    │
│ │  [🪨 Rock_Flat_06] [🪨 Cave_01] [🍄 Mushroom] [🪨 Crystal]…   │    │
│ └────────────────────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘

Right-click placed piece → context menu: Duplicate / Delete / Save as Stamp / Properties…
Properties opens a small floating panel near the piece (not the old right-rail).

Piece inspector (only visible when something is selected) — TABS:
┌─────────────────────────────────────────────┐
│ [Transform] [Variation] [Procgen]           │
│                                             │
│ position: [x] [y] [z]  ←sliders + text     │
│ rotation:     [y   ]°  ←single dial        │
│ scale:        [▬▬▬▬▬] 1.00×                │
└─────────────────────────────────────────────┘
(Variation tab: jitter_rotation_deg + jitter_scale + live preview strip)
(Procgen tab: spawn_chance + mineable_tag)
```

### Specific changes, tied to research

**Change 1 — Dominant viewport, fly-out asset browser.**
*Borrowed from:* LDtk's seamless viewport, Dreams' dominance of the
3D canvas. *Why:* the viewport IS the workspace. The asset browser
becomes a dockable/closable fly-out panel (tap `A` to toggle) instead
of eating 280px of left rail permanently.

**Change 2 — Ghost-at-cursor placement.**
*Borrowed from:* ProBuilder's push/pull gizmo that follows the cursor.
*Why:* when the user clicks a browser card, the asset enters "stamp
mode" — a semi-transparent ghost follows the cursor in the viewport.
Click on the ground plane = place there. Escape cancels. No more
"pops at (0,0,0) and I have to manually drag it."

**Change 3 — Selection-driven inspector (tabs, not always-on).**
*Borrowed from:* Houdini HDA parameter folders. *Why:* the right-rail
inspector is replaced by a floating panel that only appears when a
piece is selected, with three tabs:

- **Transform** — position (sliders + numeric), Y rotation (a dial),
  uniform scale (single slider). Three controls total instead of seven
  spinboxes.
- **Variation** — `jitter_rotation_deg`, `jitter_scale`, and a small
  **live preview strip** (see Change 5).
- **Procgen** — `spawn_chance` (0-1 slider), `mineable_tag` (text),
  "optional piece" checkbox.

**Change 4 — Stamp library with in-viewport capture.**
*Borrowed from:* Tiled's right-click-to-capture stamp workflow. *Why:*
a small right-side panel shows:
- **Recent** — last 8 assets used, most recent first.
- **Pinned** — assets the user has right-clicked → "Pin to stamps".
- **Save as Stamp** on placed pieces → bundles their *current transform
  and variation settings* so the user can slap them down again
  elsewhere with the same look.

**Change 5 — Live variation preview strip.**
*Borrowed from:* Dreams' gesture-scale feedback, ProBuilder's scatter
brush real-time preview. *Why:* when editing the Variation tab, a
horizontal strip at the bottom of the viewport shows **5 rerolls** of
the whole plug (using the current jitter + chance values). User tweaks
the jitter slider and literally watches the 5 rerolls tighten/loosen.
No "save + spawn 20 instances to see how it looks." Re-roll button
(🎲) re-randomizes the strip.

**Change 6 — Grid overlay with snap-size hotkeys.**
*Borrowed from:* TrenchBroom's 1–0 keys for grid size. *Why:* the 2m
cell box stays visible; a faint snap grid (0.25m default) is drawn on
the ground plane. Snap size cycles via number keys:
- `1` = 0.1m (fine), `2` = 0.25m (default), `3` = 0.5m, `4` = 1m,
  `5` = off (free).
- Snap state shown in a status bar ("snap: 0.25m") so it's never
  invisible.

**Change 7 — First-run guidance / empty-state.**
*Borrowed from:* LDtk's empty-project onboarding. *Why:* when
`_pieces.is_empty()`, the viewport shows a soft-overlay hint: "Tap A
to open the asset library, or press N to start a new plug." Hides on
first action. Avoids the blank-canvas paralysis.

**Change 8 — Constrain verbs to: Place / Select / Move / Remove.**
*Borrowed from:* Townscaper's three-verb interaction. *Why:* the
editor has one modal state — stamp mode (active when you've clicked
a browser card; cursor shows ghost) vs. select mode (default;
cursor selects placed pieces). Everything else is secondary. No
"paint mode" vs. "edit mode" vs. "properties mode" toggles.

### Keyboard shortcuts (after)

| Key                 | Action                                           |
|---------------------|--------------------------------------------------|
| `A`                 | Toggle asset browser fly-out                     |
| `N`                 | New plug (confirm if unsaved)                    |
| `Ctrl+S`            | Save                                             |
| `Ctrl+O`            | Load (modal grid of thumbnails)                  |
| `Ctrl+D`            | Duplicate selected piece                         |
| `Delete` / `X`      | Delete selected piece                            |
| `W` / `E` / `R`     | Translate / rotate / scale mode (gizmo swap)     |
| `G`                 | Toggle grid visibility                           |
| `1`-`5`             | Cycle snap size (see Change 6)                   |
| `🎲` button / `B`   | Re-roll variation strip                          |
| `Escape`            | Cancel stamp mode → back to selection            |
| `Ctrl+Shift+Escape` | Exit to launcher                                 |

(Borrowed from:* Blender/Unity's W/E/R gizmo convention, TrenchBroom's
number-key grid cycling.)

## What I'd build, build order

Each step is independently shippable and testable:

1. **Ghost-at-cursor stamp mode** (Change 2). Biggest single UX win;
   kills the "pops at origin" surprise. Requires raycasting the cursor
   into the viewport ground plane and parenting a ghost to it while
   in stamp mode.

2. **Snap-size hotkeys + visible snap grid** (Change 6). Small
   self-contained change. User sees/feels it immediately.

3. **Tab-ified piece inspector as floating panel** (Change 3). Shrinks
   the right rail; clears visual noise.

4. **Stamp library panel** (Change 4). Recent + Pinned + Save-as-Stamp
   context action.

5. **Live variation preview strip** (Change 5). Most technically
   involved — requires 5 mini-`SubViewport`s or pose-only spawns.
   Defer until 1-4 are paying off.

6. **First-run guidance** (Change 7). Polish. One label with fade.

7. **Asset browser fly-out** (Change 1). Restructures the whole main
   layout; save for last since it moves everything around.

## Open questions before I build

1. **How aggressive on the right-rail collapse?** Option A: full
   floating inspector (popup near piece). Option B: collapsible dock
   that slides in from the right. Floating is more viewport-dominant
   but can occlude the piece. Dock is safer. Your call.

2. **Stamp library storage?** Session-only (resets on editor relaunch)
   or persisted to `user://plug_editor_stamps.cfg`? Suggest
   persisted — muscle-memory dies if Recent forgets overnight.

3. **Variation strip — inline or in a separate floating window?** I'd
   suggest inline (bottom of viewport) so it's always next to the
   slider you're editing.

4. **Do you want a full hotkey remap UI** (Options → Controls for the
   editor) or hardcode the bindings for now? Hardcode for MVP is
   fine unless you already foresee rebinding wars.

5. **Empty-state hint wording.** I'll stub "Tap A for asset library,
   N for new plug" — override if you want different phrasing.

## Sources

- LDtk — https://ldtk.io · https://deepnight.net/tutorial/making-of-ldtk/
- Tiled docs — https://doc.mapeditor.org/en/stable/manual/
- Media Molecule / Dreams toolset — https://www.gamedeveloper.com/design/how-media-molecule-designed-a-fun-and-robust-toolset-for-i-dreams-i-
- Oskar Stålberg / Townscaper — https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making
- Unreal PCG — https://dev.epicgames.com/documentation/en-us/unreal-engine/procedural-content-generation-overview
- TrenchBroom manual — https://trenchbroom.github.io/manual/latest/
- Houdini HDAs — https://www.sidefx.com/docs/houdini/assets/asset_ui.html
- Unity ProBuilder — https://learn.unity.com/tutorial/editing-with-probuilder
- Godot TileSet pain points — https://github.com/godotengine/godot-proposals/issues/7177
