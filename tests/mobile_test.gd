extends Node
## Teste automatizado do modo celular. Rode com:
##   godot --path . res://tests/mobile_test.tscn -- --mobile
## Injeta toques reais (InputEventScreenTouch/Drag) e confere tiro, espada, câmera, escala e mira assistida.

const LEVEL: String = "res://Scenes/Fase2/Fase2.tscn"  # Fase usada no teste.

var _fails: int = 0  # Falhas.
var _checks: int = 0  # Total de verificações.
var _player: Player = null  # Jogador.
var _mc: Node = null  # Controles de toque.
var _plat: Node = null  # Plataforma.


var root: Window = null  # Janela raiz.


## Guarda a janela raiz e agenda o teste.
func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


## Confere uma condição, mostra o resultado e conta a falha.
func check(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  ok   ", label)
	else:
		_fails += 1
		print("  FAIL ", label)


## Posição lógica (coordenadas do jogo) -> pixel da janela (o stretch do projeto muda a escala).
func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


## Diz se o jogo está pausado (para mensagens de depuração).
func paused_dbg() -> bool:
	return get_tree().paused


var _was_paused: bool = false  # Último estado de pausa visto.


## Espera `n` quadros de física e avisa quando o jogo pausa ou despausa.
func frames(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame
		if get_tree().paused != _was_paused:
			_was_paused = get_tree().paused
			print("   EVT paused=", _was_paused, " quiz=", get_tree().current_scene, " ", root.find_children("Quiz","",true,false).map(func(node): return node.visible), " pause=", root.find_children("Pause","",true,false).map(func(node): return node.visible))


## Simula um toque (apertar ou soltar) na posição lógica.
func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = _to_window(pos)
	e.pressed = pressed
	Input.parse_input_event(e)


## Simula o arrastar de um dedo.
func drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = _to_window(pos)
	Input.parse_input_event(e)


## Lista os tiros do jogador que estão em uso.
func active_projectiles() -> Array[PlayerProjectile]:
	var out: Array[PlayerProjectile] = []
	for n: Node in root.find_children("*", "PlayerProjectile", true, false):
		var p := n as PlayerProjectile
		if p.is_in_use():
			out.append(p)
	return out


## Põe o jogador numa posição fixa, recupera a vida, recolhe os tiros e espera.
func reset_player() -> void:
	_player.global_position = Vector2(560, 330)  # Posição de teste.
	_player.velocity = Vector2.ZERO  # Para.
	_player.hp = _player.hp_maximo  # Vida cheia.
	for p: PlayerProjectile in active_projectiles():  # Recolhe os tiros em voo.
		p.recycle()
	await frames(30)  # Espera 30 quadros.


## Toca no analógico de mira na direção `angle` e solta depois de `hold` quadros. Devolve os dados do primeiro tiro (direção, dano, escala, posição e quadro).
## Toca no analógico de mira na direção `angle` e solta depois de `hold` quadros. Devolve o 1º tiro.
func tap_shot(angle: float, hold: int) -> Dictionary:
	var aim_center: Vector2 = _mc.call("_rest_aim")  # Centro do analógico de mira.
	var dir := Vector2.from_angle(angle)  # Direção do toque.
	touch(0, aim_center + dir * 60.0, true)  # Aperta.
	await frames(hold)  # Segura.
	touch(0, aim_center + dir * 60.0, false)  # Solta.
	var shot: Dictionary = {}  # Dados do tiro.
	for i: int in 30:  # Espera até 30 quadros pelo tiro.
		await get_tree().physics_frame
		var list: Array[PlayerProjectile] = active_projectiles()  # Tiros em uso.
		if not list.is_empty():  # Saiu um tiro.
			var p: PlayerProjectile = list[0]  # Primeiro tiro.
			# Guarda os dados.
			shot = {"dir": p.direction, "damage": p.damage, "scale": p.scale.x, "pos": p.global_position,
					"frames": i}
			break  # Para de esperar.
	return shot  # Devolve os dados.


## Roda todos os testes do modo celular: escala e câmera, botão de arma, toque rápido, tiro carregado, arraste, mira assistida, espada e dash.
func _run() -> void:
	_mc = root.get_node("MobileControls")  # Controles de toque.
	_plat = root.get_node("Platform")  # Plataforma.
	# Mostra eventos importantes do jogo.
	EventBus.level_completed.connect(func(n: String) -> void: print("   EVT level_completed ", n, " t=", Time.get_ticks_msec()))
	EventBus.player_died.connect(func() -> void: print("   EVT player_died"))  # Jogador morreu.
	EventBus.game_over.connect(func() -> void: print("   EVT game_over"))  # Game over.
	EventBus.level_started.connect(func() -> void: print("   EVT level_started"))  # Fase começou.
	var packed: PackedScene = load(LEVEL)  # Carrega a fase.
	var level: Node = packed.instantiate()  # Cria a fase.
	root.add_child(level)  # Entra na árvore.
	get_tree().current_scene = level  # como no jogo: tiros e efeitos nascem sob a fase
	await frames(10)  # Espera 10 quadros.
	_player = level.get_node("Player") as Player  # Jogador.
	await frames(30)  # Espera 30 quadros.

	print("-- Escala, câmera e valores base")  # Escala, câmera e valores base.
	check(_plat.is_mobile, "_plat.is_mobile")  # Modo celular ligado.
	# Jogador com 150% do tamanho.
	check(is_equal_approx(_player.scale.x, 1.5), "player com 150%% do tamanho (%s)" % _player.scale)
	var cam: Camera2D = root.get_viewport().get_camera_2d()  # Câmera ativa.
	check(cam != null and cam is FollowCamera, "FollowCamera ativa")  # É a câmera de seguimento.
	check(cam != null and is_equal_approx(cam.zoom.x, 2.0), "zoom 2x")  # Zoom 2x.
	# Dano máximo do tiro.
	check(_player.max_damage == 68, "dano máximo do tiro = 68 (+70%%) (%d)" % _player.max_damage)
	# Dano da espada.
	check(_player.weapon.damage == 50, "dano da espada = 50 (dobro) (%d)" % _player.weapon.damage)
	var sword := _player.weapon as Sword  # Espada.
	var shape := sword.hitbox_shape.shape as CircleShape2D  # Forma da hitbox.
	# Hitbox da espada +40%.
	check(is_equal_approx(shape.radius, 28.0 * 1.4), "hitbox da espada +40%% (raio %.1f)" % shape.radius)

	print("-- Câmera segue o player")  # Câmera segue o jogador.
	_player.global_position = Vector2(700, 300)  # Move o jogador.
	await frames(60)  # Espera.
	check(cam.get_screen_center_position().distance_to(Vector2(700, 300)) < 3.0,  # Câmera centrada nele.
			"câmera centrada no player (%s)" % cam.get_screen_center_position())
	_player.global_position = Vector2(5, 5)  # Canto do mapa.
	await frames(60)  # Espera.
	var c2: Vector2 = cam.get_screen_center_position()  # Centro da câmera.
	check(c2.x >= 0.0 and c2.y >= 0.0, "câmera respeita o limite (%s)" % c2)  # Respeita o limite.

	print("-- Botão de arma: alterna para o tiro")  # Botão de arma: alterna para o tiro.
	await reset_player()  # Prepara o jogador.
	var wb: Vector2 = _mc.call("_button_center", &"weapon")  # Centro do botão de arma.
	touch(1, wb, true)  # Aperta.
	await frames(2)  # Espera.
	touch(1, wb, false)  # Solta.
	await frames(2)  # Espera.
	check(_mc.weapon_ranged, "weapon_ranged = true")  # Está no tiro.

	# Toque rápido em 8 direções e 2 ângulos quebrados, sem inimigo.
	print("-- Toque rápido (1 quadro) em 8 direções + 2 ângulos quebrados, sem inimigo")
	# Ângulos testados.
	var angles: Array[float] = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0, 22.0, 200.0]
	for a: float in angles:  # Cada ângulo.
		await reset_player()  # Prepara.
		var shot: Dictionary = await tap_shot(deg_to_rad(a), 1)  # Toca.
		var ok: bool = not shot.is_empty()  # Saiu tiro?
		check(ok, "toque em %d°: saiu tiro" % int(a))  # Saiu.
		if ok:  # Saiu.
			var got: float = rad_to_deg((shot["dir"] as Vector2).angle())  # Direção obtida.
			var diff: float = absf(wrapf(got - a, -180.0, 180.0))  # Diferença para o esperado.
			# Direção correta.
			check(diff < 2.0, "toque em %d°: direção %.1f° (erro %.1f°)" % [int(a), got, diff])
			# Dano acima do mínimo.
			check(int(shot["damage"]) >= 20, "toque em %d°: dano %d >= mínimo" % [int(a), int(shot["damage"])])

	print("-- Tiro carregado (segurar 1.5 s)")  # Tiro carregado (segurar 1,5 s).
	await reset_player()  # Prepara.
	var charged: Dictionary = await tap_shot(deg_to_rad(30.0), 90)  # Toca e segura.
	check(not charged.is_empty(), "tiro carregado saiu")  # Saiu.
	print("   DBG shown=", _mc._shown, " blocked=", _mc._blocked, " paused=", paused_dbg(), " state=", _player.state, " hp=", _player.hp, " dead=", _player.esta_morto(), " fingers=", _mc._fingers)
	if not charged.is_empty():  # Saiu.
		# Dano carregado.
		check(int(charged["damage"]) == 68, "dano carregado = 68 (%d)" % int(charged["damage"]))
		# Escala do tiro carregado.
		check(is_equal_approx(float(charged["scale"]), 4.5), "escala do tiro carregado = 4.5 (%.2f)" % float(charged["scale"]))

	# Arrastar o analógico depois de tocar muda a direção.
	print("-- Arrastar o analógico depois de tocar muda a direção")
	await reset_player()  # Prepara.
	var center: Vector2 = _mc.call("_rest_aim")  # Centro do analógico.
	touch(0, center + Vector2(60, 0), true)  # Toca à direita.
	await frames(3)  # Espera.
	drag(0, center + Vector2(0, 60))  # Arrasta para baixo.
	await frames(3)  # Espera.
	touch(0, center + Vector2(0, 60), false)  # Solta.
	var shot_drag: Dictionary = {}  # Dados do tiro.
	for i: int in 30:  # Espera o tiro.
		await get_tree().physics_frame
		var l: Array[PlayerProjectile] = active_projectiles()  # Tiros em uso.
		if not l.is_empty():  # Há tiro.
			shot_drag = {"dir": l[0].direction}  # Guarda a direção.
			break  # Para.
	# Direção final para baixo.
	check(not shot_drag.is_empty() and absf(rad_to_deg((shot_drag["dir"] as Vector2).angle()) - 90.0) < 2.0,
			"direção final = 90° (para baixo)")

	# Mira assistida: inimigo levemente fora da linha.
	print("-- Mira assistida: inimigo levemente fora da linha")
	await reset_player()  # Prepara.
	var enemy_scene: PackedScene = load("res://enemies/tank/TankEnemy.tscn")  # Cena do tank.
	var enemy := enemy_scene.instantiate() as EnemyBase  # Cria o tank.
	level.add_child(enemy)  # Entra na fase.
	# Posiciona o inimigo 14° fora da linha.
	enemy.global_position = _player.global_position + Vector2.from_angle(deg_to_rad(14.0)) * 330.0
	enemy.process_mode = Node.PROCESS_MODE_DISABLED  # Congela o inimigo.
	await frames(5)  # Espera.
	# A mira automática do toque rápido já apontaria para o inimigo; usamos o arrasto para mirar reto (0°).
	touch(0, center + Vector2(60, 0), true)  # Toca.
	drag(0, center + Vector2(75, 0))  # Arrasta um pouco.
	await frames(3)  # Espera.
	touch(0, center + Vector2(75, 0), false)  # Solta.
	var start_dir := Vector2.RIGHT  # Direção inicial do tiro.
	var turned: float = 0.0  # Quanto o tiro curvou.
	var seen: bool = false  # Viu o tiro?
	for i: int in 40:  # Espera o tiro.
		await get_tree().physics_frame
		var l2: Array[PlayerProjectile] = active_projectiles()  # Tiros em uso.
		if not l2.is_empty():  # Há tiro.
			seen = true  # Viu.
			turned = absf(rad_to_deg(start_dir.angle_to(l2[0].direction)))  # Mede a curva.
			if i > 25:  # Depois de um tempo para.
				break
	check(seen, "tiro com assistência saiu")  # Saiu tiro assistido.
	# Curvou pouco, na direção do inimigo.
	check(turned > 2.0 and turned < 20.0, "tiro curvou %.1f° em direção ao inimigo (leve)" % turned)
	# Não libera o inimigo (a fase concluiria); só o tira do caminho.
	enemy.global_position = Vector2(6000, 6000)  # Afasta o inimigo.
	await frames(3)  # Espera.

	# Espada: segurar o analógico bate; toque rápido bate.
	print("-- Espada: segurar o analógico bate; toque rápido bate")
	await reset_player()  # Prepara.
	touch(1, wb, true)  # Aperta o botão de arma.
	await frames(2)  # Espera.
	touch(1, wb, false)  # Solta.
	await frames(2)  # Espera.
	check(not _mc.weapon_ranged, "weapon_ranged = false (espada)")  # Está na espada.
	# Espada: mira enquanto segura, golpeia ao soltar.
	print("-- Espada: mira enquanto segura, golpeia ao soltar")
	touch(0, center + Vector2(0, 60), true)  # Segura o analógico para baixo.
	await frames(30)  # Espera.
	var swung_while_held: bool = _player.state == Player.State.ATTACK_MELEE  # Já golpeou?
	check(not swung_while_held, "não golpeia enquanto o dedo segura")  # Não golpeia enquanto segura.
	check(_player.is_aiming_sword(), "mira da espada visível enquanto segura")  # A mira da espada aparece.
	var ind: Node = _player.get_node("AimIndicator")  # Mira visual.
	check(ind.visible, "AimIndicator visível")  # Visível.
	# Aponta para baixo.
	check(_player.get_sword_direction().distance_to(Vector2.DOWN) < 0.01, "mira da espada aponta para baixo")
	touch(0, center + Vector2(0, 60), false)  # Solta.
	var saw_after_release: bool = false  # Golpeou ao soltar?
	for i: int in 10:  # Espera até 10 quadros.
		await get_tree().physics_frame
		if _player.state == Player.State.ATTACK_MELEE:  # Golpeando.
			saw_after_release = true  # Viu.
			break  # Para.
	check(saw_after_release, "golpeia ao soltar")  # Golpeia ao soltar.
	# A mira continua durante o golpe.
	check(_player.is_aiming_sword(), "mira da espada continua durante o golpe")
	await frames(40)  # Espera o fim.
	# A mira some depois.
	check(not _player.is_aiming_sword() and not ind.visible, "mira some depois do golpe")
	var saw_melee: bool = false  # Toque rápido.
	touch(0, center + Vector2(60, 0), true)  # Toca.
	await frames(1)  # Espera.
	touch(0, center + Vector2(60, 0), false)  # Solta.
	for i: int in 20:  # Espera o golpe.
		await get_tree().physics_frame
		if _player.state == Player.State.ATTACK_MELEE:  # Golpeando.
			saw_melee = true  # Viu.
			break  # Para.
	check(saw_melee, "toque rápido de 1 quadro faz a espada bater")  # Toque rápido faz a espada bater.
	await frames(40)  # Espera.

	# Espada acerta o inimigo (mira automática do toque, escala 1,5).
	print("-- Espada acerta o inimigo (mira automática do toque, escala 1.5)")
	await reset_player()  # Prepara.
	var hits: Array[int] = []  # Danos recebidos.
	_player.causou_dano.connect(func(_a: Node, q: int) -> void: hits.append(q))  # Guarda cada dano.
	enemy.process_mode = Node.PROCESS_MODE_INHERIT  # Descongela o inimigo.
	enemy.set_physics_process(false)  # Desliga só a IA.
	enemy.state_machine.process_mode = Node.PROCESS_MODE_DISABLED  # Desliga a máquina de estados.
	# Posiciona o inimigo à frente.
	enemy.global_position = _player.global_position + Vector2.from_angle(deg_to_rad(40.0)) * 95.0
	await frames(5)  # Espera.
	touch(0, center + Vector2(60, 0), true)  # Toca.
	await frames(1)  # Espera.
	touch(0, center + Vector2(60, 0), false)  # Solta.
	await frames(40)  # Espera o golpe.
	# Causou 50 de dano.
	check(not hits.is_empty() and hits[0] == 50, "espada causou 50 de dano (%s)" % str(hits))
	enemy.global_position = Vector2(6000, 6000)  # Afasta o inimigo.
	await frames(3)  # Espera.

	# Toque rápido logo depois de um dash não se perde.
	print("-- Toque rápido logo depois de um dash não se perde")
	await reset_player()  # Prepara.
	# Estado antes de alternar a arma.
	print("   DBG before toggle ranged=", _mc.weapon_ranged, " shown=", _mc._shown, " blocked=", _mc._blocked, " paused=", get_tree().paused, " dead=", _player.esta_morto(), " inTree=", _player.is_inside_tree(), " state=", _player.state, " pos=", _player.global_position)
	touch(1, wb, true)  # Aperta o botão de arma.
	await frames(2)  # Espera.
	print("   DBG during toggle fingers=", _mc._fingers, " ranged=", _mc.weapon_ranged)  # Estado durante.
	touch(1, wb, false)  # Solta.
	await frames(2)  # volta ao tiro
	var db: Vector2 = _mc.call("_button_center", &"dash")  # Centro do botão de dash.
	touch(2, db, true)  # Aperta o dash.
	await frames(2)  # Espera.
	touch(2, db, false)  # Solta.
	print("   DBG ranged=", _mc.weapon_ranged, " state=", _player.state)  # Estado.
	var late: Dictionary = await tap_shot(deg_to_rad(60.0), 1)  # Toque rápido logo depois.
	# Estado depois.
	print("   DBG after: late=", late, " pending=", _mc._tap_pending, " state=", _player.state, " shoot=", _mc._act_state.get(&"charge_shoot"))
	check(not late.is_empty(), "tiro saiu mesmo logo após o dash")  # O tiro saiu.

	print("== %d verificações, %d falhas" % [_checks, _fails])  # Resultado.
	get_tree().quit(1 if _fails > 0 else 0)  # Sai com código de erro se algo falhou.
