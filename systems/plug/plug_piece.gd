class_name PlugPiece extends Resource
## One placement inside a PlugTemplate: a prefab, its transform relative
## to the plug origin, and per-piece variation knobs.
##
## prefab_path is stored as a string (not PackedScene) so renamed assets
## fail loudly instead of silently dropping references during edits.

@export var prefab_path: String = ""
@export var position: Vector3 = Vector3.ZERO
@export var rotation_deg: Vector3 = Vector3.ZERO
@export var scale: Vector3 = Vector3.ONE

## At spawn time the spawner may add ±jitter_rotation_deg to Y rotation
## for organic variation. 0 = exact-reproducible.
@export var jitter_rotation_deg: float = 0.0
## At spawn time: scale multiplied by 1 ± jitter_scale. 0 = exact.
@export var jitter_scale: float = 0.0
## 0..1 — when <1, this piece may or may not spawn (optional decoration).
@export var spawn_chance: float = 1.0
## Per-piece tag the runtime can use for richer mining: each mineable
## piece spawns as its own entity so the player can destroy them
## independently. "rock" pieces become minable, "prop" pieces don't, etc.
@export var mineable_tag: String = ""   # "", "rock", "prop", "crystal", ...


func load_prefab() -> PackedScene:
	if prefab_path == "" or not ResourceLoader.exists(prefab_path):
		return null
	return load(prefab_path)


func build_transform(extra_yaw_deg: float = 0.0, rng: RandomNumberGenerator = null) -> Transform3D:
	var rot: Vector3 = rotation_deg
	if rng != null and jitter_rotation_deg > 0.0:
		rot.y += rng.randf_range(-jitter_rotation_deg, jitter_rotation_deg)
	rot.y += extra_yaw_deg
	var s: Vector3 = scale
	if rng != null and jitter_scale > 0.0:
		var f: float = 1.0 + rng.randf_range(-jitter_scale, jitter_scale)
		s *= f
	var basis: Basis = Basis.from_euler(Vector3(
		deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z),
	)).scaled(s)
	return Transform3D(basis, position)
