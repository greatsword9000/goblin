class_name ReactionEntry extends Resource
## ReactionEntry — one (event → lines) mapping inside a ReactionTable.
##
## event_key is the EventBus signal name (e.g. "tile_built"). Lines is
## a pool of short bark strings; one is picked at random on trigger.

@export var event_key: String = ""
@export var lines: Array[String] = []
