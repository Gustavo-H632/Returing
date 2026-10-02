class_name ChaserIdleState
extends ChaserState
## Vaga perto da posição atual até ver o player.

const ARRIVE_DISTANCE_SQ: float = 16.0  # 4 px

@export var wander: bool = true
@export var wander_radius: float = 32.0
@export var wander_interval: float = 2.5
@export var wander_speed_factor: float = 0.35

var _wander_target: Vector2 = Vector2.ZERO
var _wander_timer: float = 0.0


## Para e reinicia o vagar.
func enter() -> void:
	enemy.velocity = Vector2.ZERO
	_wander_target = enemy.global_position
	_wander_timer = wander_interval


## Vaga ou começa a perseguir.
func physics_update(delta: float) -> void:
	if enemy.can_see_player():
		request_transition(&"ChaseState")
		return

	if not wander:
		enemy.stop_moving()
		return

	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = wander_interval
		_wander_target = enemy.global_position + Vector2.from_angle(randf() * TAU) * wander_radius

	if enemy.global_position.distance_squared_to(_wander_target) > ARRIVE_DISTANCE_SQ:
		enemy.move_towards(_wander_target, enemy.move_speed * wander_speed_factor)
	else:
		enemy.stop_moving()
