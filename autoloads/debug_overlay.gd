extends CanvasLayer
## DebugOverlay — backtick toggles live stats panel.
##
## Owns: visibility state, stats label, (future) per-system debug panels.
## Listens to: InputMap action "debug_toggle".
##
## Phase 1: FPS, frame time, mouse viewport position, tile under cursor
## (pulled from GridWorld via whichever scene registers a camera). Expand
## as systems land.

const REFRESH_INTERVAL: float = 0.1

var _panel: PanelContainer
var _label: Label
var _accum: float = 0.0

# Optional camera the overlay queries for cursor→world raycasts. Scenes that
# own a camera (starter_dungeon, tests) call register_camera() on _ready.
var _active_camera: Node = null


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

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	_panel.add_child(margin)

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(0.85, 1.0, 0.85))
	margin.add_child(_label)


## Scenes with an RTS camera register it here so the overlay can cast rays
## for "tile under cursor". Passed as Node (not typed) to avoid circular
## class_name imports; method presence is checked with `has_method`.
func register_camera(camera: Node) -> void:
	_active_camera = camera


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		visible = not visible
		print("[DebugOverlay] toggled → visible=%s" % visible)
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
	var fps: int = Engine.get_frames_per_second()
	var frame_ms: float = 1000.0 / maxf(float(fps), 1.0)
	var mouse_pos: Vector2 = get_viewport().get_mouse_position()
	var lines: Array[String] = [
		"GOBLIN — debug (backtick)",
		"FPS: %d  (%.2f ms)" % [fps, frame_ms],
		"Mouse viewport: (%d, %d)" % [int(mouse_pos.x), int(mouse_pos.y)],
	]
	var cursor_line: String = _cursor_info_line()
	if cursor_line != "":
		lines.append(cursor_line)
	lines.append(_resources_line())
	lines.append(_tasks_line())
	lines.append(_minions_line())
	_label.text = "\n".join(lines)


func _resources_line() -> String:
	var copper: int = ResourceManager.amount("copper")
	var gold: int = ResourceManager.amount("gold")
	return "Stockpile:  copper=%d  gold=%d" % [copper, gold]


func _tasks_line() -> String:
	return "Tasks pending: %d" % TaskQueue.pending_count()


func _minions_line() -> String:
	var nodes: Array = get_tree().get_nodes_in_group("minions")
	var count: int = nodes.size()
	# Fallback: count Minion class instances if group not populated
	if count == 0:
		for n in get_tree().root.get_children():
			count += _count_minions_recursive(n)
	return "Minions: %d" % count


func _count_minions_recursive(n: Node) -> int:
	var c: int = 0
	if n is Minion:
		c += 1
	for child in n.get_children():
		c += _count_minions_recursive(child)
	return c


func _cursor_info_line() -> String:
	if _active_camera == null or not is_instance_valid(_active_camera):
		return ""
	if not _active_camera.has_method("cursor_world_position"):
		return ""
	var world_pos: Vector3 = _active_camera.call("cursor_world_position")
	var grid_pos: Vector3i = GridWorld.tile_at_world(world_pos)
	var tile: TileResource = GridWorld.get_tile(grid_pos)
	var tile_desc: String = tile.id if tile != null else "(empty)"
	return "Cursor world: (%.1f, %.1f, %.1f)  grid: %s  tile: %s" % [
		world_pos.x, world_pos.y, world_pos.z, str(grid_pos), tile_desc,
	]
