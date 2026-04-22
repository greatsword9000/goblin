class_name CharacterCustomizer extends Control
## In-engine Sidekick character authoring tool.
##
## Layout:
##   ┌──────── HEADER (name, archetype, save/load) ─────────┐
##   │ FACE │              │                │ ACCESSORIES   │
##   │ cards│   3D PREVIEW │  BODY cards    │   cards       │
##   │      │              │                │               │
##   ├──────────────────────────────────────────────────────┤
##   │ Body Morphs  |  Tints  |  Height                     │
##   └──────────────────────────────────────────────────────┘
##
## Slot cards show the currently-equipped part's thumbnail. Double-click any
## card → modal GalleryPopup with a grid of ALL options (thumbnails, tooltips,
## current pick highlighted). This is the single entry point for swapping
## body pieces, accessories, hair, species variants — anything parts-based.
##
## Color tints (skin/hair) live in a separate swatch strip at the bottom so
## users can re-color without opening the gallery.

const USER_PRESET_DIR := "user://character_presets"
const GAME_PRESET_DIR := "res://resources/npc_presets"

const GalleryScript = preload("res://ui/character_customizer/gallery_popup.gd")
const SlotCardScript = preload("res://ui/character_customizer/slot_card.gd")

# Slot grouping for the three card columns
const FACE_SLOTS := ["head", "hair", "facial_hair", "eyebrow_l", "eyebrow_r",
                     "eye_l", "eye_r", "ear_l", "ear_r", "nose", "teeth", "tongue"]
const BODY_SLOTS := ["torso", "arm_upper_l", "arm_upper_r", "arm_lower_l", "arm_lower_r",
                     "hand_l", "hand_r", "hips", "leg_l", "leg_r", "foot_l", "foot_r"]
const ACC_SLOTS  := ["acc_head", "acc_face", "acc_back",
                     "acc_shoulder_l", "acc_shoulder_r",
                     "acc_elbow_l", "acc_elbow_r",
                     "acc_hip_front", "acc_hip_back", "acc_hip_l", "acc_hip_r",
                     "acc_knee_l", "acc_knee_r",
                     "wrap"]

## Preferred order for body-morph sliders. Any shape name returned by
## SidekickCharacter.available_blend_shapes() that's NOT in this list still
## gets a slider at the end. Order only; we introspect at runtime so we don't
## hallucinate shapes that aren't actually on the meshes.
const BODY_MORPH_ORDER := ["masculineFeminine", "defaultBuff", "defaultHeavy", "defaultSkinny"]

# Canonical tint palette — quick swatches; color picker beside for custom.
const TINT_PALETTE := [
    Color(0.45, 0.62, 0.35),  # goblin-green
    Color(0.32, 0.50, 0.28),
    Color(0.58, 0.50, 0.34),
    Color(0.82, 0.64, 0.46),  # human skin
    Color(0.92, 0.78, 0.60),
    Color(0.55, 0.38, 0.27),
    Color(0.35, 0.25, 0.20),  # dark hair
    Color(0.72, 0.48, 0.22),  # ginger
    Color(0.95, 0.88, 0.55),  # blond
    Color(0.88, 0.88, 0.90),  # grey/white
    Color(0.70, 0.15, 0.15),  # red gear
    Color(0.12, 0.25, 0.55),  # blue gear
]
# Which slots get a tint row. Covers all visible body + gear surfaces so the
# user can recolor anything they see on the character.
const TINT_SLOTS := [
    "head", "hair", "facial_hair",
    "torso", "arm_upper_l", "arm_upper_r", "arm_lower_l", "arm_lower_r",
    "hand_l", "hand_r",
    "hips", "leg_l", "leg_r", "foot_l", "foot_r",
]

@onready var preview_camera: Camera3D = %PreviewCamera
@onready var preview_pivot: Node3D = %PreviewPivot
@onready var face_card_list: VBoxContainer = %FaceCardList
@onready var body_card_list: VBoxContainer = %BodyCardList
@onready var acc_card_list: VBoxContainer = %AccCardList
@onready var blend_list: VBoxContainer = %BlendList
@onready var tint_list: VBoxContainer = %TintList
@onready var height_slider: HSlider = %HeightSlider
@onready var height_label: Label = %HeightLabel
@onready var preset_name_edit: LineEdit = %PresetNameEdit
@onready var preset_picker: OptionButton = %PresetPicker
@onready var status_label: Label = %StatusLabel
@onready var archetype_edit: LineEdit = %ArchetypeEdit
@onready var hero_eligible_check: CheckBox = %HeroEligibleCheck

var _character: SidekickCharacter
var _preset: CharacterPreset
var _cards: Dictionary = {}          # slot -> SlotCard
var _blend_sliders: Dictionary = {}  # shape_name -> HSlider
var _gallery: GalleryPopup
var _suppress_events: bool = false
var _selected_slot: String = ""


func _ready() -> void:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(USER_PRESET_DIR))
    _spawn_preview_character()
    _build_gallery()
    _build_slot_cards()
    _build_tint_swatches()
    _wire_header()
    _refresh_preset_picker()
    _load_default_preset()
    # Build blend sliders AFTER default preset applies so meshes exist.
    _build_blend_sliders()
    # Forward mouse events from the viewport container to our orbit logic.
    var vpc: SubViewportContainer = %PreviewViewportContainer
    if vpc: vpc.gui_input.connect(_on_viewport_input)


func _spawn_preview_character() -> void:
    var scene: PackedScene = load("res://entities/sidekick_character/sidekick_character.tscn")
    _character = scene.instantiate()
    preview_pivot.add_child(_character)
    _character.preset_applied.connect(func(_p): _refresh_all_cards())
    _character.part_swapped.connect(func(slot, _name): _refresh_card(slot))


func _build_gallery() -> void:
    _gallery = GalleryScript.new()
    add_child(_gallery)
    _gallery.part_chosen.connect(_on_gallery_pick)


func _build_slot_cards() -> void:
    var lib := _library()
    if lib == null: return
    _populate_column(face_card_list, FACE_SLOTS, lib)
    _populate_column(body_card_list, BODY_SLOTS, lib)
    _populate_column(acc_card_list,  ACC_SLOTS,  lib)


func _populate_column(container: VBoxContainer, slots: Array, lib: Node) -> void:
    container.add_theme_constant_override("separation", 4)
    for slot in slots:
        if lib.parts_for_slot(slot).is_empty(): continue
        var card: SlotCard = SlotCardScript.new()
        container.add_child(card)
        card.configure(slot)
        card.slot_activated.connect(_on_slot_double_click)
        card.slot_focused.connect(_on_slot_focus)
        _cards[slot] = card


func _build_blend_sliders() -> void:
    # Called after preset apply so meshes exist; builds sliders from what the
    # meshes actually have, filtered to body-morph shapes only (not the ~200
    # ARKit facial expression shapes — those are driven by dialogue/animation
    # systems, not by manual sliders in the customizer).
    for c in blend_list.get_children(): c.queue_free()
    _blend_sliders.clear()
    if _character == null: return
    var all_shapes: Array[String] = _character.available_blend_shapes()

    # Sidekick prefixes shape names with the mesh they're on (e.g.
    # `HIPSBlends.masculineFeminine`). Strip the prefix for matching.
    var body_shapes: Array[String] = []
    var seen: Dictionary = {}
    for raw in all_shapes:
        var base: String = raw
        var dot := raw.find(".")
        if dot >= 0: base = raw.substr(dot + 1)
        if not BODY_MORPH_ORDER.has(base): continue
        if seen.has(base): continue
        seen[base] = true
        body_shapes.append(base)

    if body_shapes.is_empty():
        var note := Label.new()
        note.text = "(no body-morph shapes available)"
        note.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
        blend_list.add_child(note)
        return

    # Sort by preferred order
    body_shapes.sort_custom(func(a, b):
        return BODY_MORPH_ORDER.find(a) < BODY_MORPH_ORDER.find(b))

    for shape in body_shapes:
        var row := HBoxContainer.new()
        var lbl := Label.new()
        lbl.text = shape
        lbl.custom_minimum_size.x = 160
        row.add_child(lbl)
        var slider := HSlider.new()
        slider.min_value = -1.0  # some Synty shapes go negative (masc/fem axis)
        slider.max_value = 1.0
        slider.step = 0.01
        slider.custom_minimum_size.x = 180
        slider.value_changed.connect(_on_blend_changed.bind(shape))
        row.add_child(slider)
        var val := Label.new()
        val.text = "0.00"
        val.custom_minimum_size.x = 40
        slider.value_changed.connect(func(v): val.text = "%.2f" % v)
        row.add_child(val)
        blend_list.add_child(row)
        _blend_sliders[shape] = slider


func _build_tint_swatches() -> void:
    for slot in TINT_SLOTS:
        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 4)
        var lbl := Label.new()
        lbl.text = slot
        lbl.custom_minimum_size.x = 100
        row.add_child(lbl)
        for col in TINT_PALETTE:
            var b := Button.new()
            b.custom_minimum_size = Vector2i(22, 22)
            b.flat = false
            var sb := StyleBoxFlat.new()
            sb.bg_color = col
            sb.border_color = Color(0, 0, 0, 0.4)
            sb.set_border_width_all(1)
            sb.corner_radius_top_left = 3
            sb.corner_radius_top_right = 3
            sb.corner_radius_bottom_left = 3
            sb.corner_radius_bottom_right = 3
            b.add_theme_stylebox_override("normal", sb)
            b.add_theme_stylebox_override("hover", sb)
            b.pressed.connect(_on_tint_pressed.bind(slot, col))
            row.add_child(b)
        # Custom color picker at the end
        var picker := ColorPickerButton.new()
        picker.custom_minimum_size = Vector2i(44, 22)
        picker.color_changed.connect(_on_tint_pressed.bind(slot))
        row.add_child(picker)
        # Reset button
        var reset := Button.new()
        reset.text = "×"
        reset.tooltip_text = "clear tint"
        reset.custom_minimum_size = Vector2i(22, 22)
        reset.pressed.connect(_on_tint_clear.bind(slot))
        row.add_child(reset)
        tint_list.add_child(row)


func _wire_header() -> void:
    height_slider.min_value = 0.5
    height_slider.max_value = 1.5
    height_slider.step = 0.01
    height_slider.value = 1.0
    height_slider.value_changed.connect(_on_height_changed)
    %NewButton.pressed.connect(_on_new_pressed)
    %SaveButton.pressed.connect(_on_save_pressed)
    %DeleteButton.pressed.connect(_on_delete_pressed)
    %PromoteButton.pressed.connect(_on_promote_pressed)
    preset_picker.item_selected.connect(_on_preset_picker_changed)


func _library() -> Node:
    return get_node_or_null("/root/SidekickPartLibrary")


# --------------------------------------------------------------------------
# Slot card interaction
# --------------------------------------------------------------------------

func _on_slot_focus(slot: String) -> void:
    _selected_slot = slot
    for s in _cards:
        _cards[s].set_selected(s == slot)


func _on_slot_double_click(slot: String) -> void:
    _selected_slot = slot
    var current: String = ""
    if _preset: current = _preset.parts.get(slot, "")
    _gallery.open_for_slot(slot, current)


func _on_gallery_pick(slot: String, part_name: String) -> void:
    if _suppress_events: return
    _character.set_part(slot, part_name)
    if _preset: _preset.parts[slot] = part_name
    _refresh_card(slot)


func _refresh_card(slot: String) -> void:
    if not _cards.has(slot): return
    var part: String = _preset.parts.get(slot, "") if _preset else ""
    _cards[slot].set_current_part(part)


func _refresh_all_cards() -> void:
    for slot in _cards:
        _refresh_card(slot)


# --------------------------------------------------------------------------
# Blend shapes / tints / height
# --------------------------------------------------------------------------

func _on_blend_changed(value: float, shape: String) -> void:
    if _suppress_events: return
    _character.set_blend_shape_global(shape, value)


func _on_tint_pressed(color_or_slot, arg2 = null) -> void:
    # Two call shapes: (slot, color) from swatch buttons, (color) from ColorPicker
    var slot: String
    var color: Color
    if arg2 == null:
        # ColorPicker path: color_or_slot is Color, slot came from the bound arg
        slot = _last_picker_slot(color_or_slot)
        color = color_or_slot
    else:
        slot = String(color_or_slot)
        color = arg2
    if slot == "": return
    _character.set_tint(slot, color)
    if _preset: _preset.tint_overrides[slot] = color


# Small hack: ColorPickerButton bind order inverts. We don't actually need the
# slot from the color, because the bind pattern emits (color, slot). So:
func _last_picker_slot(_c) -> String: return ""


func _on_tint_clear(slot: String) -> void:
    var mesh := _character.get_slot_mesh(slot)
    if mesh: mesh.set_surface_override_material(0, null)
    if _preset: _preset.tint_overrides.erase(slot)


func _on_height_changed(value: float) -> void:
    if _suppress_events: return
    height_label.text = "%.2f" % value
    if _character: _character.scale = Vector3.ONE * value
    if _preset: _preset.height_scale = value


# --------------------------------------------------------------------------
# Preset management (same as before)
# --------------------------------------------------------------------------

func _load_default_preset() -> void:
    var lib := _library()
    if lib == null:
        status("SidekickPartLibrary autoload missing")
        return
    _preset = lib.default_preset()
    _character.apply_preset(_preset)
    _sync_ui_from_preset()


func _list_presets() -> Array:
    var out := []
    for dir_path in [USER_PRESET_DIR, GAME_PRESET_DIR]:
        if not DirAccess.dir_exists_absolute(dir_path): continue
        var d := DirAccess.open(dir_path)
        if d == null: continue
        d.list_dir_begin()
        var fn := d.get_next()
        while fn != "":
            if fn.ends_with(".tres") and not d.current_is_dir():
                out.append("%s/%s" % [dir_path, fn])
            fn = d.get_next()
    out.sort()
    return out


func _refresh_preset_picker() -> void:
    preset_picker.clear()
    preset_picker.add_item("(select preset...)", 0)
    var presets := _list_presets()
    for i in range(presets.size()):
        var p: String = presets[i]
        preset_picker.add_item(p.get_file().get_basename(), i + 1)
        preset_picker.set_item_metadata(i + 1, p)


func _on_preset_picker_changed(idx: int) -> void:
    if idx == 0: return
    var path: String = preset_picker.get_item_metadata(idx)
    var res := ResourceLoader.load(path)
    if res is CharacterPreset:
        _preset = (res as CharacterPreset).deep_duplicate()
        _character.apply_preset(_preset)
        _build_blend_sliders()  # rebuild — different preset may expose different shapes
        _sync_ui_from_preset()
        status("loaded: %s" % path.get_file())
    else:
        status("failed to load %s" % path)


func _on_new_pressed() -> void:
    _load_default_preset()
    preset_name_edit.text = "New Preset"
    _preset.display_name = "New Preset"
    status("new preset")


func _on_save_pressed() -> void:
    if _preset == null:
        status("nothing to save"); return
    _collect_ui_into_preset()
    var lib := _library()
    var issues := _preset.validate(lib)
    if not issues.is_empty():
        status("validation failed: %s" % ", ".join(issues))
        return
    var fname := _safe_filename(_preset.display_name) + ".tres"
    var path := "%s/%s" % [USER_PRESET_DIR, fname]
    var err := ResourceSaver.save(_preset, path)
    if err != OK:
        status("save failed: %d" % err); return
    status("saved: %s" % path)
    _refresh_preset_picker()


func _on_delete_pressed() -> void:
    var idx := preset_picker.selected
    if idx <= 0: return
    var path: String = preset_picker.get_item_metadata(idx)
    if path.begins_with(GAME_PRESET_DIR):
        status("refusing to delete committed preset via UI"); return
    if DirAccess.remove_absolute(ProjectSettings.globalize_path(path)) == OK:
        status("deleted: %s" % path.get_file())
        _refresh_preset_picker()


func _on_promote_pressed() -> void:
    if _preset == null: return
    _collect_ui_into_preset()
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GAME_PRESET_DIR))
    var fname := _safe_filename(_preset.display_name) + ".tres"
    var path := "%s/%s" % [GAME_PRESET_DIR, fname]
    var err := ResourceSaver.save(_preset, path)
    if err == OK:
        status("promoted to game: %s" % path); _refresh_preset_picker()


func _safe_filename(s: String) -> String:
    var out := ""
    for c in s:
        if c.is_valid_identifier() or c in "_- ": out += c
        else: out += "_"
    out = out.strip_edges().replace(" ", "_").to_lower()
    return out if out != "" else "unnamed"


# --------------------------------------------------------------------------
# UI ↔ preset sync
# --------------------------------------------------------------------------

func _sync_ui_from_preset() -> void:
    if _preset == null: return
    _suppress_events = true
    preset_name_edit.text = _preset.display_name
    archetype_edit.text = _preset.archetype
    hero_eligible_check.button_pressed = _preset.is_hero_eligible
    height_slider.value = _preset.height_scale
    height_label.text = "%.2f" % _preset.height_scale
    _refresh_all_cards()
    for shape in _blend_sliders:
        var slider: HSlider = _blend_sliders[shape]
        var v := 0.0
        for slot in _preset.blend_shapes:
            var d: Dictionary = _preset.blend_shapes[slot]
            if d.has(shape): v = float(d[shape]); break
        slider.value = v
    _suppress_events = false


func _collect_ui_into_preset() -> void:
    if _preset == null: return
    _preset.display_name = preset_name_edit.text.strip_edges()
    _preset.archetype = archetype_edit.text.strip_edges()
    _preset.is_hero_eligible = hero_eligible_check.button_pressed
    _preset.height_scale = height_slider.value
    _preset.rig_target = "sidekick"
    _preset.format_version = CharacterPreset.FORMAT_VERSION
    # parts already written through _on_gallery_pick; just ensure dictionary is current
    # blend shapes
    _preset.blend_shapes.clear()
    for shape in _blend_sliders:
        var v: float = _blend_sliders[shape].value
        if absf(v) < 0.001: continue
        for slot in _character._slot_nodes.keys():
            var mesh: MeshInstance3D = _character._slot_nodes[slot]
            if mesh and mesh.mesh and mesh.find_blend_shape_by_name(shape) >= 0:
                var d: Dictionary = _preset.blend_shapes.get(slot, {})
                d[shape] = v
                _preset.blend_shapes[slot] = d


func status(s: String) -> void:
    status_label.text = s
    print("[CharacterCustomizer] %s" % s)


# --------------------------------------------------------------------------
# Camera orbit — drag on viewport
# --------------------------------------------------------------------------

var _orbit := Vector2(0, 0.2)
var _dist := 2.5

func _physics_process(_dt: float) -> void:
    if preview_camera == null: return
    var p := Vector3(
        _dist * cos(_orbit.y) * sin(_orbit.x),
        _dist * sin(_orbit.y) + 1.0,
        _dist * cos(_orbit.y) * cos(_orbit.x))
    preview_camera.position = p
    preview_camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)

func _on_viewport_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion:
        var mm: InputEventMouseMotion = event
        if mm.button_mask & MOUSE_BUTTON_MASK_LEFT:
            _orbit.x -= mm.relative.x * 0.01
            _orbit.y = clampf(_orbit.y + mm.relative.y * 0.01, -1.2, 1.2)
    elif event is InputEventMouseButton:
        var mb: InputEventMouseButton = event
        if not mb.pressed: return
        if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
            _dist = maxf(1.0, _dist - 0.2)
        elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            _dist = minf(8.0, _dist + 0.2)
