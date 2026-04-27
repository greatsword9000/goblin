class_name SpeechBubble extends Node3D
## SpeechBubble — short bark that rises above an entity and fades.
##
## Intentionally distinct from DamageNumber so the player can parse
## "number = hit, text = reaction" at a glance. Smaller, paler, italic.

const LIFETIME: float = 1.4
const RISE_METERS: float = 0.8

@onready var _label: Label3D = $Label3D


static func spawn(world_pos: Vector3, text: String, parent: Node) -> void:
	var scene: PackedScene = load("res://ui/world/speech_bubble.tscn")
	if scene == null:
		return
	var inst: SpeechBubble = scene.instantiate()
	parent.add_child(inst)
	inst.global_position = world_pos
	inst.configure(text)


func configure(text: String) -> void:
	if _label == null:
		return
	_label.text = text
	var start_pos: Vector3 = global_position
	var end_pos: Vector3 = start_pos + Vector3(0.0, RISE_METERS, 0.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", end_pos, LIFETIME)
	tween.tween_property(_label, "modulate:a", 0.0, LIFETIME)
	tween.finished.connect(queue_free)
