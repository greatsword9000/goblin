extends Node3D
## HoverHighlighter — cursor target indicator.
##
## Uses a Decal for floor / entity highlights so the projection handles
## whatever Y the floor mesh actually sits at (Synty FBX prefabs have
## internal transforms we don't control). Decals project downward in
## their local -Y direction within their `size` AABB, regardless of
## underlying geometry.
##
## Walls use a translucent BoxMesh wrap since we author the wall
## primitive ourselves and know its exact position/size.
##
## Reference: https://docs.godotengine.org/en/stable/classes/class_decal.html

class_name HoverHighlighter

const RAY_LENGTH: float = 80.0
const PHYSICS_MASK: int = 1 | 2 | 16  # World + Minions + Pickups

const COLOR_GRABBABLE: Color = Color(0.35, 1.0, 0.45, 1.0)
const COLOR_MINEABLE:  Color = Color(1.0, 0.72, 0.25, 1.0)
const COLOR_WALKABLE:  Color = Color(0.45, 0.75, 1.0, 1.0)

@export var camera_source: Node

var _decal: Decal
var _wall_box: MeshInstance3D
var _wall_material: StandardMaterial3D


func _ready() -> void:
	_decal = Decal.new()
	# Size = AABB extent. X/Z cover one cell; Y is projection depth from
	# the decal origin downward — plenty to reach the floor from above.
	_decal.size = Vector3(GridWorld.CELL_SIZE, 6.0, GridWorld.CELL_SIZE)
	_decal.texture_albedo = _make_solid_texture(Color.WHITE)
	_decal.albedo_mix = 0.9
	_decal.modulate = COLOR_WALKABLE
	_decal.emission_energy = 1.0
	_decal.upper_fade = 0.05
	_decal.lower_fade = 0.05
	_decal.top_level = true
	_decal.visible = false
	add_child(_decal)

	_wall_material = StandardMaterial3D.new()
	_wall_material.albedo_color = COLOR_MINEABLE
	_wall_material.albedo_color.a = 0.40
	_wall_material.emission_enabled = true
	_wall_material.emission = COLOR_MINEABLE
	_wall_material.emission_energy_multiplier = 0.5
	_wall_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_wall_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_wall_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Draw after opaque but don't write depth — avoids z-fight with the
	# wall mesh we're wrapping.
	_wall_material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(
		GridWorld.CELL_SIZE * 1.04,
		GridWorld.CELL_SIZE * 1.04,
		GridWorld.CELL_SIZE * 1.04,
	)
	_wall_box = MeshInstance3D.new()
	_wall_box.mesh = box
	_wall_box.material_override = _wall_material
	_wall_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall_box.top_level = true
	_wall_box.visible = false
	add_child(_wall_box)


## Build a 1x1 white pixel texture — decal needs an albedo, and we tint
## via `modulate` to keep one texture reusable across colors.
func _make_solid_texture(c: Color) -> ImageTexture:
	var img: Image = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(c)
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null:
		_hide_all()
		return

	var mouse: Vector2 = get_viewport().get_mouse_position()
	var from: Vector3 = cam.project_ray_origin(mouse)
	var dir: Vector3 = cam.project_ray_normal(mouse)
	var params := PhysicsRayQueryParameters3D.create(
		from, from + dir * RAY_LENGTH, PHYSICS_MASK,
	)
	var hit := cam.get_world_3d().direct_space_state.intersect_ray(params)

	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		var grabbable: Node3D = _resolve_highlight_target(collider as Node)
		if grabbable != null:
			_show_decal_over(grabbable.global_position, COLOR_GRABBABLE)
			return

		var hit_pos: Vector3 = hit.get("position", Vector3.ZERO)
		var grid_pos: Vector3i = GridWorld.tile_at_world(hit_pos)
		var tile: TileResource = GridWorld.get_tile(grid_pos)
		var visual: Node3D = GridWorld.get_visual(grid_pos)
		if tile != null and visual != null:
			if tile.is_mineable:
				_show_wall_box(visual.global_position, COLOR_MINEABLE)
				return
			if tile.is_walkable:
				_show_decal_over(visual.global_position, COLOR_WALKABLE)
				return

	# Past the dungeon edge — use math y=0 intersection.
	if camera_source != null and camera_source.has_method("cursor_world_position"):
		var fallback_pos: Vector3 = camera_source.call("cursor_world_position")
		var cell2: Vector3i = GridWorld.tile_at_world(fallback_pos)
		var visual2: Node3D = GridWorld.get_visual(cell2)
		var tile2: TileResource = GridWorld.get_tile(cell2)
		if visual2 != null and tile2 != null:
			if tile2.is_mineable:
				_show_wall_box(visual2.global_position, COLOR_MINEABLE)
				return
			if tile2.is_walkable:
				_show_decal_over(visual2.global_position, COLOR_WALKABLE)
				return
	_hide_all()


## Project a decal down onto whatever's below the target cell's XZ.
## `base_pos` is any point whose XZ identifies the cell — we position the
## decal well above it so its AABB reaches down onto the floor / entity.
func _show_decal_over(base_pos: Vector3, color: Color) -> void:
	_decal.global_position = Vector3(base_pos.x, base_pos.y + 3.0, base_pos.z)
	_decal.modulate = color
	_decal.visible = true
	_wall_box.visible = false


func _show_wall_box(wall_center: Vector3, color: Color) -> void:
	_wall_box.global_position = wall_center
	_wall_material.albedo_color = Color(color.r, color.g, color.b, 0.40)
	_wall_material.emission = color
	_wall_box.visible = true
	_decal.visible = false


func _hide_all() -> void:
	_decal.visible = false
	_wall_box.visible = false


func _resolve_highlight_target(node: Node) -> Node3D:
	var cursor: Node = node
	for _i in range(4):
		if cursor == null:
			break
		if cursor is Minion or cursor is OrePickup:
			return cursor as Node3D
		cursor = cursor.get_parent()
	return null
