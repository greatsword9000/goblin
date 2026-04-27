## One-shot: authors four starter PlugTemplate .tres files under
## res://resources/plugs/ so the user has something loadable in the
## editor immediately. Re-run anytime you want to reset the starters
## to their known-good defaults (it will overwrite).
##
## Usage:
##   Godot --headless --path . -s _tools/author_default_plugs.gd
extends SceneTree


const OUT_DIR: String = "res://resources/plugs"


func _init() -> void:
	_ensure_dir(OUT_DIR)
	_author_gold_vein()
	_author_crystal_cluster()
	_author_mushroom_patch()
	_author_rubble_pile()
	print("[DefaultPlugs] done — 4 plugs written to %s" % OUT_DIR)
	quit()


func _ensure_dir(path: String) -> void:
	var abs := ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(abs):
		DirAccess.make_dir_recursive_absolute(abs)


func _author_gold_vein() -> void:
	# Three gold-coin piles scattered inside a 1×1 cell.
	var paths := [
		"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Prop_Gold_Coins_01.tscn",
		"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Prop_Gold_Coins_02.tscn",
		"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Prop_Gold_Coins_03.tscn",
	]
	var positions := [
		Vector3(-0.5, 0, -0.3),
		Vector3(0.3, 0, 0.5),
		Vector3(0.4, 0, -0.6),
	]
	var yaws := [12.0, -45.0, 110.0]
	_save_plug(
		"gold-vein-small", "Gold Vein (small)",
		"decor_cluster", "cave",
		["gold", "ore", "small"],
		paths, positions, yaws, 0.6,
	)


func _author_crystal_cluster() -> void:
	# Three small gems clustered near cell center, varying heights.
	var paths := [
		"res://assets/synty/PolygonDungeon/Prefabs/SM_Prop_Gem_01.tscn",
		"res://assets/synty/PolygonDungeon/Prefabs/SM_Prop_Gem_03.tscn",
		"res://assets/synty/PolygonDungeon/Prefabs/SM_Prop_Gem_05.tscn",
	]
	var positions := [
		Vector3(-0.2, 0, 0.1),
		Vector3(0.3, 0, -0.2),
		Vector3(0.1, 0, 0.4),
	]
	var yaws := [0.0, 35.0, -30.0]
	_save_plug(
		"crystal-cluster-01", "Crystal Cluster",
		"decor_cluster", "crystal",
		["crystal", "gems", "small"],
		paths, positions, yaws, 0.8,
	)


func _author_mushroom_patch() -> void:
	var paths := [
		"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Mushroom_Giant_01.tscn",
		"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Mushroom_Giant_02.tscn",
		"res://assets/synty/PolygonDungeon/Prefabs/SM_Env_Mushroom_Giant_03.tscn",
	]
	var positions := [
		Vector3(-0.4, 0, 0.3),
		Vector3(0.2, 0, -0.4),
		Vector3(0.5, 0, 0.3),
	]
	var yaws := [0.0, 90.0, 180.0]
	_save_plug(
		"mushroom-patch-01", "Mushroom Patch",
		"decor_cluster", "mushroom",
		["mushroom", "organic", "small"],
		paths, positions, yaws, 0.5,
	)


func _author_rubble_pile() -> void:
	var paths := [
		"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Env_Rock_Small_01.tscn",
		"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Env_Rock_Flat_01.tscn",
		"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Env_Rock_Flat_02.tscn",
		"res://assets/synty/PolygonDungeonRealms/Prefabs/SM_Env_Rock_Small_01.tscn",
	]
	var positions := [
		Vector3(-0.3, 0, 0.2),
		Vector3(0.4, 0, -0.3),
		Vector3(-0.5, 0, -0.5),
		Vector3(0.2, 0, 0.5),
	]
	var yaws := [0.0, 45.0, 90.0, 135.0]
	_save_plug(
		"rubble-pile-01", "Rubble Pile",
		"decor_cluster", "dungeon",
		["rubble", "decor", "small"],
		paths, positions, yaws, 1.0,
	)


## Build a PlugTemplate resource from parallel arrays and save it.
func _save_plug(
	template_id: String,
	display_name: String,
	role: String,
	aesthetic: String,
	tags: Array[String],
	prefab_paths: Array,
	positions: Array,
	yaws: Array,
	scale: float,
) -> void:
	var t: PlugTemplate = PlugTemplate.new()
	t.template_id = template_id
	t.display_name = display_name
	t.footprint_cells = Vector2i.ONE
	t.role = role
	t.aesthetic = aesthetic
	t.tags = tags
	t.orientation_mode = "omni"
	t.spawn_yaw_snap = 90
	t.allow_mirror = true
	t.spawn_weight = 1.0

	var pieces: Array[PlugPiece] = []
	for i in range(prefab_paths.size()):
		var path: String = prefab_paths[i]
		if not ResourceLoader.exists(path):
			push_warning("[DefaultPlugs] missing prefab: %s (skipping)" % path)
			continue
		var p: PlugPiece = PlugPiece.new()
		p.prefab_path = path
		p.position = positions[i]
		p.rotation_deg = Vector3(0, yaws[i], 0)
		p.scale = Vector3.ONE * scale
		p.jitter_rotation_deg = 15.0
		p.jitter_scale = 0.1
		p.spawn_chance = 1.0
		pieces.append(p)
	t.pieces = pieces

	var out_path: String = "%s/%s.tres" % [OUT_DIR, template_id]
	var err: Error = ResourceSaver.save(t, out_path)
	if err == OK:
		print("[DefaultPlugs] wrote %s (%d pieces)" % [out_path, pieces.size()])
	else:
		push_error("[DefaultPlugs] failed to save %s: %d" % [out_path, err])
