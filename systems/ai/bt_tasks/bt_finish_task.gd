@tool
extends BTAction
## BTFinishTask — calls TaskComponent.finish_task(success). Terminal node.

@export var success: bool = true


func _generate_name() -> String:
	return "FinishTask  success=%s" % success


func _tick(_delta: float) -> Status:
	var tc: Node = agent.get_node_or_null("TaskComponent")
	if tc != null:
		tc.call("finish_task", success)
	blackboard.set_var(&"task", null)
	return SUCCESS if success else FAILURE
