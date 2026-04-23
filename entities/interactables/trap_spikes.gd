class_name TrapSpikes extends Area3D
## Spike trap — fires on adventurer contact, deals damage, cools down.
##
## Physics: collision_layer=Traps(6), collision_mask=Adventurers(3). Set in
## the .tscn. Layer bits: 6→32, 3→4.

const DAMAGE_PER_HIT: float = 5.0
const COOLDOWN_SECONDS: float = 1.5

var _armed: bool = true
var _cooldown_left: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_build_visual()
	_build_collision()


func _build_visual() -> void:
	var spike_color := Color(0.75, 0.75, 0.80)
	var base_color := Color(0.18, 0.16, 0.14)
	# Base plate
	var base := MeshInstance3D.new()
	var plate := BoxMesh.new()
	plate.size = Vector3(1.6, 0.1, 1.6)
	base.mesh = plate
	var bm := StandardMaterial3D.new()
	bm.albedo_color = base_color
	base.material_override = bm
	base.position = Vector3(0.0, 0.05, 0.0)
	add_child(base)
	# Four spikes
	var offsets := [
		Vector3(-0.3, 0.0, -0.3),
		Vector3( 0.3, 0.0, -0.3),
		Vector3(-0.3, 0.0,  0.3),
		Vector3( 0.3, 0.0,  0.3),
	]
	for o: Vector3 in offsets:
		var spike := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.12
		cone.height = 0.55
		spike.mesh = cone
		var sm := StandardMaterial3D.new()
		sm.albedo_color = spike_color
		sm.metallic = 0.4
		spike.material_override = sm
		spike.position = o + Vector3(0.0, 0.37, 0.0)
		add_child(spike)


func _build_collision() -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.6, 0.6, 1.6)
	cs.shape = box
	cs.position = Vector3(0.0, 0.3, 0.0)
	add_child(cs)


func _on_body_entered(body: Node3D) -> void:
	if not _armed:
		return
	if not body.is_in_group("adventurers"):
		return
	var stats: StatsComponent = body.get_node_or_null("StatsComponent") as StatsComponent
	if stats == null:
		return
	stats.take_damage(DAMAGE_PER_HIT, null)
	_armed = false
	_cooldown_left = COOLDOWN_SECONDS


func _process(delta: float) -> void:
	if _armed:
		return
	_cooldown_left -= delta
	if _cooldown_left <= 0.0:
		_armed = true
