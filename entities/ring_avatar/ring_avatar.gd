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

@onready var _body: Node3D = $Body
@onready var _ring_glow: OmniLight3D = $Body/RingGlow
@onready var _tendril_anchor: Node3D = $Body/TendrilAnchor
@onready var _tendril: TendrilController = $Tendril

var _bob_phase: float = 0.0
var _body_base_y: float = 0.0


func _ready() -> void:
	_body_base_y = _body.position.y
	if _tendril != null:
		_tendril.anchor_node = _tendril_anchor


## Wire the tendril's cursor source. Called by the scene that owns both the
## Ring Avatar and the RTS camera rig (e.g. StarterDungeon).
func set_cursor_source(cam_rig: Node) -> void:
	if _tendril != null:
		_tendril.cursor_source = cam_rig


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
