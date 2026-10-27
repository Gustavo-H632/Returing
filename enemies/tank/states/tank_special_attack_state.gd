class_name TankSpecialAttackState
extends TankState
## Investida em linha reta.

enum Phase { TELEGRAPH, DASHING }

@export var dash_animation: StringName = &"move"

var _phase: Phase = Phase.TELEGRAPH
var _time_left: float = 0.0


func _on_enter() -> void:
	_phase = Phase.TELEGRAPH
	_time_left = tank.dash_prepare_time
	tank.velocity = Vector2.ZERO
	tank.dash_direction = tank.direction_to_target()
	if tank.dash_direction == Vector2.ZERO:
		tank.dash_direction = Vector2.RIGHT
	tank.face_direction(tank.dash_direction)


func exit() -> void:
	if tank.dash_hitbox != null:
		tank.dash_hitbox.set_active(false)
	tank.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	_time_left -= delta
	match _phase:
		Phase.TELEGRAPH:
			tank.stop_moving()
			if _time_left <= 0.0:
				_start_dash()
		Phase.DASHING:
			tank.velocity = tank.dash_direction * tank.dash_speed
			tank.move_and_slide()
			if tank.get_slide_collision_count() > 0 or _time_left <= 0.0:
				_end_dash()


func _start_dash() -> void:
	_phase = Phase.DASHING
	_time_left = tank.dash_duration
	tank.play_anim(dash_animation, true, 2.0)
	if tank.dash_hitbox != null:
		tank.dash_hitbox.set_active(true)


func _end_dash() -> void:
	tank.start_dash_cooldown()
	if tank.has_target():
		request_transition(&"Chase")
	else:
		request_no_target_state()
