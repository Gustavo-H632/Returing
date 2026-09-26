class_name ChaserStateMachine
extends Node

#classe state machine
@export var initial_state: ChaserState

var current_state: ChaserState
var states: Dictionary = {} #adiciona o ChaserState


func _ready() -> void:
	var actor := get_parent() as CharacterBody2D
	if actor == null:
		push_error("ChaserStateMachine deve ser filho direto de um CharacterBody2D.")
		return

	for child in get_children():
		if child is ChaserState:
			states[String(child.name)] = child
			child.actor = actor
			child.transitioned.connect(_on_state_transitioned)


## Chamado pelo inimigo.
func start() -> void:
	if current_state != null:
		return 
	if initial_state == null:
		push_warning("ChaserStateMachine sem 'initial_state' definido no Inspector.")
		return
	current_state = initial_state
	current_state.enter()


func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)


func _on_state_transitioned(state: ChaserState, new_state_name: String) -> void:
	if state != current_state:
		return

	var new_state: ChaserState = states.get(new_state_name)
	if new_state == null:
		push_error("ChaserStateMachine: estado '%s' não existe como filho." % new_state_name)
		return

	current_state.exit()
	new_state.enter()
	current_state = new_state


func notify_player_spotted(player: Node2D) -> void:
	if current_state:
		current_state.on_player_spotted(player)

func notify_player_lost(player: Node2D) -> void:
	if current_state:
		current_state.on_player_lost(player)

func notify_player_in_attack_range(player: Node2D) -> void:
	if current_state:
		current_state.on_player_in_attack_range(player)

func notify_player_left_attack_range(player: Node2D) -> void:
	if current_state:
		current_state.on_player_left_attack_range(player)
