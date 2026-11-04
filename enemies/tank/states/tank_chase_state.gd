class_name TankChaseState
extends TankState
## Segue o player, contornando paredes.


func _on_enter() -> void:
	tank.reset_navigation()


func physics_update(delta: float) -> void:
	if not tank.has_target():
		request_no_target_state()  # Patrol se a cena tiver; senão Idle
		return
	var distance_sq: float = tank.distance_sq_to_target()
	if distance_sq <= tank.stomp_radius * tank.stomp_radius:
		request_transition(&"Attack")
		return
	if tank.can_dash() and distance_sq >= tank.min_distance_for_dash * tank.min_distance_for_dash:
		request_transition(&"SpecialAttack")
		return
	# Contorna parede, igual ao Drone e ao Robo (antes o Tank empacava
	# nas paredes enquanto Drone e Robo já as contornavam).
	tank.navigate_towards(tank.target.global_position, tank.move_speed, delta)
