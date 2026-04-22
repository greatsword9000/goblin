extends Node
## RuckusManager — noise/notoriety meter that drives raid pacing.
##
## Owns: current ruckus value (0.0–1.0), threshold tracking, weights table,
##       rolling contributor log for the debug overlay.
## Listens to: tagged EventBus signals (weights keys).
## Emits: EventBus.ruckus_changed, EventBus.ruckus_threshold_crossed.
##
## Reset: on `raid_defeated`, drops to RESIDUAL_ON_RESET and re-arms any
## thresholds above the new value.

const DEFAULT_WEIGHTS_PATH: String = "res://resources/systems/ruckus_weights.tres"
const RESIDUAL_ON_RESET: float = 0.1

var value: float = 0.0
var weights: RuckusWeights

var _crossed: Array[float] = []
var _contributors: Array[Dictionary] = []


func _ready() -> void:
	_load_weights()
	_connect_events()


func _load_weights() -> void:
	var res: Resource = load(DEFAULT_WEIGHTS_PATH)
	if res is RuckusWeights:
		weights = res
	else:
		push_warning("[RuckusManager] weights.tres missing; using empty weights")
		weights = RuckusWeights.new()


func _connect_events() -> void:
	EventBus.tile_mined.connect(_on_tile_mined)
	EventBus.tile_built.connect(_on_tile_built)
	EventBus.minion_died.connect(_on_minion_died)
	EventBus.adventurer_died.connect(_on_adventurer_died)
	EventBus.minion_slapped.connect(_on_minion_slapped)
	EventBus.resource_hauled_to_throne.connect(_on_resource_hauled)
	EventBus.raid_defeated.connect(_on_raid_defeated)


# ── EventBus handlers ──────────────────────────────────────────
func _on_tile_mined(_grid_pos: Vector3i, _tile: Resource) -> void:
	_apply_event("tile_mined")


func _on_tile_built(_grid_pos: Vector3i, _buildable: Resource) -> void:
	_apply_event("tile_built")


func _on_minion_died(_minion: Node3D) -> void:
	_apply_event("minion_died")


func _on_adventurer_died(_adventurer: Node3D) -> void:
	_apply_event("adventurer_died")


func _on_minion_slapped(_minion: Node3D) -> void:
	_apply_event("minion_slapped")


func _on_resource_hauled(_type: String, _amount: int) -> void:
	_apply_event("resource_hauled_to_throne")


func _on_raid_defeated() -> void:
	reset_to(RESIDUAL_ON_RESET)


# ── Core API ───────────────────────────────────────────────────
func add_ruckus(amount: float, source: String) -> void:
	if amount == 0.0:
		return
	var old: float = value
	value = clampf(value + amount, 0.0, 1.0)
	var delta: float = value - old
	if delta == 0.0:
		return
	_log_contributor(source, delta)
	EventBus.ruckus_changed.emit(value, delta, source)
	_check_thresholds(old, value)


func reset_to(new_value: float) -> void:
	var clamped: float = clampf(new_value, 0.0, 1.0)
	var delta: float = clamped - value
	value = clamped
	var kept: Array[float] = []
	for t: float in _crossed:
		if t <= value:
			kept.append(t)
	_crossed = kept
	EventBus.ruckus_changed.emit(value, delta, "reset")


## Top N contributors summed by source, descending. For debug overlay.
func top_contributors(top_n: int = 3) -> Array:
	var totals: Dictionary = {}
	for entry: Dictionary in _contributors:
		var src: String = entry["source"]
		totals[src] = float(totals.get(src, 0.0)) + float(entry["amount"])
	var sorted_arr: Array = []
	for src: String in totals:
		sorted_arr.append({"source": src, "amount": totals[src]})
	sorted_arr.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["amount"]) > float(b["amount"]))
	return sorted_arr.slice(0, top_n)


# ── Internals ──────────────────────────────────────────────────
func _apply_event(event_name: String) -> void:
	var w: float = weights.weight_for(event_name)
	if w == 0.0:
		return
	add_ruckus(w, event_name)


func _check_thresholds(old: float, new_val: float) -> void:
	for t: float in weights.thresholds:
		if new_val >= t and old < t and not _crossed.has(t):
			_crossed.append(t)
			EventBus.ruckus_threshold_crossed.emit(t)


func _log_contributor(source: String, delta: float) -> void:
	_contributors.push_back({
		"source": source,
		"amount": delta,
		"t": Time.get_ticks_msec() / 1000.0,
	})
	var limit: int = weights.contributor_log_size
	while _contributors.size() > limit:
		_contributors.pop_front()
