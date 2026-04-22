class_name EquipmentComponent extends Node
## EquipmentComponent — attaches a prop scene to a humanoid bone at runtime.
##
## Godot's FBX importer + Synty's inline BoneMap retarget Synty characters
## to the standard humanoid rig (`Godot/Humanoid` bone profile). That gives
## us predictable bone names across every Synty humanoid we've imported:
## `RightHand`, `LeftHand`, `Head`, `RightUpperArm`, etc. Reference:
## https://docs.godotengine.org/en/stable/classes/class_skeletonprofilehumanoid.html
##
## Usage on a Minion / RingAvatar / anyone with a Skeleton3D under them:
##   @onready var _equipment := $EquipmentComponent
##   _equipment.equip("main_hand", preload("res://.../pickaxe.tscn"))
##   _equipment.unequip("main_hand")
##
## Each slot is its own BoneAttachment3D so multiple slots don't fight
## (right hand + left hand + head at the same time, etc.).

## Map logical slot names → humanoid bone names. Add more as we need them.
const SLOT_TO_BONE: Dictionary = {
	"main_hand": "RightHand",
	"off_hand": "LeftHand",
	"head": "Head",
	"back": "UpperChest",
}

## Per-slot local transform offset applied to the prop after it's attached.
## Tune these once per slot so every item in the slot sits correctly.
@export var slot_offsets: Dictionary = {
	"main_hand": Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)),
	"off_hand":  Transform3D(Basis(), Vector3(0.0, 0.0, 0.0)),
	"head":      Transform3D(Basis(), Vector3(0.0, 0.1, 0.0)),
	"back":      Transform3D(Basis(), Vector3(0.0, 0.0, -0.15)),
}

var _skeleton: Skeleton3D = null
var _attachments: Dictionary = {}  # slot -> BoneAttachment3D
var _equipped: Dictionary = {}     # slot -> Node3D (prop instance)


func _ready() -> void:
	# Resolve the skeleton lazily on first use — it might not be ready at
	# _ready time if the character prefab instances the FBX after us.
	pass


func _ensure_skeleton() -> bool:
	if _skeleton != null and is_instance_valid(_skeleton):
		return true
	var parent: Node = get_parent()
	if parent == null:
		return false
	_skeleton = _find_skeleton(parent)
	return _skeleton != null


func _find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found: Skeleton3D = _find_skeleton(child)
		if found != null:
			return found
	return null


func _get_or_make_attachment(slot: String) -> BoneAttachment3D:
	if _attachments.has(slot):
		return _attachments[slot]
	if not _ensure_skeleton():
		push_warning("EquipmentComponent: no Skeleton3D under %s" % get_parent().name)
		return null
	var bone_name: String = SLOT_TO_BONE.get(slot, "")
	if bone_name == "":
		push_warning("EquipmentComponent: unknown slot '%s'" % slot)
		return null
	var bone_idx: int = _skeleton.find_bone(bone_name)
	if bone_idx < 0:
		_print_available_bones()
		push_warning("EquipmentComponent: bone '%s' not found on skeleton" % bone_name)
		return null
	var att: BoneAttachment3D = BoneAttachment3D.new()
	att.bone_name = bone_name
	_skeleton.add_child(att)
	_attachments[slot] = att
	return att


## Equip `scene` into `slot`. Replaces anything currently in that slot.
func equip(slot: String, scene: PackedScene) -> void:
	if scene == null:
		return
	var att: BoneAttachment3D = _get_or_make_attachment(slot)
	if att == null:
		return
	unequip(slot)
	var prop: Node = scene.instantiate()
	att.add_child(prop)
	if prop is Node3D:
		(prop as Node3D).transform = slot_offsets.get(slot, Transform3D.IDENTITY)
	_equipped[slot] = prop


func unequip(slot: String) -> void:
	var prop: Node = _equipped.get(slot, null)
	if prop == null:
		return
	prop.queue_free()
	_equipped.erase(slot)


func is_equipped(slot: String) -> bool:
	return _equipped.has(slot)


func _print_available_bones() -> void:
	if _skeleton == null:
		return
	print("[Equipment] Available bones on %s's skeleton:" % get_parent().name)
	for i in range(_skeleton.get_bone_count()):
		print("  - %s" % _skeleton.get_bone_name(i))
