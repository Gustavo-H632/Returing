class_name GuideAttackState
extends GuideState
## Base dos ataques do Guide: o chefão segue perseguindo enquanto ataca (salvo `moves_while_attacking`).

## Desligado, o chefão freia e fica parado durante o ataque.
@export var moves_while_attacking: bool = true

var _elapsed: float = 0.0  # Tempo desde o início do ataque.


## Ao entrar zera o tempo e prepara o ataque.
func _on_enter() -> void:
	_elapsed = 0.0  # Zera o tempo.
	_begin_attack()  # Prepara o ataque (cada subclasse faz o seu).


## A cada quadro: sem alvo patrulha; senão persegue (ou freia) e deixa a subclasse atualizar o ataque.
func physics_update(delta: float) -> void:
	if not guide.has_target():  # Sem alvo: sai do ataque.
		request_no_target_state()
		return
	if moves_while_attacking:  # Continua perseguindo durante o ataque.
		guide.chase_target(delta)  # Persegue.
	else:
		enemy.brake(delta)  # Fica parado.
		enemy.face_target()  # Encara o jogador.
	_elapsed += delta  # Soma o tempo do ataque.
	_update_attack(delta)  # Atualiza o ataque da subclasse.


## Termina o ataque: começa a pausa até o próximo e volta a perseguir.
func finish_attack() -> void:
	guide.start_attack_cooldown()  # Começa a espera até o próximo ataque.
	request_transition(GuideEnemy.STATE_CHASE)  # Volta a perseguir.


## Gancho: prepara o ataque ao entrar no estado.
func _begin_attack() -> void:
	pass


## Gancho: roda a cada frame de física até chamar finish_attack().
func _update_attack(_delta: float) -> void:
	pass
