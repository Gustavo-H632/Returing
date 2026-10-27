class_name RoboChaseState
extends RoboState
## Aproxima-se, contornando paredes, até o alcance de tiro.


func _on_enter() -> void:
	robo.reset_navigation()


func physics_update(delta: float) -> void:
	if not robo.has_target():
		robo.drop_target()
		request_no_target_state()
		return
	if robo.target_in_melee_range:
		request_transition(&"AttackMelee")
		return
	if robo.is_target_in_ranged_distance():
		request_transition(&"AttackRanged")
		return
	robo.navigate_towards(robo.target.global_position, robo.move_speed, delta)
