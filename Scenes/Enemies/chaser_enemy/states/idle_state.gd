class_name ChaserIdleState
extends ChaserState

#State idle
@export var wander: bool = true
@export var wander_radius: float = 32.0
@export var wander_interval: float = 2.5
@export var wander_speed_factor: float = 0.35

var _wander_target: Vector2
var _wander_timer: float = 0.0


func enter() -> void:
	actor.velocity = Vector2.ZERO
	_wander_target = actor.global_position
	_wander_timer = wander_interval


func physics_update(delta: float) -> void:
	if not wander:
		actor.velocity = Vector2.ZERO
		actor.move_and_slide()
		return
# Wander é o comportamento de um inimigo vagar ate uma posição tendo em base um tempo limite e uma distancia definida
	_wander_timer -= delta
	if _wander_timer <= 0.0:
		_wander_timer = wander_interval
		var offset := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0))
		if offset != Vector2.ZERO:
			offset = offset.normalized() * wander_radius
		_wander_target = actor.global_position + offset

	var to_target := _wander_target - actor.global_position
	if to_target.length() > 4.0:
		actor.velocity = to_target.normalized() * actor.move_speed * wander_speed_factor
		actor.face_direction(actor.velocity)
	else:
		actor.velocity = Vector2.ZERO

	actor.move_and_slide()

#transição state chase
func on_player_spotted(player: Node2D) -> void:
	actor.player_ref = player
	transitioned.emit(self, "ChaseState")
