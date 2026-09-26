class_name TankState
extends Node

#States básicos do inimigo tanqu
var actor: CharacterBody2D

var state_machine: TankStateMachine


## Chamado  no momento em que o estado se torna o atual.

func enter() -> void:
	pass


## Chamado no momento em que este estado deixa de ser o atual.

func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func update(_delta: float) -> void:
	pass
