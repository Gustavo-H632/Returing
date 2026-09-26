class_name ShooterChaseState
extends ShooterState
## Persegue enemy.target diretamente. 


func physics_update(_delta: float) -> void:
	if enemy.target == null or not is_instance_valid(enemy.target):
		# Alvo foi destruído
		enemy.velocity = Vector2.ZERO
		enemy.move_and_slide()
		return

	if enemy.is_player_in_melee_range:
		transition_requested.emit("AttackMelee")
		return

	var distance := enemy.global_position.distance_to(enemy.target.global_position)
	if distance <= enemy.ranged_attack_distance:
		transition_requested.emit("AttackRanged")
		return

	var direction := enemy.global_position.direction_to(enemy.target.global_position)
	enemy.velocity = direction * enemy.move_speed
	enemy.move_and_slide()
