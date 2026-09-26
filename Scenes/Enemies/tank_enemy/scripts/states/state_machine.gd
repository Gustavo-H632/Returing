class_name TankStateMachine
extends Node

## TankStateMachine nsições.

@export var initial_state: TankState

var current_state: TankState
var states: Dictionary = {} 

## Emitido sempre que o estado atual muda. 
signal state_changed(new_state_name: String)



func setup(owner_actor: CharacterBody2D) -> void:
	for child in get_children():
		if child is TankState:
			states[child.name.to_lower()] = child
			child.state_machine = self
			child.actor = owner_actor

	# Garante o idle
	if not initial_state and states.has("idle"):
		initial_state = states["idle"]

	if initial_state:
		current_state = initial_state
		current_state.enter()
	else:
		push_warning("TankStateMachine: nenhum estado inicial encontrado/definido.")


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)


func transition_to(state_name: String) -> void:
	var key := state_name.to_lower()
	var new_state: TankState = states.get(key)

	if not new_state:
		push_warning("TankStateMachine: estado '%s' não encontrado." % state_name)
		return
	if new_state == current_state:
		return 

	if current_state:
		current_state.exit()

	current_state = new_state
	current_state.enter()
	state_changed.emit(new_state.name)
