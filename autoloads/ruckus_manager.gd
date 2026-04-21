extends Node
## RuckusManager — noise/notoriety meter that drives raid pacing.
##
## Owns: current ruckus value (0.0–1.0), threshold tracking, weights table.
## Listens to: EventBus events tagged in the weights table (tile_mined, etc.) (TODO — M07).
##
## TODO(M07): add_ruckus(amount, source), threshold crossings, weights.tres.

var value: float = 0.0
