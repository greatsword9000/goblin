class_name DistantTorchTelegraph extends Node3D
## Raid-warning VFX. A glowing orange sphere at the corridor mouth that
## appears when Ruckus crosses SHOW_THRESHOLD. Replaced in M09 by the
## actual adventurer spawn.

const SHOW_THRESHOLD: float = 0.75
const HIDE_THRESHOLD: float = 1.0

@export var base_color: Color = Color(1.0, 0.55, 0.18)
@export var sphere_radius: float = 0.6

var _mesh: MeshInstance3D
var _light: OmniLight3D
var _material: StandardMaterial3D


func _ready() -> void:
	_build_visual()
	visible = false
	EventBus.ruckus_changed.connect(_on_ruckus_changed)
	_update_visibility(RuckusManager.value)


func _build_visual() -> void:
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = sphere_radius
	sphere.height = sphere_radius * 2.0

	_material = StandardMaterial3D.new()
	_material.albedo_color = base_color
	_material.emission_enabled = true
	_material.emission = base_color
	_material.emission_energy_multiplier = 3.0

	_mesh = MeshInstance3D.new()
	_mesh.mesh = sphere
	_mesh.material_override = _material
	add_child(_mesh)

	_light = OmniLight3D.new()
	_light.light_color = base_color
	_light.light_energy = 2.0
	_light.omni_range = 8.0
	add_child(_light)


func _on_ruckus_changed(new_value: float, _delta: float, _source: String) -> void:
	_update_visibility(new_value)


func _update_visibility(v: float) -> void:
	visible = v >= SHOW_THRESHOLD and v < HIDE_THRESHOLD


func _process(_delta: float) -> void:
	if not visible:
		return
	var t: float = Time.get_ticks_msec() / 1000.0
	var pulse: float = 0.7 + 0.3 * sin(t * 3.0)
	_material.emission_energy_multiplier = 2.0 + pulse * 2.0
	_light.light_energy = 1.0 + pulse * 2.0
