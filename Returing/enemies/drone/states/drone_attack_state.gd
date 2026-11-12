class_name DroneAttackState
extends DroneState
## Golpe em 3 fases por cronômetro de física (determinístico, sem corrotina).

enum Phase { WINDUP, ACTIVE, COOLDOWN }  # Fases do golpe: preparação, janela de dano e recuperação.

var _phase: Phase = Phase.WINDUP  # Fase atual.
var _time_left: float = 0.0  # Tempo restante da fase.


## Ao entrar: para o drone e começa a preparação do golpe.
func _on_enter() -> void:
	drone.velocity = Vector2.ZERO  # Para o corpo.
	_begin_windup()  # Começa a preparação.


## Ao sair: garante que a hitbox do golpe fique desligada.
func exit() -> void:
	if drone.attack_hitbox != null:  # Hitbox existe.
		drone.attack_hitbox.set_active(false)  # Desliga.


## A cada quadro, desconta o tempo e avança as fases: preparação -> dano -> recuperação -> decide o próximo passo.
func physics_update(delta: float) -> void:
	drone.stop_moving()  # Fica parado durante o golpe.
	_time_left -= delta  # Desconta o tempo da fase.
	if _time_left > 0.0:  # Ainda dentro da fase.
		return
	match _phase:  # A fase acabou: passa à próxima.
		Phase.WINDUP:
			if drone.attack_hitbox != null:  # Fim da preparação: liga a hitbox.
				drone.attack_hitbox.set_active(true)
			_phase = Phase.ACTIVE  # Entra na janela de dano.
			_time_left = drone.attack_hit_window  # Tempo da janela de dano.
		Phase.ACTIVE:
			if drone.attack_hitbox != null:  # Fim da janela de dano: desliga a hitbox.
				drone.attack_hitbox.set_active(false)
			_phase = Phase.COOLDOWN  # Entra na recuperação.
			_time_left = drone.attack_cooldown_time  # Tempo de recuperação.
		Phase.COOLDOWN:
			_decide_next()  # Fim da recuperação: decide o que fazer.


## Começa a preparação: avisa que está progredindo, vira para o jogador e toca a animação do golpe.
func _begin_windup() -> void:
	report_progress()  # Avisa a rede de segurança.
	drone.face_target()  # Encara o alvo.
	_phase = Phase.WINDUP  # Fase de preparação.
	_time_left = drone.attack_windup_time  # Tempo da preparação.
	drone.play_anim(animation, true)  # reinicia a animação a cada golpe


## Depois do golpe: sem alvo volta a patrulhar, alvo fora do alcance persegue, senão golpeia de novo.
func _decide_next() -> void:
	if not drone.has_target():  # Perdeu o alvo.
		request_no_target_state()
	elif not drone.target_in_attack_range:  # Alvo saiu do alcance: persegue.
		request_transition(&"Chase")
	else:
		_begin_windup()  # Alvo ainda perto: novo golpe.
