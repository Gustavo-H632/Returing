class_name GuideAttackState
extends GuideState
## Base dos ataques do Guide: o chefão segue perseguindo enquanto ataca (salvo `moves_while_attacking`).

## Desligado, o chefão freia e fica parado durante o ataque.
@export var moves_while_attacking: bool = true

var _elapsed: float = 0.0


func _on_enter() -> void:
	_elapsed = 0.0
	_begin_attack()


func physics_update(delta: float) -> void:
	if not guide.has_target():
		request_no_target_state()
		return
	if moves_while_attacking:
		guide.chase_target(delta)
	else:
		enemy.brake(delta)
		enemy.face_target()
	_elapsed += delta
	_update_attack(delta)


## Termina o ataque: começa a pausa até o próximo e volta a perseguir.
func finish_attack() -> void:
	guide.start_attack_cooldown()
	request_transition(GuideEnemy.STATE_CHASE)


## Gancho: prepara o ataque ao entrar no estado.
func _begin_attack() -> void:
	pass


## Gancho: roda a cada frame de física até chamar finish_attack().
func _update_attack(_delta: float) -> void:
	pass
