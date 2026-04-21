extends Node
## ResourceManager — stockpile accounting for gold, ore, and other
## material resources. Single source of truth for "how much do I have."
##
## Owns: a Dictionary<String, int> of stockpiles.
## Emits (via EventBus): resource_gained, resource_spent, resource_hauled_to_throne.
##
## Autoloaded. Call `gain("gold", 5)` or `spend("copper", 3)` from any system.

var _stockpile: Dictionary = {}  # String (resource_type) -> int (amount)


func amount(resource_type: String) -> int:
	return int(_stockpile.get(resource_type, 0))


func has_amount(resource_type: String, required: int) -> bool:
	return amount(resource_type) >= required


func gain(resource_type: String, delta: int) -> void:
	if delta <= 0:
		return
	_stockpile[resource_type] = amount(resource_type) + delta
	EventBus.resource_gained.emit(resource_type, delta)


## Attempt to deduct `delta` of `resource_type`. Returns true on success.
## Does not partially spend.
func spend(resource_type: String, delta: int) -> bool:
	if delta <= 0:
		return true
	if not has_amount(resource_type, delta):
		return false
	_stockpile[resource_type] -= delta
	EventBus.resource_spent.emit(resource_type, delta)
	return true


## Bulk-check a cost dict without spending. Useful for build-menu validity.
func can_afford(costs: Dictionary) -> bool:
	for key in costs.keys():
		if not has_amount(str(key), int(costs[key])):
			return false
	return true


## Bulk-spend a cost dict atomically. Returns true on success; no partial
## spend if any component is short.
func spend_all(costs: Dictionary) -> bool:
	if not can_afford(costs):
		return false
	for key in costs.keys():
		spend(str(key), int(costs[key]))
	return true


## Shortcut for hauled ore: increments the stockpile and emits the
## dedicated "reached throne" signal so visual/audio systems can react.
func haul_to_throne(resource_type: String, delta: int) -> void:
	gain(resource_type, delta)
	EventBus.resource_hauled_to_throne.emit(resource_type, delta)
	print("[ResourceManager] hauled %d %s to throne (total=%d)" % [
		delta, resource_type, amount(resource_type),
	])


## Snapshot used by SaveManager (M13).
func get_save_data() -> Dictionary:
	return _stockpile.duplicate()


func load_save_data(data: Dictionary) -> void:
	_stockpile.clear()
	for key in data.keys():
		_stockpile[str(key)] = int(data[key])
