extends CanvasLayer
## ReadyButton — HUD button that forces an immediate raid when pressed.
##
## Fills Ruckus to 1.0 so the meter visually lands there, then calls
## `RaidDirector.spawn_squad()`. Idempotent while a raid is active
## (disables itself). Re-enables on `raid_defeated`.

const BTN_WIDTH: float = 140.0
const BTN_HEIGHT: float = 36.0
const BOTTOM_MARGIN: float = 32.0

var _button: Button


func _ready() -> void:
	layer = 51
	_build_ui()
	EventBus.raid_spawned.connect(_on_raid_spawned)
	EventBus.raid_defeated.connect(_on_raid_defeated)


func _build_ui() -> void:
	var root: Control = Control.new()
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_bottom = 1.0
	root.anchor_top = 1.0
	root.offset_left = -BTN_WIDTH * 0.5
	root.offset_right = BTN_WIDTH * 0.5
	root.offset_top = -BTN_HEIGHT - BOTTOM_MARGIN
	root.offset_bottom = -BOTTOM_MARGIN
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_button = Button.new()
	_button.text = "READY!"
	_button.anchor_right = 1.0
	_button.anchor_bottom = 1.0
	_button.add_theme_font_size_override("font_size", 14)
	_button.pressed.connect(_on_pressed)
	root.add_child(_button)


func _on_pressed() -> void:
	# Push the meter to 1.0 first so visuals catch up, then trigger. The
	# auto-trigger listener will also fire raid on ruckus_threshold_crossed
	# at 1.0 but RaidDirector guards against double-spawn via _raid_active.
	var needed: float = 1.0 - RuckusManager.value
	if needed > 0.0:
		RuckusManager.add_ruckus(needed, "ready_button")
	RaidDirector.spawn_squad()


func _on_raid_spawned(_squad: Array) -> void:
	_button.disabled = true
	_button.text = "RAID!"


func _on_raid_defeated() -> void:
	_button.disabled = false
	_button.text = "READY!"
