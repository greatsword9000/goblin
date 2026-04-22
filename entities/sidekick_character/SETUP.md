# Sidekick Character System — Setup

Modular Sidekick-rigged character system for encounter heroes. One character can be customized via the in-engine Character Customizer (slot dropdowns, body-morph sliders, height scale) and saved as a named `CharacterPreset` resource for later reuse.

See also: `~/.claude/memory/project_goblin_encounter_heroes.md` for the tiering architecture (Sidekick rig for hero/camera-loved NPCs, POLYGON rig for background cast).

---

## Architecture overview

```
SidekickCharacter (Node3D)              # entities/sidekick_character/
  └── Skeleton3D                        # canonical 88-bone rig (loaded from master FBX)
        ├── MeshInstance3D "torso"      # one per visible slot
        ├── MeshInstance3D "hair"
        └── ...                         # toggled via visibility / queue_free
```

- **Rig** — 88 bones, UE5 Mannequin naming + Synty attach sockets (`shoulderAttach_l/r`, `prop_l/r`, etc.). Verified present via smoke test.
- **Parts** — 427 FBX meshes extracted from `SIDEKICK_Goblin_Fighters_Unity_2021_3_v1_0_4.unitypackage`, organized under `res://assets/sidekick/goblin_fighters/{base,outfits}/`. Every part skinned to the identical 88-bone skeleton, so swapping = `visible` toggle / reparent, never re-skin.
- **Body morphs** — four canonical Sidekick shapes (`masculineFeminine`, `defaultBuff`, `defaultHeavy`, `defaultSkinny`) are present across multiple slot meshes and driven globally by the customizer sliders.
- **Height** — uniform `Vector3.scale` on the root Node3D. Useful range 0.85–1.15; beyond that swap the base species variant (1-10) instead.
- **Rig tiering** — `CharacterPreset.rig_target == "sidekick"` is enforced in `apply_preset()`. POLYGON-rig presets are rejected with a warning so a misrouted preset never silently ruins a character instance.

---

## File map

| Path | Purpose |
|---|---|
| `assets/sidekick/goblin_fighters/base/` | Species parts (10 variants × slots) |
| `assets/sidekick/goblin_fighters/outfits/` | Fighter outfit parts (10 outfit variants × slots) |
| `assets/sidekick/goblin_fighters/textures/` | Color maps (5 species + 5 fighter) |
| `assets/sidekick/goblin_fighters/_part_index.json` | Machine-readable slot → part index (consumed by `SidekickPartLibrary`) |
| `resources/character/sidekick_part_library.gd` | **Autoload.** Loads the JSON index, caches scenes, serves parts |
| `resources/character/character_preset.gd` | `Resource` subclass — the saved NPC definition |
| `resources/npc_presets/` | Committed NPC presets (ships with game, referenced by Encounter Director) |
| `entities/sidekick_character/sidekick_character.tscn` | Runtime character scene |
| `entities/sidekick_character/sidekick_character.gd` | `apply_preset()`, `set_part()`, `set_blend_shape_global()`, `set_tint()` |
| `ui/character_customizer/character_customizer.tscn` | In-engine authoring tool |
| `ui/character_customizer/character_customizer.gd` | Customizer logic |
| `_tools/verify_sidekick_pipeline.gd` | Headless smoke test (19 checks) |
| `user://character_presets/` | Per-user authoring sandbox (promote to `res://resources/npc_presets/` to commit) |

---

## Baking thumbnails (required once for visual gallery)

The Character Customizer's gallery shows each option as a rendered thumbnail. These have to be baked once — and re-baked any time new parts are added. **Easiest path, zero terminal:**

1. In the Godot editor, menu: **Project → Tools → Sidekick → Bake Thumbnails (Missing Only)**
2. First run: ~5–10 minutes for all 427 parts. Subsequent runs skip anything already on disk.
3. Output: `res://assets/sidekick/goblin_fighters/thumbnails/<part_name>.png` (128×128).

Use **"Bake Thumbnails (Force All)"** to re-render everything after changing the baker's lighting / framing.

Standalone CLI (for CI / batch — **only with editor closed**):
```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot -s _tools/bake_sidekick_thumbnails.gd
```
The standalone script refuses to run if it detects another Godot instance on this project (prevents lock conflict / crashes). **Do NOT pass `--headless`** on macOS — the dummy display driver can't render to texture; you'll get empty PNGs.

---

## Launching the Customizer (Godot editor)

**Via plugin menu (preferred):** **Project → Tools → Sidekick → Open Character Customizer**.

**Or manually:**
1. Open `res://ui/character_customizer/character_customizer.tscn`.
2. Press **F6** (run current scene) or use the Play button.
3. **Layout:**
   - **Top bar:** name, archetype, hero-eligible checkbox, save/load/promote buttons.
   - **Left column:** FACE cards (head, hair, eyes, ears, nose, etc.). Each card shows the current part's thumbnail. **Single-click** selects (highlight). **Double-click** opens the gallery.
   - **Center:** 3D preview. Drag to orbit, scroll to zoom.
   - **Right-center column:** BODY cards (torso, arms, hands, hips, legs, feet).
   - **Right column:** ACCESSORY cards (helmets, pauldrons, hip plates, knee pads, etc.).
   - **Bottom strip:** body morph sliders | per-slot tint swatches | height slider.
4. **Gallery popup** (opened by double-clicking any slot card): grid of all options as rendered thumbnails, currently-equipped one highlighted, tooltip with part metadata, "Hide slot" button at top for removing that slot entirely. Click any thumbnail to swap and auto-close.
5. **Tints:** per-slot color swatch row at the bottom. Preset palette (goblin-green, human skin tones, hair colors, gear reds/blues) plus a custom ColorPicker and an × button to clear. Tint is stored in the preset as a `Color` per slot and applied as an albedo multiplier on a duplicated StandardMaterial3D.
5. Buttons:
   - **New** — reset to default goblin.
   - **Save** — write to `user://character_presets/<name>.tres` (authoring sandbox).
   - **Delete** — remove a user preset (refuses to delete committed `res://` presets).
   - **Promote → game** — copy the current preset to `res://resources/npc_presets/<name>.tres` so it ships with the build.
   - **Load ▼** — dropdown of all user + committed presets.

---

## Using a preset at runtime

```gdscript
# Load & apply a preset at spawn
var preset: CharacterPreset = load("res://resources/npc_presets/goblin_chief.tres")
var char_scene: PackedScene = load("res://entities/sidekick_character/sidekick_character.tscn")
var chief: SidekickCharacter = char_scene.instantiate()
add_child(chief)
chief.apply_preset(preset)
```

Runtime part swap or blend-shape tweak:

```gdscript
chief.set_part("torso", "SK_GOBL_FIGT_06_10TORS_GO01")
chief.set_blend_shape_global("masculineFeminine", 0.7)
chief.set_tint("hair", Color(0.4, 0.2, 0.1))
```

---

## Running the smoke test

From repo root:

```sh
/Applications/Godot_mono.app/Contents/MacOS/Godot --headless \
  -s _tools/verify_sidekick_pipeline.gd
```

Exits 0 on PASS, 1 on FAIL. Checks:
1. `SidekickPartLibrary` autoload loads the JSON index
2. Part count ≥ 400, slot count ≥ 35
3. Required slots (`head`, `torso`, `hips`, legs, hands, `hair`) all populated
4. Master FBX imports with exactly 88 bones
5. All 24 canonical bone names present (`root`, `pelvis`, `spine_01/02/03`, `ik_hand_gun`, `prop_l`, etc.)
6. `default_preset()` fills 8+ slots and validates clean
7. Spawned `SidekickCharacter` has 88 bones and ≥5 mesh parts after `apply_preset(default)`
8. Preset save/load roundtrip preserves `display_name`, `height_scale`, `blend_shapes`
9. Bulletproofing: unknown part names flagged by `validate()`, tolerated by `apply_preset()`, `apply_preset(null)` survives, wrong `rig_target` rejected gracefully

---

## Re-importing / adding more Sidekick packs

When a new Sidekick `.unitypackage` arrives:

1. Drop the file at `~/Desktop/synty_staging_assets/<pack_name>/`.
2. Re-run the extraction script (logic is in the Bash history — Python script unpacks the tar, maps GUIDs to pathnames, organizes FBX by slot, rebuilds `_part_index.json`).
3. Copy FBX into `res://assets/sidekick/<pack_name>/{base,outfits}/`.
4. Run headless import:
   ```sh
   /Applications/Godot_mono.app/Contents/MacOS/Godot --headless --import --quit-after 1
   ```
5. Run the smoke test to verify the new parts are discoverable.

The `SLOT_MAP` in the extraction script covers all 38 slot codes currently known. If a new pack introduces new codes, unknown slots will appear as `unknown_XXCODE` in the index — extend `SLOT_MAP` and re-run.

---

## Known limitations / future work

- **Facial blend shapes** — ARKit facial shapes are present on individual face/head meshes but not yet wired into the customizer (only the 4 global body shapes are). Adding a per-mesh blend-shape panel is straightforward; do it when we start building dialogue / lip-sync.
- **Animations** — no animations wired yet. The rig is UE5-Mannequin-compatible, so Mixamo animations or the Synty Animation Pack (Sidekick flavor) both work with a one-time import + retarget pass.
- **Single pack** — currently ships with Goblin Fighters. Extension path for Human / other species packs is well-defined; same pipeline, different folder.
- **Tint is slot-uniform** — no per-mesh texture/material editing. Adequate for variant hair/skin color; insufficient for detailed outfit repaint.

---

## Changelog

- **2026-04-21** — Initial implementation. Extracted 427 FBX from Goblin Fighters pack. Built `CharacterPreset` Resource, `SidekickPartLibrary` autoload, `SidekickCharacter` scene/script, `CharacterCustomizer` UI, and 19-check smoke test. All checks pass; zero import warnings.
- **2026-04-21** — Visual gallery redesign. Added `GalleryPopup` (thumbnail grid picker), `SlotCard` (per-slot card with current-part thumbnail), and `ThumbnailBakerCore` (renders a PNG per part). Replaced the text-dropdown customizer layout with three flanking card columns (face/body/accessories) around the 3D preview. Added tint swatch rows per slot and body-morph sliders in the footer strip. Wrapped everything in a `sidekick_tools` editor plugin with a Project menu: Bake Thumbnails (Missing / Force All) and Open Character Customizer. Standalone baker now refuses to run if it detects another Godot on the project, and refuses `--headless` on macOS (dummy driver can't render). Smoke test extended with UI-compile check and non-blocking thumbnail count.
