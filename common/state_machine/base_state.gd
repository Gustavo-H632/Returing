class_name BaseState
extends Node
## Estado genérico: todo estado de inimigo herda desta classe.

@warning_ignore("unused_signal")
signal transition_requested(state_name: StringName)

var actor: Node = null
var state_machine: BaseStateMachine = null


## Chamado pela máquina uma única vez, ao registrar o estado.
func setup(machine: BaseStateMachine, owner_actor: Node) -> void:
	state_machine = machine
	actor = owner_actor
	_on_setup()


## Gancho para subclasses converterem o ator para o tipo concreto.
func _on_setup() -> void:
	pass


## Ao entrar no estado.
func enter() -> void:
	pass


## Ao sair do estado.
func exit() -> void:
	pass


## Frame de física.
func physics_update(_delta: float) -> void:
	pass


## Frame normal (só com run_process_update).
func update(_delta: float) -> void:
	pass


## True se é o estado atual.
func is_current() -> bool:
	return state_machine != null and state_machine.current_state == self


## Pede a troca de estado; ignorada se este deixou de ser o estado atual.
func request_transition(state_name: StringName) -> void:
	if is_current():
		state_machine.transition_to(state_name)
