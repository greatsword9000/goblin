extends Node
## TaskQueue — central backlog of work for minions.
##
## Owns: pending TaskResource list, utility-scored assignment.
## Listens to: nothing directly — systems call add_task().
##
## TODO(M04): add_task(), claim_next(minion), complete_task(), utility scoring.

var _pending: Array = []  # Array[TaskResource] once TaskResource exists
