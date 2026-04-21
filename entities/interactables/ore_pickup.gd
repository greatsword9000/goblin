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


func claim() -> void:
	# Called by the hauling minion when they pick us up. For M06 the
	# pickup just disappears — later it'll parent to the minion's hand.
	queue_free()
