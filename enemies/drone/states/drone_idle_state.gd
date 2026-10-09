class_name DroneIdleState
extends DroneState
## Paira perto do ponto atual até detectar o player.

const ARRIVE_DISTANCE_SQ: float = 16.0

@export var wander_radius: float = 40.0
@export var wander_interval: float = 2.5

var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0


func _on_enter() -> void:
	drone.velocity = Vector2.ZERO
	_wander_target = drone.global_position
	_wander_timer = wander_interval


func physics_update(delta: float) -> void:
	if drone.can_see_target():
		request_transition(&"Chase")
		return
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = wander_interval
		_wander_target = drone.spawn_position + Vector2.from_angle(randf() * TAU) * randf_range(0.0, wander_radius)
	if drone.global_position.distance_squared_to(_wander_target) > ARRIVE_DISTANCE_SQ:
		drone.move_towards(_wander_target, drone.move_speed * drone.wander_speed_multiplier)
	else:
		drone.stop_moving()
