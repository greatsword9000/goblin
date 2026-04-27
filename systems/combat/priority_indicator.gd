class_name PriorityIndicator extends Node3D
## PriorityIndicator — floating ring that follows the current focus
## attack target. Shows when RaidDirector has a priority queue head,
## hides when the queue is empty.
##
## Installed once by StarterDungeon and self-manages from _process.

const RING_RADIUS: float = 0.7
const RING_INNER_RADIUS: float = 0.5
const HOVER_Y: float = 0.08
const PULSE_PERIOD: float = 1.1

var _mesh: MeshInstance3D
var _material: StandardMaterial3D
var _phase: float = 0.0


func _ready() -> void:
	_mesh = MeshInstance3D.new()
	var torus: TorusMesh = TorusMesh.new()
	torus.inner_radius = RING_INNER_RADIUS
	torus.outer_radius = RING_RADIUS
	_mesh.mesh = torus
	_material = StandardMaterial3D.new()
	_material.albedo_color = Color(1.0, 0.2, 0.2, 0.8)
	_material.emission_enabled = true
	_material.emission = Color(1.0, 0.25, 0.25)
	_material.emission_energy_multiplier = 1.2
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_mesh.material_override = _material
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	visible = false


func _process(delta: float) -> void:
	var target: Node3D = RaidDirector.get_priority_target()
	if target == null or not is_instance_valid(target):
		visible = false
		return
	visible = true
	global_position = target.global_position + Vector3(0.0, HOVER_Y, 0.0)
	# Gentle pulse so it reads as alive.
	_phase += delta
	var pulse: float = 0.85 + 0.15 * sin(_phase * TAU / PULSE_PERIOD)
	_mesh.scale = Vector3(pulse, 1.0, pulse)
