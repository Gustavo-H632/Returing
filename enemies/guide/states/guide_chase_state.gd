class_name GuideChaseState
extends GuideState
## Perseguição constante: o Guide sempre vai atrás do player e escolhe o próximo ataque.


## Ao entrar: reinicia o desvio de paredes.
func _on_enter() -> void:
	guide.reset_navigation()  # Limpa o estado do desvio.


## Persegue o jogador e escolhe o próximo ataque: golpe de espada se estiver perto, senão sorteia outro quando a espera acaba.
func physics_update(delta: float) -> void:
	if not guide.has_target():  # Sem alvo: volta a patrulhar.
		request_no_target_state()
		return
	guide.chase_target(delta)  # Persegue o jogador.
	# O golpe de espada tem prioridade quando o player chega perto.
	if guide.can_slash():  # Jogador ao alcance do golpe de espada.
		request_transition(GuideEnemy.ATTACK_SLASH)  # Golpe de espada.
	elif guide.attack_ready():  # A espera entre ataques acabou.
		request_transition(guide.pick_attack())  # Sorteia um ataque à distância.
