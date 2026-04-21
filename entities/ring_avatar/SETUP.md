# Ring Avatar — Setup

Player-controlled goblin kid with the telekinetic ring.

| File | Role |
|---|---|
| `ring_avatar.gd` | `class_name RingAvatar extends CharacterBody3D` — WASD drift, bob animation, facing-direction yaw lerp. Public `set_cursor_source(cam)` wires the tendril. |
| `ring_avatar.tscn` | Scene: CharacterBody3D root, CollisionShape3D (capsule), Body (bob target), Mesh (placeholder capsule), RingHand (purple emissive), TendrilAnchor, RingGlow (OmniLight3D), Tendril (M03 controller). |
| `tendril_controller.gd` | M03 verlet-rope implementation. Constraints iterate per physics step; ImmediateMesh renders a camera-facing ribbon per frame. |

## Editor steps (one-time)

1. Scene is wired in-file — no editor setup needed.
2. When a goblin kid mesh (Synty Goblin War Camp / Fantasy Rivals) lands, replace the `Body/Mesh` node with the character prefab and remove the `CapsuleMesh` resource.

## Controls

| Action | Binding | Behavior |
|---|---|---|
| `move_forward/back/left/right` | WASD | Drift-float in cardinal directions. Velocity lerps toward input, kid turns to face motion. |
| `ring_primary` | LMB (hold) | Extends the verlet tendril toward the cursor's ground-plane hit. Release to retract. |

## Tuning knobs (on scene root)

- `move_speed` (6.5 m/s) · `accel` (18.0) · `face_turn_rate` (10.0)
- `bob_frequency` (1.6 Hz) · `bob_amplitude` (0.12 m)

## Tendril knobs (on Tendril node)

- `segment_count` (15) — more = smoother ribbon, higher cost
- `base_segment_length` (0.18 m) — rope naturally hangs when current_reach < full length
- `gravity` (6.0) · `damping` (0.92) · `constraint_iterations` (8)
- `spring_strength` (28.0) — end-point pull toward target when extending
- `extend_speed` / `retract_speed` — how fast `current_reach` grows/shrinks
- `tube_radius` · `tube_color` · `tube_emission_energy` · `pulse_frequency` / `pulse_amplitude`
- `collision_mask` (1 = World layer) — what the rope raycast truncates against

## Acceptance (M02)

- WASD moves kid smoothly with visible float/bob
- Camera follows but MMB-drag pans the offset
- Debug overlay shows tile under cursor (from M01)

## Acceptance (M03)

- Hold LMB → purple tendril extends from hand toward cursor with visible sag/whip
- Release → rope smoothly retracts
- Rope truncates at walls (no clipping through geometry)
- 60 FPS even with tendril active

## Known placeholder

The Body is a capsule; swap to a Synty goblin mesh once the relevant character pack is imported. The RingHand is a scaled capsule with emissive purple material as the tendril origin marker.
