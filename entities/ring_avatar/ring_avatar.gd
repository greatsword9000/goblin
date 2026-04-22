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
@onready var _mesh: Node3D = $Body/Mesh

## Synty Kids-pack prefabs share ONE FBX containing all 100 kid meshes. Each
## prefab should have a ShowOnly node filtering to just its character — but
## the converter missed applying ShowOnly to this pack, so instancing the
## prefab renders every kid stacked at origin. We filter in-code here using
## a substring match so naming variance (Kid_Goblin_01 / Chr_Kid_Goblin / etc.)
## doesn't leave us invisible.
const KID_MESH_SUBSTRING: String = "Goblin"

# Walk / run thresholds (on horizontal speed m/s). Below walk_threshold, idle.
@export var walk_threshold: float = 0.4
@export var run_threshold: float = 4.5

var _bob_phase: float = 0.0
var _body_base_y: float = 0.0

# Resolved at ready. Synty character packs ship with an AnimationPlayer
# configured by the synty-converter that aliases walk/run/idle/attack to the
# Base Locomotion bank. Kid packs get the same treatment.
var _anim_player: AnimationPlayer = null
var _current_anim: String = ""


func _ready() -> void:
	_body_base_y = _body.position.y
	_filter_to_kid_mesh()
	_anim_player = _find_anim_player(self)
	if _anim_player != null:
		_play_anim("idle", true)


func _filter_to_kid_mesh() -> void:
	# Try substring match first; if nothing matches, KEEP the first mesh
	# visible (so the avatar isn't invisible) and print all available names
	# so we can fix the substring next reload.
	var meshes: Array = _mesh.find_children("*", "MeshInstance3D", true, false)
	var matched_count: int = 0
	for mi in meshes:
		var m: MeshInstance3D = mi
		var keep: bool = KID_MESH_SUBSTRING.to_lower() in m.name.to_lower()
		m.visible = keep
		if keep:
			matched_count += 1
	if matched_count == 0 and meshes.size() > 0:
		print("[RingAvatar] no mesh matched '%s' — falling back to first mesh. All names:" % KID_MESH_SUBSTRING)
		for mi in meshes:
			print("  - %s" % (mi as MeshInstance3D).name)
		# Show ONLY the first mesh — better than 100 stacked or 0 visible.
		(meshes[0] as MeshInstance3D).visible = true
	elif matched_count > 1:
		print("[RingAvatar] %d meshes matched '%s' — keeping all. Tighten substring if wrong:" % [matched_count, KID_MESH_SUBSTRING])
		for mi in meshes:
			if (mi as MeshInstance3D).visible:
				print("  - %s" % (mi as MeshInstance3D).name)


func _find_anim_player(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer:
		return root as AnimationPlayer
	for child in root.get_children():
		var found: AnimationPlayer = _find_anim_player(child)
		if found != null:
			return found
	return null


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
	_update_bob(delta)
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
