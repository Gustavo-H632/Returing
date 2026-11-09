class_name RoboAttackRangedState
extends RoboState
## Carrega (windup) e dispara.

var _cooldown: float = 0.0  # Tempo restante para o próximo tiro.
var _windup: float = -1.0  # < 0 = sem disparo em preparação


## Ao entrar: para o Robô e reinicia os cronômetros.
func _on_enter() -> void:
	robo.velocity = Vector2.ZERO  # Para o corpo.
	_cooldown = 0.0  # Pronto para começar a preparar um tiro.
	_windup = -1.0  # Nenhum tiro em preparação.


## A cada quadro: troca para melee ou perseguição se preciso; senão encara o jogador, prepara e dispara.
func physics_update(delta: float) -> void:
	if not robo.has_target():  # Sem alvo: esquece e volta a patrulhar.
		robo.drop_target()
		request_no_target_state()
		return
	if robo.target_in_melee_range:  # Jogador encostou: usa o ataque em área.
		request_transition(&"AttackMelee")
		return
	# Jogador fugiu do alcance (com margem): persegue.
	if not robo.is_target_in_ranged_distance(RANGE_HYSTERESIS):
		request_transition(&"Chase")
		return

	robo.stop_moving()  # Fica parado para atirar.
	robo.face_target()  # Encara o jogador.
	if _windup >= 0.0:  # Há um tiro em preparação.
		_windup -= delta  # Desconta o tempo de preparação.
		if _windup < 0.0:  # Terminou a preparação: dispara.
			_fire_projectile()  # Dispara.
			report_progress()  # Avisa que o ataque progride.
			_cooldown = robo.ranged_attack_cooldown  # Começa a recarga.
			robo.play_anim(&"idle")  # Volta à animação parada.
		return
	_cooldown -= delta  # Sem tiro em preparação: desconta a recarga.
	if _cooldown <= 0.0:  # Recarga acabou: começa a preparar o próximo tiro.
		_windup = robo.ranged_windup_time  # Tempo de preparação.
		robo.play_anim(animation, true)  # Toca a animação de carga.


## Dispara um projétil na direção do jogador.
func _fire_projectile() -> void:
	if robo.projectile_scene == null:  # Sem cena de projétil configurada.
		push_warning("RoboAttackRanged: projectile_scene não configurada.")  # Aviso no console.
		return
	var origin: Vector2 = robo.get_projectile_origin()  # Boca da arma.
	# Pega um projétil do pool.
	var projectile := PoolHub.acquire(robo.projectile_scene, robo, EnemyProjectile) as EnemyProjectile
	if projectile != null:  # Lança em direção ao jogador.
		projectile.launch(origin, origin.direction_to(robo.target.global_position), robo)
