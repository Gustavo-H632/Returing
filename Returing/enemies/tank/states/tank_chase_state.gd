class_name TankChaseState
extends TankState
## Segue o player, contornando paredes.


## Ao entrar: reinicia o desvio de paredes.
func _on_enter() -> void:
	tank.reset_navigation()  # Limpa o estado do desvio.


## Persegue o jogador: pisoteia se estiver perto, investe se estiver longe e a investida estiver pronta.
func physics_update(delta: float) -> void:
	if not tank.has_target():  # Sem alvo: volta a patrulhar.
		request_no_target_state()  # Patrol se a cena tiver; senão Idle
		return
	var distance_sq: float = tank.distance_sq_to_target()  # Distância ao quadrado (sem raiz).
	if distance_sq <= tank.stomp_radius * tank.stomp_radius:  # Dentro do raio do pisoteio: ataca.
		request_transition(&"Attack")
		return
	# Longe o suficiente e investida pronta: investe.
	if tank.can_dash() and distance_sq >= tank.min_distance_for_dash * tank.min_distance_for_dash:
		request_transition(&"SpecialAttack")
		return
	# Contorna parede, igual ao Drone e ao Robo (antes o Tank empacava
	# nas paredes enquanto Drone e Robo já as contornavam).
	# Anda até o jogador contornando paredes.
	tank.navigate_towards(tank.target.global_position, tank.move_speed, delta)
