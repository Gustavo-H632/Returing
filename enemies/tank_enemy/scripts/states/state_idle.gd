extends TankState

## Estado IDLE 

var _tank: TankEnemy
var _wander_target: Vector2


func enter() -> void:
	_tank = actor as TankEnemy
	_pick_new_wander_point()

	# Conecta o timer apenas uma vez 
	if not _tank.idle_wander_timer.timeout.is_connected(_on_wander_timer_timeout):
		_tank.idle_wander_timer.timeout.connect(_on_wander_timer_timeout)

	_tank.idle_wander_timer.start(randf_range(2.0, 4.5))


func exit() -> void:
	_tank.idle_wander_timer.stop()


func physics_update(delta: float) -> void:
	var to_target := _wander_target - _tank.global_position

	if to_target.length() > 4.0:
		# Caminhando
		var direction := to_target.normalized()
		_tank.velocity = direction * _tank.move_speed * _tank.wander_speed_multiplier
	else:
		#freio
		_tank.velocity = _tank.velocity.move_toward(Vector2.ZERO, _tank.move_speed * delta)

	_tank.move_and_slide()


## Metodo de patrulha (wander)
func _pick_new_wander_point() -> void:
	var random_direction := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()

	var min_distance: float = min(20.0, _tank.wander_radius)
	var random_distance := randf_range(min_distance, _tank.wander_radius)
	_wander_target = _tank.spawn_position + random_direction * random_distance


func _on_wander_timer_timeout() -> void:
	_pick_new_wander_point()
	_tank.idle_wander_timer.start(randf_range(2.0, 4.5))
