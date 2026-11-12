class_name RoboAttackMeleeState
extends RoboState
## Ataque em área: cria o telegraph (que aplica o dano) e espera carga + recarga.

enum Phase { CHARGING, COOLDOWN }  # Fases do ataque: carregando o aviso ou em recarga.

var _phase: Phase = Phase.COOLDOWN  # Fase atual.
var _timer: float = 0.0  # Tempo restante da fase.


## Ao entrar: para o Robô e começa o aviso do ataque em área.
func _on_enter() -> void:
	robo.velocity = Vector2.ZERO  # Para o corpo.
	_start_telegraph()  # Começa o aviso.


## A cada quadro: perdeu o alvo volta ao repouso; senão espera o aviso, a recarga e decide o próximo ataque.
func physics_update(delta: float) -> void:
	if not robo.has_target():  # Sem alvo: esquece e volta a patrulhar.
		robo.drop_target()
		request_no_target_state()
		return
	robo.stop_moving()  # Fica parado durante o ataque.
	_timer -= delta  # Desconta o tempo da fase.
	if _timer > 0.0:  # Ainda dentro da fase.
		return
	match _phase:  # A fase acabou.
		Phase.CHARGING:
			_phase = Phase.COOLDOWN  # O aviso terminou (o dano já foi aplicado): entra na recarga.
			_timer = robo.melee_attack_cooldown  # Tempo de recarga.
			robo.play_anim(&"idle")  # Volta à animação parada.
		Phase.COOLDOWN:
			if robo.target_in_melee_range:  # Acabou a recarga: o jogador ainda está perto?
				_start_telegraph()  # Sim: novo aviso.
			elif robo.is_target_in_ranged_distance():  # Não, mas está no alcance de tiro: atira.
				request_transition(&"AttackRanged")
			else:
				request_transition(&"Chase")  # Senão: persegue.


## Começa o aviso: cria o círculo no chão (que causa o dano ao fim do tempo) e toca a animação.
func _start_telegraph() -> void:
	report_progress()  # Avisa a rede de segurança.
	_phase = Phase.CHARGING  # Fase de carga.
	_timer = robo.melee_telegraph_time  # Tempo de carga igual ao do aviso.
	robo.play_anim(animation, true)  # Toca a animação do ataque do começo.
	if robo.melee_telegraph_scene == null:  # Sem cena de aviso configurada.
		push_warning("RoboAttackMelee: melee_telegraph_scene não configurada.")  # Aviso no console.
		return
	# Pega um aviso do pool.
	var telegraph := PoolHub.acquire(robo.melee_telegraph_scene, robo, MeleeTelegraph) as MeleeTelegraph
	if telegraph != null:
		# Lança o aviso no Robô com o dano configurado.
		telegraph.launch(robo.global_position, robo.melee_telegraph_time, robo.melee_damage, robo)
