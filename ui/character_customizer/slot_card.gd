class_name SlotCard extends PanelContainer
## A single slot card for the Character Customizer. Shows the current part's
## thumbnail + slot name. Single-click selects; double-click opens the gallery.
##
## Parent wires gallery via slot_activated signal.

signal slot_activated(slot: String)
signal slot_focused(slot: String)

const THUMB_DIR := "res://assets/sidekick/goblin_fighters/thumbnails"
const CARD_SIZE := Vector2i(100, 130)
const HIGHLIGHT_MODULATE := Color(1.15, 1.15, 0.55)
const NORMAL_MODULATE := Color(1, 1, 1)

var slot: String = ""
var _current_part: String = ""
var _selected: bool = false
var _thumb: TextureRect
var _name_label: Label
var _slot_label: Label


func _ready() -> void:
    custom_minimum_size = CARD_SIZE
    mouse_filter = Control.MOUSE_FILTER_STOP

    var vb := VBoxContainer.new()
    vb.add_theme_constant_override("separation", 2)
    add_child(vb)

    _slot_label = Label.new()
    _slot_label.add_theme_font_size_override("font_size", 10)
    _slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _slot_label.add_theme_color_override("font_color", Color(0.7, 0.8, 0.9))
    vb.add_child(_slot_label)

    _thumb = TextureRect.new()
    _thumb.custom_minimum_size = Vector2i(92, 92)
    _thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _thumb.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
    _thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vb.add_child(_thumb)

    _name_label = Label.new()
    _name_label.add_theme_font_size_override("font_size", 9)
    _name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _name_label.clip_text = true
    _name_label.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
    vb.add_child(_name_label)


func configure(slot_name: String) -> void:
    slot = slot_name
    _slot_label.text = slot.to_upper().replace("_", " ")


func set_current_part(part_name: String) -> void:
    _current_part = part_name
    if part_name == "":
        _thumb.texture = null
        _name_label.text = "(none)"
        return

    var thumb_path := "%s/%s.png" % [THUMB_DIR, part_name]
    var tex: Texture2D = null
    if ResourceLoader.exists(thumb_path):
        tex = load(thumb_path)
    elif FileAccess.file_exists(thumb_path):
        var img := Image.new()
        if img.load(ProjectSettings.globalize_path(thumb_path)) == OK:
            tex = ImageTexture.create_from_image(img)
    _thumb.texture = tex

    # compact display: "v03" tag or short suffix of the part name
    var short := part_name
    var parts_arr := part_name.split("_")
    if parts_arr.size() >= 4:
        short = "v%s" % parts_arr[3]  # variant index
    _name_label.text = short


func set_selected(b: bool) -> void:
    _selected = b
    modulate = HIGHLIGHT_MODULATE if b else NORMAL_MODULATE


func _gui_input(event: InputEvent) -> void:
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_LEFT:
            if event.double_click:
                slot_activated.emit(slot)
            else:
                slot_focused.emit(slot)
