class_name TankChaseState
extends TankState
## Segue o player; escolhe pisoteio (perto) ou investida (longe).


func physics_update(_delta: float) -> void:
	if not tank.has_target():
		request_transition(&"Idle")
		return
	var distance_sq: float = tank.distance_sq_to_target()
	if distance_sq <= tank.stomp_radius * tank.stomp_radius:
		request_transition(&"Attack")
		return
	if tank.can_dash() and distance_sq >= tank.min_distance_for_dash * tank.min_distance_for_dash:
		request_transition(&"SpecialAttack")
		return
	tank.move_towards(tank.target.global_position, tank.move_speed)
