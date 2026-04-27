class_name PersonalityComponent extends Node
## PersonalityComponent — attach to a minion. Rolls a fresh
## PersonalityProfile on _ready and assigns a goblin name from the pool.
##
## Save/load: profile + name serialize via get_save_data / load_save_data.

const NAME_POOL: Array[String] = [
	"Grobnar", "Ogwhack", "Snikk", "Dumper", "Lobblin",
	"Grizzle", "Wartnose", "Muckfoot", "Scratcher", "Gribble",
	"Thumper", "Sneak", "Blisto", "Pog", "Noggin",
	"Krank", "Gumbo", "Yerk", "Ripple", "Dungey",
]

# Track names already claimed this session so siblings never share.
static var _claimed_names: Dictionary = {}

@export var profile: PersonalityProfile
var minion_name: String = ""


func _ready() -> void:
	if profile == null:
		profile = _roll_profile()
	if minion_name == "":
		minion_name = _pick_name()


## Normal-ish distribution around 0.5 via three uniform rolls.
func _roll_profile() -> PersonalityProfile:
	var p: PersonalityProfile = PersonalityProfile.new()
	p.cheerful = _norm_roll()
	p.grumpy = _norm_roll()
	p.curious = _norm_roll()
	p.lazy = _norm_roll()
	return p


func _norm_roll() -> float:
	return clampf((randf() + randf() + randf()) / 3.0, 0.0, 1.0)


## Pick a name that hasn't been claimed this session. Falls back to a
## numbered pool entry if we exhaust the list.
func _pick_name() -> String:
	var shuffled: Array[String] = NAME_POOL.duplicate()
	shuffled.shuffle()
	for candidate in shuffled:
		if not _claimed_names.has(candidate):
			_claimed_names[candidate] = true
			return candidate
	# Overflow — numbered fallback.
	var n: int = _claimed_names.size() + 1
	var fallback: String = "Goblin#%d" % n
	_claimed_names[fallback] = true
	return fallback


func get_save_data() -> Dictionary:
	return {
		"name": minion_name,
		"cheerful": profile.cheerful if profile != null else 0.5,
		"grumpy": profile.grumpy if profile != null else 0.5,
		"curious": profile.curious if profile != null else 0.5,
		"lazy": profile.lazy if profile != null else 0.5,
	}


func load_save_data(data: Dictionary) -> void:
	minion_name = str(data.get("name", minion_name))
	if profile == null:
		profile = PersonalityProfile.new()
	profile.cheerful = float(data.get("cheerful", 0.5))
	profile.grumpy = float(data.get("grumpy", 0.5))
	profile.curious = float(data.get("curious", 0.5))
	profile.lazy = float(data.get("lazy", 0.5))
