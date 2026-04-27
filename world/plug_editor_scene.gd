class_name PlugEditor extends Control
## In-game Plug Creator — hand-author compositions of Synty prefabs that
## procgen samples from. See docs/plug_system_design.md for the full
## design.
##
## Layout: left asset browser (thumbnail cards from AssetTags) ·
## center 3D viewport (subject + cell-boundary box + 3-axis gizmo) ·
## right piece list + inspector · bottom template-meta bar (id, role,
## aesthetic, footprint, orientation, tags, Save/Load/New).
##
## The editor runs in the same binary as the shipping game — previews
## use the exact scene instantiation path the runtime uses, so WYSIWYG.

const CELL_SIZE: float = 2.0   # matches GridWorld.CELL_SIZE
const PLUGS_DIR: String = "res://resources/plugs"
const SNAP_STEP: float = 0.25   # §8 Q2 — 25cm snap, Shift to disable

# ─── Scene refs ───────────────────────────────────────────────────
@onready var _asset_list: ItemList = %AssetList
@onready var _asset_filter_role: OptionButton = %FilterRole
@onready var _asset_filter_aesthetic: OptionButton = %FilterAesthetic
@onready var _asset_filter_shape: OptionButton = %FilterShape
@onready var _asset_search: LineEdit = %AssetSearch
@onready var _category_bar: VBoxContainer = %CategoryBar

@onready var _subject_root: Node3D = %SubjectRoot
@onready var _cell_box: MeshInstance3D = %CellBox
@onready var _facing_arrow: MeshInstance3D = %FacingArrow
# Stamp-mode raycast needs the viewport + camera, so grab them now
# instead of hiding them as "for composition only."
@onready var _plug_viewport: SubViewport = %PlugViewport
@onready var _edit_camera: Camera3D = %EditCamera
# Parent for the container so we can map global mouse → viewport-local.
@onready var _viewport_container: SubViewportContainer = $MainRow/ViewportWrap

@onready var _piece_list: ItemList = %PieceList
@onready var _pos_x: SpinBox = %PosX
@onready var _pos_y: SpinBox = %PosY
@onready var _pos_z: SpinBox = %PosZ
@onready var _rot_y: SpinBox = %RotY
@onready var _scale_u: SpinBox = %ScaleU
@onready var _jitter_rot: SpinBox = %JitterRot
@onready var _jitter_scale: SpinBox = %JitterScale
@onready var _spawn_chance: SpinBox = %SpawnChance
@onready var _mineable_tag: LineEdit = %MineableTag
@onready var _duplicate_btn: Button = %DuplicateBtn
@onready var _delete_btn: Button = %DeleteBtn
@onready var _fit_btn: Button = %FitBtn
@onready var _undo_btn: Button = %UndoBtn
@onready var _snap_btn: Button = %SnapBtn

@onready var _meta_id: LineEdit = %MetaId
@onready var _meta_name: LineEdit = %MetaName
@onready var _meta_role: OptionButton = %MetaRole
@onready var _meta_aesthetic: OptionButton = %MetaAesthetic
@onready var _meta_footprint: OptionButton = %MetaFootprint
@onready var _meta_orientation: OptionButton = %MetaOrientation
@onready var _meta_tags: LineEdit = %MetaTags

@onready var _save_btn: Button = %SaveBtn
@onready var _load_btn: Button = %LoadBtn
@onready var _new_btn: Button = %NewBtn
@onready var _exit_btn: Button = %ExitBtn
@onready var _toast: Label = %Toast

# ─── State ────────────────────────────────────────────────────────

## Piece rows in the right-panel list, parallel to _spawned_nodes.
var _pieces: Array[PlugPiece] = []
## Node3Ds placed in the viewport, parallel to _pieces.
var _spawned_nodes: Array[Node3D] = []

# ─── Hover preview (asset browser tooltip) ───────────────────────
# A floating panel that follows the cursor and shows a larger render
# of whichever asset card is under the mouse. Uses ThumbnailRenderer
# (already disk-cached) so repeated hovers are cheap.
var _hover_panel: PanelContainer = null
var _hover_rect: TextureRect = null
var _hover_label: Label = null
var _last_hover_idx: int = -1

# ─── Undo stack ──────────────────────────────────────────────────
# Each entry is a snapshot of _pieces (deep-copied PlugPiece resources)
# from BEFORE a destructive operation. Restoring pops the top snapshot,
# tears down current nodes, and respawns from the snapshot. Covers
# place / delete / duplicate / fit-to-cell. Spinbox transform edits are
# intentionally NOT tracked (would spam the stack per keystroke).
const UNDO_DEPTH: int = 32
var _undo_stack: Array = []
## True once the current selection's inspector spinboxes have pushed an
## undo snapshot. Prevents stack spam when the user scrubs a spinbox
## (which fires value_changed per tick). Cleared on a new selection,
## an explicit undo, or New Plug — the natural session boundaries.
var _transform_edit_pushed: bool = false
## Currently selected piece index (−1 = none).
var _selected_idx: int = -1
## Filter choices for the asset browser — lazy-initialized from AssetTags.
var _filter_roles: Array[String] = []
var _filter_aesthetics: Array[String] = []
var _filter_shapes: Array[String] = []
## Populated AssetTags query results, in the order shown in _asset_list.
var _browser_hits: Array = []

# Thumbnails load asynchronously — track pending requests to avoid
# re-rendering the same asset while a prior render is in flight.
var _thumb_pending: Dictionary = {}   # asset_path → true

# ─── Human-categorized asset browser (Change C) ──────────────────
# Categories map to AssetTags manifest filters. Click a category button
# and the grid re-queries with that role filter combined with whatever
# aesthetic pill is active. Much more discoverable than the original
# role/aesthetic/shape dropdowns (those still exist, hidden, as an
# "advanced" escape hatch).
const CATEGORIES: Array[Dictionary] = [
	{"name": "All",        "filter": {}},
	{"name": "Floors",     "filter": {"role": "env_floor"}},
	{"name": "Walls",      "filter": {"role": ["env_wall_tile", "env_wall_prop"]}},
	{"name": "Rocks",      "filter": {"role": "env_rock"}},
	{"name": "Structural", "filter": {"role": "env_structural"}},
	{"name": "Props",      "filter": {"role": "prop"}},
	{"name": "Buildings",  "filter": {"role": "building"}},
	{"name": "Decor",      "filter": {"role": "env_other"}},
]
## Aesthetic pills — second-axis filter. "Any" means the category alone
## decides. Values align with the aesthetic tags the classifier writes.
const AESTHETIC_PRESETS: Array[String] = [
	"Any", "cave", "dungeon", "dungeon_realms", "alpine",
	"hell", "crystal", "mushroom", "dwarf",
]
var _active_category_idx: int = 0
var _active_aesthetic_idx: int = 0
var _category_buttons: Array[Button] = []
var _aesthetic_buttons: Array[Button] = []

# ─── Orbit camera (Change A) ──────────────────────────────────────
# Pivot-orbit camera: MMB-drag rotates around pivot, RMB-drag pans
# (moving the pivot), wheel zooms (adjusts distance). Pitch clamped
# to avoid gimbal lock and under-ground views.
var _cam_pivot: Vector3 = Vector3(0, 0.5, 0)
var _cam_yaw: float = deg_to_rad(45.0)
var _cam_pitch: float = deg_to_rad(35.0)
var _cam_distance: float = 7.0
const CAM_PITCH_MIN: float = deg_to_rad(5.0)
const CAM_PITCH_MAX: float = deg_to_rad(85.0)
const CAM_DIST_MIN: float = 1.5
const CAM_DIST_MAX: float = 30.0
const CAM_ORBIT_SENS: float = 0.006
const CAM_PAN_SENS: float = 0.008
const CAM_ZOOM_STEP: float = 1.15   # multiplicative
var _mmb_dragging: bool = false
var _rmb_dragging: bool = false

# ─── Piece drag state ────────────────────────────────────────────
# Set when LMB is pressed on a placed piece. The piece follows the
# cursor on the ground plane until LMB releases. Undo pushes only on
# the first motion so pure click-selects don't pollute the stack.
var _piece_drag_idx: int = -1
var _piece_drag_click_ground: Vector3 = Vector3.ZERO
var _piece_drag_orig_pos: Vector3 = Vector3.ZERO
var _piece_drag_undo_pushed: bool = false

# ─── Empty-state overlay + scale reference (Changes B + E) ────────
var _empty_state_overlay: Control = null
var _empty_state_dismissed: bool = false
var _scale_reference: Node3D = null

# ─── Stamp mode (Change #1: ghost-at-cursor placement) ────────────
# When the user picks an asset from the browser, they enter "stamp
# mode": a semi-transparent ghost of the asset follows the cursor on
# the ground plane. Left-click in the viewport commits — real piece
# is placed at the ghost's position, stamp mode stays active for
# rapid-fire placement. Escape exits stamp mode.
var _stamp_active: bool = false
var _stamp_asset_path: String = ""
var _stamp_ghost: Node3D = null
## Cached intersection point from the last _process() tick — used by
## _commit_stamp() on click so click-placement matches the ghost's
## displayed position exactly (no lag / reprojection surprises).
var _stamp_hit_pos: Vector3 = Vector3.ZERO
var _stamp_hit_valid: bool = false


func _ready() -> void:
	_wire_signals()
	_populate_filter_dropdowns()
	_populate_meta_dropdowns()
	_build_category_bar()
	_refresh_asset_browser()
	_render_cell_box()
	_apply_camera()
	_build_scale_reference()
	_build_empty_state_overlay()
	_build_hover_preview()
	_new_plug()
	_show_toast("MMB: orbit · RMB: pan · scroll: zoom · click asset → click in 3D view to place")


# ─── Category bar (Change C) ─────────────────────────────────────

## Two rows of toggle-like buttons in the left panel:
##   Row 1: category (Floors / Walls / Rocks / …)
##   Row 2: aesthetic (Cave / Dungeon / Alpine / …)
## Built programmatically into the %CategoryBar VBox placeholder.
func _build_category_bar() -> void:
	if _category_bar == null: return

	var cat_label: Label = Label.new()
	cat_label.text = "Category"
	cat_label.add_theme_font_size_override("font_size", 11)
	cat_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1))
	_category_bar.add_child(cat_label)

	var cat_row: HFlowContainer = HFlowContainer.new()
	_category_bar.add_child(cat_row)
	for i in range(CATEGORIES.size()):
		var cat: Dictionary = CATEGORIES[i]
		var b: Button = Button.new()
		b.text = cat.name
		b.toggle_mode = true
		b.button_pressed = (i == 0)
		b.custom_minimum_size = Vector2(0, 26)
		var idx := i
		b.pressed.connect(func(): _on_category_selected(idx))
		cat_row.add_child(b)
		_category_buttons.append(b)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	_category_bar.add_child(gap)

	var aes_label: Label = Label.new()
	aes_label.text = "Aesthetic"
	aes_label.add_theme_font_size_override("font_size", 11)
	aes_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7, 1))
	_category_bar.add_child(aes_label)

	var aes_row: HFlowContainer = HFlowContainer.new()
	_category_bar.add_child(aes_row)
	for i in range(AESTHETIC_PRESETS.size()):
		var b: Button = Button.new()
		b.text = AESTHETIC_PRESETS[i].capitalize()
		b.toggle_mode = true
		b.button_pressed = (i == 0)
		b.custom_minimum_size = Vector2(0, 24)
		var idx := i
		b.pressed.connect(func(): _on_aesthetic_selected(idx))
		aes_row.add_child(b)
		_aesthetic_buttons.append(b)


func _on_category_selected(idx: int) -> void:
	_active_category_idx = idx
	for i in range(_category_buttons.size()):
		_category_buttons[i].button_pressed = (i == idx)
	_refresh_asset_browser()


func _on_aesthetic_selected(idx: int) -> void:
	_active_aesthetic_idx = idx
	for i in range(_aesthetic_buttons.size()):
		_aesthetic_buttons[i].button_pressed = (i == idx)
	_refresh_asset_browser()


# ─── Camera ───────────────────────────────────────────────────────

func _apply_camera() -> void:
	if _edit_camera == null:
		return
	var offset: Vector3 = Vector3(
		_cam_distance * cos(_cam_pitch) * cos(_cam_yaw),
		_cam_distance * sin(_cam_pitch),
		_cam_distance * cos(_cam_pitch) * sin(_cam_yaw),
	)
	_edit_camera.global_position = _cam_pivot + offset
	_edit_camera.look_at(_cam_pivot, Vector3.UP)


func _cam_orbit(rel: Vector2) -> void:
	_cam_yaw += rel.x * CAM_ORBIT_SENS
	_cam_pitch = clamp(_cam_pitch + rel.y * CAM_ORBIT_SENS, CAM_PITCH_MIN, CAM_PITCH_MAX)
	_apply_camera()


func _cam_pan(rel: Vector2) -> void:
	if _edit_camera == null: return
	# Move pivot along camera-local right (+X) and up (+Y) axes.
	var basis: Basis = _edit_camera.global_transform.basis
	var scale_per_pixel: float = _cam_distance * CAM_PAN_SENS
	_cam_pivot += -basis.x * rel.x * scale_per_pixel
	_cam_pivot += basis.y * rel.y * scale_per_pixel
	_apply_camera()


func _cam_zoom(steps: float) -> void:
	# Positive steps zoom IN (shrink distance). Multiplicative to feel
	# consistent across near/far ranges.
	_cam_distance = clamp(_cam_distance / pow(CAM_ZOOM_STEP, steps), CAM_DIST_MIN, CAM_DIST_MAX)
	_apply_camera()


# ─── Scale reference (a ghost kid silhouette) ─────────────────────

## A faintly-visible capsule roughly kid-sized (1.1m tall, 0.3m radius)
## placed at the edge of the cell so the author has a size anchor. Toggle
## visibility with the `K` key. Doesn't emit collision — pure decor.
func _build_scale_reference() -> void:
	_scale_reference = Node3D.new()
	_scale_reference.name = "ScaleReference"
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cap: CapsuleMesh = CapsuleMesh.new()
	cap.radius = 0.30
	cap.height = 1.20
	mi.mesh = cap
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.9, 0.5, 0.35)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = mat
	# Stand outside the 1×1 cell (to the left-front) so it doesn't clip
	# against placed pieces but is always visible for proportion check.
	_scale_reference.add_child(mi)
	mi.position.y = 0.6  # capsule center at half-height above ground
	_scale_reference.position = Vector3(-1.6, 0.0, 1.6)
	_plug_viewport.add_child(_scale_reference)


# ─── Empty-state help overlay ─────────────────────────────────────

## First-run / blank-canvas helper. Shown while `_pieces.is_empty()`;
## hides on first placement. A single `PanelContainer` over the
## viewport with numbered steps. Escape doesn't hide it — placement
## does, so the user always sees the instructions until they act.
func _build_empty_state_overlay() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "EmptyStateOverlay"
	# STOP so clicks on the popup don't fall through to the viewport
	# (previous IGNORE caused rogue stamp commits when the overlay
	# happened to overlap the viewport area).
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.88)
	style.border_color = Color(0.35, 0.55, 0.85, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = 20
	style.content_margin_top = 16
	style.content_margin_right = 20
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	# Header row: title + × close button (right-aligned).
	var header: HBoxContainer = HBoxContainer.new()
	box.add_child(header)

	var title: Label = Label.new()
	title.text = "Build a plug"
	title.add_theme_font_size_override("font_size", 20)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var close_btn: Button = Button.new()
	close_btn.text = "×"
	close_btn.flat = true
	close_btn.custom_minimum_size = Vector2(28, 28)
	close_btn.add_theme_font_size_override("font_size", 22)
	close_btn.tooltip_text = "Dismiss (won't show again this session)"
	close_btn.pressed.connect(_on_empty_state_dismissed)
	header.add_child(close_btn)

	var sub: Label = Label.new()
	sub.text = "A plug is a hand-authored arrangement of pieces that procgen will stamp into the world."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(420, 0)
	sub.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82, 1))
	box.add_child(sub)

	var gap: Control = Control.new()
	gap.custom_minimum_size = Vector2(0, 8)
	box.add_child(gap)

	for step in [
		"1 · Middle-mouse drag to look around, scroll to zoom.",
		"2 · Pick a piece from the [b]Asset Browser[/b] on the left.",
		"3 · Click in the 3D view to place it. The green ghost shows where it'll land.",
		"4 · Repeat. When it looks right, fill in [b]id / name[/b] below and press [b]Save[/b].",
	]:
		var l: RichTextLabel = RichTextLabel.new()
		l.bbcode_enabled = true
		l.fit_content = true
		l.scroll_active = false
		l.custom_minimum_size = Vector2(420, 0)
		l.text = step
		box.add_child(l)

	panel.anchor_left = 0.5
	panel.anchor_top = 0.15
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.15
	panel.offset_left = -240
	panel.offset_right = 240
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(panel)
	_empty_state_overlay = panel
	_empty_state_overlay.visible = true


func _build_hover_preview() -> void:
	var panel: PanelContainer = PanelContainer.new()
	panel.name = "HoverPreview"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.1, 0.14, 0.96)
	style.border_color = Color(0.4, 0.6, 0.9, 1)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 6
	style.content_margin_top = 6
	style.content_margin_right = 6
	style.content_margin_bottom = 6
	panel.add_theme_stylebox_override("panel", style)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	_hover_rect = TextureRect.new()
	_hover_rect.custom_minimum_size = Vector2(192, 192)
	_hover_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_hover_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(_hover_rect)

	_hover_label = Label.new()
	_hover_label.custom_minimum_size = Vector2(192, 0)
	_hover_label.add_theme_font_size_override("font_size", 11)
	_hover_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85, 1))
	_hover_label.clip_text = true
	box.add_child(_hover_label)

	add_child(panel)
	_hover_panel = panel


## Async thumbnail load for the hover preview. Matches the pattern used
## by the asset-list icon loader (_request_thumbnail) — render_async
## yields a frame so the SubViewport actually composites before we read
## the texture. Guards against the user moving to a different item mid-
## await so we don't clobber the panel with a stale texture.
func _load_hover_thumb(path: String, idx_at_request: int) -> void:
	var tex: Texture2D = await ThumbnailRenderer.render_async(path)
	if tex == null:
		return
	if _last_hover_idx == idx_at_request and _hover_rect != null:
		_hover_rect.texture = tex


## Called every frame from _process. Detects which asset card the mouse
## is currently over, renders its thumbnail (disk-cached) on item change,
## and positions the panel to the right of the cursor — flipping to the
## left edge if it would overflow the window.
func _update_hover_preview() -> void:
	if _hover_panel == null or _asset_list == null:
		return
	var mouse_global: Vector2 = get_viewport().get_mouse_position()
	var list_rect: Rect2 = _asset_list.get_global_rect()
	if not list_rect.has_point(mouse_global):
		if _hover_panel.visible:
			_hover_panel.visible = false
			_last_hover_idx = -1
		return
	var local: Vector2 = mouse_global - list_rect.position
	var idx: int = _asset_list.get_item_at_position(local, true)
	if idx < 0 or idx >= _browser_hits.size():
		if _hover_panel.visible:
			_hover_panel.visible = false
			_last_hover_idx = -1
		return
	if idx != _last_hover_idx:
		_last_hover_idx = idx
		var path: String = String(_browser_hits[idx].path)
		_hover_label.text = path.get_file().get_basename()
		_hover_rect.texture = null   # clear stale image while the new one loads
		_load_hover_thumb(path, idx)
	# Place to the right of cursor; flip left if it would clip; clamp Y.
	var window_size: Vector2 = get_viewport().get_visible_rect().size
	var panel_size: Vector2 = _hover_panel.size
	var pos: Vector2 = mouse_global + Vector2(20, 0)
	if pos.x + panel_size.x > window_size.x:
		pos.x = mouse_global.x - panel_size.x - 20
	pos.y = clampf(pos.y, 0.0, maxf(0.0, window_size.y - panel_size.y))
	_hover_panel.position = pos
	_hover_panel.visible = true


func _update_empty_state_visibility() -> void:
	if _empty_state_overlay == null: return
	if _empty_state_dismissed:
		_empty_state_overlay.visible = false
		return
	_empty_state_overlay.visible = _pieces.is_empty()


func _on_empty_state_dismissed() -> void:
	_empty_state_dismissed = true
	if _empty_state_overlay != null:
		_empty_state_overlay.visible = false


# ─── Init plumbing ────────────────────────────────────────────────

func _wire_signals() -> void:
	_asset_list.item_activated.connect(_on_asset_activated)
	_asset_list.item_clicked.connect(_on_asset_clicked)
	_asset_filter_role.item_selected.connect(func(_i): _refresh_asset_browser())
	_asset_filter_aesthetic.item_selected.connect(func(_i): _refresh_asset_browser())
	_asset_filter_shape.item_selected.connect(func(_i): _refresh_asset_browser())
	_asset_search.text_changed.connect(func(_t): _refresh_asset_browser())

	_piece_list.item_selected.connect(_on_piece_selected)
	_duplicate_btn.pressed.connect(_on_duplicate_piece)
	_delete_btn.pressed.connect(_on_delete_piece)
	_fit_btn.pressed.connect(_on_fit_to_cell)
	_undo_btn.pressed.connect(_on_undo)
	_snap_btn.pressed.connect(_on_snap_to_neighbor)

	_pos_x.value_changed.connect(func(_v): _sync_selected_from_inspector())
	_pos_y.value_changed.connect(func(_v): _sync_selected_from_inspector())
	_pos_z.value_changed.connect(func(_v): _sync_selected_from_inspector())
	_rot_y.value_changed.connect(func(_v): _sync_selected_from_inspector())
	_scale_u.value_changed.connect(func(_v): _sync_selected_from_inspector())
	_jitter_rot.value_changed.connect(func(_v): _sync_selected_from_inspector())
	_jitter_scale.value_changed.connect(func(_v): _sync_selected_from_inspector())
	_spawn_chance.value_changed.connect(func(_v): _sync_selected_from_inspector())
	_mineable_tag.text_changed.connect(func(_t): _sync_selected_from_inspector())

	_meta_footprint.item_selected.connect(func(_i): _render_cell_box())
	_meta_orientation.item_selected.connect(func(_i): _render_facing_arrow())

	_save_btn.pressed.connect(_on_save)
	_load_btn.pressed.connect(_on_load)
	_new_btn.pressed.connect(_new_plug)
	_exit_btn.pressed.connect(_on_exit)


func _populate_filter_dropdowns() -> void:
	# Harvest distinct values from the AssetTags index so filters are
	# self-configuring as new packs land.
	var roles: Dictionary = {}
	var aesthetics: Dictionary = {}
	var shapes: Dictionary = {}
	for t in AssetTags._all_tags:
		roles[t.get("role", "")] = true
		aesthetics[t.get("aesthetic", "")] = true
		shapes[t.get("shape", "")] = true
	_filter_roles = _build_filter_list(roles)
	_filter_aesthetics = _build_filter_list(aesthetics)
	_filter_shapes = _build_filter_list(shapes)
	_fill_option(_asset_filter_role, _filter_roles)
	_fill_option(_asset_filter_aesthetic, _filter_aesthetics)
	_fill_option(_asset_filter_shape, _filter_shapes)


func _populate_meta_dropdowns() -> void:
	# Roles: standard procgen buckets plus "(custom)" via free-form tags.
	_fill_option(_meta_role, [
		"env_floor", "env_wall_straight", "env_wall_corner",
		"env_ceiling", "decor_cluster", "env_floor_accent",
	])
	_fill_option(_meta_aesthetic, _filter_aesthetics.slice(1))  # drop "(any)"
	_fill_option(_meta_footprint, ["1x1", "2x1", "1x2", "2x2", "3x1", "3x3"])
	_fill_option(_meta_orientation, ["omni", "facing", "corner"])


static func _fill_option(opt: OptionButton, values: Array) -> void:
	opt.clear()
	for v in values:
		opt.add_item(str(v))


static func _safe_get(arr: Array[String], idx: int, fallback: String) -> String:
	if idx < 0 or idx >= arr.size(): return fallback
	return arr[idx]


static func _build_filter_list(source: Dictionary) -> Array[String]:
	var out: Array[String] = ["(any)"]
	var keys: Array = source.keys()
	keys.sort()
	for k in keys:
		if k != "": out.append(str(k))
	return out


# ─── Asset browser ────────────────────────────────────────────────

func _refresh_asset_browser() -> void:
	# Merge three filter sources: (1) active category button, (2) active
	# aesthetic pill, (3) the legacy shape dropdown if someone enabled
	# the advanced escape hatch. Category filter wins on `role` conflict.
	var filters: Dictionary = {}
	var cat: Dictionary = CATEGORIES[_active_category_idx]
	for k in (cat.filter as Dictionary):
		filters[k] = (cat.filter as Dictionary)[k]
	var aes_key: String = AESTHETIC_PRESETS[_active_aesthetic_idx]
	if aes_key != "Any":
		filters["aesthetic"] = aes_key
	# Advanced dropdowns (hidden by default, power user escape hatch).
	if _asset_filter_shape != null and _asset_filter_shape.visible:
		var shape: String = _safe_get(_filter_shapes, _asset_filter_shape.selected, "(any)")
		if shape != "(any)": filters["shape"] = shape
	var search: String = _asset_search.text.strip_edges().to_lower()

	_browser_hits = AssetTags.query(filters)
	if search != "":
		_browser_hits = _browser_hits.filter(func(t): return search in String(t.path).to_lower())
	if _browser_hits.size() > 200:
		_browser_hits = _browser_hits.slice(0, 200)

	_asset_list.clear()
	for hit in _browser_hits:
		# Single-line label — was "name\nrole · WxHxD", which wrapped
		# ugly at narrow widths and was mostly redundant. Tooltip shows
		# the full details on hover instead.
		var fname: String = String(hit.path).get_file().get_basename()
		var short: String = fname
		if short.length() > 22:
			short = short.substr(0, 20) + "…"
		var idx: int = _asset_list.add_item(short)
		var size_m: Array = hit.get("size_m", [0, 0, 0])
		_asset_list.set_item_tooltip(idx, "%s\n%s · %s\n%.2f × %.2f × %.2f m" % [
			fname, hit.get("role", "?"), hit.get("aesthetic", "?"),
			size_m[0], size_m[1], size_m[2],
		])
		_request_thumbnail(hit.path, idx)


func _request_thumbnail(asset_path: String, list_idx: int) -> void:
	if _thumb_pending.has(asset_path):
		return
	_thumb_pending[asset_path] = true
	var tex: Texture2D = await ThumbnailRenderer.render_async(asset_path)
	_thumb_pending.erase(asset_path)
	if tex == null:
		return   # headless / render-failure — leave the card with no icon
	# Item may have been cleared by a filter change — check index still
	# maps to this path before assigning.
	if list_idx < _asset_list.item_count:
		var expected_fname: String = asset_path.get_file().get_basename()
		var current_label: String = _asset_list.get_item_text(list_idx)
		if expected_fname in current_label:
			_asset_list.set_item_icon(list_idx, tex)


func _on_asset_activated(idx: int) -> void:
	# Double-click or single-click: enter stamp mode with this asset.
	# A ghost follows the cursor until you click the viewport to commit
	# or press Escape to cancel.
	_enter_stamp_mode(_browser_hits[idx].path)


func _on_asset_clicked(idx: int, _pos: Vector2, button: int) -> void:
	if button == MOUSE_BUTTON_LEFT or button == MOUSE_BUTTON_RIGHT:
		_enter_stamp_mode(_browser_hits[idx].path)


# ─── Stamp mode ───────────────────────────────────────────────────

func _enter_stamp_mode(asset_path: String) -> void:
	_exit_stamp_mode()   # clean up any previous ghost
	_stamp_active = true
	_stamp_asset_path = asset_path
	_stamp_ghost = _build_ghost(asset_path)
	if _stamp_ghost != null:
		_plug_viewport.add_child(_stamp_ghost)
	_show_toast("Stamp: %s · click viewport to place · Esc to cancel" % asset_path.get_file().get_basename())


func _exit_stamp_mode() -> void:
	_stamp_active = false
	_stamp_asset_path = ""
	_stamp_hit_valid = false
	if _stamp_ghost != null:
		_stamp_ghost.queue_free()
		_stamp_ghost = null


## Spawns a visually-distinct preview instance: recursively overrides
## every MeshInstance3D material with a semi-transparent teal so the
## ghost reads as "not yet placed" without touching the real asset.
func _build_ghost(asset_path: String) -> Node3D:
	if not ResourceLoader.exists(asset_path):
		return null
	var scene: PackedScene = load(asset_path)
	if scene == null:
		return null
	var inst: Node = scene.instantiate()
	if not (inst is Node3D):
		inst.queue_free()
		return null
	var root: Node3D = inst
	var ghost_mat: StandardMaterial3D = StandardMaterial3D.new()
	ghost_mat.albedo_color = Color(0.4, 0.85, 0.95, 0.45)
	ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	# material_overlay draws a translucent layer on top of whatever the
	# prefab's own materials do — keeps the silhouette but flags "ghost".
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = ghost_mat
	# Disable collisions so the ghost doesn't block clicks / raycasts.
	for body in root.find_children("*", "CollisionObject3D", true, false):
		(body as CollisionObject3D).collision_layer = 0
		(body as CollisionObject3D).collision_mask = 0
	return root


func _process(_delta: float) -> void:
	# Hover preview runs every frame regardless of stamp state so users
	# can browse asset thumbnails while mid-stamp.
	_update_hover_preview()
	if not _stamp_active or _stamp_ghost == null:
		return
	var hit: Variant = _raycast_ground_from_mouse()
	if hit == null:
		_stamp_hit_valid = false
		_stamp_ghost.visible = false
		return
	_stamp_hit_valid = true
	_stamp_ghost.visible = true
	var pos: Vector3 = _snap(hit as Vector3)
	_stamp_hit_pos = pos
	_stamp_ghost.position = pos


## Returns the ground-plane (y=0) intersection point for the current
## mouse position, or null if the cursor isn't over the viewport or
## the ray doesn't hit the plane (looking up at the sky, etc.).
func _raycast_ground_from_mouse() -> Variant:
	if _viewport_container == null or _edit_camera == null:
		return null
	var global_mouse: Vector2 = get_viewport().get_mouse_position()
	var container_rect: Rect2 = _viewport_container.get_global_rect()
	if not container_rect.has_point(global_mouse):
		return null
	# Map the mouse position from global → container-local → viewport-local.
	var local_mouse: Vector2 = global_mouse - container_rect.position
	# When the container `stretch=true`, the SubViewport's size may
	# differ from the container; scale accordingly.
	var vp_size: Vector2 = Vector2(_plug_viewport.size)
	if container_rect.size.x > 0 and container_rect.size.y > 0:
		local_mouse.x *= vp_size.x / container_rect.size.x
		local_mouse.y *= vp_size.y / container_rect.size.y
	var origin: Vector3 = _edit_camera.project_ray_origin(local_mouse)
	var dir: Vector3 = _edit_camera.project_ray_normal(local_mouse)
	var ground: Plane = Plane(Vector3.UP, 0.0)
	var hit: Variant = ground.intersects_ray(origin, dir)
	return hit   # Vector3 or null


## Physics raycast into the plug viewport from the current mouse position.
## Returns the dictionary from PhysicsDirectSpaceState3D.intersect_ray()
## (has `collider`, `position`, `normal`), or {} on miss.
## Used by click-to-select to find which placed piece the user clicked.
func _raycast_physics_from_mouse() -> Dictionary:
	if _viewport_container == null or _edit_camera == null or _plug_viewport == null:
		return {}
	var global_mouse: Vector2 = get_viewport().get_mouse_position()
	var container_rect: Rect2 = _viewport_container.get_global_rect()
	if not container_rect.has_point(global_mouse):
		return {}
	var local_mouse: Vector2 = global_mouse - container_rect.position
	var vp_size: Vector2 = Vector2(_plug_viewport.size)
	if container_rect.size.x > 0 and container_rect.size.y > 0:
		local_mouse.x *= vp_size.x / container_rect.size.x
		local_mouse.y *= vp_size.y / container_rect.size.y
	var origin: Vector3 = _edit_camera.project_ray_origin(local_mouse)
	var dir: Vector3 = _edit_camera.project_ray_normal(local_mouse)
	# Use get_world_3d() on the camera (traverses to the effective world)
	# instead of _plug_viewport.world_3d (the property, which is null when
	# use_own_world_3d = false). Matches the pattern used elsewhere in
	# the project (hover_highlighter, pickup_system, mining_system).
	var world: World3D = _edit_camera.get_world_3d()
	if world == null:
		return {}
	var params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin, origin + dir * 200.0)
	params.collide_with_areas = false
	return world.direct_space_state.intersect_ray(params)


## Walk the node tree upward from a physics-hit collider to find which
## placed piece (if any) owns it. Returns the index in _pieces or -1.
func _piece_index_from_hit(collider: Object) -> int:
	var n: Node = collider as Node
	while n != null:
		var idx: int = _spawned_nodes.find(n)
		if idx >= 0:
			return idx
		n = n.get_parent()
	return -1


func _commit_stamp() -> void:
	if not _stamp_active or not _stamp_hit_valid:
		return
	var pos: Vector3 = _stamp_hit_pos
	var path: String = _stamp_asset_path
	_place_asset(path, pos)
	# Stay in stamp mode with the same asset — rapid-fire placement.
	# Escape exits.


# ─── Piece management ─────────────────────────────────────────────

func _place_asset(asset_path: String, at_pos: Vector3) -> void:
	_push_undo()
	var piece: PlugPiece = PlugPiece.new()
	piece.prefab_path = asset_path
	piece.position = _snap(at_pos)
	_pieces.append(piece)
	var node: Node3D = _spawn_piece_node(piece)
	_spawned_nodes.append(node)
	_rebuild_piece_list()
	_select_piece(_pieces.size() - 1)
	_update_empty_state_visibility()
	_show_toast("Placed %s" % asset_path.get_file().get_basename())


func _spawn_piece_node(piece: PlugPiece) -> Node3D:
	var scene: PackedScene = piece.load_prefab()
	if scene == null:
		push_warning("Missing prefab: %s" % piece.prefab_path)
		return null
	var inst: Node = scene.instantiate()
	if not (inst is Node3D):
		inst.queue_free()
		return null
	var n: Node3D = inst
	n.transform = piece.build_transform()
	_subject_root.add_child(n)
	return n


func _rebuild_piece_list() -> void:
	_piece_list.clear()
	for i in range(_pieces.size()):
		var p: PlugPiece = _pieces[i]
		var label: String = "%s" % p.prefab_path.get_file().get_basename()
		if p.spawn_chance < 1.0:
			label += "  · chance %.2f" % p.spawn_chance
		if p.mineable_tag != "":
			label += "  · %s" % p.mineable_tag
		_piece_list.add_item(label)


func _select_piece(idx: int) -> void:
	# Changing selection ends the prior transform edit session: the next
	# inspector tweak on a different piece deserves its own undo snapshot.
	_transform_edit_pushed = false
	_selected_idx = idx
	if idx < 0 or idx >= _pieces.size():
		_clear_inspector()
		return
	_piece_list.select(idx)
	_push_inspector_from(_pieces[idx])


func _on_piece_selected(idx: int) -> void:
	_select_piece(idx)


func _push_inspector_from(p: PlugPiece) -> void:
	_pos_x.set_value_no_signal(p.position.x)
	_pos_y.set_value_no_signal(p.position.y)
	_pos_z.set_value_no_signal(p.position.z)
	_rot_y.set_value_no_signal(p.rotation_deg.y)
	_scale_u.set_value_no_signal(p.scale.x)   # uniform for MVP
	_jitter_rot.set_value_no_signal(p.jitter_rotation_deg)
	_jitter_scale.set_value_no_signal(p.jitter_scale)
	_spawn_chance.set_value_no_signal(p.spawn_chance)
	_mineable_tag.text = p.mineable_tag


func _clear_inspector() -> void:
	for sb in [_pos_x, _pos_y, _pos_z, _rot_y, _scale_u, _jitter_rot, _jitter_scale, _spawn_chance]:
		sb.set_value_no_signal(0.0)
	_mineable_tag.text = ""


func _sync_selected_from_inspector() -> void:
	if _selected_idx < 0 or _selected_idx >= _pieces.size(): return
	# Push one undo snapshot per edit session. A session starts on the
	# first spinbox change after a new selection and ends on selection
	# change / undo / New Plug (where the flag is reset). Keeps the
	# stack usable even when the user rapid-scrubs a slider.
	if not _transform_edit_pushed:
		_push_undo()
		_transform_edit_pushed = true
	var p: PlugPiece = _pieces[_selected_idx]
	p.position = Vector3(_pos_x.value, _pos_y.value, _pos_z.value)
	p.rotation_deg = Vector3(0, _rot_y.value, 0)
	p.scale = Vector3.ONE * _scale_u.value
	p.jitter_rotation_deg = _jitter_rot.value
	p.jitter_scale = _jitter_scale.value
	p.spawn_chance = _spawn_chance.value
	p.mineable_tag = _mineable_tag.text
	# Re-apply transform to the live node.
	var n: Node3D = _spawned_nodes[_selected_idx]
	if n != null:
		n.transform = p.build_transform()
	# Refresh list row label (mineable tag / spawn chance shown there).
	if _selected_idx < _piece_list.item_count:
		_piece_list.set_item_text(_selected_idx, _label_for_piece(p))


func _label_for_piece(p: PlugPiece) -> String:
	var label: String = p.prefab_path.get_file().get_basename()
	if p.spawn_chance < 1.0:
		label += "  · chance %.2f" % p.spawn_chance
	if p.mineable_tag != "":
		label += "  · %s" % p.mineable_tag
	return label


## Multiplicative per-tick scale of the selected piece. Binds to
## Shift+wheel / Cmd+wheel. 1.1× per tick for smooth reversibility.
## Clamped to the ScaleU spinbox range. Updates the live node in place
## instead of respawning (wheel ticks fire rapidly).
const WHEEL_SCALE_STEP: float = 1.1

## Nudge the selected piece by (dx, 0, dz). Reuses the transform-edit
## session flag so a rapid burst of arrow-key taps lands as ONE undo
## step (press Ctrl+Z once to revert the entire nudge session).
func _nudge_selected(dx: float, dz: float) -> void:
	if _selected_idx < 0 or _selected_idx >= _pieces.size(): return
	if not _transform_edit_pushed:
		_push_undo()
		_transform_edit_pushed = true
	var p: PlugPiece = _pieces[_selected_idx]
	p.position += Vector3(dx, 0.0, dz)
	_pos_x.set_value_no_signal(p.position.x)
	_pos_z.set_value_no_signal(p.position.z)
	var n: Node3D = _spawned_nodes[_selected_idx]
	if n != null:
		n.transform = p.build_transform()


## Rotate the selected piece around Y by `step_deg`. Called from the R
## key (+90°) and Shift+R (-90°). Pushes one undo snapshot per rotation
## so each keypress is individually undoable.
func _rotate_selected_yaw(step_deg: float) -> void:
	if _selected_idx < 0 or _selected_idx >= _pieces.size(): return
	_push_undo()
	var p: PlugPiece = _pieces[_selected_idx]
	var new_y: float = fposmod(p.rotation_deg.y + step_deg, 360.0)
	p.rotation_deg = Vector3(p.rotation_deg.x, new_y, p.rotation_deg.z)
	_rot_y.set_value_no_signal(new_y)
	var n: Node3D = _spawned_nodes[_selected_idx]
	if n != null:
		n.transform = p.build_transform()
	_show_toast("Rotated to %.0f°" % new_y)


func _wheel_scale_selected(dir: float) -> void:
	if _selected_idx < 0 or _selected_idx >= _pieces.size(): return
	var p: PlugPiece = _pieces[_selected_idx]
	var factor: float = WHEEL_SCALE_STEP if dir > 0 else 1.0 / WHEEL_SCALE_STEP
	var new_scale: float = clampf(p.scale.x * factor, 0.01, 200.0)
	p.scale = Vector3.ONE * new_scale
	_scale_u.set_value_no_signal(new_scale)
	var n: Node3D = _spawned_nodes[_selected_idx]
	if n != null:
		n.transform = p.build_transform()


# ─── Undo stack helpers ──────────────────────────────────────────

## Deep-copy the current pieces list so it can be restored later.
func _snapshot_pieces() -> Array:
	var snap: Array = []
	for p in _pieces:
		snap.append((p as PlugPiece).duplicate(true))
	return snap


## Called BEFORE a destructive operation so the user can undo it.
func _push_undo() -> void:
	_undo_stack.append(_snapshot_pieces())
	while _undo_stack.size() > UNDO_DEPTH:
		_undo_stack.pop_front()
	_refresh_undo_button()


## Pop the top snapshot and rebuild the editor state from it. No-op if
## the stack is empty.
func _on_undo() -> void:
	if _undo_stack.is_empty():
		return
	# Undo ends any in-progress transform edit session so a follow-up
	# spinbox tweak gets its own snapshot instead of piggy-backing onto
	# the one we just popped.
	_transform_edit_pushed = false
	var snap: Array = _undo_stack.pop_back()
	# Tear down current nodes.
	for n in _spawned_nodes:
		if n != null: n.queue_free()
	_spawned_nodes.clear()
	_pieces.clear()
	# Restore from snapshot.
	for sp in snap:
		var p: PlugPiece = sp
		_pieces.append(p)
		_spawned_nodes.append(_spawn_piece_node(p))
	_selected_idx = -1
	_rebuild_piece_list()
	_clear_inspector()
	_piece_list.deselect_all()
	_update_empty_state_visibility()
	_refresh_undo_button()
	_show_toast("Undo (%d steps remaining)" % _undo_stack.size())


func _refresh_undo_button() -> void:
	if _undo_btn != null:
		_undo_btn.disabled = _undo_stack.is_empty()


func _on_duplicate_piece() -> void:
	if _selected_idx < 0 or _selected_idx >= _pieces.size(): return
	_push_undo()
	var src: PlugPiece = _pieces[_selected_idx]
	var copy: PlugPiece = PlugPiece.new()
	copy.prefab_path = src.prefab_path
	copy.position = src.position + Vector3(0.25, 0, 0.25)  # offset so it's visible
	copy.rotation_deg = src.rotation_deg
	copy.scale = src.scale
	copy.jitter_rotation_deg = src.jitter_rotation_deg
	copy.jitter_scale = src.jitter_scale
	copy.spawn_chance = src.spawn_chance
	copy.mineable_tag = src.mineable_tag
	_pieces.append(copy)
	_spawned_nodes.append(_spawn_piece_node(copy))
	_rebuild_piece_list()
	_select_piece(_pieces.size() - 1)


## Scale the selected piece so its largest horizontal (X or Z) dimension
## equals the plug's current footprint in meters. Measures the prefab's
## natural AABB (at scale=1) and computes a uniform scale factor. Lets
## users normalize cm-native Synty prefabs that render tiny by default
## without making any global assumption about "uniform size".
func _on_fit_to_cell() -> void:
	if _selected_idx < 0 or _selected_idx >= _pieces.size(): return
	_push_undo()
	var p: PlugPiece = _pieces[_selected_idx]
	var scene: PackedScene = p.load_prefab()
	if scene == null:
		_show_toast("Fit: prefab missing")
		return
	# Instantiate off-scene to measure the natural AABB without affecting
	# the live node or moving the piece.
	var probe: Node = scene.instantiate()
	if not (probe is Node3D):
		probe.queue_free()
		_show_toast("Fit: prefab is not 3D")
		return
	add_child(probe)
	var aabb: AABB = AABB()
	var first: bool = true
	for vi in (probe as Node3D).find_children("*", "VisualInstance3D", true, false):
		var v: VisualInstance3D = vi
		var w: AABB = v.global_transform * v.get_aabb()
		aabb = w if first else aabb.merge(w)
		first = false
	probe.queue_free()
	if first:
		_show_toast("Fit: no visible mesh to measure")
		return
	var longest_xz: float = maxf(aabb.size.x, aabb.size.z)
	if longest_xz <= 0.0001:
		_show_toast("Fit: mesh has zero horizontal size")
		return
	var footprint: Vector2i = _parse_footprint(_meta_footprint.get_item_text(_meta_footprint.selected)) if _meta_footprint.item_count > 0 else Vector2i.ONE
	var target_m: float = float(maxi(footprint.x, footprint.y)) * CELL_SIZE
	var factor: float = target_m / longest_xz
	p.scale = Vector3.ONE * factor
	# Wall detection: any horizontal ratio ≥ 1.8× counts as "wall-shape"
	# (Synty SM_Env_Wall_* are ~16:1). Walls land on cell EDGES along
	# their thin axis (tile-dungeon convention — walls are boundaries
	# between cells). Floors and props land on cell CENTERS as before.
	var x_size: float = maxf(aabb.size.x, 0.0001)
	var z_size: float = maxf(aabb.size.z, 0.0001)
	var wall_ratio: float = maxf(x_size, z_size) / minf(x_size, z_size)
	var is_wall: bool = wall_ratio >= 1.8
	var thin_is_x: bool = x_size < z_size   # true = thin along X, wall runs Z
	var snapped_x: float
	var snapped_z: float
	if is_wall and thin_is_x:
		snapped_x = _snap_to_cell_edge(p.position.x)
		snapped_z = roundf(p.position.z / CELL_SIZE) * CELL_SIZE
	elif is_wall and not thin_is_x:
		snapped_x = roundf(p.position.x / CELL_SIZE) * CELL_SIZE
		snapped_z = _snap_to_cell_edge(p.position.z)
	else:
		snapped_x = roundf(p.position.x / CELL_SIZE) * CELL_SIZE
		snapped_z = roundf(p.position.z / CELL_SIZE) * CELL_SIZE
	# Origin-offset compensation: for prefabs whose mesh origin is at a
	# corner (not the mesh center), subtract the scaled AABB-center
	# offset so the VISUAL center lands on the snapped point. Y is
	# preserved — user controls vertical placement manually.
	var aabb_center: Vector3 = aabb.get_center()
	p.position = Vector3(
		snapped_x - aabb_center.x * factor,
		p.position.y,
		snapped_z - aabb_center.z * factor,
	)
	# Push the new scale + position into the spinboxes AND respawn the node.
	_scale_u.set_value_no_signal(factor)
	_pos_x.set_value_no_signal(p.position.x)
	_pos_z.set_value_no_signal(p.position.z)
	var old: Node3D = _spawned_nodes[_selected_idx]
	if old != null: old.queue_free()
	_spawned_nodes[_selected_idx] = _spawn_piece_node(p)
	var kind: String = "wall → edge" if is_wall else "cell center"
	_show_toast("Fit: scaled to %.2f, %s (%.1f, %.1f)" % [factor, kind, snapped_x, snapped_z])


## Snap a coordinate to the nearest cell-edge line. Edges sit halfway
## between cell centers: at (n + 0.5) × CELL_SIZE. For CELL_SIZE = 2,
## edges are at −1, 1, 3, 5, … (cell centers are 0, 2, 4, …).
func _snap_to_cell_edge(v: float) -> float:
	return (roundf(v / CELL_SIZE - 0.5) + 0.5) * CELL_SIZE


## Magnet-snap: shift the selected piece so its face touches the
## nearest neighbor's face. Picks the nearest neighbor by AABB-center
## distance, then aligns on the dominant horizontal axis (X or Z) of
## the center-to-center vector. Y preserved. Rotation preserved —
## rotated pieces still align on world axes; OBB-aware snapping is a
## bigger refactor for a follow-up if you find you need it.
func _on_snap_to_neighbor() -> void:
	if _selected_idx < 0 or _selected_idx >= _pieces.size():
		_show_toast("Snap: nothing selected")
		return
	var self_node: Node3D = _spawned_nodes[_selected_idx]
	if self_node == null:
		return
	# Find nearest neighbor by AABB-center distance.
	var self_aabb: AABB = _world_aabb_of(self_node)
	var nearest_idx: int = -1
	var nearest_dist: float = INF
	for i in _spawned_nodes.size():
		if i == _selected_idx or _spawned_nodes[i] == null:
			continue
		var other_center: Vector3 = _world_aabb_of(_spawned_nodes[i]).get_center()
		var d: float = (other_center - self_aabb.get_center()).length()
		if d < nearest_dist:
			nearest_dist = d
			nearest_idx = i
	if nearest_idx < 0:
		_show_toast("Snap: no neighbor to align to")
		return
	# Guard: snap's shift math uses world-axis AABBs. For 90° rotations
	# the AABB is clean and everything works. For non-90° rotations the
	# AABB is inflated (a 2m wall at 45° has a ~2.8m × 2.8m AABB) and
	# snap would overshoot. Tell the user rather than produce garbage.
	var self_yaw: float = fposmod(_pieces[_selected_idx].rotation_deg.y, 90.0)
	var other_yaw: float = fposmod(_pieces[nearest_idx].rotation_deg.y, 90.0)
	if absf(self_yaw) > 0.5 or absf(other_yaw) > 0.5:
		_show_toast("Snap expects 0/90/180/270° rotations — press R to square up first")
		return
	_push_undo()
	var other_aabb: AABB = _world_aabb_of(_spawned_nodes[nearest_idx])
	var self_x: float = maxf(self_aabb.size.x, 0.0001)
	var self_z: float = maxf(self_aabb.size.z, 0.0001)
	var other_x: float = maxf(other_aabb.size.x, 0.0001)
	var other_z: float = maxf(other_aabb.size.z, 0.0001)
	var self_is_wall: bool = maxf(self_x, self_z) / minf(self_x, self_z) >= 1.8
	var other_is_wall: bool = maxf(other_x, other_z) / minf(other_x, other_z) >= 1.8
	var self_long_axis: int = 0 if self_x >= self_z else 2
	var other_long_axis: int = 0 if other_x >= other_z else 2
	var p: PlugPiece = _pieces[_selected_idx]
	var shift: Vector3 = Vector3.ZERO
	var mode: String = ""
	if self_is_wall and other_is_wall and self_long_axis == other_long_axis:
		# Parallel walls → side-by-side along their shared long axis,
		# aligned on the perpendicular axis (so they sit on the same line).
		var long_ax: int = self_long_axis
		var perp_ax: int = 2 if long_ax == 0 else 0
		# Perp: snap self's perp-coord to match other's perp-coord.
		shift[perp_ax] = other_aabb.get_center()[perp_ax] - self_aabb.get_center()[perp_ax]
		# Long: offset to the side closest to where self currently is.
		# If they're already at the same long-coord, tie-break to +dir.
		var self_long: float = self_aabb.get_center()[long_ax]
		var other_long: float = other_aabb.get_center()[long_ax]
		var dir_long: float = 1.0 if self_long >= other_long else -1.0
		var gap: float = other_aabb.size[long_ax] * 0.5 + self_aabb.size[long_ax] * 0.5
		var target_long: float = other_long + dir_long * gap
		shift[long_ax] = target_long - self_long
		mode = "parallel-wall side-by-side"
	else:
		# Non-parallel-wall case: align face-to-face on the dominant axis
		# of the center-to-center delta.
		var delta: Vector3 = self_aabb.get_center() - other_aabb.get_center()
		var axis: int = 0 if absf(delta.x) >= absf(delta.z) else 2
		var dir: float = 1.0 if delta[axis] >= 0.0 else -1.0
		var other_near_face: float = other_aabb.position[axis] + (other_aabb.size[axis] if dir > 0.0 else 0.0)
		var target_on_axis: float = other_near_face + dir * self_aabb.size[axis] * 0.5
		shift[axis] = target_on_axis - self_aabb.get_center()[axis]
		mode = "face-to-face on %s" % ("X" if axis == 0 else "Z")
	p.position += shift
	_pos_x.set_value_no_signal(p.position.x)
	_pos_z.set_value_no_signal(p.position.z)
	self_node.transform = p.build_transform()
	_show_toast("Snapped: %s → neighbor #%d" % [mode, nearest_idx])


## World-space AABB merging every VisualInstance3D under `node`.
## Used by fit-to-cell and snap-to-neighbor for consistent bounds.
func _world_aabb_of(node: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for vi in node.find_children("*", "VisualInstance3D", true, false):
		var v: VisualInstance3D = vi
		var w: AABB = v.global_transform * v.get_aabb()
		out = w if first else out.merge(w)
		first = false
	return out


func _on_delete_piece() -> void:
	if _selected_idx < 0 or _selected_idx >= _pieces.size(): return
	_push_undo()
	var n: Node3D = _spawned_nodes[_selected_idx]
	if n != null: n.queue_free()
	_pieces.remove_at(_selected_idx)
	_spawned_nodes.remove_at(_selected_idx)
	_selected_idx = -1
	_rebuild_piece_list()
	_clear_inspector()
	_update_empty_state_visibility()


func _snap(v: Vector3) -> Vector3:
	if Input.is_key_pressed(KEY_SHIFT):
		return v
	return Vector3(
		round(v.x / SNAP_STEP) * SNAP_STEP,
		round(v.y / SNAP_STEP) * SNAP_STEP,
		round(v.z / SNAP_STEP) * SNAP_STEP,
	)


# ─── Scene decor (cell box + grid + facing arrow) ────────────────

func _render_cell_box() -> void:
	# Draw a flat ground-level rectangle outlining the cell footprint —
	# NOT a tall translucent cube. The previous 2m × 4m × 2m box put
	# the camera inside the geometry, stacking transparent back-faces
	# into a white wash that covered the whole viewport.
	var footprint: Vector2i = _parse_footprint(_meta_footprint.get_item_text(_meta_footprint.selected)) if _meta_footprint.item_count > 0 else Vector2i.ONE
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(footprint.x * CELL_SIZE, 0.02, footprint.y * CELL_SIZE)
	_cell_box.mesh = mesh
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.35, 0.65, 1.0, 0.55)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_cell_box.material_override = mat
	# Center the footprint on origin regardless of N×M size; the pancake
	# sits just above y=0 so pieces don't Z-fight with the grid floor.
	_cell_box.position = Vector3(
		(footprint.x - 1) * CELL_SIZE * 0.5,
		0.01,
		(footprint.y - 1) * CELL_SIZE * 0.5,
	)
	_render_facing_arrow()


func _render_facing_arrow() -> void:
	var mode: String = _meta_orientation.get_item_text(_meta_orientation.selected)
	_facing_arrow.visible = mode == "facing" or mode == "corner"
	if not _facing_arrow.visible: return
	var arrow: CylinderMesh = CylinderMesh.new()
	arrow.height = 2.5
	arrow.top_radius = 0.0
	arrow.bottom_radius = 0.3
	_facing_arrow.mesh = arrow
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.4, 0.2, 1)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_facing_arrow.material_override = mat
	# Point down +Z (front of plug) at the cell's front edge.
	_facing_arrow.rotation = Vector3(deg_to_rad(90), 0, 0)
	_facing_arrow.position = Vector3(0, 0.5, CELL_SIZE * 0.4)


func _parse_footprint(s: String) -> Vector2i:
	var parts: PackedStringArray = s.split("x")
	if parts.size() != 2: return Vector2i.ONE
	return Vector2i(int(parts[0]), int(parts[1]))


# ─── Save / Load / New ────────────────────────────────────────────

func _new_plug() -> void:
	for n in _spawned_nodes:
		if n != null: n.queue_free()
	# Safety net: nuke ANY remaining children of _subject_root. If a spawn
	# path ever desyncs with _spawned_nodes (e.g. probe leaks from fit,
	# a canceled drag-in-progress, a crash mid-_place_asset), orphans
	# would otherwise be undeletable. New Plug guarantees a clean slate.
	if _subject_root != null:
		for child in _subject_root.get_children():
			child.queue_free()
	_pieces.clear()
	_spawned_nodes.clear()
	_selected_idx = -1
	_meta_id.text = ""
	_meta_name.text = ""
	_meta_tags.text = ""
	# Discard the undo history — undoing into a foreign plug would be
	# disorienting and spawn orphaned nodes from stale snapshots.
	_undo_stack.clear()
	_transform_edit_pushed = false
	_refresh_undo_button()
	_rebuild_piece_list()
	_clear_inspector()
	_render_cell_box()
	_update_empty_state_visibility()


func _on_save() -> void:
	var id_err: String = PlugTemplate.validate_id(_meta_id.text)
	if id_err != "":
		_show_toast("Save failed: %s" % id_err)
		return
	var t: PlugTemplate = PlugTemplate.new()
	t.template_id = _meta_id.text
	t.display_name = _meta_name.text if _meta_name.text != "" else t.template_id
	t.footprint_cells = _parse_footprint(_meta_footprint.get_item_text(_meta_footprint.selected))
	t.role = _meta_role.get_item_text(_meta_role.selected)
	t.aesthetic = _meta_aesthetic.get_item_text(_meta_aesthetic.selected)
	t.orientation_mode = _meta_orientation.get_item_text(_meta_orientation.selected)
	t.tags = _parse_tags(_meta_tags.text)
	t.pieces = _pieces.duplicate()
	var err: Error = PlugLibrary.save_template(t)
	if err != OK:
		_show_toast("Save failed: error %s" % err)
		return
	_show_toast("Saved %s · %d pieces" % [t.template_id, t.pieces.size()])


func _on_load() -> void:
	# MVP: cycle through available templates. A modal grid comes later.
	var all: Array = PlugLibrary.all()
	if all.is_empty():
		_show_toast("No saved plugs yet")
		return
	# Pick the next one after the currently loaded id (or the first).
	var current: String = _meta_id.text
	var idx: int = 0
	for i in range(all.size()):
		if all[i].template_id == current:
			idx = (i + 1) % all.size()
			break
	_load_template(all[idx])


func _load_template(t: PlugTemplate) -> void:
	_new_plug()
	_meta_id.text = t.template_id
	_meta_name.text = t.display_name
	_meta_tags.text = ", ".join(t.tags)
	_select_by_text(_meta_role, t.role)
	_select_by_text(_meta_aesthetic, t.aesthetic)
	_select_by_text(_meta_footprint, "%dx%d" % [t.footprint_cells.x, t.footprint_cells.y])
	_select_by_text(_meta_orientation, t.orientation_mode)
	_render_cell_box()
	for src in t.pieces:
		var copy: PlugPiece = PlugPiece.new()
		copy.prefab_path = src.prefab_path
		copy.position = src.position
		copy.rotation_deg = src.rotation_deg
		copy.scale = src.scale
		copy.jitter_rotation_deg = src.jitter_rotation_deg
		copy.jitter_scale = src.jitter_scale
		copy.spawn_chance = src.spawn_chance
		copy.mineable_tag = src.mineable_tag
		_pieces.append(copy)
		_spawned_nodes.append(_spawn_piece_node(copy))
	_rebuild_piece_list()
	_show_toast("Loaded %s" % t.template_id)


static func _select_by_text(opt: OptionButton, text: String) -> void:
	for i in range(opt.item_count):
		if opt.get_item_text(i) == text:
			opt.select(i); return


static func _parse_tags(s: String) -> Array[String]:
	var out: Array[String] = []
	for tok in s.split(","):
		var t: String = tok.strip_edges()
		if t != "": out.append(t)
	return out


func _on_exit() -> void:
	get_tree().change_scene_to_file("res://ui/launcher/launcher.tscn")


func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate = Color(1, 1, 1, 1)
	var tw: Tween = create_tween()
	tw.tween_interval(3.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.8)


# ─── Mouse input (viewport) ───────────────────────────────────────
#
# Mouse events live in _input() — NOT _unhandled_input() — because the
# SubViewportContainer sits inside an HBoxContainer. HBoxContainer
# defaults to mouse_filter = STOP, which consumes the click before
# _unhandled_input fires. _input runs before GUI hit-testing, so the
# viewport can react regardless of what Controls are in the tree.

func _input(event: InputEvent) -> void:
	# ── Mouse buttons ──────────────────────────────────────────────
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if _viewport_container == null:
			return
		var over_viewport: bool = _viewport_container.get_global_rect().has_point(mb.global_position)
		# Camera: MMB-drag orbit, RMB-drag pan, wheel zoom.
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			_mmb_dragging = mb.pressed and over_viewport
			if over_viewport: get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_RIGHT:
			_rmb_dragging = mb.pressed and over_viewport
			if over_viewport: get_viewport().set_input_as_handled()
			return
		if over_viewport and mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				var dir: float = 1.0 if mb.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0
				# Shift+wheel (or Cmd+wheel on Mac) scales a piece. If
				# nothing is explicitly selected, auto-target the last
				# placed piece so "place → resize" works without a
				# click-select step. Plain wheel = camera zoom.
				if mb.shift_pressed or mb.meta_pressed:
					if _selected_idx < 0 and _pieces.size() > 0:
						_select_piece(_pieces.size() - 1)
					if _selected_idx >= 0:
						_wheel_scale_selected(dir)
						get_viewport().set_input_as_handled()
						return
				_cam_zoom(dir)
				get_viewport().set_input_as_handled()
				return
		# LMB inside the viewport: commit a stamp (if stamping), or click-
		# to-select + start drag on a placed piece (if not stamping).
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and over_viewport:
			if _stamp_active:
				_commit_stamp()
				get_viewport().set_input_as_handled()
				return
			var hit: Dictionary = _raycast_physics_from_mouse()
			if not hit.is_empty():
				var picked_idx: int = _piece_index_from_hit(hit.collider)
				if picked_idx >= 0:
					_select_piece(picked_idx)
					# Start drag. Record the ground point under the cursor
					# and the piece's current position so we can compute
					# a delta on each motion tick.
					var ground_hit: Variant = _raycast_ground_from_mouse()
					if ground_hit != null:
						_piece_drag_idx = picked_idx
						_piece_drag_click_ground = ground_hit as Vector3
						_piece_drag_orig_pos = _pieces[picked_idx].position
						_piece_drag_undo_pushed = false
					get_viewport().set_input_as_handled()
					return
		# LMB release: end any piece drag in progress.
		if not mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and _piece_drag_idx >= 0:
			_piece_drag_idx = -1
			get_viewport().set_input_as_handled()
			return
	# ── Mouse motion ───────────────────────────────────────────────
	if event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event
		# Piece drag takes priority over camera drags.
		if _piece_drag_idx >= 0:
			var ground_hit: Variant = _raycast_ground_from_mouse()
			if ground_hit != null:
				var cur: Vector3 = ground_hit as Vector3
				var delta_xz: Vector3 = cur - _piece_drag_click_ground
				delta_xz.y = 0.0
				# Lazy undo: only push on actual motion, not on pure click-select.
				if not _piece_drag_undo_pushed and delta_xz.length() > 0.0001:
					_push_undo()
					_piece_drag_undo_pushed = true
				var new_pos: Vector3 = _snap(_piece_drag_orig_pos + delta_xz)
				new_pos.y = _piece_drag_orig_pos.y   # preserve Y
				var pp: PlugPiece = _pieces[_piece_drag_idx]
				pp.position = new_pos
				_pos_x.set_value_no_signal(new_pos.x)
				_pos_z.set_value_no_signal(new_pos.z)
				var pn: Node3D = _spawned_nodes[_piece_drag_idx]
				if pn != null:
					pn.transform = pp.build_transform()
			get_viewport().set_input_as_handled()
			return
		if _mmb_dragging:
			_cam_orbit(mm.relative)
			get_viewport().set_input_as_handled()
			return
		if _rmb_dragging:
			_cam_pan(mm.relative)
			get_viewport().set_input_as_handled()
			return


# ─── Keyboard shortcuts ───────────────────────────────────────────
#
# Keys stay in _unhandled_input so focused LineEdits (id, name, tags)
# still receive their text without the editor firing Ctrl+S-style
# shortcuts mid-typing.

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	var k: InputEventKey = event
	if k.ctrl_pressed and k.keycode == KEY_Z:
		_on_undo(); get_viewport().set_input_as_handled()
	elif k.meta_pressed and k.keycode == KEY_Z:
		# Cmd+Z on macOS — match platform convention.
		_on_undo(); get_viewport().set_input_as_handled()
	elif k.ctrl_pressed and k.keycode == KEY_S:
		_on_save(); get_viewport().set_input_as_handled()
	elif k.ctrl_pressed and k.keycode == KEY_N:
		_new_plug(); get_viewport().set_input_as_handled()
	elif (k.keycode == KEY_DELETE or k.keycode == KEY_BACKSPACE) and _selected_idx >= 0:
		# Accept both: Mac laptops label Backspace as "Delete".
		_on_delete_piece(); get_viewport().set_input_as_handled()
	elif k.keycode == KEY_K:
		# Toggle scale reference silhouette.
		if _scale_reference != null:
			_scale_reference.visible = not _scale_reference.visible
			_show_toast("Scale reference %s" % ("shown" if _scale_reference.visible else "hidden"))
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_R and _selected_idx >= 0:
		# R = rotate selected piece 90° on Y (architectural snap).
		# Shift+R rotates the other direction.
		var step: float = -90.0 if k.shift_pressed else 90.0
		_rotate_selected_yaw(step)
		get_viewport().set_input_as_handled()
	elif _selected_idx >= 0 and k.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN]:
		# Arrow-key nudge: 25cm step (SNAP_STEP) by default, Shift = full
		# CELL_SIZE (2m). Maps world-axis: Up = −Z, Down = +Z, Left = −X,
		# Right = +X. Reuses the transform-edit session flag so rapid
		# taps collapse into one undo step.
		var step_m: float = CELL_SIZE if k.shift_pressed else SNAP_STEP
		var dx: float = 0.0
		var dz: float = 0.0
		match k.keycode:
			KEY_LEFT:  dx = -step_m
			KEY_RIGHT: dx = step_m
			KEY_UP:    dz = -step_m
			KEY_DOWN:  dz = step_m
		_nudge_selected(dx, dz)
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_ESCAPE:
		# Mark handled FIRST so we don't touch get_viewport() after a
		# potential scene change. Then cascade: cancel stamp → clear
		# selection → no-op. Exiting the editor is done via the Exit
		# button, not ESC, so users don't lose work by accident.
		get_viewport().set_input_as_handled()
		if _stamp_active:
			_exit_stamp_mode()
			_show_toast("Stamp cancelled")
		elif _selected_idx >= 0:
			_select_piece(-1)
			_piece_list.deselect_all()
			_show_toast("Selection cleared")
