extends CanvasLayer
## OpeningHint — brief WASD hint that auto-fades after a few seconds.
##
## M14 opening beat — no tutorial, just a one-line nudge on game start.
## Fires on _ready, holds for HOLD_SECONDS, fades over FADE_SECONDS, frees.

const HOLD_SECONDS: float = 3.0
const FADE_SECONDS: float = 1.4

var _label: Label


func _ready() -> void:
	layer = 80
	_build_ui()
	var tween: Tween = create_tween()
	tween.tween_interval(HOLD_SECONDS)
	tween.tween_property(_label, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(queue_free)


func _build_ui() -> void:
	_label = Label.new()
	_label.text = "WASD to move  ·  B build  ·  Space raid"
	_label.add_theme_font_size_override("font_size", 16)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.8))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.anchor_left = 0.5
	_label.anchor_right = 0.5
	_label.anchor_top = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = -260.0
	_label.offset_right = 260.0
	_label.offset_top = -120.0
	_label.offset_bottom = -90.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label)
