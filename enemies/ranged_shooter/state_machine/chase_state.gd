class_name ShooterChaseState
extends ShooterState
## Persegue até o alcance de tiro ou de corpo a corpo.


## Anda até o alvo ou ataca.
func physics_update(_delta: float) -> void:
	if not enemy.has_target():
		# Sem alvo: volta ao Idle
		enemy.drop_target()
		request_transition(&"Idle")
		return
	if enemy.is_player_in_melee_range:
		request_transition(&"AttackMelee")
		return
	if enemy.is_target_in_ranged_distance():
		request_transition(&"AttackRanged")
		return

	enemy.velocity = enemy.global_position.direction_to(enemy.target.global_position) * enemy.move_speed
	enemy.move_and_slide()
