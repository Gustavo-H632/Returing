extends TankState
## IDLE: vaga perto do spawn até ver o player.

const ARRIVE_DISTANCE_SQ: float = 16.0  # 4 px
const WANDER_MIN_DISTANCE: float = 20.0

@export var wander_wait_min: float = 2.0
@export var wander_wait_max: float = 4.5

var _wander_target: Vector2 = Vector2.ZERO
var _wait_left: float = 0.0


## Escolhe o primeiro ponto.
func enter() -> void:
	_pick_new_wander_point()


## Vaga ou começa a perseguir.
func physics_update(delta: float) -> void:
	if tank.has_target():
		request_transition(&"chase")
		return

	_wait_left -= delta
	if _wait_left <= 0.0:
		_pick_new_wander_point()

	if tank.global_position.distance_squared_to(_wander_target) > ARRIVE_DISTANCE_SQ:
		var direction := tank.global_position.direction_to(_wander_target)
		tank.velocity = direction * tank.move_speed * tank.wander_speed_multiplier
	else:
		tank.brake(delta)
	tank.move_and_slide()


## Sorteia ponto e espera.
func _pick_new_wander_point() -> void:
	var min_distance := minf(WANDER_MIN_DISTANCE, tank.wander_radius)
	var distance := randf_range(min_distance, maxf(tank.wander_radius, min_distance))
	_wander_target = tank.spawn_position + Vector2.from_angle(randf() * TAU) * distance
	_wait_left = randf_range(wander_wait_min, maxf(wander_wait_max, wander_wait_min))
