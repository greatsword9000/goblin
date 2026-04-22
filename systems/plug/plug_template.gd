class_name PlugTemplate extends Resource
## A hand-authored composition of PlugPieces pinned to a grid-cell
## footprint. Saved as res://resources/plugs/<template_id>.tres.
##
## Procgen queries PlugLibrary by role + aesthetic + footprint, gets back
## matching templates, and instantiates one per cell via instantiate_at().
## Orientation logic (which way the plug faces) is driven by
## orientation_mode — floors are omni, walls face their floor neighbor,
## corners bisect two floor neighbors.

## Stable kebab-case ID, used as filename and as the primary lookup key.
## Must match ^[a-z0-9][a-z0-9_-]*$ — validated on save.
@export var template_id: String = ""
## Free-form human label shown in Load menus. Change freely; doesn't
## affect ID or any references.
@export var display_name: String = ""
## Optional pre-rendered thumbnail — generated on Save by the creator
## tool. Shown in Load / Library menus.
@export var thumbnail: Texture2D = null

# ─── Grid contract (procgen queries by these) ───────────────────────

## How many cells (2m each) the plug occupies in X,Z. Most plugs are
## (1,1); larger compositions like shrines may be (2,2) or (3,3).
@export var footprint_cells: Vector2i = Vector2i.ONE
## Which role this plug fulfills. Values form an open-ended taxonomy:
##   "env_floor", "env_wall_straight", "env_wall_corner",
##   "decor_cluster", "env_floor_accent", "env_ceiling", etc.
@export var role: String = ""
## Which visual family / biome this plug belongs to:
##   "cave", "dungeon", "crystal", "hell", "mushroom_grove", etc.
@export var aesthetic: String = ""
## Free-form tags procgen can filter on: "wet", "overgrown", "ruined",
## "small", "boss_room_only", etc.
@export var tags: Array[String] = []

# ─── Orientation contract ──────────────────────────────────────────

## How the spawner should rotate this plug when placing it:
##   "omni"    — rotation-symmetric; floor patches, decor clusters.
##               Spawner applies random yaw snapped to spawn_yaw_snap.
##   "facing"  — plug has a distinct front; walls. Spawner rotates so
##               the plug's +Z faces the adjacent floor neighbor.
##   "corner"  — plug covers two perpendicular edges; spawner rotates
##               so the concave bend faces the two floor neighbors.
@export var orientation_mode: String = "omni"
## Yaw quantization for omni plugs. 0 = free rotation, 90 = 4-way,
## 180 = flip, 360 = locked at whatever rotation was authored.
@export var spawn_yaw_snap: int = 90
## If true, the spawner may randomly mirror the plug on X for more
## variety. Breaks some asymmetric authored arrangements — set false
## for plugs where layout matters.
@export var allow_mirror: bool = true

# ─── Selection weight ──────────────────────────────────────────────

## Relative selection weight inside a PlugLibrary.query() bucket. 1.0 is
## default; 2.0 means twice as likely to be picked as a 1.0 plug with
## the same tags. 0.0 means never auto-pick (authored but disabled).
@export var spawn_weight: float = 1.0

# ─── The pieces ────────────────────────────────────────────────────

@export var pieces: Array[PlugPiece] = []


## Instantiate this plug at a world transform. Returns a Node3D root
## containing one child per piece that passed its spawn_chance roll.
## Children keep their authored transforms so they can be individually
## mined / replaced at runtime.
##
## `seed` — deterministic RNG seed so the same cell always spawns the
## same variant. Pass (cell.x * 73856093) ^ (cell.z * 19349663) or similar.
func instantiate_at(world_origin: Vector3, yaw_deg: float, rng_seed: int = 0) -> Node3D:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed if rng_seed != 0 else int(Time.get_ticks_usec())
	var root: Node3D = Node3D.new()
	root.name = "Plug_%s" % template_id
	root.position = world_origin
	root.rotation.y = deg_to_rad(yaw_deg)
	root.set_meta("template_id", template_id)
	for p in pieces:
		if p.spawn_chance < 1.0 and rng.randf() > p.spawn_chance:
			continue
		var scene: PackedScene = p.load_prefab()
		if scene == null:
			push_warning("PlugTemplate %s: missing prefab %s" % [template_id, p.prefab_path])
			continue
		var inst: Node = scene.instantiate()
		if not (inst is Node3D):
			push_warning("PlugTemplate %s: %s didn't instantiate as Node3D" % [template_id, p.prefab_path])
			inst.queue_free()
			continue
		var n3d: Node3D = inst
		n3d.transform = p.build_transform(0.0, rng)
		if p.mineable_tag != "":
			n3d.set_meta("mineable_tag", p.mineable_tag)
		root.add_child(n3d)
	return root


## Validate a candidate template_id. Returns "" on success or an error
## message. Used by the save dialog.
static func validate_id(candidate: String) -> String:
	if candidate == "":
		return "ID cannot be empty"
	var rx: RegEx = RegEx.new()
	rx.compile("^[a-z0-9][a-z0-9_-]*$")
	if rx.search(candidate) == null:
		return "ID must be lowercase, start with a letter/digit, contain only [a-z0-9_-]"
	return ""
