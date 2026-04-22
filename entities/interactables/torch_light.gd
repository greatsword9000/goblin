class_name TorchLight extends Node3D
## TorchLight — wraps a Synty torch prop with an OmniLight3D that flickers
## like a flame. Add as a child of any Node3D (or spawn via starter_dungeon).
##
## Flicker model: base_energy + per-frame noise + slow cosine wobble. Cheap,
## produces a lively glow without shader work.

@export var flame_color: Color = Color(1.0, 0.55, 0.2)
@export var base_energy: float = 2.6
@export var flicker_amplitude: float = 0.5   # how big the random jitter is
@export var wobble_rate: float = 3.0         # slow cosine component (Hz)
@export var light_range: float = 8.0
@export var light_offset: Vector3 = Vector3(0.0, 1.1, 0.0)
@export var flame_radius: float = 0.12

var _light: OmniLight3D
var _flame_mesh: MeshInstance3D
var _flame_material: StandardMaterial3D
var _time: float = 0.0


func _ready() -> void:
	_light = OmniLight3D.new()
	_light.light_color = flame_color
	_light.light_energy = base_energy
	_light.omni_range = light_range
	_light.shadow_enabled = true
	_light.position = light_offset
	add_child(_light)

	# Visible flame: small emissive sphere at the light origin. Its size and
	# emission energy wobble with the flicker.
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = flame_radius
	sphere.height = flame_radius * 2.0

	_flame_material = StandardMaterial3D.new()
	_flame_material.albedo_color = flame_color
	_flame_material.emission_enabled = true
	_flame_material.emission = flame_color
	_flame_material.emission_energy_multiplier = 6.0
	_flame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_flame_mesh = MeshInstance3D.new()
	_flame_mesh.mesh = sphere
	_flame_mesh.material_override = _flame_material
	_flame_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame_mesh.position = light_offset
	add_child(_flame_mesh)


func _process(delta: float) -> void:
	_time += delta
	var wobble: float = cos(_time * wobble_rate * TAU) * 0.15
	var jitter: float = (randf() - 0.5) * flicker_amplitude
	var energy: float = maxf(0.1, base_energy + wobble + jitter)
	_light.light_energy = energy
	if _flame_mesh != null:
		# Match the flame mesh scale + brightness to the light intensity.
		var s: float = 0.85 + wobble * 0.6 + jitter * 0.5
		_flame_mesh.scale = Vector3.ONE * clampf(s, 0.6, 1.4)
		_flame_material.emission_energy_multiplier = 4.0 + energy
