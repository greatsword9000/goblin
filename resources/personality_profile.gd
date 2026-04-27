class_name PersonalityProfile extends Resource
## PersonalityProfile — per-minion personality axes.
##
## Four axes on a 0-1 scale. Each is rolled independently on spawn via
## normal distribution centered on 0.5. Downstream systems consume these
## to bias idle-behavior selection, bark frequency, reaction intensity.
##
## Phase 1 uses this for inspection UI + flavored idle variant picking.
## Future phases expand into dialogue / equipment preference / morale.

@export var cheerful: float = 0.5  ## Humming, waving, dancing vs. stoic silence.
@export var grumpy: float = 0.5    ## Kicks stones, crosses arms, mutters.
@export var curious: float = 0.5   ## Peers around, stares at the kid.
@export var lazy: float = 0.5      ## Longer rests, leans against walls.


## Summarize the top 1-2 axes as a short descriptor for inspection UI.
## Example: "cheerful, curious, a bit of a coward".
func summary() -> String:
	var axes: Array = [
		{"name": "cheerful", "value": cheerful},
		{"name": "grumpy", "value": grumpy},
		{"name": "curious", "value": curious},
		{"name": "lazy", "value": lazy},
	]
	axes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["value"]) > float(b["value"]))
	var out: Array = []
	for entry: Dictionary in axes:
		if float(entry["value"]) >= 0.6:
			out.append(str(entry["name"]))
	if out.is_empty():
		return "unremarkable"
	return ", ".join(out)
