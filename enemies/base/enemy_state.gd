class_name EnemyState
extends BaseState
## Estado base dos inimigos.

## Margem de alcance para o inimigo não ficar trocando de estado na borda.
const RANGE_HYSTERESIS: float = 1.15

## Animação tocada ao entrar no estado (vazio = não troca).
@export var animation: StringName = &""

var enemy: EnemyBase = null


func _on_setup() -> void:
	enemy = actor as EnemyBase
	if enemy == null:
		push_error("%s: o ator da máquina de estados precisa herdar de EnemyBase." % name)
		return
	_on_enemy_setup()


## Gancho para subclasses fazerem o cast para o tipo concreto.
func _on_enemy_setup() -> void:
	pass


func enter() -> void:
	if animation != &"":
		enemy.play_anim(animation)
	_on_enter()


func _on_enter() -> void:
	pass


## Sem alvo: volta a patrulhar (ou ao Idle, se a cena não tiver o estado Patrol).
func request_no_target_state() -> void:
	request_transition(&"Patrol" if state_machine.has_state(&"Patrol") else &"Idle")
