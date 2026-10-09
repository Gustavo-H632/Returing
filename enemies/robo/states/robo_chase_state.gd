class_name RoboChaseState
extends RoboState
## Aproxima-se até o alcance de tiro (ou de área, se o player colar).


func physics_update(_delta: float) -> void:
	if not robo.has_target():
		robo.drop_target()
		request_transition(&"Idle")
		return
	if robo.target_in_melee_range:
		request_transition(&"AttackMelee")
		return
	if robo.is_target_in_ranged_distance():
		request_transition(&"AttackRanged")
		return
	robo.move_towards(robo.target.global_position, robo.move_speed)
