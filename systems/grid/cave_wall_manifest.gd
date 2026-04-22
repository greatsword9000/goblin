class_name CaveWallManifest extends Resource
## Tags each cave-wall prefab with its role and spawn metadata.
##
## The wall spawner picks a prefab by role (straight slab, convex corner,
## concave corner) rather than by name, so swapping assets or adding
## variants is a data-only change. Natural mesh dimensions are measured
## here so per-cell scale is computed rather than eyeballed.
##
## Role semantics:
##   STRAIGHT   — flat-backed slab, carved face on one side. Lines a rock
##                cell that borders a single floor cell (4 rotations).
##   OUTCORNER  — concave corner piece, covers two perpendicular edges at
##                once. Used when a rock cell has two adjacent floor
##                neighbors (L-shape). 4 rotations.
##   INCORNER   — convex corner, rarely used — reserved for inside bumps.
##   CAPPED     — end piece where a wall terminates into open space.

enum Role { STRAIGHT, OUTCORNER, INCORNER, CAPPED }

@export var prefab: PackedScene = null
@export var role: Role = Role.STRAIGHT
## Natural-mesh XZ footprint in meters (measured pre-scale).
@export var natural_width: float = 6.0
@export var natural_depth: float = 2.0
@export var natural_height: float = 11.0
## If the prefab's local origin is not at the back-center of the slab
## (as SM_Env_Cave_01 in Synty is), offset the spawn to align the back face
## to the cell edge. In local natural-mesh space.
@export var origin_offset: Vector3 = Vector3.ZERO
## Rotation that orients the carved FACE toward -Z (camera-forward).
## SM_Env_Cave_01 comes in with face on +X → yaw_deg = -90.
@export var face_align_yaw_deg: float = 0.0
