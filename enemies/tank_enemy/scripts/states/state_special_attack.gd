extends TankState
## SPECIAL_ATTACK: investida em linha reta (telegraph e dash). Acaba ao bater ou no tempo.

enum Phase { TELEGRAPH, DASHING }

var _phase: Phase = Phase.TELEGRAPH
var _time_left: float = 0.0


## Começa o telegraph.
func enter() -> void:
	_phase = Phase.TELEGRAPH
	_time_left = tank.dash_prepare_time
	tank.velocity = Vector2.ZERO
	# Trava a direção no início
	if tank.has_target():
		tank.dash_direction = tank.global_position.direction_to(tank.player.global_position)
	if tank.dash_direction == Vector2.ZERO:
		tank.dash_direction = Vector2.RIGHT


## Desliga a hitbox e para.
func exit() -> void:
	if tank.dash_hitbox != null:
		tank.dash_hitbox.set_active(false)
	tank.velocity = Vector2.ZERO


## Telegraph parado, depois dash.
func physics_update(delta: float) -> void:
	_time_left -= delta
	match _phase:
		Phase.TELEGRAPH:
			tank.velocity = Vector2.ZERO
			tank.move_and_slide()
			if _time_left <= 0.0:
				_start_dash()
		Phase.DASHING:
			tank.velocity = tank.dash_direction * tank.dash_speed
			tank.move_and_slide()
			if tank.get_slide_collision_count() > 0 or _time_left <= 0.0:
				_end_dash()


## Liga a hitbox e começa o dash.
func _start_dash() -> void:
	_phase = Phase.DASHING
	_time_left = tank.dash_duration
	if tank.dash_hitbox != null:
		tank.dash_hitbox.damage = tank.dash_damage
		tank.dash_hitbox.set_active(true)


## Recarga e volta a perseguir.
func _end_dash() -> void:
	tank.start_dash_cooldown()
	request_transition(&"chase" if tank.has_target() else &"idle")
