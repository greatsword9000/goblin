extends Node
## RaidDirector — decides when and what adventurer squads spawn.
##
## Owns: upcoming raid composition, spawn-debt accumulator.
## Listens to: EventBus.ruckus_threshold_crossed, ready_button input (TODO — M09).
##
## TODO(M09): compose_squad(), spawn_squad(), intensity curves (port from PS AI Director).
