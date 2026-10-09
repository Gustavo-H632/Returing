class_name DroneChaseState
extends DroneState
## Persegue o player enquanto ele estiver na área de detecção.


func physics_update(_delta: float) -> void:
	if not drone.has_target():
		request_transition(&"Idle")
		return
	if drone.target_in_attack_range:
		request_transition(&"Attack")
		return
	drone.move_towards(drone.target.global_position, drone.move_speed * drone.chase_speed_multiplier)
