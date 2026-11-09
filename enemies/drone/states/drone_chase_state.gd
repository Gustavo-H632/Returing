class_name DroneChaseState
extends DroneState
## Persegue o player contornando paredes; sem alvo, volta a patrulhar.


## Ao entrar: reinicia o desvio de paredes.
func _on_enter() -> void:
	drone.reset_navigation()  # Limpa o estado do desvio.


## Persegue o jogador contornando paredes; sem alvo patrulha; no alcance, ataca.
func physics_update(delta: float) -> void:
	if not drone.has_target():  # Sem alvo: volta a patrulhar.
		request_no_target_state()
		return
	if drone.target_in_attack_range:  # Chegou perto: ataca.
		request_transition(&"Attack")
		return
	# Anda até o jogador (com desvio de paredes).
	drone.navigate_towards(drone.target.global_position, drone.move_speed * drone.chase_speed_multiplier, delta)
