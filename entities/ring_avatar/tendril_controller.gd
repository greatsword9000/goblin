class_name TendrilController extends Node3D
## TendrilController — verlet-rope telekinetic tendril.
##
## The signature Ring Avatar beat. Hold `ring_primary` (LMB): the tendril
## extends from the kid's hand anchor toward the cursor's ground-plane
## position. Release: it retracts to the origin with a springy snap.
##
## Physics: classic verlet integration. Each segment endpoint is a point
## with `pos` / `prev_pos`; gravity accumulates into implicit velocity;
## pairs are constraint-relaxed to their rest length for several iterations.
## Start point is pinned to the hand anchor; end point is either driven
## toward the cursor (extending) or sprung toward the anchor (retracting).
##
## Rendering: ImmediateMesh generates a ribbon each frame — two triangle
## strips along segment length, facing camera via billboarding.
##
## Collision: a ray from anchor to current target truncates the rope length
## to the hit distance so it can't pass through walls.
##
## Wiring: parented under RingAvatar/Body/TendrilAnchor. The scene sets
## `cursor_source` to the camera rig (anything with `cursor_world_position()`).

@export_group("Physics")
@export var segment_count: int = 20
## Max rope reach = segment_count * base_segment_length. Tune this up for a
## longer telekinetic reach; verlet constraints resolve to shorter lengths
## when the target is closer than max.
@export var base_segment_length: float = 0.6
@export var gravity: float = 6.0
@export var damping: float = 0.92
@export var constraint_iterations: int = 8
@export var spring_strength: float = 28.0
@export var extend_speed: float = 14.0
@export var retract_speed: float = 18.0

@export_group("Visual")
@export var tube_radius: float = 0.18
@export var tube_color: Color = Color(0.85, 0.35, 1.0)
@export var tube_emission_energy: float = 4.0
@export var pulse_frequency: float = 3.0
@export var pulse_amplitude: float = 0.2

@export_group("Wiring")
@export var cursor_source: Node  # must provide cursor_world_position() -> Vector3
@export var collision_mask: int = 1  # world layer only by default
## If set, the anchor's global_transform is used as origin each frame;
## otherwise this node's own global_transform is the origin.
@export var anchor_node: Node3D

var _positions: PackedVector3Array
var _prev_positions: PackedVector3Array
var _rest_lengths: PackedFloat32Array

var _extending: bool = false
var _target: Vector3 = Vector3.ZERO
var _current_reach: float = 0.0
var _pulse_phase: float = 0.0

var _mesh_instance: MeshInstance3D
var _immediate_mesh: ImmediateMesh
var _tube_material: StandardMaterial3D


func _ready() -> void:
	_init_rope()
	_init_visual()
	set_as_top_level(true)  # world-space positions are already world-space


func _init_rope() -> void:
	_positions = PackedVector3Array()
	_prev_positions = PackedVector3Array()
	_rest_lengths = PackedFloat32Array()
	var origin: Vector3 = _origin_position()
	for i in range(segment_count):
		_positions.append(origin)
		_prev_positions.append(origin)
	for i in range(segment_count - 1):
		_rest_lengths.append(base_segment_length)


func _init_visual() -> void:
	_immediate_mesh = ImmediateMesh.new()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _immediate_mesh
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Vertices are computed in world-space; pin the mesh instance to world
	# origin so local == world when ImmediateMesh draws.
	_mesh_instance.top_level = true
	add_child(_mesh_instance)
	_mesh_instance.global_transform = Transform3D.IDENTITY

	_tube_material = StandardMaterial3D.new()
	_tube_material.albedo_color = tube_color
	_tube_material.emission_enabled = true
	_tube_material.emission = tube_color
	_tube_material.emission_energy_multiplier = tube_emission_energy
	_tube_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# Render both sides — ribbon winding can flip depending on camera angle.
	_tube_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tube_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	_mesh_instance.material_override = _tube_material


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ring_primary"):
		_extending = true
		var cs_valid: bool = cursor_source != null and cursor_source.has_method("cursor_world_position")
		var an_valid: bool = anchor_node != null and is_instance_valid(anchor_node)
		print("[Tendril] LMB pressed — extending=true  anchor_ok=%s  cursor_src_ok=%s" % [an_valid, cs_valid])
	elif event.is_action_released("ring_primary"):
		_extending = false
		print("[Tendril] LMB released — reach was %.2f" % _current_reach)


func _physics_process(delta: float) -> void:
	_update_target(delta)
	_step_verlet(delta)
	_apply_constraints()


func _process(delta: float) -> void:
	_pulse_phase += delta * pulse_frequency * TAU
	_render_tube()


func _origin_position() -> Vector3:
	if anchor_node != null and is_instance_valid(anchor_node):
		return anchor_node.global_position
	return global_position


func _update_target(delta: float) -> void:
	var origin: Vector3 = _origin_position()
	var max_reach: float = base_segment_length * float(segment_count - 1)

	if _extending and cursor_source != null and cursor_source.has_method("cursor_world_position"):
		var cursor: Vector3 = cursor_source.call("cursor_world_position")
		var desired_target: Vector3 = cursor
		# Clamp target to max reach so verlet constraints aren't fighting an
		# unreachable goal.
		var delta_vec: Vector3 = desired_target - origin
		var dist: float = delta_vec.length()
		if dist > 0.001:
			var clamped_dist: float = minf(dist, max_reach)
			# Collision truncation — shorten if a wall intervenes.
			clamped_dist = _raycast_clamp(origin, delta_vec.normalized(), clamped_dist)
			_target = origin + delta_vec.normalized() * clamped_dist
			_current_reach = move_toward(_current_reach, clamped_dist, extend_speed * delta)
		else:
			_target = origin
			_current_reach = move_toward(_current_reach, 0.0, retract_speed * delta)
	else:
		_current_reach = move_toward(_current_reach, 0.0, retract_speed * delta)
		_target = origin + (_target - origin).normalized() * _current_reach if _current_reach > 0.01 else origin


func _raycast_clamp(origin: Vector3, dir: Vector3, desired_dist: float) -> float:
	var space := get_world_3d().direct_space_state
	var params := PhysicsRayQueryParameters3D.create(origin, origin + dir * desired_dist, collision_mask)
	var hit := space.intersect_ray(params)
	if hit.is_empty():
		return desired_dist
	return origin.distance_to(hit["position"]) - 0.05  # small epsilon so tip doesn't bury in wall


func _step_verlet(delta: float) -> void:
	var origin: Vector3 = _origin_position()
	_positions[0] = origin
	_prev_positions[0] = origin

	# Integrate interior + end points
	var gravity_vec := Vector3(0.0, -gravity, 0.0)
	for i in range(1, segment_count):
		var pos: Vector3 = _positions[i]
		var prev: Vector3 = _prev_positions[i]
		var velocity: Vector3 = (pos - prev) * damping
		var new_pos: Vector3 = pos + velocity + gravity_vec * delta * delta
		_prev_positions[i] = pos
		_positions[i] = new_pos

	# Drive the end point toward either the extended target or back to origin.
	var end_i: int = segment_count - 1
	var end_pos: Vector3 = _positions[end_i]
	var goal: Vector3 = _target if _extending else origin
	var spring_force: Vector3 = (goal - end_pos) * spring_strength * delta
	_positions[end_i] = end_pos + spring_force * delta


func _apply_constraints() -> void:
	var origin: Vector3 = _origin_position()
	# Adjust effective segment length based on current reach so rope can
	# shorten when retracting and extend smoothly when extending.
	var target_total: float = maxf(_current_reach, 0.001)
	var segment_len: float = maxf(target_total / float(segment_count - 1), 0.001)

	for _pass in range(constraint_iterations):
		_positions[0] = origin
		for i in range(segment_count - 1):
			var a: Vector3 = _positions[i]
			var b: Vector3 = _positions[i + 1]
			var delta_vec: Vector3 = b - a
			var dist: float = delta_vec.length()
			if dist < 0.0001:
				continue
			var diff: float = (dist - segment_len) / dist
			var correction: Vector3 = delta_vec * 0.5 * diff
			if i == 0:
				# Start pinned — push all the correction onto point i+1
				_positions[i + 1] = b - delta_vec * diff
			else:
				_positions[i] = a + correction
				_positions[i + 1] = b - correction


func _render_tube() -> void:
	_immediate_mesh.clear_surfaces()
	if _current_reach < 0.02:
		return

	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		if Engine.get_process_frames() % 60 == 0:
			print("[Tendril] no active camera; can't render")
		return
	var cam_pos: Vector3 = cam.global_position

	# One-shot diagnostic each second while the rope is extended
	if Engine.get_process_frames() % 60 == 0 and _extending:
		var p0: Vector3 = _positions[0]
		var pN: Vector3 = _positions[segment_count - 1]
		print("[Tendril] reach=%.2f  p0=%s  pN=%s  mi.global_pos=%s" % [
			_current_reach, p0, pN, _mesh_instance.global_position,
		])

	var pulse: float = 1.0 + sin(_pulse_phase) * pulse_amplitude
	var radius: float = tube_radius * pulse

	_immediate_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(segment_count):
		var p: Vector3 = _positions[i]
		var tangent: Vector3
		if i == 0:
			tangent = (_positions[i + 1] - p).normalized()
		elif i == segment_count - 1:
			tangent = (p - _positions[i - 1]).normalized()
		else:
			tangent = (_positions[i + 1] - _positions[i - 1]).normalized()
		var to_cam: Vector3 = (cam_pos - p).normalized()
		var side: Vector3 = tangent.cross(to_cam).normalized()
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		_immediate_mesh.surface_add_vertex(p - side * radius)
		_immediate_mesh.surface_add_vertex(p + side * radius)
	_immediate_mesh.surface_end()
