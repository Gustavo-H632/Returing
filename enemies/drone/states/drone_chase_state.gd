class_name DroneChaseState
extends DroneState
## Persegue o player contornando paredes.a a patrulhar.


func _on_enter() -> void:
	drone.reset_navigation()


func physics_update(delta: float) -> void:
	if not drone.has_target():
		request_no_target_state()
		return
	if drone.target_in_attack_range:
		request_transition(&"Attack")
		return
	drone.navigate_towards(drone.target.global_position, drone.move_speed * drone.chase_speed_multiplier, delta)
