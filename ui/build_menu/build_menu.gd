class_name BuildMenu extends CanvasLayer
## BuildMenu — popup of buildable options. Phase 1 is a vertical button list;
## radial pass lives in Phase 2 polish.
##
## Shown by BuildingSystem on right-click. Emits `buildable_chosen` when the
## player picks one, `cancelled` on Escape / cancel button / outside click.

signal buildable_chosen(buildable: BuildableDefinition)
signal cancelled

const PANEL_WIDTH: float = 220.0
const BUTTON_HEIGHT: float = 30.0

var _panel: PanelContainer
var _vbox: VBoxContainer


func _ready() -> void:
	layer = 60
	_build_ui()
	visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 6)
	margin.add_theme_constant_override("margin_right", 6)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(_vbox)


func show_at(screen_pos: Vector2, buildables: Array[BuildableDefinition]) -> void:
	for child in _vbox.get_children():
		child.queue_free()

	var header := Label.new()
	header.text = "BUILD"
	header.add_theme_font_size_override("font_size", 13)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(header)

	for b in buildables:
		var btn := Button.new()
		btn.text = _format_label(b)
		btn.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
		btn.disabled = not ResourceManager.can_afford(b.costs)
		btn.pressed.connect(_on_choose.bind(b))
		_vbox.add_child(btn)

	var cancel := Button.new()
	cancel.text = "Cancel"
	cancel.custom_minimum_size = Vector2(0, BUTTON_HEIGHT)
	cancel.pressed.connect(_on_cancel)
	_vbox.add_child(cancel)

	var vp: Vector2 = Vector2(get_viewport().get_visible_rect().size)
	_panel.position = Vector2(
		clampf(screen_pos.x, 0, vp.x - PANEL_WIDTH),
		clampf(screen_pos.y, 0, vp.y - 200.0),
	)
	visible = true


func _format_label(b: BuildableDefinition) -> String:
	var parts: Array[String] = []
	for key: String in b.costs.keys():
		parts.append("%d %s" % [int(b.costs[key]), key])
	var cost_str: String = " ".join(parts) if parts.size() > 0 else "free"
	return "%s — %s" % [b.display_name, cost_str]


func _on_choose(b: BuildableDefinition) -> void:
	visible = false
	buildable_chosen.emit(b)


func _on_cancel() -> void:
	visible = false
	cancelled.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()
