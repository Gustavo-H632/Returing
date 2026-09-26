extends TankState

## Estado chase

var _tank: TankEnemy


func enter() -> void:
	_tank = actor as TankEnemy


func physics_update(_delta: float) -> void:
	if not _tank.player:
		# O player saiu da área de detecção 
		state_machine.transition_to("idle")
		return

	var distance := _tank.global_position.distance_to(_tank.player.global_position)

	# Longe demais para o ataque fisico mas dentro da investida
	if distance >= _tank.min_distance_for_dash:
		state_machine.transition_to("special_attack")
		return

	# investida
	var direction := (_tank.player.global_position - _tank.global_position).normalized()
	_tank.velocity = direction * _tank.move_speed
	_tank.move_and_slide()
