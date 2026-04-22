extends Node
class_name GoalScorers
## GoalScorers — stateless utility functions. Each method takes (agent, sync)
## and returns a float score. Multiplied by GoalDef.weight by the picker.
##
## Rules of thumb:
##   - Return >0 for "this is worth doing"; 0 means not applicable.
##   - -INF to hard-reject.
##   - Keep it read-only. No side effects, no mutations.
##   - Fast. Picker calls this on every event.
##
## Add a new goal? Add a `score_X` here and reference it in a GoalDef.tres.

## "There's work I could claim." Based on pending task count + proximity to
## nearest pending task. Returns 0 if queue is empty.
static func score_claim_task(agent: Node3D, _sync: BlackboardSync) -> float:
	if TaskQueue.pending_count() == 0:
		return 0.0
	# Strong constant baseline — claim_task should outrank wander when work exists
	return 2.0


## Wander when idle. Low baseline so real work preempts. The GoalDef should
## forbid flags like `carried` and `alarm`.
static func score_wander(_agent: Node3D, _sync: BlackboardSync) -> float:
	return 0.1


## Just hang while being carried. Requires `carried == true` (gated in GoalDef).
## Weight should be high so this always wins when the flag is set.
static func score_idle_carried(_agent: Node3D, _sync: BlackboardSync) -> float:
	return 100.0


## Flee on alarm. Requires `alarm == true`. Phase-1 stub: just a constant;
## later this scales by distance to raiders, HP, faction etc.
static func score_flee(_agent: Node3D, _sync: BlackboardSync) -> float:
	return 50.0
