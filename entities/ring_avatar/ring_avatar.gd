class_name RingAvatar extends CharacterBody3D
## RingAvatar — the goblin kid, controlled by the player.
##
## Movement model: floating drift, not grounded. WASD produces target
## velocity; actual velocity lerps toward it so the kid feels weighty but
## responsive. Kid faces movement direction via yaw-lerp.
##
## Visuals: a child MeshInstance3D "Body" (Synty goblin once imported; box
## placeholder otherwise) bobs vertically via sine wave. A child
## OmniLight3D "RingGlow" anchors where the tendril will originate in M03.
##
## Exposed points for M03+:
##   - tendril_anchor_path — world-space origin of the ring tendril
##   - facing_direction() — current XZ facing as Vector3

@export var move_speed: float = 6.5
@export var accel: float = 18.0
@export var face_turn_rate: float = 10.0
@export var bob_frequency: float = 1.6      # Hz
@export var bob_amplitude: float = 0.12     # meters

## Optional camera reference so WASD is camera-relative (W = "up on screen"
## regardless of camera yaw). Set by StarterDungeon after spawn.
var _camera_ref: Node3D = null

@onready var _body: Node3D = $Body
@onready var _ring_glow: OmniLight3D = $Body/RingGlow
@onready var _tendril_anchor: Node3D = $Body/TendrilAnchor

var _bob_phase: float = 0.0
var _body_base_y: float = 0.0


func _ready() -> void:
	_body_base_y = _body.position.y


## Wire the camera reference so WASD is camera-relative. Kept as
## set_cursor_source() for compatibility with the (now disabled) tendril
## wiring path — rename when we revisit the tendril visual.
func set_cursor_source(cam_rig: Node) -> void:
	if cam_rig is Node3D:
		_camera_ref = cam_rig


## World-space origin of the (future) tendril — kept exposed since M05
## pickup/drop will anchor to this point regardless of visual representation.
func ring_hand_position() -> Vector3:
	return _tendril_anchor.global_position if _tendril_anchor != null else global_position


func _physics_process(delta: float) -> void:
	var input_vec: Vector3 = _read_input()
	var target_velocity: Vector3 = input_vec * move_speed
	velocity = velocity.lerp(target_velocity, clampf(accel * delta, 0.0, 1.0))
	move_and_slide()
	_update_facing(input_vec, delta)
	_update_bob(delta)


func _read_input() -> Vector3:
	var v: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		v.z -= 1.0
	if Input.is_action_pressed("move_back"):
		v.z += 1.0
	if Input.is_action_pressed("move_left"):
		v.x -= 1.0
	if Input.is_action_pressed("move_right"):
		v.x += 1.0
	if v.length_squared() > 1.0:
		v = v.normalized()
	# Camera-relative: rotate input by the camera rig's yaw so W is always
	# "up on screen" regardless of how the camera is rotated.
	if _camera_ref != null and v.length_squared() > 0.0001:
		var cam_yaw: float = _camera_ref.global_rotation.y
		v = v.rotated(Vector3.UP, cam_yaw)
	return v


func _update_facing(input_vec: Vector3, delta: float) -> void:
	if input_vec.length_squared() < 0.01:
		return
	var target_yaw: float = atan2(-input_vec.x, -input_vec.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, clampf(face_turn_rate * delta, 0.0, 1.0))


func _update_bob(delta: float) -> void:
	_bob_phase += delta * bob_frequency * TAU
	_body.position.y = _body_base_y + sin(_bob_phase) * bob_amplitude


## World-space position where the M03 tendril should originate.
func tendril_origin() -> Vector3:
	return _tendril_anchor.global_position if _tendril_anchor != null else global_position


## Current XZ-plane facing unit vector (ignores Y).
func facing_direction() -> Vector3:
	var f: Vector3 = -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD
