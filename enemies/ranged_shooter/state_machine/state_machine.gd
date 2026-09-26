class_name ShooterStateMachine
extends Node
#State Machine generica

@export var initial_state: ShooterState

var enemy: RangedEnemy
var current_state: ShooterState
var states: Dictionary = {}


func _ready() -> void:
	enemy = get_parent() as RangedEnemy
	if enemy == null:
		push_error("ShooterStateMachine: o nó pai precisa ser um RangedEnemy.")
		return

	for child in get_children():
		if child is ShooterState:
			child.enemy = enemy
			states[child.name] = child
			child.transition_requested.connect(_on_transition_requested)

	if initial_state:
		current_state = initial_state
		current_state.enter()


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _on_transition_requested(state_name: String) -> void:
	change_state(state_name)


## Troca de estado 
func change_state(state_name: String) -> void:
	if not states.has(state_name):
		push_warning("ShooterStateMachine: estado '%s' não encontrado." % state_name)
		return

	if current_state == states[state_name]:
		return

	if current_state:
		current_state.exit()

	current_state = states[state_name]
	current_state.enter()
