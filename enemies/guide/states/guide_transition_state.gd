class_name GuideTransitionState
extends GuideState
## Transição da fase 1 para a 2: invulnerável e sem atacar, volta ao meio da sala, levanta as
## paredes em volta de si e espera a wave acabar.

enum Phase { RETURNING, WAITING }  # Fases da transição: voltando ao centro e esperando a wave.

var _phase: Phase = Phase.RETURNING  # Fase atual.
var _timeout_left: float = 0.0  # Tempo restante antes de desistir de esperar a wave.
var _finished: bool = false  # True depois de terminar (impede terminar duas vezes).


## Ao entrar: para o chefão, toca a animação de andar e avisa que a transição começou.
func _on_enter() -> void:
	_finished = false  # Ainda não terminou.
	_phase = Phase.RETURNING  # Começa voltando ao centro.
	enemy.velocity = Vector2.ZERO  # Para o corpo.
	enemy.play_anim(&"move")  # Anima o movimento.
	guide.on_transition_started()  # Limpa os ataques e deixa invulnerável.


## Ao sair: desliga o aviso de fim da wave.
func exit() -> void:
	CombatUtils.disconnect_if_connected(EventBus.boss_wave_cleared, _on_wave_cleared)  # Desconecta o sinal.


## Primeiro volta ao centro; depois freia e espera a wave (com tempo limite de segurança).
func physics_update(delta: float) -> void:
	match _phase:  # Fase atual.
		Phase.RETURNING:
			if guide.return_to_center(delta):  # Chegou ao centro: levanta as paredes.
				_begin_waiting()
		Phase.WAITING:
			enemy.brake(delta)  # Parado esperando.
			_timeout_left -= delta  # Desconta o tempo limite.
			if _timeout_left <= 0.0 and not _finished:  # Estourou o tempo: não trava a fase.
				# Avisa o desenvolvedor.
				push_warning("%s: a wave da transição não terminou em %.0f s; iniciando a fase 2." % [
					guide.name, guide.transition_wave_timeout])
				_finish()  # Segue para a fase 2.


## Chegou ao meio: escuta o fim da wave, levanta as paredes e pede a wave.
## Chegou ao meio: guarda o tempo limite, escuta o fim da wave, levanta as paredes e pede a wave.
func _begin_waiting() -> void:
	_phase = Phase.WAITING  # Passa a esperar.
	_timeout_left = guide.transition_wave_timeout  # Tempo limite configurado no chefão.
	enemy.play_anim(animation)  # Animação de espera.
	CombatUtils.connect_once(EventBus.boss_wave_cleared, _on_wave_cleared)  # Escuta o fim da wave.
	guide.on_center_reached()  # Levanta as paredes e pede a wave.


## A wave do chefão acabou.
## A wave acabou: só vale se for a do chefão.
func _on_wave_cleared(kind: StringName) -> void:
	if kind == guide.enemy_kind:  # Só a wave desse chefão conta.
		_finish()  # Termina a transição.


## Remove as paredes, inicia a fase 2 e volta a perseguir (uma única vez).
## Termina a transição uma única vez: remove as paredes, inicia a fase 2 e volta a perseguir.
func _finish() -> void:
	if _finished:  # Já terminou: ignora.
		return
	_finished = true  # Marca como terminada.
	guide.on_transition_finished()  # Remove paredes e entra na fase 2.
	request_transition(GuideEnemy.STATE_CHASE)  # Volta a perseguir.
