class_name CharacterPreset extends Resource
## Saved customization for a Sidekick-rigged character (NPC or player).
##
## Authored via the Character Customizer UI (Ctrl+Shift+C), consumed by
## SidekickCharacter.apply_preset(). Persisted as .tres in
## user://character_presets/ or res://resources/npc_presets/ for committed NPCs.
##
## Format version is bumped when fields are added/removed; loaders fall back
## gracefully on older presets so saved NPCs don't break on upgrade.

const FORMAT_VERSION := 1

## Display name shown in editor dropdowns and debug overlays.
@export var display_name: String = "Unnamed"

## Optional archetype tag for runtime filtering ("goblin_grunt", "shaman", etc.)
@export var archetype: String = ""

## Rig target: "sidekick" (hero — camera zoom, facial anim, dialogue) or
## "polygon" (background — cheaper rig, no facial / lip-sync).
## Used by the Encounter Director to pick which character becomes the camera
## focus for a given encounter. Only sidekick presets feed through this system;
## polygon preset authoring lives in its own tool (not built yet).
@export_enum("sidekick", "polygon") var rig_target: String = "sidekick"

## True if this preset is eligible to be promoted to "encounter hero" — i.e.
## it has enough customization (named, has facial parts) to carry a close-up.
## The Encounter Director filters on this flag.
@export var is_hero_eligible: bool = true

## Format version of this preset; used by the loader to migrate old saves.
@export var format_version: int = FORMAT_VERSION

## Per-slot chosen part: { "torso": "SK_GOBL_BASE_01_10TORS_GO01", ... }
## Empty string or missing slot = slot hidden (no mesh).
@export var parts: Dictionary = {}

## Per-mesh blend-shape values: { "torso": { "masculineFeminine": 0.5, "defaultHeavy": 0.8 } }
## Missing shapes silently skipped at apply-time (bulletproofing: blend-shape
## set differs per outfit mesh).
@export var blend_shapes: Dictionary = {}

## Per-slot color tint override: { "torso": Color(1, 0.8, 0.8) }
## Applied as MaterialOverride albedo multiplier.
@export var tint_overrides: Dictionary = {}

## Uniform height scale on root Node3D. ~0.85-1.15 = genuine variance,
## beyond that reads as "child" or "giant" — swap base mesh instead.
@export_range(0.5, 1.5, 0.01) var height_scale: float = 1.0


## Deep-copy duplicate — Godot's default Resource.duplicate() is shallow on
## Dictionary fields, which would alias parts/blend_shapes across presets.
func deep_duplicate() -> CharacterPreset:
    var copy := CharacterPreset.new()
    copy.display_name = display_name
    copy.archetype = archetype
    copy.format_version = format_version
    copy.parts = parts.duplicate(true)
    copy.blend_shapes = blend_shapes.duplicate(true)
    copy.tint_overrides = tint_overrides.duplicate(true)
    copy.height_scale = height_scale
    return copy


## Returns a validation report: [] on success, list of string issues otherwise.
## Does NOT mutate. Called by CharacterCustomizer before save and by
## SidekickCharacter before apply.
func validate(library: SidekickPartLibrary) -> Array[String]:
    var issues: Array[String] = []
    if display_name.strip_edges() == "":
        issues.append("display_name is empty")
    for slot in parts:
        var part_name := String(parts[slot])
        if part_name == "":
            continue  # empty string = intentionally hidden, not an error
        if not library.has_part(slot, part_name):
            issues.append("part '%s' not in library for slot '%s'" % [part_name, slot])
    return issues
