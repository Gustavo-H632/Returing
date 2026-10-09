class_name DroneAttackState
extends DroneState
## Golpe em 3 fases por cronômetro de física (determinístico, sem corrotina):
## WINDUP -> ACTIVE (hitbox ligada) -> COOLDOWN. exit() sempre desliga a hitbox.

enum Phase { WINDUP, ACTIVE, COOLDOWN }

var _phase: Phase = Phase.WINDUP
var _time_left: float = 0.0


func _on_enter() -> void:
	drone.velocity = Vector2.ZERO
	_begin_windup()


func exit() -> void:
	if drone.attack_hitbox != null:
		drone.attack_hitbox.set_active(false)


func physics_update(delta: float) -> void:
	drone.stop_moving()
	_time_left -= delta
	if _time_left > 0.0:
		return
	match _phase:
		Phase.WINDUP:
			if drone.attack_hitbox != null:
				drone.attack_hitbox.set_active(true)
			_phase = Phase.ACTIVE
			_time_left = drone.attack_hit_window
		Phase.ACTIVE:
			if drone.attack_hitbox != null:
				drone.attack_hitbox.set_active(false)
			_phase = Phase.COOLDOWN
			_time_left = drone.attack_cooldown_time
		Phase.COOLDOWN:
			_decide_next()


func _begin_windup() -> void:
	drone.face_target()
	_phase = Phase.WINDUP
	_time_left = drone.attack_windup_time
	drone.play_anim(animation, true)  # reinicia a animação a cada golpe


func _decide_next() -> void:
	if not drone.has_target():
		request_transition(&"Idle")
	elif not drone.target_in_attack_range:
		request_transition(&"Chase")
	else:
		_begin_windup()
