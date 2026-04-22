extends Node
## Autoload: index of every PlugTemplate under res://resources/plugs/.
## Procgen queries this; the editor tool writes to it.
##
## Usage:
##   PlugLibrary.query({
##       "role": "env_wall_straight",
##       "aesthetic": "cave",
##       "footprint_cells": Vector2i(1, 1),
##   })  → Array[PlugTemplate]   (filtered + weighted for random pick)
##   PlugLibrary.pick_weighted(results, rng) → PlugTemplate

const PLUGS_DIR: String = "res://resources/plugs"

var _templates: Array[PlugTemplate] = []
var _by_id: Dictionary = {}   # template_id -> PlugTemplate
var _loaded: bool = false

signal library_reloaded()


func _ready() -> void:
	reload()


## Walk the plugs directory and load every .tres. Call after editor
## saves so runtime queries see the new plug immediately.
func reload() -> void:
	_templates.clear()
	_by_id.clear()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(PLUGS_DIR)):
		_loaded = true
		return
	var dir: DirAccess = DirAccess.open(PLUGS_DIR)
	if dir == null:
		_loaded = true
		return
	for f in dir.get_files():
		if not f.ends_with(".tres"):
			continue
		# Skip autosaves (prefixed with _ or under _autosave/ subdir).
		if f.begins_with("_"):
			continue
		var path: String = "%s/%s" % [PLUGS_DIR, f]
		var res: Resource = load(path)
		if res is PlugTemplate:
			var t: PlugTemplate = res
			if t.template_id == "":
				push_warning("PlugLibrary: %s has empty template_id; skipping" % path)
				continue
			if _by_id.has(t.template_id):
				push_warning("PlugLibrary: duplicate id '%s' (first wins)" % t.template_id)
				continue
			_templates.append(t)
			_by_id[t.template_id] = t
	_loaded = true
	library_reloaded.emit()
	print("[PlugLibrary] loaded %d templates" % _templates.size())


func all() -> Array[PlugTemplate]:
	return _templates.duplicate()


func get_by_id(template_id: String) -> PlugTemplate:
	return _by_id.get(template_id, null)


## Query templates by filter dict. Every key must match; values can be
## strings, Vector2is, bools, or arrays (treated as "∈ array"). Returns
## an Array[PlugTemplate], spawn_weight > 0, sorted by id for stability.
func query(filters: Dictionary) -> Array[PlugTemplate]:
	var out: Array[PlugTemplate] = []
	for t in _templates:
		if t.spawn_weight <= 0.0:
			continue
		if _matches(t, filters):
			out.append(t)
	out.sort_custom(func(a, b): return a.template_id < b.template_id)
	return out


## Pick one template from an array using spawn_weight as the weight.
## Uses the provided RNG so callers can keep placement deterministic.
func pick_weighted(candidates: Array[PlugTemplate], rng: RandomNumberGenerator) -> PlugTemplate:
	if candidates.is_empty():
		return null
	var total: float = 0.0
	for t in candidates: total += t.spawn_weight
	if total <= 0.0:
		return candidates[0]
	var r: float = rng.randf() * total
	var acc: float = 0.0
	for t in candidates:
		acc += t.spawn_weight
		if r <= acc: return t
	return candidates[-1]


func _matches(t: PlugTemplate, filters: Dictionary) -> bool:
	for key in filters:
		var expected: Variant = filters[key]
		var actual: Variant = _get_field(t, key)
		if typeof(expected) == TYPE_ARRAY:
			if not (actual in expected):
				return false
		elif actual != expected:
			return false
	return true


func _get_field(t: PlugTemplate, key: String) -> Variant:
	match key:
		"template_id": return t.template_id
		"role": return t.role
		"aesthetic": return t.aesthetic
		"footprint_cells": return t.footprint_cells
		"orientation_mode": return t.orientation_mode
		"tags": return t.tags
		_: return t.get(key) if t.has_method("get") else null


## Save a template to disk. Called by the editor. Updates the in-memory
## index without a full reload.
func save_template(t: PlugTemplate) -> Error:
	if t.template_id == "":
		return ERR_INVALID_DATA
	var dir_abs: String = ProjectSettings.globalize_path(PLUGS_DIR)
	if not DirAccess.dir_exists_absolute(dir_abs):
		DirAccess.make_dir_recursive_absolute(dir_abs)
	var path: String = "%s/%s.tres" % [PLUGS_DIR, t.template_id]
	var err: Error = ResourceSaver.save(t, path)
	if err != OK:
		return err
	# Update index.
	if not _by_id.has(t.template_id):
		_templates.append(t)
	_by_id[t.template_id] = t
	library_reloaded.emit()
	return OK
