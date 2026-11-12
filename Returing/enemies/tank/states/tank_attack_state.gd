class_name TankAttackState
extends TankState
## Pisoteio: prepara (windup) e golpeia em pulsos enquanto o player está no raio.

var _windup_left: float = 0.0  # Tempo restante antes do primeiro pisoteio.


## Ao entrar: para o Tank, começa a preparação e liga a hitbox (ela só causa dano nos pulsos).
func _on_enter() -> void:
	tank.velocity = Vector2.ZERO  # Para o corpo.
	_windup_left = tank.stomp_windup_time  # Começa a preparação.
	if tank.stomp_hitbox != null:  # Hitbox existe.
		tank.stomp_hitbox.set_active(true)  # ligada, mas só causa dano via pulse()


## Ao sair: desliga a hitbox do pisoteio.
func exit() -> void:
	if tank.stomp_hitbox != null:  # Hitbox existe.
		tank.stomp_hitbox.set_active(false)  # Desliga.


## A cada quadro: freia, volta a perseguir se o jogador se afastou e dá pulsos de pisoteio quando pode.
func physics_update(delta: float) -> void:
	tank.brake(delta)  # Fica parado.
	if not tank.has_target():  # Sem alvo: volta a patrulhar.
		request_no_target_state()  # Patrol se a cena tiver; senão Idle
		return
	# Distância de saída, com margem para não ficar trocando de estado.
	var leave_radius: float = tank.stomp_radius * RANGE_HYSTERESIS
	if tank.distance_sq_to_target() > leave_radius * leave_radius:  # Jogador fora do raio: persegue.
		request_transition(&"Chase")
		return
	tank.face_target()  # Encara o jogador.
	_windup_left -= delta  # Desconta a preparação.
	if _windup_left > 0.0:  # Ainda preparando.
		return
	var hitbox: Hitbox = tank.stomp_hitbox  # Hitbox do pisoteio.
	# Pode pisotear (hitbox ligada e recarga pronta).
	if hitbox != null and tank.can_stomp() and hitbox.monitoring:
		tank.play_anim(animation, true)  # Toca a animação do pisoteio.
		hitbox.pulse()  # Dá o pulso de dano em quem está na área.
		tank.start_stomp_cooldown()  # Começa a recarga.
		report_progress()  # Avisa que o ataque progride.
