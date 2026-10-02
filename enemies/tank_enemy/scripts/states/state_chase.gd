extends TankState
## CHASE: segue o player e escolhe pisoteio (perto) ou investida (longe).


## Decide o ataque ou anda até o player.
func physics_update(_delta: float) -> void:
	if not tank.has_target():
		request_transition(&"idle")
		return

	var distance_sq := tank.distance_sq_to_player()

	# Checa a distância todo frame (o player pode já estar perto)
	if distance_sq <= tank.attack_range_radius * tank.attack_range_radius:
		request_transition(&"attack")
		return

	if tank.can_dash() and distance_sq >= tank.min_distance_for_dash * tank.min_distance_for_dash:
		request_transition(&"special_attack")
		return

	tank.velocity = tank.global_position.direction_to(tank.player.global_position) * tank.move_speed
	tank.move_and_slide()
