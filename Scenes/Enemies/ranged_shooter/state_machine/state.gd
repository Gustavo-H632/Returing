class_name ShooterState
extends Node
#Classe de state machine
signal transition_requested(state_name: String)


var enemy: RangedEnemy


## Chamado quando o state vira o state atual.
func enter() -> void:
	pass


## Chamado quanjdo o state atual muda
func exit() -> void:
	pass


## Chamado a cada _physicsprocess
func physics_update(_delta: float) -> void:
	pass
