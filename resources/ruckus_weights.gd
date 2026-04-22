class_name RuckusWeights extends Resource
## Editable weights table. Each EventBus signal contributes its weight to
## the Ruckus meter when fired. Values are fractions of the full meter
## (0.0 = no contribution, 1.0 = instant threshold).
##
## Keys MUST match EventBus signal names exactly. Missing keys = 0.

@export var weights: Dictionary = {
	"tile_mined": 0.02,
	"tile_built": 0.04,
	"minion_died": 0.06,
	"adventurer_died": 0.15,
	"minion_slapped": 0.01,
	"resource_hauled_to_throne": 0.005,
}

## Thresholds at which RuckusManager fires ruckus_threshold_crossed. Must
## be ascending. 1.0 is the full-meter trigger (raid in M09).
@export var thresholds: Array[float] = [0.25, 0.5, 0.75, 0.9, 1.0]

## Contributor log window — top-N contributors retained for debug overlay.
@export var contributor_log_size: int = 32


func weight_for(event_name: String) -> float:
	return float(weights.get(event_name, 0.0))
