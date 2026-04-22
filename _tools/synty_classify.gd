@tool
extends SceneTree
## Scans Synty prefabs in a pack and writes a JSON manifest tagging each
## prefab by OBSERVABLE mesh properties (not name patterns). Output lets
## procgen systems query like:
##   "flat_panel, tileable, cave aesthetic, m_native scale"
## instead of guessing from prefab names.
##
## Run:
##   Godot --headless --path <project> -s _tools/synty_classify.gd -- <PackName>
##
## Writes: assets/synty/<PackName>/_tag_manifest.json

const SHAPE_FLAT_PANEL := "flat_panel"         # one axis << other two, likely tileable
const SHAPE_SLAB := "slab"                     # one axis small, other two similar (tile?)
const SHAPE_PILLAR := "pillar"                 # one axis >> other two
const SHAPE_CUBIC := "cubic"                   # roughly equal axes
const SHAPE_ORGANIC_CHUNK := "organic_chunk"   # irregular blob, no clear axis
const SHAPE_BACKDROP := "backdrop"             # huge (>15m any axis)
const SHAPE_TINY := "tiny"                     # too small to classify (<0.02m)

const ORIGIN_CENTER := "center"
const ORIGIN_BACK_FACE := "back_face"
const ORIGIN_FRONT_FACE := "front_face"
const ORIGIN_BOTTOM_CENTER := "bottom_center"
const ORIGIN_TOP_CENTER := "top_center"
const ORIGIN_CORNER := "corner"
const ORIGIN_OFFSET := "offset"

const SCALE_GROUP_M := "m_native"
const SCALE_GROUP_CM := "cm_native"


func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() < 1:
		push_error("usage: -s synty_classify.gd -- <PackName>")
		quit(1); return
	var pack: String = args[0]
	var prefabs_dir: String = "res://assets/synty/%s/Prefabs" % pack
	var out_path: String = "res://assets/synty/%s/_tag_manifest.json" % pack

	var dir: DirAccess = DirAccess.open(prefabs_dir)
	if dir == null:
		push_error("no such dir: %s" % prefabs_dir)
		quit(1); return

	var tags: Array = []
	var paths: Array[String] = []
	for f in dir.get_files():
		if not f.ends_with(".tscn"):
			continue
		paths.append("%s/%s" % [prefabs_dir, f])
	paths.sort()
	print("[classify] scanning %d prefabs in %s" % [paths.size(), pack])

	for p in paths:
		var tag: Dictionary = _classify_prefab(p, pack)
		if tag.size() > 0:
			tags.append(tag)

	_write_manifest(out_path, pack, tags)
	_print_summary(tags)
	quit()


func _classify_prefab(path: String, pack: String) -> Dictionary:
	var ps: PackedScene = load(path)
	if ps == null:
		return {}
	var inst: Node = ps.instantiate()
	self.root.add_child(inst)

	var aabb: AABB = _aabb(inst)
	var tri: int = _triangles(inst)
	var has_skeleton: bool = inst.find_children("*", "Skeleton3D", true, false).size() > 0
	var has_anim: bool = inst.find_children("*", "AnimationPlayer", true, false).size() > 0
	var mesh_count: int = inst.find_children("*", "MeshInstance3D", true, false).size()

	self.root.remove_child(inst); inst.queue_free()

	var size: Vector3 = aabb.size
	var origin: Vector3 = aabb.position
	var axes: Array[float] = [size.x, size.y, size.z]
	axes.sort()  # [smallest, mid, largest]

	var shape: String = _classify_shape(axes)
	var origin_kind: String = _classify_origin(size, origin)
	# Which axis is the "thin" one — the spawner uses this to know which
	# direction the flat back faces. Walls are thin in X or Z; floors in Y.
	var facing_axis: String = ["x", "y", "z"][_axis_argmin([size.x, size.y, size.z])]
	var scale_group: String = SCALE_GROUP_M if axes[2] >= 0.3 else SCALE_GROUP_CM
	var aesthetic: String = _classify_aesthetic(path, pack)
	var role: String = _classify_role(path, shape, has_skeleton, has_anim)

	# Normalize dimensions to meters regardless of import scale so heuristics
	# apply uniformly across packs. PolygonDungeon FBX imports at cm scale,
	# DungeonRealms/Alpine at meter scale.
	var m_scale: float = 100.0 if scale_group == SCALE_GROUP_CM else 1.0
	var max_axis_m: float = axes[2] * m_scale
	var min_axis_m: float = axes[0] * m_scale

	# Tileability heuristic: flat panel / slab shape, low-mid poly, reasonable
	# dimensions. Origin convention doesn't affect whether it's tileable —
	# only how the spawner places it (we expose origin via AABB data).
	var tileable: bool = (shape in [SHAPE_FLAT_PANEL, SHAPE_SLAB]
		and tri < 800
		and max_axis_m > 1.0    # at least 1m at natural scale
		and max_axis_m < 12.0   # exclude backdrops (they span rooms, not cells)
		and min_axis_m > 0.05)  # not a paper-thin decal

	return {
		"path": path,
		"pack": pack,
		"size": [size.x, size.y, size.z],
		"size_m": [size.x * m_scale, size.y * m_scale, size.z * m_scale],
		"origin": [origin.x, origin.y, origin.z],
		"tri_count": tri,
		"mesh_count": mesh_count,
		"has_skeleton": has_skeleton,
		"has_anim": has_anim,
		"shape": shape,
		"origin_kind": origin_kind,
		"facing_axis": facing_axis,
		"scale_group": scale_group,
		"aesthetic": aesthetic,
		"role": role,
		"tileable": tileable,
	}


func _classify_shape(axes: Array[float]) -> String:
	# axes is [smallest, mid, largest]
	if axes[2] < 0.02:
		return SHAPE_TINY
	if axes[2] > 15.0:
		return SHAPE_BACKDROP
	var smallest_ratio: float = axes[0] / axes[2]
	var mid_ratio: float = axes[1] / axes[2]
	# Flat panel: smallest << mid ≈ largest (thin slab with substantial face).
	if smallest_ratio < 0.15 and mid_ratio > 0.5:
		return SHAPE_FLAT_PANEL
	# Slab: smallest modest, mid and largest similar.
	if smallest_ratio < 0.35 and mid_ratio > 0.6:
		return SHAPE_SLAB
	# Pillar: largest >> other two.
	if mid_ratio < 0.45:
		return SHAPE_PILLAR
	# Cubic: all axes within 1.6x of each other.
	if smallest_ratio > 0.6:
		return SHAPE_CUBIC
	return SHAPE_ORGANIC_CHUNK


func _classify_origin(size: Vector3, origin: Vector3) -> String:
	# origin is AABB.position (min corner). Where is Vector3.ZERO relative to it?
	var center: Vector3 = origin + size * 0.5
	var eps: float = 0.1
	var h_centered: bool = abs(center.x) < eps * size.x and abs(center.z) < eps * size.z
	var h_x_zero: bool = abs(center.x) < eps * size.x
	var h_z_zero: bool = abs(center.z) < eps * size.z
	var v_centered: bool = abs(center.y) < eps * size.y
	var v_bottom: bool = origin.y > -eps * size.y  # bottom roughly at world y=0
	var v_top: bool = origin.y + size.y < eps * size.y

	if h_centered and v_centered: return ORIGIN_CENTER
	if h_centered and v_bottom: return ORIGIN_BOTTOM_CENTER
	if h_centered and v_top: return ORIGIN_TOP_CENTER
	# Back-face: origin on one horizontal axis (usually Z) at the back edge.
	if h_x_zero and not h_z_zero and v_centered: return ORIGIN_BACK_FACE
	if h_z_zero and not h_x_zero and v_centered: return ORIGIN_BACK_FACE
	return ORIGIN_OFFSET


func _classify_aesthetic(path: String, pack: String) -> String:
	var file: String = path.get_file().to_lower()
	# Pack-level defaults.
	var pack_aesthetic: String = {
		"PolygonDungeon": "dungeon",
		"PolygonDungeonRealms": "dungeon_realms",
		"PolygonDarkFantasy": "dark_fantasy",
		"PolygonDarkFortress": "dark_fortress",
		"PolygonFantasyKingdom": "fantasy_kingdom",
		"PolygonFantasyRivals": "fantasy_rivals",
		"PolygonGoblinWarCamp": "goblin_war_camp",
		"PolygonKids": "kids",
		"PNB_Alpine_Mountain": "alpine",
	}.get(pack, "unknown")
	# Filename overrides — the pack has mixed themes (e.g. dungeon has hell pieces).
	for tag in ["cave", "dwarf", "hell", "desert", "tropical", "snow", "ice",
				"lava", "crystal", "ruin", "camp", "mushroom", "alpine"]:
		if "_%s_" % tag in file or "_%s." % tag in file or file.begins_with(tag + "_"):
			return tag
	return pack_aesthetic


func _classify_role(path: String, shape: String, has_skeleton: bool, has_anim: bool) -> String:
	var file: String = path.get_file().to_lower()
	if has_skeleton or file.begins_with("character_") or file.begins_with("sk_chr_"):
		return "character"
	if file.begins_with("fx_"):
		return "fx"
	if file.begins_with("sm_wep_"):
		return "weapon"
	if file.begins_with("sm_prop_"):
		return "prop"
	if file.begins_with("sm_bld_"):
		return "building"
	if file.begins_with("sm_env_"):
		# Further classify environment by shape + filename hint.
		if "floor" in file or "ground" in file or ("flat" in file and shape == SHAPE_FLAT_PANEL):
			return "env_floor"
		if "wall" in file and shape in [SHAPE_FLAT_PANEL, SHAPE_SLAB]:
			return "env_wall_tile"
		if "wall" in file:
			return "env_wall_prop"
		if "cave" in file and "background" in file:
			return "env_backdrop"
		# Cave slabs (SM_Env_Cave_01, _Large_01 etc.) are architectural
		# wall tiles, not rocks — shape distinguishes them from organic
		# cave chunks which fall through to env_rock.
		if "cave" in file and shape in [SHAPE_FLAT_PANEL, SHAPE_SLAB]:
			return "env_wall_tile"
		if "cave" in file or "rock" in file or "cliff" in file:
			return "env_rock"
		if "pillar" in file or "stairs" in file or "beam" in file:
			return "env_structural"
		return "env_other"
	return "unknown"


func _axis_argmin(v: Array) -> int:
	var idx: int = 0
	for i in range(1, v.size()):
		if v[i] < v[idx]: idx = i
	return idx


func _aabb(node: Node) -> AABB:
	var out: AABB = AABB(); var first: bool = true
	for vi in node.find_children("*", "VisualInstance3D", true, false):
		var v: VisualInstance3D = vi
		var w: AABB = v.global_transform * v.get_aabb()
		out = w if first else out.merge(w); first = false
	return out


func _triangles(node: Node) -> int:
	var n: int = 0
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null: continue
		for i in range(m.get_surface_count()):
			var arr: Array = m.surface_get_arrays(i)
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr.size() > Mesh.ARRAY_INDEX else PackedInt32Array()
			if idx.size() > 0:
				n += idx.size() / 3
			else:
				var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
				n += v.size() / 3
	return n


func _write_manifest(out_path: String, pack: String, tags: Array) -> void:
	var f: FileAccess = FileAccess.open(out_path, FileAccess.WRITE)
	if f == null:
		push_error("cannot write %s" % out_path); return
	var data: Dictionary = {
		"pack": pack,
		"generated_by": "_tools/synty_classify.gd",
		"schema_version": 1,
		"tag_count": tags.size(),
		"tags": tags,
	}
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	print("[classify] wrote %s (%d entries)" % [out_path, tags.size()])


func _print_summary(tags: Array) -> void:
	var by_role: Dictionary = {}
	var by_shape: Dictionary = {}
	var by_aesthetic: Dictionary = {}
	var tileables: Array = []
	for t in tags:
		by_role[t.role] = by_role.get(t.role, 0) + 1
		by_shape[t.shape] = by_shape.get(t.shape, 0) + 1
		by_aesthetic[t.aesthetic] = by_aesthetic.get(t.aesthetic, 0) + 1
		if t.tileable:
			tileables.append(t)
	print("\n=== Summary ===")
	print("role: ", by_role)
	print("shape: ", by_shape)
	print("aesthetic: ", by_aesthetic)
	print("\n--- Tileable prefabs (%d) ---" % tileables.size())
	tileables.sort_custom(func(a, b): return a.role < b.role)
	for t in tileables:
		print("  %-45s role=%-15s aes=%-12s size_m=%5.2f×%5.2f×%5.2f tris=%4d origin=%s" % [
			t.path.get_file(), t.role, t.aesthetic,
			t.size_m[0], t.size_m[1], t.size_m[2], t.tri_count, t.origin_kind,
		])
