class_name ThroneDisplay extends Node3D
## ThroneDisplay — scales the throne pile visual as gold accumulates.
##
## Attached to a Node3D placed on the throne tile. Listens to
## EventBus.resource_hauled_to_throne and lerps the visual scale up
## through bands (tiny → small → mound → heap → overflowing).
##
## Reads the target MeshInstance3D from the Synty throne prefab that
## GridWorld already spawned at the throne cell — no duplicate mesh.

@export var item_id_watched: String = "copper"
@export var bands: Array[int] = [1, 10, 30, 80, 200]   # thresholds
@export var band_scales: Array[float] = [0.6, 0.8, 1.0, 1.25, 1.5]
@export var lerp_rate: float = 3.0

var _tracked_total: int = 0
var _target_scale: float = 0.6
var _throne_visual: Node3D = null


func _ready() -> void:
	EventBus.resource_hauled_to_throne.connect(_on_haul)
	_recompute_target()
	scale = Vector3.ONE * _target_scale


## Point at the throne's actual visual so we're scaling the right node
## (GridWorld spawns the visual as a child of its visual_root, not under
## us). StarterDungeon resolves and assigns this after tile placement.
func set_target_visual(n: Node3D) -> void:
	_throne_visual = n


func _on_haul(resource_type: String, _amount: int) -> void:
	if resource_type != item_id_watched:
		return
	_recompute_target()


func _recompute_target() -> void:
	var total: int = ResourceManager.amount(item_id_watched)
	_tracked_total = total
	var chosen: float = band_scales[0]
	for i in range(bands.size()):
		if total >= bands[i] and i < band_scales.size():
			chosen = band_scales[i]
	_target_scale = chosen


func _process(delta: float) -> void:
	if _throne_visual == null:
		return
	var cur: float = _throne_visual.scale.x
	var next: float = lerpf(cur, _target_scale, clampf(lerp_rate * delta, 0.0, 1.0))
	_throne_visual.scale = Vector3.ONE * next * _base_visual_scale()


func _base_visual_scale() -> float:
	# Throne tile .tres has visual_scale = 0.3; we multiply that baseline
	# so the band factors are relative to the authored scale.
	var tile: TileResource = GridWorld.get_tile(GridWorld.tile_at_world(global_position))
	return tile.visual_scale if tile != null else 1.0
