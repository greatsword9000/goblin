extends CanvasLayer
## RuckusMeter — HUD widget showing current Ruckus level.
##
## Listens: EventBus.ruckus_changed.
## Color tiers: green <0.5, amber <0.9, red ≥0.9.

const WIDTH: float = 280.0
const BAR_HEIGHT: float = 20.0
const TOP_MARGIN: float = 18.0

var _bar: ProgressBar
var _label: Label

var _style_green: StyleBoxFlat
var _style_amber: StyleBoxFlat
var _style_red: StyleBoxFlat


func _ready() -> void:
	layer = 50
	_prepare_styles()
	_build_ui()
	EventBus.ruckus_changed.connect(_on_ruckus_changed)
	_refresh(RuckusManager.value)


func _prepare_styles() -> void:
	_style_green = _fill_style(Color(0.45, 0.85, 0.45))
	_style_amber = _fill_style(Color(0.95, 0.75, 0.35))
	_style_red = _fill_style(Color(0.95, 0.35, 0.35))


func _fill_style(c: Color) -> StyleBoxFlat:
	var s: StyleBoxFlat = StyleBoxFlat.new()
	s.bg_color = c
	s.corner_radius_top_left = 3
	s.corner_radius_top_right = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	return s


func _build_ui() -> void:
	var root: Control = Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.0
	root.offset_left = -WIDTH * 0.5
	root.offset_right = WIDTH * 0.5
	root.offset_top = TOP_MARGIN
	root.offset_bottom = TOP_MARGIN + BAR_HEIGHT + 18.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_label = Label.new()
	_label.text = "RUCKUS"
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.anchor_right = 1.0
	_label.offset_bottom = 16.0
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_label)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.001
	_bar.show_percentage = false
	_bar.anchor_right = 1.0
	_bar.offset_top = 18.0
	_bar.offset_bottom = 18.0 + BAR_HEIGHT
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.12, 0.85)
	bg.corner_radius_top_left = 3
	bg.corner_radius_top_right = 3
	bg.corner_radius_bottom_left = 3
	bg.corner_radius_bottom_right = 3
	_bar.add_theme_stylebox_override("background", bg)
	root.add_child(_bar)


func _on_ruckus_changed(new_value: float, _delta: float, _source: String) -> void:
	_refresh(new_value)


func _refresh(val: float) -> void:
	_bar.value = val
	_bar.add_theme_stylebox_override("fill", _style_for(val))


func _style_for(val: float) -> StyleBoxFlat:
	if val < 0.5:
		return _style_green
	if val < 0.9:
		return _style_amber
	return _style_red
