class_name ItemComponent extends Node
## ItemComponent — marks an entity as a carryable item with a resource type.
##
## Minions with a HaulTask carry these to the throne. Hauling is "pick up
## in minion's hand, walk to throne, vanish, credit stockpile."

@export var item_id: String = "copper"
@export var amount: int = 1
