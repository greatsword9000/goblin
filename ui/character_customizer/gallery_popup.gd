class_name GalleryPopup extends PopupPanel
## Modal gallery picker for a single slot.
##
## Layout:
##   ┌──────────────────────────────────────────────────┐
##   │ Choose: TORSO          [Hide slot] [Cancel]       │
##   ├─────────────────────────────┬────────────────────┤
##   │  [thumb] [thumb] [thumb]    │                    │
##   │  [thumb] [thumb] [thumb]    │   LIVE 3D PREVIEW  │
##   │  [thumb] [thumb] [thumb]    │   (rotating,       │
##   │  [thumb] [thumb] [thumb]    │    hovered part)   │
##   │                             │                    │
##   └─────────────────────────────┴────────────────────┘
##
## Hybrid strategy:
##   - Grid thumbnails: pre-baked PNGs (cheap, instant, deterministic).
##   - Side preview: live SubViewport with the hovered part's actual mesh,
##     auto-rotating for a turntable view. Single viewport → no stutter.
##   - If no part is hovered, the preview mirrors the currently-equipped pick.

signal part_chosen(slot: String, part_name: String)

const THUMB_DIR := "res://assets/sidekick/goblin_fighters/thumbnails"
const TEX_DIR := "res://assets/sidekick/goblin_fighters/textures"
const COLUMNS := 4
const BUTTON_SIZE := Vector2i(128, 128)
const PREVIEW_SIZE := Vector2i(320, 420)
const ROTATE_SPEED := 0.6  # rad/sec

var _slot: String = ""
var _current_pick: String = ""
var _grid: GridContainer
var _header_label: Label
var _preview_viewport: SubViewport
var _preview_pivot: Node3D
var _preview_name_label: Label
var _preview_meta_label: Label
var _hovered_part: String = ""


func _ready() -> void:
	size = Vector2i(COLUMNS * (BUTTON_SIZE.x + 24) + PREVIEW_SIZE.x + 80, 720)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	# Header
	var header_row := HBoxContainer.new()
	vbox.add_child(header_row)
	_header_label = Label.new()
	_header_label.add_theme_font_size_override("font_size", 20)
	_header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(_header_label)
	var clear_btn := Button.new()
	clear_btn.text = "Hide slot (no part)"
	clear_btn.pressed.connect(_on_clear_pressed)
	header_row.add_child(clear_btn)
	var close_btn := Button.new()
	close_btn.text = "Cancel"
	close_btn.pressed.connect(hide)
	header_row.add_child(close_btn)

	# Body — grid on left, preview on right
	var body := HBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	vbox.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	scroll.add_child(_grid)

	body.add_child(_build_preview_pane())


func _build_preview_pane() -> Control:
	var col := VBoxContainer.new()
	col.custom_minimum_size = Vector2i(PREVIEW_SIZE.x, 0)

	var title := Label.new()
	title.text = "── Live Preview ──"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	var vpc := SubViewportContainer.new()
	vpc.custom_minimum_size = PREVIEW_SIZE
	vpc.stretch = true
	col.add_child(vpc)

	_preview_viewport = SubViewport.new()
	_preview_viewport.size = PREVIEW_SIZE
	_preview_viewport.transparent_bg = false
	_preview_viewport.own_world_3d = true
	_preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_preview_viewport.msaa_3d = Viewport.MSAA_4X
	vpc.add_child(_preview_viewport)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.14, 0.19, 1)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.82, 0.9)
	env.ambient_light_energy = 0.7
	env_node.environment = env
	_preview_viewport.add_child(env_node)

	var key := DirectionalLight3D.new()
	key.transform = Transform3D().rotated(Vector3.RIGHT, deg_to_rad(-30)).rotated(Vector3.UP, deg_to_rad(35))
	key.light_energy = 1.1
	_preview_viewport.add_child(key)

	var cam := Camera3D.new()
	cam.name = "PreviewCam"
	cam.current = true
	cam.position = Vector3(0, 1.0, 2.4)
	cam.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	_preview_viewport.add_child(cam)

	_preview_pivot = Node3D.new()
	_preview_pivot.name = "Pivot"
	_preview_viewport.add_child(_preview_pivot)

	_preview_name_label = Label.new()
	_preview_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_name_label.clip_text = true
	col.add_child(_preview_name_label)

	_preview_meta_label = Label.new()
	_preview_meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_meta_label.add_theme_font_size_override("font_size", 11)
	_preview_meta_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.85))
	col.add_child(_preview_meta_label)
	return col


func _process(delta: float) -> void:
	if _preview_pivot and visible:
		_preview_pivot.rotate_y(ROTATE_SPEED * delta)


func open_for_slot(slot: String, current_part_name: String = "") -> void:
	_slot = slot
	_current_pick = current_part_name
	_header_label.text = "Choose: %s" % slot.to_upper()
	_populate()
	_show_preview(current_part_name)  # start with the currently-equipped pick
	popup_centered()


func _populate() -> void:
	for c in _grid.get_children():
		c.queue_free()

	var lib: Node = get_node_or_null("/root/SidekickPartLibrary")
	if lib == null: return

	for entry in lib.parts_for_slot(_slot):
		var btn := _build_button(entry)
		_grid.add_child(btn)


func _build_button(entry) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = BUTTON_SIZE + Vector2i(0, 30)
	btn.toggle_mode = false
	btn.clip_text = true
	btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	btn.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	btn.expand_icon = true

	var thumb_path: String = "%s/%s.png" % [THUMB_DIR, entry.name]
	if ResourceLoader.exists(thumb_path):
		btn.icon = load(thumb_path)
	elif FileAccess.file_exists(thumb_path):
		var img := Image.new()
		if img.load(ProjectSettings.globalize_path(thumb_path)) == OK:
			btn.icon = ImageTexture.create_from_image(img)

	var tag: String = "v%s%s" % [entry.variant, ("" if entry.is_base else "*")]
	btn.text = "\n%s" % tag
	btn.tooltip_text = "%s\nslot: %s | variant: %s | %s" % [
		entry.name, entry.slot, entry.variant,
		"base species" if entry.is_base else "outfit"
	]

	if entry.name == _current_pick:
		btn.modulate = Color(1.1, 1.1, 0.5)
		btn.add_theme_color_override("font_color", Color.YELLOW)

	btn.pressed.connect(_on_part_pressed.bind(entry.name))
	btn.mouse_entered.connect(_show_preview.bind(entry.name))
	btn.mouse_exited.connect(_on_button_unhover.bind(entry.name))
	return btn


## Loads `part_name` into the live preview viewport. Clears previous preview.
## Empty string = clear to empty pedestal.
func _show_preview(part_name: String) -> void:
	if _preview_pivot == null: return
	_hovered_part = part_name
	# Clear old
	for c in _preview_pivot.get_children():
		c.queue_free()
	if part_name == "":
		_preview_name_label.text = "(no part)"
		_preview_meta_label.text = ""
		return

	var lib: Node = get_node_or_null("/root/SidekickPartLibrary")
	if lib == null: return
	var scene: PackedScene = lib.load_part_scene(_slot, part_name)
	if scene == null:
		_preview_name_label.text = part_name
		_preview_meta_label.text = "(FBX not imported yet)"
		return

	var inst := scene.instantiate()
	_preview_pivot.add_child(inst)
	_apply_preview_texture(inst, part_name)
	_preview_name_label.text = part_name
	var entry = lib.find_part(_slot, part_name)
	if entry:
		_preview_meta_label.text = "variant %s  •  %s" % [
			entry.variant,
			"base species" if entry.is_base else "outfit"
		]


## When the mouse leaves a button, fall back to showing the currently-picked
## part (not empty) so the preview is never blank mid-browse.
func _on_button_unhover(part_name: String) -> void:
	if _hovered_part == part_name:
		_show_preview(_current_pick)


## Same auto-texture logic as SidekickCharacter — color map per (pack, variant).
## Duplicated here because the popup renders in its own World3D (no shared cache).
func _apply_preview_texture(root: Node, part_name: String) -> void:
	var tokens: PackedStringArray = part_name.split("_")
	if tokens.size() < 4: return
	var pack: String = tokens[2]
	var variant: String = tokens[3]
	var tex_name: String = ""
	match pack:
		"BASE": tex_name = "T_GoblinSpecies_%sColorMap.png" % variant
		"FIGT": tex_name = "T_GoblinFighter_%sColorMap.png" % variant
	if tex_name == "": return
	var tex_path: String = "%s/%s" % [TEX_DIR, tex_name]
	if not ResourceLoader.exists(tex_path): return
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load(tex_path)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Apply to every MeshInstance3D descendant, every surface
	_apply_mat_recursive(root, mat)


func _apply_mat_recursive(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n
		if mi.mesh:
			for i in range(mi.mesh.get_surface_count()):
				mi.set_surface_override_material(i, mat)
	for c in n.get_children():
		_apply_mat_recursive(c, mat)


func _on_part_pressed(part_name: String) -> void:
	part_chosen.emit(_slot, part_name)
	hide()


func _on_clear_pressed() -> void:
	part_chosen.emit(_slot, "")
	hide()
