class_name RingAvatar extends CharacterBody3D
## RingAvatar — the goblin kid, controlled by the player.
##
## Movement model: horizontal drift on a flat grid. WASD produces target
## velocity; actual velocity lerps toward it so the kid feels weighty but
## responsive. Kid faces movement direction via yaw-lerp. No gravity yet —
## floor tiles are collider-less in Phase 1, so the body rides at spawn Y.
##
## Visuals: a child MeshInstance3D "Body" (Synty kid-goblin, retargeted to
## humanoid rig at FBX import time) plays idle/walk/run from BaseLocomotion.
## A child OmniLight3D "RingGlow" anchors where the tendril will originate
## in M03.
##
## Exposed points for M03+:
##   - tendril_anchor_path — world-space origin of the ring tendril
##   - facing_direction() — current XZ facing as Vector3

@export var move_speed: float = 6.5
@export var accel: float = 18.0
@export var face_turn_rate: float = 10.0

## Optional camera reference so WASD is camera-relative (W = "up on screen"
## regardless of camera yaw). Set by StarterDungeon after spawn.
var _camera_ref: Node3D = null

@onready var _body: Node3D = $Body
@onready var _ring_glow: OmniLight3D = $Body/RingGlow
@onready var _tendril_anchor: Node3D = $Body/TendrilAnchor
@onready var _mesh: Node3D = $Body/Mesh

# Walk / run thresholds (on horizontal speed m/s). Below walk_threshold, idle.
@export var walk_threshold: float = 0.4
@export var run_threshold: float = 4.5

var _anim_player: AnimationPlayer = null
var _current_anim: String = ""

## Face mesh (eyes/brows). The kid body FBX has a bald head; Synty's runtime
## attaches this mesh to the Head bone as a separate draw call.
const KID_FACE_FBX: String = "res://assets/synty/PolygonKids/Models/SM_Chr_Kid_Face_01.fbx"


func _ready() -> void:
	# Resolve the wrapper's AnimationPlayer before attaching the face FBX —
	# the face has its own embedded AP with unrelated "Take 001" tracks, and
	# a recursive search would hit it first once attached.
	_anim_player = _find_wrapper_anim_player()
	_attach_kid_face()


## The Character_Kid_Goblin wrapper declares an AnimationPlayer as a direct
## child alongside the FBX's Skeleton3D. Scope search to direct children so
## BoneAttachment-borne APs (face) don't shadow it.
func _find_wrapper_anim_player() -> AnimationPlayer:
	for c in _mesh.get_children():
		if c is AnimationPlayer:
			return c
	return null


## Attach face mesh to the Head bone via BoneAttachment3D.
func _attach_kid_face() -> void:
	var face_scene: PackedScene = load(KID_FACE_FBX)
	if face_scene == null:
		return
	for sk in _mesh.find_children("*", "Skeleton3D", true, false):
		var s: Skeleton3D = sk
		var head_idx: int = s.find_bone("Head")
		if head_idx < 0:
			continue
		var att: BoneAttachment3D = BoneAttachment3D.new()
		att.name = "FaceAttach"
		att.bone_name = "Head"
		att.bone_idx = head_idx
		s.add_child(att)
		att.add_child(face_scene.instantiate())
		return


func _play_anim(name: String, loop: bool = true) -> void:
	if _anim_player == null or _current_anim == name:
		return
	if not _anim_player.has_animation(name):
		# Fall back to first available animation if the requested one's missing.
		var fallback: String = name
		for known in ["idle", "walk", "run", "unknown"]:
			if _anim_player.has_animation(known):
				fallback = known
				break
		name = fallback
	_current_anim = name
	_anim_player.play(name)
	# LOOP_LINEAR = 1 in Godot 4.
	var anim: Animation = _anim_player.get_animation(name)
	if anim != null:
		anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE


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
	_update_locomotion_anim()


func _update_locomotion_anim() -> void:
	if _anim_player == null:
		return
	var horiz_speed: float = Vector2(velocity.x, velocity.z).length()
	if horiz_speed < walk_threshold:
		_play_anim("idle")
	elif horiz_speed < run_threshold:
		_play_anim("walk")
	else:
		_play_anim("run")


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


## World-space position where the M03 tendril should originate.
func tendril_origin() -> Vector3:
	return _tendril_anchor.global_position if _tendril_anchor != null else global_position


## Current XZ-plane facing unit vector (ignores Y).
func facing_direction() -> Vector3:
	var f: Vector3 = -global_transform.basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.001 else Vector3.FORWARD
