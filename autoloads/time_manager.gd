extends Node
## TimeManager — owns pause state and scaled game time.
##
## Owns: pause flag, time_scale, accumulated playtime.
## Listens to: EventBus.game_paused / game_resumed (TODO).
##
## TODO(M00+): pause gating, time-scale for slow-mo, playtime accumulator.

var playtime_seconds: float = 0.0
var is_paused: bool = false

func _process(delta: float) -> void:
	if not is_paused:
		playtime_seconds += delta
