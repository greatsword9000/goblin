extends CanvasLayer
## MinionInspector — HUD panel that auto-shows the hovered minion's info.
##
## Polls cursor each frame (cheap — single raycast). When the cursor is
## over a Minion, reveals a bottom-left panel with name, HP bar, state,
## and personality summary. Hides otherwise. No click required.

const RAY_LENGTH: float = 80.0
# Layer 2 = Minions.
const RAY_MASK: int = 2
const PANEL_WIDTH: float = 240.0
const PANEL_HEIGHT: float = 110.0
const MARGIN: float = 16.0

var _panel: PanelContainer
var _name_label: Label
var _hp_bar: ProgressBar
var _state_label: Label
var _personality_label: Label


func _ready() -> void:
	layer = 49  # just under ruckus/ready
	_build_ui()
	_panel.visible = false


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_left = 0.0
	_panel.anchor_bottom = 1.0
	_panel.anchor_top = 1.0
	_panel.offset_left = MARGIN
	_panel.offset_right = MARGIN + PANEL_WIDTH
	_panel.offset_top = -PANEL_HEIGHT - MARGIN
	_panel.offset_bottom = -MARGIN
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	_panel.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 16)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	vbox.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.min_value = 0.0
	_hp_bar.max_value = 1.0
	_hp_bar.step = 0.01
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 12.0)
	vbox.add_child(_hp_bar)

	_state_label = Label.new()
	_state_label.add_theme_font_size_override("font_size", 12)
	_state_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	vbox.add_child(_state_label)

	_personality_label = Label.new()
	_personality_label.add_theme_font_size_override("font_size", 12)
	_personality_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	_personality_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_personality_label.custom_minimum_size = Vector2(PANEL_WIDTH - 24.0, 0.0)
	vbox.add_child(_personality_label)


func _process(_delta: float) -> void:
	var minion: Minion = _minion_under_cursor()
	if minion == null:
		_panel.visible = false
		return
	_panel.visible = true
	_refresh(minion)


func _minion_under_cursor() -> Minion:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		return null
	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	var params := PhysicsRayQueryParameters3D.create(from, from + dir * RAY_LENGTH, RAY_MASK)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(params)
	if hit.is_empty():
		return null
	var collider: Object = hit.get("collider")
	var cursor: Node = collider as Node
	for _i in range(4):
		if cursor == null:
			break
		if cursor is Minion:
			return cursor as Minion
		cursor = cursor.get_parent()
	return null


func _refresh(minion: Minion) -> void:
	_name_label.text = minion.minion_name if minion.minion_name != "" else "Goblin"
	var stats: StatsComponent = minion.get_node_or_null("StatsComponent") as StatsComponent
	if stats != null:
		_hp_bar.value = stats.hp_fraction()
	_state_label.text = "state: %s" % Minion.State.keys()[minion._state]
	var summary: String = "personality: ?"
	if minion.personality != null and minion.personality.profile != null:
		summary = "personality: %s" % minion.personality.profile.summary()
	_personality_label.text = summary
