extends Node
## SaveManager — versioned save/load for Phase 1 world state.
##
## Scope for M13 minimum: world tiles, stockpile, ruckus value. Entity
## snapshots (live minions/adventurers/pickups) are NOT preserved yet —
## a reload restarts the starter dungeon fresh and layers saved world
## state on top. Full entity roundtrip is M13-polish work.
##
## Save format: JSON blob under user://saves/slotN.json. The top-level
## `version` field gates migration; bump SAVE_VERSION whenever the shape
## changes and add a _migrate_* function below.

const SAVE_VERSION: int = 1
const SAVE_DIR: String = "user://saves/"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		save_to_slot(0)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("quick_load"):
		load_from_slot(0)
		get_viewport().set_input_as_handled()


func save_to_slot(slot: int) -> bool:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"ruckus": RuckusManager.value,
		"resources": ResourceManager.get_save_data(),
		"tiles": _gather_tile_overrides(),
	}
	var path: String = "%sslot%d.json" % [SAVE_DIR, slot]
	var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("[SaveManager] could not open %s for writing" % path)
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	EventBus.game_saved.emit(slot)
	print("[SaveManager] saved slot %d (ruckus=%.2f, tiles=%d)" % [
		slot, RuckusManager.value, (data["tiles"] as Array).size(),
	])
	return true


func load_from_slot(slot: int) -> bool:
	var path: String = "%sslot%d.json" % [SAVE_DIR, slot]
	if not FileAccess.file_exists(path):
		push_warning("[SaveManager] no save at %s" % path)
		return false
	var f: FileAccess = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var txt: String = f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(txt)
	if not (parsed is Dictionary):
		push_warning("[SaveManager] malformed save file")
		return false
	var data: Dictionary = parsed as Dictionary
	var version: int = int(data.get("version", 0))
	if version != SAVE_VERSION:
		data = _migrate(data, version)
	RuckusManager.value = float(data.get("ruckus", 0.0))
	ResourceManager.load_save_data(data.get("resources", {}))
	_apply_tile_overrides(data.get("tiles", []))
	EventBus.game_loaded.emit(slot)
	print("[SaveManager] loaded slot %d" % slot)
	return true


## Grab every cell whose tile id differs from the WorldGenerator baseline.
## Cheap enough for 101×101 grids — we only serialize the delta.
func _gather_tile_overrides() -> Array:
	var out: Array = []
	for cell: Vector3i in GridWorld.get_all_cells():
		var tile: TileResource = GridWorld.get_tile(cell)
		if tile == null:
			continue
		out.append({
			"x": cell.x, "y": cell.y, "z": cell.z,
			"id": tile.id,
		})
	return out


## Apply saved tile ids back to the grid by looking each id up from the
## known tile library under res://resources/tiles/. Skips ids we can't
## resolve — future work: register tiles explicitly.
func _apply_tile_overrides(arr: Variant) -> void:
	if not (arr is Array):
		return
	for entry: Variant in arr:
		if not (entry is Dictionary):
			continue
		var d: Dictionary = entry
		var cell := Vector3i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0)))
		var id: String = str(d.get("id", ""))
		var tile: TileResource = _resolve_tile(id)
		if tile != null:
			GridWorld.set_tile(cell, tile, NAN, false)


func _resolve_tile(id: String) -> TileResource:
	# Minimal registry — extend as new tile types land.
	match id:
		"cave_rock": return load("res://resources/tiles/cave_rock.tres")
		"floor_stone": return load("res://resources/tiles/floor_stone.tres")
		"built_wall": return load("res://resources/tiles/built_wall.tres")
		"throne_base": return load("res://resources/tiles/throne_base.tres")
		_: return null


func _migrate(data: Dictionary, from_version: int) -> Dictionary:
	# Phase 1 — no migrations yet. Return untouched and hope for the best.
	push_warning("[SaveManager] unknown save version %d; attempting as-is" % from_version)
	return data
