class_name ReactionTable extends Resource
## ReactionTable — bundle of ReactionEntries a ReactionComponent consults.
##
## Swap in different tables per minion archetype (grumpy vs chatty) by
## assigning a different table resource in the Inspector. Phase 1 ships
## a single default (reactions_default.tres).

@export var entries: Array[ReactionEntry] = []


func lines_for(event_key: String) -> Array[String]:
	for e: ReactionEntry in entries:
		if e != null and e.event_key == event_key:
			return e.lines
	return []
