extends CanvasLayer
## DebugOverlay — F1 toggles live stats panel.
##
## Owns: visibility state, stats label, (future) per-system debug panels.
## Listens to: InputMap action "debug_toggle".
##
## Phase 1 minimum: FPS, frame time, mouse viewport position. Expand as systems land.

const REFRESH_INTERVAL: float = 0.1

var _panel: PanelContainer
var _label: Label
var _accum: float = 0.0

func _ready() -> void:
	layer = 100
	_build_ui()
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_top = 0.0
	_panel.offset_left = 8.0
	_panel.offset_top = 8.0
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	margin.add_child(_label)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not visible:
		return
	_accum += delta
	if _accum < REFRESH_INTERVAL:
		return
	_accum = 0.0
	_refresh()

func _refresh() -> void:
	var fps := Engine.get_frames_per_second()
	var frame_ms := 1000.0 / max(fps, 1.0)
	var mouse_pos := get_viewport().get_mouse_position()
	var lines := [
		"GOBLIN — debug (F1)",
		"FPS: %d  (%.2f ms)" % [fps, frame_ms],
		"Mouse viewport: (%d, %d)" % [int(mouse_pos.x), int(mouse_pos.y)],
	]
	_label.text = "\n".join(lines)
