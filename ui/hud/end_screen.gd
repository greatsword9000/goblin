extends CanvasLayer
## EndScreen — "the demo ends here / more tomorrow" fade card.
##
## Fades a black overlay in over FADE_IN_SECONDS, holds the title text,
## then reveals a quit button. Self-contained — instantiated by
## PostRaidController on first raid_defeated.

const FADE_IN_SECONDS: float = 1.5
const HOLD_BEFORE_BUTTON: float = 3.5

var _bg: ColorRect
var _title: Label
var _sub: Label
var _quit: Button


func _ready() -> void:
	layer = 100  # above everything
	_build_ui()
	_run_sequence()


func _build_ui() -> void:
	_bg = ColorRect.new()
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.color = Color(0.0, 0.0, 0.0, 0.0)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bg)

	_title = Label.new()
	_title.text = "the demo ends here"
	_title.add_theme_font_size_override("font_size", 36)
	_title.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85, 0.0))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.anchor_left = 0.0
	_title.anchor_right = 1.0
	_title.anchor_top = 0.35
	_title.anchor_bottom = 0.4
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_sub = Label.new()
	_sub.text = "more tomorrow."
	_sub.add_theme_font_size_override("font_size", 20)
	_sub.add_theme_color_override("font_color", Color(0.75, 0.72, 0.65, 0.0))
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.anchor_top = 0.45
	_sub.anchor_bottom = 0.5
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_sub)

	_quit = Button.new()
	_quit.text = "Quit"
	_quit.anchor_left = 0.5
	_quit.anchor_right = 0.5
	_quit.anchor_top = 0.65
	_quit.anchor_bottom = 0.65
	_quit.offset_left = -60.0
	_quit.offset_right = 60.0
	_quit.offset_top = -18.0
	_quit.offset_bottom = 18.0
	_quit.modulate = Color(1, 1, 1, 0)
	_quit.pressed.connect(func(): get_tree().quit())
	add_child(_quit)


func _run_sequence() -> void:
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_bg, "color:a", 0.95, FADE_IN_SECONDS)
	tween.tween_property(_title, "modulate:a", 1.0, FADE_IN_SECONDS).set_delay(0.3)
	tween.tween_property(_sub, "modulate:a", 1.0, FADE_IN_SECONDS).set_delay(0.9)
	tween.chain().tween_interval(HOLD_BEFORE_BUTTON)
	tween.chain().tween_property(_quit, "modulate:a", 1.0, 0.6)
