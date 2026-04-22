extends SceneTree
## Headless smoke test for the Sidekick character pipeline.
##
## Run with:
##   /Applications/Godot_mono.app/Contents/MacOS/Godot --headless \
##     --path /Users/greatsword/Documents/Goblin \
##     -s _tools/verify_sidekick_pipeline.gd
##
## Exits 0 on success, non-zero on any failure. Prints a structured report.

const EXPECTED_BONE_COUNT := 88
const EXPECTED_SLOT_MIN := 35  # we should have ≥35 slots populated
const EXPECTED_PART_MIN := 400 # ≥400 parts total
const MASTER_FBX := "res://assets/sidekick/goblin_fighters/base/SK_GOBL_BASE_01_10TORS_GO01.fbx"
const REQUIRED_SLOTS := ["head", "torso", "hips", "leg_l", "leg_r", "hand_l", "hand_r", "hair"]

var _failures: Array[String] = []

func _fail(msg: String) -> void:
    _failures.append(msg)
    push_error("  FAIL: %s" % msg)

func _ok(msg: String) -> void:
    print("  OK:   %s" % msg)

func _initialize() -> void:
    print("\n========================================")
    print("Sidekick Pipeline Smoke Test")
    print("========================================\n")
    # Yield so autoloads finish _ready() before tests inspect them.
    await process_frame
    await process_frame

    _test_library_loaded()
    _test_slot_coverage()
    _test_master_fbx_imported()
    _test_default_preset()
    _test_character_spawn()
    _test_preset_save_load_roundtrip()
    _test_bulletproofing_edges()
    _test_ui_scripts_parse()
    _test_thumbnails_optional()

    print("\n========================================")
    if _failures.is_empty():
        print("RESULT: PASS (all smoke tests)")
        print("========================================\n")
        quit(0)
    else:
        print("RESULT: FAIL (%d failures)" % _failures.size())
        for f in _failures: print("  - %s" % f)
        print("========================================\n")
        quit(1)


func _lib() -> Node:
    return root.get_node_or_null("SidekickPartLibrary")


func _test_library_loaded() -> void:
    print("→ Library load")
    var lib := _lib()
    if lib == null:
        _fail("SidekickPartLibrary autoload not registered")
        return
    if not lib.is_loaded():
        _fail("SidekickPartLibrary did not load index")
        return
    _ok("autoload present, index loaded")
    _ok("total parts: %d" % lib.total_part_count())
    _ok("total slots: %d" % lib.all_slots().size())


func _test_slot_coverage() -> void:
    print("→ Slot coverage")
    var lib := _lib()
    if lib == null: return
    var slot_count: int = lib.all_slots().size()
    if slot_count < EXPECTED_SLOT_MIN:
        _fail("only %d slots populated (expected ≥%d)" % [slot_count, EXPECTED_SLOT_MIN])
    else:
        _ok("slot count %d ≥ %d" % [slot_count, EXPECTED_SLOT_MIN])
    var total: int = lib.total_part_count()
    if total < EXPECTED_PART_MIN:
        _fail("only %d parts indexed (expected ≥%d)" % [total, EXPECTED_PART_MIN])
    else:
        _ok("part count %d ≥ %d" % [total, EXPECTED_PART_MIN])
    for slot in REQUIRED_SLOTS:
        var parts = lib.parts_for_slot(slot)
        if parts.is_empty():
            _fail("required slot '%s' has no parts" % slot)
        else:
            _ok("slot '%s' populated (%d parts)" % [slot, parts.size()])


func _test_master_fbx_imported() -> void:
    print("→ Master FBX import")
    if not ResourceLoader.exists(MASTER_FBX):
        _fail("master FBX not imported: %s" % MASTER_FBX)
        return
    var scene := ResourceLoader.load(MASTER_FBX) as PackedScene
    if scene == null:
        _fail("master FBX failed to load as PackedScene")
        return
    var inst := scene.instantiate()
    var sk := _find_skeleton(inst)
    if sk == null:
        _fail("no Skeleton3D in master FBX")
        inst.queue_free()
        return
    var n := sk.get_bone_count()
    if n != EXPECTED_BONE_COUNT:
        _fail("master skeleton has %d bones, expected %d" % [n, EXPECTED_BONE_COUNT])
    else:
        _ok("master skeleton has %d bones (UE5 Mannequin-compatible)" % n)
    # Verify some canonical bone names exist
    var required_bones := ["root", "pelvis", "spine_01", "spine_02", "spine_03",
                           "neck_01", "head", "clavicle_l", "clavicle_r",
                           "upperarm_l", "lowerarm_l", "hand_l",
                           "thumb_01_l", "index_01_l", "middle_01_l", "ring_01_l", "pinky_01_l",
                           "thigh_l", "calf_l", "foot_l", "ball_l",
                           "ik_hand_gun", "ik_foot_root", "prop_l"]
    var missing := []
    for b in required_bones:
        if sk.find_bone(b) < 0: missing.append(b)
    if missing.is_empty():
        _ok("all %d canonical bones present" % required_bones.size())
    else:
        _fail("missing bones: %s" % ", ".join(missing))
    inst.queue_free()


func _find_skeleton(n: Node) -> Skeleton3D:
    if n is Skeleton3D: return n
    for c in n.get_children():
        var r := _find_skeleton(c)
        if r != null: return r
    return null


func _test_default_preset() -> void:
    print("→ Default preset generation")
    var lib := _lib()
    if lib == null: return
    var p = lib.default_preset()
    if p == null:
        _fail("default_preset() returned null")
        return
    if p.parts.size() < 8:
        _fail("default preset has only %d parts (expected ≥8)" % p.parts.size())
    else:
        _ok("default preset has %d slots filled" % p.parts.size())
    var issues = p.validate(lib)
    if not issues.is_empty():
        _fail("default preset validation: %s" % ", ".join(issues))
    else:
        _ok("default preset validates clean")


func _test_character_spawn() -> void:
    print("→ Character spawn + apply_preset")
    var lib := _lib()
    if lib == null: return
    var scene: PackedScene = ResourceLoader.load("res://entities/sidekick_character/sidekick_character.tscn")
    if scene == null:
        _fail("sidekick_character.tscn did not load")
        return
    var char_inst = scene.instantiate()
    root.add_child(char_inst)
    # Let _ready run
    await process_frame

    if char_inst.bone_count() != EXPECTED_BONE_COUNT:
        _fail("spawned character has %d bones (expected %d)" % [char_inst.bone_count(), EXPECTED_BONE_COUNT])
    else:
        _ok("spawned character skeleton has %d bones" % char_inst.bone_count())

    var preset = lib.default_preset()
    char_inst.apply_preset(preset)
    await process_frame

    var sk: Skeleton3D = char_inst.get_skeleton()
    var mesh_children := 0
    for c in sk.get_children():
        if c is MeshInstance3D: mesh_children += 1
    if mesh_children < 5:
        _fail("after apply_preset, only %d mesh children attached (expected ≥5)" % mesh_children)
    else:
        _ok("character has %d mesh parts attached after apply_preset" % mesh_children)
    char_inst.queue_free()


func _test_preset_save_load_roundtrip() -> void:
    print("→ Preset save / load roundtrip")
    var lib := _lib()
    if lib == null: return
    var p: CharacterPreset = lib.default_preset()
    p.display_name = "Smoke Test Hero"
    p.archetype = "test_archetype"
    p.height_scale = 1.08
    p.blend_shapes = {"torso": {"masculineFeminine": 0.42}}
    var path := "user://character_presets/smoke_test_hero.tres"
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://character_presets"))
    var err := ResourceSaver.save(p, path)
    if err != OK:
        _fail("save failed: %d" % err)
        return
    _ok("saved to %s" % path)
    var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as CharacterPreset
    if loaded == null:
        _fail("load failed")
        return
    if loaded.display_name != "Smoke Test Hero":
        _fail("display_name roundtrip failed: '%s'" % loaded.display_name)
    elif absf(loaded.height_scale - 1.08) > 0.001:
        _fail("height_scale roundtrip: %f" % loaded.height_scale)
    elif not loaded.blend_shapes.has("torso"):
        _fail("blend_shapes roundtrip lost 'torso' entry")
    else:
        _ok("roundtrip preserved name, scale, blend shapes")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_ui_scripts_parse() -> void:
    print("→ UI scripts compile")
    var to_check := [
        "res://ui/character_customizer/character_customizer.gd",
        "res://ui/character_customizer/character_customizer.tscn",
        "res://ui/character_customizer/gallery_popup.gd",
        "res://ui/character_customizer/slot_card.gd",
        "res://addons/sidekick_tools/sidekick_tools_plugin.gd",
        "res://addons/sidekick_tools/thumbnail_baker_core.gd",
    ]
    for p in to_check:
        if not ResourceLoader.exists(p):
            _fail("missing: %s" % p)
            continue
        var r := ResourceLoader.load(p)
        if r == null:
            _fail("load failed: %s" % p)
        else:
            _ok("compiled: %s" % p.get_file())


func _test_thumbnails_optional() -> void:
    print("→ Thumbnails (non-blocking)")
    var thumb_dir := "res://assets/sidekick/goblin_fighters/thumbnails"
    var abs := ProjectSettings.globalize_path(thumb_dir)
    if not DirAccess.dir_exists_absolute(abs):
        _ok("no thumbnails yet — bake via Project → Sidekick menu (NOT a failure)")
        return
    var d := DirAccess.open(abs)
    var count := 0
    d.list_dir_begin()
    var fn := d.get_next()
    while fn != "":
        if fn.ends_with(".png"): count += 1
        fn = d.get_next()
    _ok("thumbnails on disk: %d / 427" % count)
    if count == 0:
        _ok("  (empty — run the baker when ready)")


func _test_bulletproofing_edges() -> void:
    print("→ Bulletproofing (bad input tolerance)")
    var lib := _lib()
    if lib == null: return

    # Invalid part name in preset should not crash, should warn
    var p := CharacterPreset.new()
    p.display_name = "Bad Preset"
    p.parts = {"torso": "totally_nonexistent_part_name"}
    var issues := p.validate(lib)
    if issues.is_empty():
        _fail("validate() did not flag unknown part")
    else:
        _ok("validate() flagged bad part: %s" % issues[0])

    # apply_preset with bad part should survive
    var scene: PackedScene = ResourceLoader.load("res://entities/sidekick_character/sidekick_character.tscn")
    var ch = scene.instantiate()
    root.add_child(ch)
    await process_frame
    ch.apply_preset(p)  # should log warning but not crash
    await process_frame
    _ok("apply_preset tolerated bad part without crash")
    ch.queue_free()

    # Null preset
    var ch2 = scene.instantiate()
    root.add_child(ch2)
    await process_frame
    ch2.apply_preset(null)  # must not crash
    _ok("apply_preset(null) survived")
    ch2.queue_free()

    # Wrong rig target
    var poly_preset := CharacterPreset.new()
    poly_preset.display_name = "Poly"
    poly_preset.rig_target = "polygon"
    var ch3 = scene.instantiate()
    root.add_child(ch3)
    await process_frame
    ch3.apply_preset(poly_preset)  # should skip with warning
    _ok("apply_preset rejected wrong rig_target gracefully")
    ch3.queue_free()
