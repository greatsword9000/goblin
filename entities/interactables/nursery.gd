class_name Nursery extends Node3D
## Nursery — hatches new goblin workers on a cadence up to a global cap.
##
## Placed by M08 BuildingSystem. Reads MinionDefinition for the spawn target;
## StarterDungeon (or BuildingSystem) assigns it after instantiation.

@export var hatch_cadence_seconds: float = 120.0
@export var global_minion_cap: int = 8
@export var minion_definition: MinionDefinition = null

var _time_since_last_hatch: float = 0.0


func _ready() -> void:
	_build_visual()
	if minion_definition == null:
		var res: Resource = load("res://resources/minions/goblin_worker.tres")
		if res is MinionDefinition:
			minion_definition = res


func _build_visual() -> void:
	var wood_color := Color(0.30, 0.18, 0.10)
	var egg_color := Color(0.85, 0.78, 0.55)
	# Alcove base — shallow box
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.4, 0.2, 1.4)
	base.mesh = base_mesh
	var bm := StandardMaterial3D.new()
	bm.albedo_color = wood_color
	base.material_override = bm
	base.position = Vector3(0.0, 0.1, 0.0)
	add_child(base)
	# Three eggs clustered on top
	var egg_offsets := [
		Vector3(-0.25, 0.0,  0.0),
		Vector3( 0.25, 0.0, -0.15),
		Vector3( 0.05, 0.0,  0.25),
	]
	for o: Vector3 in egg_offsets:
		var egg := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.18
		sphere.height = 0.44
		egg.mesh = sphere
		var em := StandardMaterial3D.new()
		em.albedo_color = egg_color
		em.emission_enabled = true
		em.emission = egg_color
		em.emission_energy_multiplier = 0.4
		egg.material_override = em
		egg.position = o + Vector3(0.0, 0.38, 0.0)
		add_child(egg)


func _process(delta: float) -> void:
	if _at_cap():
		return
	_time_since_last_hatch += delta
	if _time_since_last_hatch >= hatch_cadence_seconds:
		_time_since_last_hatch = 0.0
		_hatch()


func _at_cap() -> bool:
	return get_tree().get_nodes_in_group("minions").size() >= global_minion_cap


func _hatch() -> void:
	if minion_definition == null or minion_definition.scene == null:
		push_warning("[Nursery] missing minion_definition or scene — cannot hatch")
		return
	var minion: Node3D = minion_definition.scene.instantiate()
	if minion is Minion:
		(minion as Minion).definition = minion_definition
	# Parent under the scene root so it lives in world-space next to us.
	get_parent().add_child(minion)
	minion.global_position = global_position
	print("[Nursery] hatched goblin_worker at %s" % global_position)
