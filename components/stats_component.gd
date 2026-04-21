class_name StatsComponent extends Node
## StatsComponent — HP, combat stats, movement speed, skill levels.
##
## Attach as a child of any entity that can be damaged or do work. Emits
## local signals (damaged, died, healed); systems listen via the entity,
## not through EventBus unless the event is cross-system interesting.

signal damaged(amount: float, attacker: Node)
signal died(killer: Node)
signal healed(amount: float)

@export var max_hp: float = 10.0
@export var attack: float = 2.0
@export var defense: float = 0.0
@export var move_speed: float = 3.0

var current_hp: float

var is_dead: bool = false


func _ready() -> void:
	current_hp = max_hp


## Apply damage. `attacker` is optional context for the death signal and
## any future threat-tracking. Returns actual damage dealt (post-defense).
func take_damage(amount: float, attacker: Node = null) -> float:
	if is_dead:
		return 0.0
	var dealt: float = maxf(1.0, amount - defense)
	current_hp -= dealt
	damaged.emit(dealt, attacker)
	if current_hp <= 0.0:
		is_dead = true
		died.emit(attacker)
	return dealt


func heal(amount: float) -> void:
	if is_dead:
		return
	current_hp = minf(max_hp, current_hp + amount)
	healed.emit(amount)


func hp_fraction() -> float:
	return clampf(current_hp / maxf(max_hp, 0.0001), 0.0, 1.0)
