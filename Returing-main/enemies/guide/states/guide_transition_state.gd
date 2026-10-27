class_name GuideTransitionState
extends GuideState
## Transição da fase 1 para a 2: invulnerável e sem atacar, volta ao meio da sala, levanta as
## paredes em volta de si e espera a wave acabar.

enum Phase { RETURNING, WAITING }

var _phase: Phase = Phase.RETURNING
var _timeout_left: float = 0.0
var _finished: bool = false


func _on_enter() -> void:
	_finished = false
	_phase = Phase.RETURNING
	enemy.velocity = Vector2.ZERO
	enemy.play_anim(&"move")
	guide.on_transition_started()


func exit() -> void:
	CombatUtils.disconnect_if_connected(EventBus.boss_wave_cleared, _on_wave_cleared)


func physics_update(delta: float) -> void:
	match _phase:
		Phase.RETURNING:
			if guide.return_to_center(delta):
				_begin_waiting()
		Phase.WAITING:
			enemy.brake(delta)
			_timeout_left -= delta
			if _timeout_left <= 0.0 and not _finished:
				push_warning("%s: a wave da transição não terminou em %.0f s; iniciando a fase 2." % [
					guide.name, guide.transition_wave_timeout])
				_finish()


## Chegou ao meio: escuta o fim da wave, levanta as paredes e pede a wave.
func _begin_waiting() -> void:
	_phase = Phase.WAITING
	_timeout_left = guide.transition_wave_timeout
	enemy.play_anim(animation)
	CombatUtils.connect_once(EventBus.boss_wave_cleared, _on_wave_cleared)
	guide.on_center_reached()


## A wave do chefão acabou.
func _on_wave_cleared(kind: StringName) -> void:
	if kind == guide.enemy_kind:
		_finish()


## Remove as paredes, inicia a fase 2 e volta a perseguir (uma única vez).
func _finish() -> void:
	if _finished:
		return
	_finished = true
	guide.on_transition_finished()
	request_transition(GuideEnemy.STATE_CHASE)
