extends Node
## Autoload: renders a PackedScene (or a live Node3D) to a small Texture2D
## via a hidden SubViewport, caches results to disk, and serves them back
## on subsequent requests.
##
## Used by the plug creator's asset browser and the Sidekick character
## customizer — anywhere we need a grid of preview cards.
##
## Usage:
##   var tex := await ThumbnailRenderer.render_async(scene_path)
##   card.texture = tex
##
## Thumbnails are cached at:
##   res://resources/_thumbnails/<sha1-of-path>.png

const CACHE_DIR: String = "res://resources/_thumbnails"
const THUMB_SIZE: Vector2i = Vector2i(128, 128)
## Isometric-ish angle, matches the in-game camera tilt so previews
## read the same as the spawned asset in a scene.
const CAM_ANGLE_DEG: Vector3 = Vector3(-30, 35, 0)
const CAM_DISTANCE_FACTOR: float = 1.9   # multiplier on AABB diagonal

var _viewport: SubViewport = null
var _camera: Camera3D = null
var _scene_root: Node3D = null
var _key_light: DirectionalLight3D = null
var _fill_light: DirectionalLight3D = null

var _in_memory_cache: Dictionary = {}   # res_path -> Texture2D


func _ready() -> void:
	_ensure_cache_dir()
	_build_render_rig()


## Render a scene path to a thumbnail. Returns a cached Texture2D
## immediately if on-disk, or renders-and-caches if not.
## Safe to call before _ready completes on some code paths — we lazily
## build the rig if needed.
func render_sync(scene_path: String) -> Texture2D:
	if _in_memory_cache.has(scene_path):
		return _in_memory_cache[scene_path]
	var cache_path: String = _cache_path_for(scene_path)
	# Disk cache hit.
	if ResourceLoader.exists(cache_path):
		var tex: Texture2D = load(cache_path)
		_in_memory_cache[scene_path] = tex
		return tex
	# Cache miss — render.
	if _viewport == null:
		_build_render_rig()
	var result: Texture2D = _render_to_texture(scene_path)
	if result != null:
		_save_cached(cache_path, result)
		_in_memory_cache[scene_path] = result
	return result


## Async variant that yields a frame so the render rig has time to
## actually composite. Use this from UI code — it prevents frame stalls.
func render_async(scene_path: String) -> Texture2D:
	if _in_memory_cache.has(scene_path):
		return _in_memory_cache[scene_path]
	var cache_path: String = _cache_path_for(scene_path)
	if ResourceLoader.exists(cache_path):
		var tex: Texture2D = load(cache_path)
		_in_memory_cache[scene_path] = tex
		return tex
	if _viewport == null:
		_build_render_rig()
	await get_tree().process_frame
	var result: Texture2D = _render_to_texture(scene_path)
	if result != null:
		_save_cached(cache_path, result)
		_in_memory_cache[scene_path] = result
	return result


## Force-regenerate the cached thumbnail for a scene path. Call after
## editing a prefab's materials or mesh.
func invalidate(scene_path: String) -> void:
	_in_memory_cache.erase(scene_path)
	var cache_path: String = _cache_path_for(scene_path)
	if FileAccess.file_exists(cache_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cache_path))


# ─── Rig ──────────────────────────────────────────────────────────

func _build_render_rig() -> void:
	_viewport = SubViewport.new()
	_viewport.size = THUMB_SIZE
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)

	_scene_root = Node3D.new()
	_scene_root.name = "SubjectRoot"
	_viewport.add_child(_scene_root)

	_key_light = DirectionalLight3D.new()
	_key_light.rotation_degrees = Vector3(-45, 35, 0)
	_key_light.light_energy = 1.2
	_viewport.add_child(_key_light)

	_fill_light = DirectionalLight3D.new()
	_fill_light.rotation_degrees = Vector3(-20, -140, 0)
	_fill_light.light_energy = 0.4
	_fill_light.light_color = Color(0.9, 0.95, 1.0, 1)
	_viewport.add_child(_fill_light)

	_camera = Camera3D.new()
	_camera.rotation_degrees = CAM_ANGLE_DEG
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 30.0
	_viewport.add_child(_camera)


func _render_to_texture(scene_path: String) -> Texture2D:
	if not ResourceLoader.exists(scene_path):
		return null
	# Headless has a dummy rendering server that can't produce textures —
	# short-circuit so callers don't get null-ref spam.
	if DisplayServer.get_name() == "headless":
		return null
	var scene: PackedScene = load(scene_path)
	if scene == null:
		return null
	# Clear any previous subject.
	for c in _scene_root.get_children():
		c.queue_free()
	var subject: Node = scene.instantiate()
	if not (subject is Node3D):
		subject.queue_free()
		return null
	_scene_root.add_child(subject)
	# Frame camera to the AABB of the subject so it fills the shot.
	var aabb: AABB = _aabb_of(subject as Node3D)
	_frame_camera(aabb)
	# Force the viewport to render this frame.
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_sync()
	RenderingServer.force_draw(false)
	var img: Image = _viewport.get_texture().get_image()
	if img == null:
		return null
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex


func _frame_camera(aabb: AABB) -> void:
	if aabb.size == Vector3.ZERO:
		_camera.position = Vector3(2, 2, 2)
		_camera.look_at(Vector3.ZERO, Vector3.UP)
		return
	var center: Vector3 = aabb.position + aabb.size * 0.5
	var radius: float = aabb.size.length() * 0.5
	var dir: Vector3 = Vector3(
		cos(deg_to_rad(CAM_ANGLE_DEG.y)) * cos(deg_to_rad(CAM_ANGLE_DEG.x)),
		-sin(deg_to_rad(CAM_ANGLE_DEG.x)),
		sin(deg_to_rad(CAM_ANGLE_DEG.y)) * cos(deg_to_rad(CAM_ANGLE_DEG.x)),
	).normalized()
	var dist: float = radius * CAM_DISTANCE_FACTOR / tan(deg_to_rad(_camera.fov) * 0.5)
	_camera.position = center + dir * dist
	_camera.look_at(center, Vector3.UP)


func _aabb_of(root: Node3D) -> AABB:
	var out: AABB = AABB()
	var first: bool = true
	for vi in root.find_children("*", "VisualInstance3D", true, false):
		var v: VisualInstance3D = vi
		var world: AABB = v.global_transform * v.get_aabb()
		out = world if first else out.merge(world)
		first = false
	return out


# ─── Disk cache ────────────────────────────────────────────────────

func _ensure_cache_dir() -> void:
	var abs_path: String = ProjectSettings.globalize_path(CACHE_DIR)
	if not DirAccess.dir_exists_absolute(abs_path):
		DirAccess.make_dir_recursive_absolute(abs_path)


func _cache_path_for(scene_path: String) -> String:
	# Use the path's hash so cache filenames are short and safe.
	var hashed: String = scene_path.sha1_text().substr(0, 16)
	return "%s/%s.png" % [CACHE_DIR, hashed]


func _save_cached(cache_path: String, tex: Texture2D) -> void:
	var img: Image = tex.get_image()
	if img == null:
		return
	var abs_path: String = ProjectSettings.globalize_path(cache_path)
	img.save_png(abs_path)
