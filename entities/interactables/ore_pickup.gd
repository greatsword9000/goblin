class_name OrePickup extends Area3D
## OrePickup — dropped ore waiting to be hauled.
##
## Spawned by MiningSystem (via tile_mined events) at the cleared tile's
## world position. Carries an ItemComponent declaring its resource type +
## amount. When a minion with a HaulTask touches it (or its task specifies
## this pickup by NodePath), the pickup is consumed and credited to
## ResourceManager.
##
## Visual is a tiny emissive cube per item for now; swap to a Synty gem
## prop when we know the right one.

@export var item_id: String = "copper"
@export var amount: int = 1

@onready var _item: ItemComponent = $ItemComponent


func _ready() -> void:
	if _item != null:
		_item.item_id = item_id
		_item.amount = amount


## Called by the hauling minion — reparent the pickup onto the minion's
## head anchor so it's visibly carried. Disable the trigger area so no
## other minion can grab it mid-haul.
func claim(carrier: Node3D) -> void:
	# Disable the Area3D trigger so we don't match another haul scan.
	monitoring = false
	monitorable = false
	get_parent().remove_child(self)
	carrier.add_child(self)
	# Sit on the goblin's head — above the 1m capsule.
	transform = Transform3D(Basis(), Vector3(0.0, 1.4, 0.0))


## Called on throne delivery.
func consume() -> void:
	queue_free()
