class_name RTSCameraController extends Node3D
## RTSCameraController — iso-ish camera rig for dungeon overview.
##
## Node layout: this Node3D is the pivot; a Camera3D child is offset back
## and pitched. Pan moves the pivot on XZ; rotate yaws the pivot; zoom
## dollies the camera in/out along its local -Z.
##
## Controls (Phase 1):
##   - WASD / arrows → edge-pan at PAN_SPEED
##   - Middle mouse drag → direct pan
##   - Right mouse drag on empty space → yaw rotate
##   - Mouse wheel → zoom (clamped)

@export var pan_speed: float = 14.0
@export var drag_pan_speed: float = 0.04
@export var rotate_speed: float = 0.008
@export var zoom_step: float = 1.2
@export var zoom_min: float = 6.0
@export var zoom_max: float = 40.0
@export var initial_pitch_deg: float = -42.0
@export var initial_zoom: float = 18.0

## Optional follow target. When assigned, the rig's world position lerps
## toward target + follow_offset every frame; WASD + MMB drag modify the
## offset so the player can pan away while the kid keeps moving.
@export var follow_target: Node3D
@export var follow_lerp: float = 8.0

var _camera: Camera3D
var _zoom: float = 0.0
var _panning: bool = false
var _rotating: bool = false
var _follow_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_camera = _find_or_make_camera()
	_zoom = clamp(initial_zoom, zoom_min, zoom_max)
	_apply_camera_transform()


func _find_or_make_camera() -> Camera3D:
	for child in get_children():
		if child is Camera3D:
			return child
	var cam: Camera3D = Camera3D.new()
	cam.name = "Camera3D"
	cam.current = true
	add_child(cam)
	return cam


func _apply_camera_transform() -> void:
	var pitch_rad: float = deg_to_rad(initial_pitch_deg)
	var offset: Vector3 = Vector3(0.0, -sin(pitch_rad), cos(pitch_rad)) * _zoom
	# Note: pitch is applied via camera basis so yaw (on the pivot) stays clean.
	_camera.position = offset
	_camera.rotation = Vector3(pitch_rad, 0.0, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		_handle_mouse_motion(event)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	match event.button_index:
		MOUSE_BUTTON_MIDDLE:
			_panning = event.pressed
		MOUSE_BUTTON_RIGHT:
			_rotating = event.pressed
		MOUSE_BUTTON_WHEEL_UP:
			if event.pressed:
				_zoom = clamp(_zoom - zoom_step, zoom_min, zoom_max)
				_apply_camera_transform()
		MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom = clamp(_zoom + zoom_step, zoom_min, zoom_max)
				_apply_camera_transform()


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _panning:
		var right: Vector3 = global_transform.basis.x
		var forward: Vector3 = -global_transform.basis.z
		forward.y = 0.0
		forward = forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD
		var world_delta: Vector3 = (-right * event.relative.x + forward * event.relative.y) * drag_pan_speed * _zoom * 0.1
		_apply_pan(world_delta)
	if _rotating:
		rotate_y(-event.relative.x * rotate_speed)


func _process(delta: float) -> void:
	# WASD only pans the camera when NOT following a target — when a follow
	# target is set, WASD drives the target (Ring Avatar) instead.
	if follow_target == null:
		var kb_input: Vector3 = Vector3.ZERO
		if Input.is_action_pressed("move_forward"):
			kb_input.z -= 1.0
		if Input.is_action_pressed("move_back"):
			kb_input.z += 1.0
		if Input.is_action_pressed("move_left"):
			kb_input.x -= 1.0
		if Input.is_action_pressed("move_right"):
			kb_input.x += 1.0
		if kb_input.length_squared() > 0.0:
			kb_input = kb_input.normalized()
			var right: Vector3 = global_transform.basis.x
			var forward: Vector3 = -global_transform.basis.z
			forward.y = 0.0
			forward = forward.normalized() if forward.length() > 0.001 else Vector3.FORWARD
			_apply_pan((right * kb_input.x - forward * kb_input.z) * pan_speed * delta)

	if follow_target != null and is_instance_valid(follow_target):
		var desired: Vector3 = follow_target.global_position + _follow_offset
		global_position = global_position.lerp(desired, clampf(follow_lerp * delta, 0.0, 1.0))


## Accumulate a pan delta. When following a target, we store it as an offset
## from the target so the camera keeps the offset even as the target moves.
func _apply_pan(world_delta: Vector3) -> void:
	if follow_target != null:
		_follow_offset += world_delta
	else:
		global_position += world_delta


## Cast a ray from the current cursor through the camera onto the ground plane
## (Y=0) and return the world-space hit. Used by DebugOverlay for tile-under-cursor.
func cursor_world_position() -> Vector3:
	var viewport: Viewport = get_viewport()
	if viewport == null or _camera == null:
		return Vector3.ZERO
	var mouse: Vector2 = viewport.get_mouse_position()
	var origin: Vector3 = _camera.project_ray_origin(mouse)
	var direction: Vector3 = _camera.project_ray_normal(mouse)
	if absf(direction.y) < 0.0001:
		return Vector3.ZERO
	var t: float = -origin.y / direction.y
	if t < 0.0:
		return Vector3.ZERO
	return origin + direction * t
