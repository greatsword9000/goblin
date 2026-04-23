extends CanvasLayer
## StockpilePanel — top-right HUD widget showing current resource totals.
##
## Listens: EventBus.resource_gained, resource_spent, resource_hauled_to_throne.
## Shows all tracked resource types; zero-count rows stay visible so the
## player can see "nursery needs 5 copper, I have 0" at a glance.

const RESOURCE_KEYS: Array[String] = ["Resource"]
const DISPLAY_NAMES: Dictionary = {
	"Resource": "Resources",
}
const TOP_MARGIN: float = 18.0
const RIGHT_MARGIN: float = 16.0

var _label: Label


func _ready() -> void:
	layer = 50
	_build_ui()
	EventBus.resource_gained.connect(_on_resource_changed)
	EventBus.resource_spent.connect(_on_resource_changed)
	EventBus.resource_hauled_to_throne.connect(_on_resource_changed)
	_refresh()


func _build_ui() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.offset_top = TOP_MARGIN
	panel.offset_right = -RIGHT_MARGIN
	# Width ~180; panel grows from the right edge leftward.
	panel.offset_left = -196.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = Color(0.10, 0.10, 0.12, 0.85)
	bg.corner_radius_top_left = 4
	bg.corner_radius_top_right = 4
	bg.corner_radius_bottom_left = 4
	bg.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.85))
	margin.add_child(_label)


func _on_resource_changed(_type: String, _amount: int) -> void:
	_refresh()


func _refresh() -> void:
	var lines: Array[String] = []
	for key: String in RESOURCE_KEYS:
		var n: int = ResourceManager.amount(key)
		lines.append("%s: %d" % [String(DISPLAY_NAMES.get(key, key)), n])
	_label.text = "\n".join(lines)
