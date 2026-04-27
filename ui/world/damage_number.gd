class_name DamageNumber extends Node3D
## DamageNumber — floating Label3D that rises, fades, and despawns.
##
## Spawned by StatsComponent listeners (Minion, Adventurer) on `damaged`.
## Self-cleans via queue_free when the tween finishes. Kept intentionally
## simple — no pooling, no interpolation curves, Phase 1 combat polish.

const LIFETIME: float = 0.9
const RISE_METERS: float = 1.2

@onready var _label: Label3D = $Label3D


## Static factory. Pass text_override to render a bark instead of a number.
static func spawn(world_pos: Vector3, amount: float, color: Color, parent: Node, text_override: String = "") -> void:
	var scene: PackedScene = load("res://ui/world/damage_number.tscn")
	if scene == null:
		return
	var inst: DamageNumber = scene.instantiate()
	parent.add_child(inst)
	inst.global_position = world_pos
	inst.configure(amount, color, text_override)


func configure(amount: float, color: Color, text_override: String = "") -> void:
	if _label == null:
		return
	if text_override != "":
		_label.text = text_override
	else:
		_label.text = "%d" % int(round(amount))
	_label.modulate = color
	var start_pos: Vector3 = global_position
	var end_pos: Vector3 = start_pos + Vector3(0.0, RISE_METERS, 0.0)
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", end_pos, LIFETIME)
	tween.tween_property(_label, "modulate:a", 0.0, LIFETIME)
	tween.finished.connect(queue_free)
