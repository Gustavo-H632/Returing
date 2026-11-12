class_name BaseState
extends Node
## Estado genérico: todo estado de inimigo herda desta classe.

@warning_ignore("unused_signal")  # Silencia o aviso de sinal sem uso (a máquina escuta pelo código).
signal transition_requested(state_name: StringName)  # Pede à máquina para trocar de estado.

var actor: Node = null  # Dono do estado (o inimigo).
var state_machine: BaseStateMachine = null  # Máquina que controla este estado.


## Chamado pela máquina uma única vez, ao registrar o estado.
## Registra o estado na máquina (chamado uma vez): guarda a máquina e o ator e roda o gancho de preparo.
func setup(machine: BaseStateMachine, owner_actor: Node) -> void:
	state_machine = machine  # Guarda a máquina.
	actor = owner_actor  # Guarda o dono.
	_on_setup()  # Gancho para as subclasses.


## Gancho para subclasses converterem o ator para o tipo concreto.
## Gancho vazio para as subclasses converterem o ator para o tipo concreto.
func _on_setup() -> void:
	pass


## Ao entrar no estado.
## Gancho vazio: roda ao entrar no estado.
func enter() -> void:
	pass


## Ao sair do estado.
## Gancho vazio: roda ao sair do estado.
func exit() -> void:
	pass


## Frame de física.
## Gancho vazio: roda a cada quadro de física enquanto o estado está ativo.
func physics_update(_delta: float) -> void:
	pass


## Frame normal (só com run_process_update).
## Gancho vazio: roda a cada quadro normal (só se a máquina liga `run_process_update`).
func update(_delta: float) -> void:
	pass


## True se é o estado atual.
## Diz se este é o estado ativo da máquina.
func is_current() -> bool:
	# Precisa ter máquina e ser o estado atual.
	return state_machine != null and state_machine.current_state == self


## Pede a troca de estado; ignorada se este deixou de ser o estado atual.
## Pede a troca de estado; é ignorada se este estado já deixou de ser o atual.
func request_transition(state_name: StringName) -> void:
	if is_current():  # Só quem está ativo pode pedir troca.
		state_machine.transition_to(state_name)  # Pede à máquina.
