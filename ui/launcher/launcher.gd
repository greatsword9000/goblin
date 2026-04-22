class_name Launcher extends Control
## Boot menu — shown before any gameplay. Picks between:
##   - Play Game            → res://world/starter_dungeon.tscn
##   - Character Editor     → res://ui/character_customizer/character_customizer.tscn
##   - Plug Editor          → res://world/plug_editor_scene.tscn (graceful if missing)
##   - Quit
##
## Target scenes are declared as @export so they can be re-wired without
## editing this script. Buttons for missing scenes are auto-disabled with
## a "(not available)" suffix so the launcher doesn't crash on a dead link.

@export var game_scene: String = "res://world/starter_dungeon.tscn"
@export var character_editor_scene: String = "res://ui/character_customizer/character_customizer.tscn"
@export var plug_editor_scene: String = "res://world/plug_editor_scene.tscn"

@onready var play_button: Button = %PlayButton
@onready var char_button: Button = %CharButton
@onready var plug_button: Button = %PlugButton
@onready var quit_button: Button = %QuitButton
@onready var version_label: Label = %VersionLabel


func _ready() -> void:
    _configure_button(play_button, game_scene, "▶  Play Game")
    _configure_button(char_button, character_editor_scene, "🧙  Character Editor")
    _configure_button(plug_button, plug_editor_scene, "🔌  Plug Editor")
    play_button.pressed.connect(_go.bind(game_scene))
    char_button.pressed.connect(_go.bind(character_editor_scene))
    plug_button.pressed.connect(_go.bind(plug_editor_scene))
    quit_button.pressed.connect(get_tree().quit)
    version_label.text = "GOBLIN  •  Godot %s" % Engine.get_version_info().string


func _configure_button(b: Button, scene_path: String, label: String) -> void:
    if ResourceLoader.exists(scene_path):
        b.text = label
        b.disabled = false
    else:
        b.text = "%s  (not available)" % label
        b.disabled = true
        b.tooltip_text = "Scene not found: %s" % scene_path


func _go(scene_path: String) -> void:
    if not ResourceLoader.exists(scene_path):
        push_warning("[Launcher] scene missing, ignoring: %s" % scene_path)
        return
    get_tree().change_scene_to_file(scene_path)


func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
        get_tree().quit()
