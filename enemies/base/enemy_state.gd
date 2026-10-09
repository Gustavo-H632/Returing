class_name EnemyState
extends BaseState
## Estado base dos inimigos: expõe o EnemyBase tipado e o nome da animação do estado.
## Regra anti-bug: enter() toca a animação, exit() SEMPRE desliga o que o estado ligou
## (hitboxes, velocidade). Assim qualquer transição (inclusive a morte) fica limpa.

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
