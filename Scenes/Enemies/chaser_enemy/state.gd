class_name ChaserState
extends Node

#classe de state 
signal transitioned(state: ChaserState, new_state_name: String)


var actor: CharacterBody2D


func enter() -> void:
	pass

func exit() -> void:
	pass

func physics_update(_delta: float) -> void:
	pass


## Player entrou na DetectionArea 
func on_player_spotted(_player: Node2D) -> void:
	pass

## Player saiu da DetectionArea 
func on_player_lost(_player: Node2D) -> void:
	pass

## Player entrou na AttackRange 
func on_player_in_attack_range(_player: Node2D) -> void:
	pass

## Player saiu da AttackRange 
func on_player_left_attack_range(_player: Node2D) -> void:
	pass
