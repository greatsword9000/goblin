extends SceneTree
## Standalone thumbnail baker. Prefer the in-editor version (Project →
## Sidekick → Bake Thumbnails) — no second Godot process, no lock conflict.
##
## Use this script only when the editor is CLOSED, e.g. for CI or batch runs.
## Must run windowed (NOT --headless) because macOS headless uses a dummy
## display driver that cannot render to texture.
##
## Run with:
##   /Applications/Godot_mono.app/Contents/MacOS/Godot \
##     --path /Users/greatsword/Documents/Goblin \
##     -s _tools/bake_sidekick_thumbnails.gd -- [--force] [--limit=N]

const BakerCore = preload("res://addons/sidekick_tools/thumbnail_baker_core.gd")

var _force := false


func _initialize() -> void:
    for arg in OS.get_cmdline_user_args():
        if arg == "--force": _force = true

    if _is_editor_running():
        push_error(
            "[Baker] Another Godot instance appears to have this project open. " +
            "Close the editor first, or use Project → Sidekick → Bake Thumbnails from inside it."
        )
        quit(2)
        return

    if DisplayServer.get_name() == "headless":
        push_error(
            "[Baker] Running with the headless display driver — SubViewport " +
            "textures will come back empty. Re-run WITHOUT --headless."
        )
        quit(3)
        return

    await process_frame
    await process_frame

    var baker := BakerCore.new()
    root.add_child(baker)
    var res = await baker.run(root, _force)
    baker.queue_free()

    var failed: int = res.get("failed", 0)
    print("\nResult: baked=%d skipped=%d failed=%d" % [
        res.get("baked", 0), res.get("skipped", 0), failed
    ])
    quit(0 if failed == 0 else 1)


## Crude but effective: count other Godot processes pointing at our project dir.
## Returns true if another Godot has this project open (likely the editor).
func _is_editor_running() -> bool:
    var project_path: String = ProjectSettings.globalize_path("res://").rstrip("/")
    var out: Array = []
    var code := OS.execute("/bin/sh", ["-c",
        "ps -A -o pid=,command= | grep -i godot | grep -v 'grep\\|bake_sidekick_thumbnails'"
    ], out, true)
    if code != 0: return false
    var txt: String = out[0] if out.size() > 0 else ""
    var my_pid: int = OS.get_process_id()
    for line in txt.split("\n"):
        line = line.strip_edges()
        if line == "": continue
        # strip leading pid
        var parts: PackedStringArray = line.split(" ", false, 1)
        if parts.size() < 2: continue
        var pid: int = int(parts[0])
        if pid == my_pid: continue
        if project_path in line:
            print("[Baker] detected running editor on this project: pid=%d" % pid)
            return true
    return false
