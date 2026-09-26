class_name ChaserChaseState
extends ChaserState

#o inimigo persegue ativamente o player.


func enter() -> void:
	pass # O movimento é no physic process


func physics_update(_delta: float) -> void:
	if not is_instance_valid(actor.player_ref):
		# Player saiu da cena 
		transitioned.emit(self, "IdleState")
		return

	var direction: Vector2 = (actor.player_ref.global_position - actor.global_position)
	if direction.length() > 0.001:
		direction = direction.normalized()

	actor.velocity = direction * actor.move_speed * actor.chase_speed_multiplier
	actor.face_direction(actor.velocity)
	actor.move_and_slide()


func on_player_in_attack_range(_player: Node2D) -> void:
	transitioned.emit(self, "AttackState")


func on_player_lost(_player: Node2D) -> void:
	# O player saiu da range de visão atque da Onda de Energia.
	transitioned.emit(self, "EnergyWaveState")
