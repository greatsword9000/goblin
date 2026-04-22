@tool
extends BTAction
## BTWaitDuration — wait for `duration` seconds, then SUCCESS. Local version
## (LimboAI ships BTWait; we duplicate so our tree builder doesn't depend on
## ClassDB.instantiate lookups for a trivial node).

@export var duration: float = 1.0

var _t: float = 0.0


func _generate_name() -> String:
	return "Wait  %.2fs" % duration


func _enter() -> void:
	_t = 0.0


func _tick(delta: float) -> Status:
	_t += delta
	if _t >= duration:
		return SUCCESS
	return RUNNING
