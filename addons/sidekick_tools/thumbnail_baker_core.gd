@tool
extends Node
## Shared thumbnail-baking logic. Used by:
##   - addons/sidekick_tools/sidekick_tools_plugin.gd (in-editor, preferred)
##   - _tools/bake_sidekick_thumbnails.gd              (standalone, CI)
##
## Renders each Sidekick part into a 128×128 PNG under
## res://assets/sidekick/goblin_fighters/thumbnails/<part_name>.png
##
## Caller passes a `host` Node whose tree we use for the SubViewport so
## the renderer has a valid scene context. In the editor plugin that's the
## currently-edited scene root (falls back to a temporary tree node).

const THUMB_DIR := "res://assets/sidekick/goblin_fighters/thumbnails"
const THUMB_SIZE := Vector2i(128, 128)
const BG_COLOR := Color(0.15, 0.17, 0.22, 1.0)
const CAM_PADDING := 1.25


func run(host: Node, force: bool = false) -> Dictionary:
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(THUMB_DIR))

    var lib: Node = Engine.get_main_loop().root.get_node_or_null("SidekickPartLibrary")
    if lib == null:
        # Editor doesn't instantiate autoloads the same way at edit-time. Load directly.
        var LibScript := preload("res://resources/character/sidekick_part_library.gd")
        lib = LibScript.new()
        host.add_child(lib)
        # lib._ready() will fire async; wait
        await Engine.get_main_loop().process_frame
        await Engine.get_main_loop().process_frame

    var tree_root: Node = host if host else Engine.get_main_loop().root
    var vp: SubViewport = _build_viewport()
    tree_root.add_child(vp)

    var cam: Camera3D = vp.get_node("Camera3D")

    var baked := 0
    var skipped := 0
    var failed := 0

    var parts_list: Array = []
    for slot in lib.all_slots():
        for p in lib.parts_for_slot(slot):
            parts_list.append(p)

    print("[Baker] %d parts to process (force=%s)" % [parts_list.size(), force])

    var i := 0
    for entry in parts_list:
        var out_path: String = "%s/%s.png" % [THUMB_DIR, entry.name]
        var out_abs: String = ProjectSettings.globalize_path(out_path)

        if not force and FileAccess.file_exists(out_path):
            skipped += 1
            i += 1
            continue

        if not ResourceLoader.exists(entry.res_path):
            push_warning("[Baker] missing FBX: %s" % entry.res_path)
            failed += 1
            i += 1
            continue

        var scene: PackedScene = ResourceLoader.load(entry.res_path) as PackedScene
        if scene == null:
            failed += 1
            i += 1
            continue

        var inst := scene.instantiate()
        vp.add_child(inst)

        await Engine.get_main_loop().process_frame
        await Engine.get_main_loop().process_frame

        var aabb := _compute_world_aabb(inst)
        if aabb.size.length() < 0.001:
            inst.queue_free()
            failed += 1
            i += 1
            continue
        _frame_camera(cam, aabb)

        vp.render_target_update_mode = SubViewport.UPDATE_ONCE
        await Engine.get_main_loop().process_frame
        await Engine.get_main_loop().process_frame
        await RenderingServer.frame_post_draw

        var img: Image = vp.get_texture().get_image()
        if img == null or img.is_empty():
            failed += 1
        else:
            var err := img.save_png(out_abs)
            if err == OK:
                baked += 1
            else:
                failed += 1

        inst.queue_free()
        await Engine.get_main_loop().process_frame

        i += 1
        if i % 25 == 0:
            print("[Baker] %d / %d (baked=%d skipped=%d failed=%d)" % [i, parts_list.size(), baked, skipped, failed])

    vp.queue_free()
    var result := {"baked": baked, "skipped": skipped, "failed": failed}
    print("[Baker] DONE — baked=%d skipped=%d failed=%d" % [baked, skipped, failed])
    return result


func _build_viewport() -> SubViewport:
    var vp := SubViewport.new()
    vp.size = THUMB_SIZE
    vp.transparent_bg = false
    vp.own_world_3d = true
    vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    vp.msaa_3d = Viewport.MSAA_4X

    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = BG_COLOR
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.85, 0.85, 0.9)
    env.ambient_light_energy = 0.65
    env_node.environment = env
    vp.add_child(env_node)

    var key := DirectionalLight3D.new()
    key.transform = Transform3D().rotated(Vector3.RIGHT, deg_to_rad(-35)).rotated(Vector3.UP, deg_to_rad(30))
    key.light_energy = 1.1
    vp.add_child(key)

    var cam := Camera3D.new()
    cam.name = "Camera3D"
    cam.current = true
    vp.add_child(cam)
    return vp


func _compute_world_aabb(n: Node) -> AABB:
    var out: AABB
    var first := true
    for c in _all_descendants(n):
        if c is MeshInstance3D:
            var mi: MeshInstance3D = c
            if mi.mesh == null: continue
            var ab := mi.get_aabb()
            ab = mi.global_transform * ab
            if first:
                out = ab
                first = false
            else:
                out = out.merge(ab)
    return out


func _all_descendants(n: Node) -> Array:
    var out: Array = [n]
    for c in n.get_children():
        out.append_array(_all_descendants(c))
    return out


func _frame_camera(cam: Camera3D, aabb: AABB) -> void:
    var center := aabb.position + aabb.size * 0.5
    var radius := aabb.size.length() * 0.5 * CAM_PADDING
    var dir := Vector3(0.6, 0.3, 1.0).normalized()
    var fov_rad := deg_to_rad(cam.fov)
    var dist := maxf(radius / sin(fov_rad * 0.5), 0.5)
    cam.position = center + dir * dist
    cam.look_at(center, Vector3.UP)
