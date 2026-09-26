extends TankState

## Estado SPECIAL_ATTACK investida

enum Phase { TELEGRAPH, DASHING }

var _tank: TankEnemy
var _phase: Phase


func enter() -> void:
	_tank = actor as TankEnemy
	_phase = Phase.TELEGRAPH
	_tank.velocity = Vector2.ZERO

	
	# Trava a direção em linha reta 
	
	if _tank.player:
		_tank.dash_direction = (_tank.player.global_position - _tank.global_position).normalized()
	else:
		
		_tank.dash_direction = Vector2.RIGHT

	

	_tank.dash_prepare_timer.start(_tank.dash_prepare_time)
	if not _tank.dash_prepare_timer.timeout.is_connected(_on_prepare_finished):
		_tank.dash_prepare_timer.timeout.connect(_on_prepare_finished, CONNECT_ONE_SHOT)


func exit() -> void:
	_tank.dash_hitbox.set_active(false)
	_tank.dash_prepare_timer.stop()
	_tank.dash_duration_timer.stop()


func physics_update(_delta: float) -> void:
	match _phase:
		Phase.TELEGRAPH:
			#"carregando" a investida.
			_tank.velocity = Vector2.ZERO
			_tank.move_and_slide()

		Phase.DASHING:
			_tank.velocity = _tank.dash_direction * _tank.dash_speed
			_tank.move_and_slide()

			if _tank.get_slide_collision_count() > 0:
				_end_dash()
				return


func _on_prepare_finished() -> void:
	if _phase != Phase.TELEGRAPH:
		return

	_phase = Phase.DASHING

	_tank.dash_hitbox.damage = _tank.dash_damage
	_tank.dash_hitbox.set_active(true)

	_tank.dash_duration_timer.start(_tank.dash_duration)
	if not _tank.dash_duration_timer.timeout.is_connected(_end_dash):
		_tank.dash_duration_timer.timeout.connect(_end_dash, CONNECT_ONE_SHOT)


func _end_dash() -> void:
	
	if _phase != Phase.DASHING:
		return
	_phase = Phase.TELEGRAPH

	_tank.dash_hitbox.set_active(false)
	_tank.velocity = Vector2.ZERO

	if _tank.player:
		state_machine.transition_to("chase")
	else:
		state_machine.transition_to("idle")
