class_name ChaserChaseState
extends ChaserState
## Persegue o player enquanto ele estiver na visão.


## Segue o player ou troca de estado.
func physics_update(_delta: float) -> void:
	if not enemy.player_in_detection:
		# Fugiu = onda; morreu = Idle
		request_transition(enemy.lost_target_state())
		return
	if not enemy.has_target():
		request_transition(&"IdleState")
		return
	if enemy.player_in_attack_range:
		request_transition(&"AttackState")
		return

	enemy.move_towards(enemy.player_ref.global_position,
		enemy.move_speed * enemy.chase_speed_multiplier)
