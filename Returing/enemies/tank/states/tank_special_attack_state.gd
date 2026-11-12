class_name TankSpecialAttackState
extends TankState
## Investida em linha reta.

enum Phase { TELEGRAPH, DASHING }  # Fases da investida: aviso e corrida.

@export var dash_animation: StringName = &"move"  # Animação tocada durante a corrida.

var _phase: Phase = Phase.TELEGRAPH  # Fase atual.
var _time_left: float = 0.0  # Tempo restante da fase.


## Ao entrar: para o Tank e trava a direção da investida (a do jogador neste instante).
func _on_enter() -> void:
	_phase = Phase.TELEGRAPH  # Começa pelo aviso.
	_time_left = tank.dash_prepare_time  # Tempo de preparação.
	tank.velocity = Vector2.ZERO  # Fica parado.
	tank.dash_direction = tank.direction_to_target()  # Direção até o jogador.
	if tank.dash_direction == Vector2.ZERO:  # Se o jogador estiver em cima, vai para a direita.
		tank.dash_direction = Vector2.RIGHT
	tank.face_direction(tank.dash_direction)  # Vira o sprite para a direção da investida.


## Ao sair: desliga a hitbox da investida e para o corpo.
func exit() -> void:
	if tank.dash_hitbox != null:  # Hitbox existe.
		tank.dash_hitbox.set_active(false)  # Desliga.
	tank.velocity = Vector2.ZERO  # Para o corpo.


## A cada quadro: no aviso fica parado; na corrida corre em linha reta até bater ou o tempo acabar.
func physics_update(delta: float) -> void:
	_time_left -= delta  # Desconta o tempo da fase.
	match _phase:
		Phase.TELEGRAPH:  # Aviso: parado.
			tank.stop_moving()
			if _time_left <= 0.0:  # Acabou o aviso: começa a corrida.
				_start_dash()
		Phase.DASHING:  # Corrida.
			tank.velocity = tank.dash_direction * tank.dash_speed  # Corre na direção travada.
			tank.move_and_slide()  # Aplica o movimento.
			# Bateu em algo ou o tempo acabou: termina.
			if tank.get_slide_collision_count() > 0 or _time_left <= 0.0:
				_end_dash()


## Começa a corrida: liga a hitbox e toca a animação mais rápida.
func _start_dash() -> void:
	_phase = Phase.DASHING  # Fase de corrida.
	_time_left = tank.dash_duration  # Duração da corrida.
	tank.play_anim(dash_animation, true, 2.0)  # Toca a animação em dobro da velocidade.
	if tank.dash_hitbox != null:  # Hitbox existe.
		tank.dash_hitbox.set_active(true)  # Liga.


## Termina a corrida: começa a recarga e volta a perseguir (ou a patrulhar sem alvo).
func _end_dash() -> void:
	tank.start_dash_cooldown()  # Recarga da investida.
	if tank.has_target():  # Ainda vê o jogador.
		request_transition(&"Chase")
	else:
		request_no_target_state()  # Sem alvo: patrulha.
