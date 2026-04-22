class_name TorchLight extends Node3D
## TorchLight — wraps a Synty torch prop with an OmniLight3D that flickers
## like a flame. Add as a child of any Node3D (or spawn via starter_dungeon).
##
## Flicker model: base_energy + per-frame noise + slow cosine wobble. Cheap,
## produces a lively glow without shader work.

@export var flame_color: Color = Color(1.0, 0.55, 0.2)
@export var base_energy: float = 1.6
@export var flicker_amplitude: float = 0.35  # how big the random jitter is
@export var wobble_rate: float = 3.0         # slow cosine component (Hz)
@export var light_range: float = 6.0
@export var light_offset: Vector3 = Vector3(0.0, 1.4, 0.0)

var _light: OmniLight3D
var _time: float = 0.0


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = flame_color
	_light.light_energy = base_energy
	_light.omni_range = light_range
	_light.shadow_enabled = true
	_light.position = light_offset
	add_child(_light)


func _process(delta: float) -> void:
	_time += delta
	# Cheap flame: slow cosine wobble + small random jitter.
	var wobble: float = cos(_time * wobble_rate * TAU) * 0.15
	var jitter: float = (randf() - 0.5) * flicker_amplitude
	_light.light_energy = maxf(0.1, base_energy + wobble + jitter)
