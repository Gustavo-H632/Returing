class_name RoboChaseState
extends RoboState
## Aproxima-se, contornando paredes, até o alcance de tiro.


## Ao entrar: reinicia o desvio de paredes.
func _on_enter() -> void:
	robo.reset_navigation()  # Limpa o estado do desvio.


## Persegue o jogador contornando paredes; troca para ataque em área ou à distância conforme a distância.
func physics_update(delta: float) -> void:
	if not robo.has_target():  # Sem alvo: esquece e volta a patrulhar.
		robo.drop_target()
		request_no_target_state()
		return
	if robo.target_in_melee_range:  # Jogador encostou: ataque em área.
		request_transition(&"AttackMelee")
		return
	if robo.is_target_in_ranged_distance():  # Dentro do alcance de tiro: atira.
		request_transition(&"AttackRanged")
		return
	# Anda até o jogador com desvio de paredes.
	robo.navigate_towards(robo.target.global_position, robo.move_speed, delta)
