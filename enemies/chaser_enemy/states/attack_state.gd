class_name ChaserAttackState
extends ChaserState
## Golpe em 3 fases: preparação, acerto e recuperação (cronômetro, sem await).

enum Phase { WINDUP, ACTIVE, COOLDOWN }

var _phase: Phase = Phase.WINDUP
var _time_left: float = 0.0


## Para e começa a preparação.
func enter() -> void:
	enemy.velocity = Vector2.ZERO
	_begin_windup()


## Garante a hitbox desligada.
func exit() -> void:
	if enemy.hitbox != null:
		enemy.hitbox.deactivate()


## Avança as fases do golpe.
func physics_update(delta: float) -> void:
	enemy.stop_moving()
	_time_left -= delta
	if _time_left > 0.0:
		return

	match _phase:
		Phase.WINDUP:
			if enemy.hitbox != null:
				enemy.hitbox.activate()
			_phase = Phase.ACTIVE
			_time_left = enemy.attack_hit_window
		Phase.ACTIVE:
			if enemy.hitbox != null:
				enemy.hitbox.deactivate()
			_phase = Phase.COOLDOWN
			_time_left = enemy.attack_cooldown_time
		Phase.COOLDOWN:
			_decide_next_state()


## Vira para o player e prepara.
func _begin_windup() -> void:
	enemy.face_player()
	_phase = Phase.WINDUP
	_time_left = enemy.attack_windup_time


## Golpeia de novo, persegue ou perde o alvo.
func _decide_next_state() -> void:
	if not enemy.player_in_detection:
		request_transition(enemy.lost_target_state())
	elif not enemy.player_in_attack_range or not enemy.has_target():
		request_transition(&"ChaseState")
	else:
		_begin_windup()  # ainda no alcance: golpeia de novo
