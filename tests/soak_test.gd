extends Node
## Teste de estresse: joga uma fase com toques aleatórios (mover, mirar, atirar, espada, dash, trocar arma).
## Procura erros de script, travadas de estado e tiros perdidos.
##   godot --headless --path . res://tests/soak_test.tscn -- --mobile <cena> <segundos> [godmode]

var root: Window = null  # Janela raiz.
# Gerador de números aleatórios (semente fixa, para repetir o teste).
var rng := RandomNumberGenerator.new()


## Converte uma posição da tela lógica para a da janela.
func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos


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


## Guarda a janela e agenda o teste.
func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()


## Joga a fase por alguns segundos com toques aleatórios e conta tiros, golpes, dashes, acertos e travamentos de estado.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()  # Argumentos.
	var scene_path: String = args[1]  # Cena.
	var seconds: float = float(args[2])  # Duração (s).
	var god: bool = args.size() > 3  # Modo deus (vida enorme) se houver o quarto argumento.
	rng.seed = 12345  # Semente fixa.
	var level: Node = load(scene_path).instantiate()  # Cria a fase.
	root.add_child(level)  # Entra na árvore.
	get_tree().current_scene = level  # É a cena atual.
	for i in 20:  # Espera 20 quadros.
		await get_tree().physics_frame
	var player: Player = level.get_node_or_null("Player") as Player  # Jogador.
	var mc := MobileControls  # Controles de toque.
	var stats := {"shots": 0, "melee": 0, "dash": 0, "hits": 0, "stuck": 0}  # Estatísticas.
	if player != null:  # Há jogador.
		player.estado_mudou.connect(func(s: int) -> void:  # Conta cada mudança de estado.
			if s == Player.State.ATTACK_RANGED: stats["shots"] += 1
			elif s == Player.State.ATTACK_MELEE: stats["melee"] += 1
			elif s == Player.State.DASH: stats["dash"] += 1)
		player.causou_dano.connect(func(_a: Node, _q: int) -> void: stats["hits"] += 1)  # Conta cada acerto.
		if god:  # Modo deus.
			player.hp_maximo = 100000
			player.hp = 100000
	var t_end: int = Time.get_ticks_msec() + int(seconds * 1000.0)  # Hora de terminar.
	var aim_c: Vector2 = mc.control_center(&"aim")  # Centro do analógico de mira.
	var mv_c: Vector2 = mc.control_center(&"move")  # Centro do analógico de movimento.
	var move_down := false  # Dedo do movimento está apertado?
	var ticks := 0  # Contador de quadros.
	while Time.get_ticks_msec() < t_end:  # Repete até acabar o tempo.
		ticks += 1  # Mais um quadro.
		await get_tree().physics_frame  # Espera um quadro.
		if not is_instance_valid(player):  # Jogador sumiu: termina.
			break
		var r: float = rng.randf()  # Sorteio do quadro.
		# movimento: pressiona/arrasta/solta
		if r < 0.02:
			if move_down:
				touch(1, mv_c, false)
				move_down = false
			else:
				touch(1, mv_c, true)
				drag(1, mv_c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 80.0))
				move_down = true
		elif move_down and r < 0.08:
			drag(1, mv_c + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 80.0))
		# mira/ataque
		var r2: float = rng.randf()  # Sorteio da mira e do ataque.
		if r2 < 0.03:  # Mira e ataque.
			var a: Vector2 = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 70.0)
			touch(2, aim_c + a, true)
			drag(2, aim_c + a * 1.1)
			var hold: int = [1, 1, 2, 5, 30, 80][rng.randi() % 6]
			for k in hold:
				await get_tree().physics_frame
			touch(2, aim_c + a, false)
		elif r2 < 0.04:  # Trocar de arma.
			var wb: Vector2 = mc.control_center(&"weapon")
			touch(3, wb, true)
			await get_tree().physics_frame
			touch(3, wb, false)
		elif r2 < 0.06:  # Dash.
			var db: Vector2 = mc.control_center(&"dash")
			touch(4, db, true)
			await get_tree().physics_frame
			touch(4, db, false)
		# trava de estado: ficar em ATTACK_RANGED/MELEE por muito tempo sem dedo
		if is_instance_valid(player) and not mc._aim_down and not mc._tap_pending and player.state == Player.State.ATTACK_RANGED:
			stats["stuck"] += 1
	# Resultado.
	print("SOAK ", scene_path, " ticks=", ticks, " stats=", stats, " hp=", player.hp if is_instance_valid(player) else -1, " paused=", get_tree().paused)
	get_tree().quit()  # Fecha o jogo.
