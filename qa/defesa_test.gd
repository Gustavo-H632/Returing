extends Node
## Teste da transição do cristal + fase de defesa (headless). Confere: inimigos ORIGINAIS (Drone/Atirador/Tank), waves
## 1/2/3+ (só Drones; + Atiradores; + Tanks, crescendo) lidas da tabela, wave só avança quando todos morrem, aviso de
## wave, nascimento aleatório em pontos válidos (longe do jogador, fora de parede), os três tipos atacando o portal
## (10 por golpe), jogador no caminho, READY sem encerrar a fase, entrada no portal, game over, diálogo e cristal.
## Rodar: godot --headless --path . res://qa/defesa_test.tscn
## Saída: linhas "OK:" e "FALHA:"; código de saída 1 se algo falhar.

const DEFESA: String = "res://Scenes/Defesa/Defesa.tscn"
const SALA_NOVA: String = "res://Scenes/Fase2/SalaNova.tscn"
const QUIZ: String = "res://Scenes/Fase2/Fase2.tscn"
const TIME_SCALE: float = 4.0  # Acelera o jogo (os timers e tweens acompanham).

var _failures: int = 0
var _scene_requests: Array[String] = []  # Cenas pedidas ao EventBus.
var _game_overs: int = 0
var _level: DefenseLevel = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# O Global trocaria a cena de verdade (e destruiria este teste): desliga durante a execução.
	EventBus.scene_change_requested.disconnect(Global.change_scene)
	EventBus.scene_change_requested.connect(func(path: String) -> void: _scene_requests.append(path))
	EventBus.game_over.connect(func() -> void: _game_overs += 1)
	_run.call_deferred()


## Os abates dão XP e o menu de melhorias (existente) pausa o jogo ao subir de nível: o teste o ignora.
func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused = false


func _check(condition: bool, label: String) -> void:
	if condition:
		print("OK: ", label)
	else:
		_failures += 1
		print("FALHA: ", label)


## Espera `seconds` de tempo de jogo (acelerado).
func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _open_level() -> void:
	if _level != null:
		_level.queue_free()
		await get_tree().process_frame
		await get_tree().process_frame
	_level = (load(DEFESA) as PackedScene).instantiate() as DefenseLevel
	add_child(_level)
	await get_tree().process_frame
	await get_tree().process_frame


## Mata todos os inimigos vivos da wave (dano enorme pela API de dano do projeto).
func _kill_all() -> void:
	for enemy: EnemyBase in _level._enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.take_damage(100000, null)


## Espera até a wave `number` ser anunciada e toda a fila nascer.
func _wait_wave_spawned(number: int) -> void:
	var guard: int = 0
	while (_level.wave_number < number or _level.wave_phase != DefenseLevel.WavePhase.FIGHTING) and guard < 400:
		await _wait(0.1)
		guard += 1


func _kinds() -> Dictionary:
	var kinds: Dictionary = {"drone": 0, "robo": 0, "tank": 0, "outro": 0}
	for enemy: EnemyBase in _level._enemies:
		if enemy is DroneEnemy:
			kinds["drone"] += 1
		elif enemy is RoboEnemy:
			kinds["robo"] += 1
		elif enemy is TankEnemy:
			kinds["tank"] += 1
		else:
			kinds["outro"] += 1
	return kinds


func _run() -> void:
	Engine.time_scale = TIME_SCALE
	_test_assets_and_code()
	_test_wave_table()
	await _test_dialogue()
	await _test_waves()
	await _test_spawn_points()
	await _test_enemies_vs_portal()
	await _test_ready_and_exit()
	await _test_denied_and_game_over()
	await _test_crystal_sequence()
	Engine.time_scale = 1.0
	EventBus.scene_change_requested.connect(Global.change_scene)
	print("---- ", "TUDO OK" if _failures == 0 else "%d FALHA(S)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


# --- Arte em PNG, sem desenho por código ---

func _test_assets_and_code() -> void:
	for path: String in ["res://assets/defesa/arena_defesa.png", "res://assets/defesa/portal.png",
			"res://assets/defesa/barra_fundo.png", "res://assets/defesa/barra_hp.png",
			"res://assets/defesa/barra_carga.png", "res://assets/defesa/barra_pronto.png"]:
		_check(ResourceLoader.exists(path) and load(path) is Texture2D, "PNG importado: %s" % path)
	var offenders: PackedStringArray = []
	for path: String in ["res://Scenes/Defesa/defense_level.gd", "res://Scenes/Defesa/defense_portal.gd",
			"res://Scenes/Defesa/defense_hud.gd", "res://Scenes/Defesa/defense_wave_table.gd",
			"res://ui/dialogue/dialogue.gd", "res://Scenes/Transicao/crystal_transition.gd"]:
		var text: String = FileAccess.get_file_as_string(path)
		for banned: String in ["func _draw", "draw_rect", "draw_circle", "draw_line", "draw_polygon", "ImageTexture", "Image.create"]:
			if text.contains(banned):
				offenders.append("%s: %s" % [path.get_file(), banned])
	_check(offenders.is_empty(), "nenhuma arte desenhada por código (%s)" % ", ".join(offenders))
	_check(not FileAccess.file_exists("res://common/pixel_art.gd") and not FileAccess.file_exists("res://Scenes/Defesa/defense_enemy.gd"),
			"os inimigos e sprites antigos foram descartados")


# --- Tabela de waves ---

func _test_wave_table() -> void:
	var table: DefenseWaveTable = load("res://Scenes/Defesa/wave_table.tres") as DefenseWaveTable
	_check(table != null, "wave_table.tres carrega")
	var w1: Dictionary = table.get_counts(1)
	var w2: Dictionary = table.get_counts(2)
	var w3: Dictionary = table.get_counts(3)
	_check(w1.has("drone") and not w1.has("robo") and not w1.has("tank"), "wave 1: somente Drones %s" % str(w1))
	_check(w2.has("drone") and w2.has("robo") and not w2.has("tank"), "wave 2: Drones + Atiradores %s" % str(w2))
	_check(w3.has("drone") and w3.has("robo") and w3.has("tank"), "wave 3: Drones + Atiradores + Tanks %s" % str(w3))
	var grows: bool = true
	var previous: Dictionary = w3
	for n: int in range(4, 10):
		var current: Dictionary = table.get_counts(n)
		for kind: String in ["drone", "robo", "tank"]:
			if int(current[kind]) < int(previous[kind]):
				grows = false
		previous = current
	_check(grows and table.get_total(9) > table.get_total(3), "da wave 3 em diante a quantidade cresce (wave 9: %d)" % table.get_total(9))


# --- Dialogue ---

func _test_dialogue() -> void:
	for style: Dialogue.Style in [Dialogue.Style.VOICE, Dialogue.Style.BOX]:
		var dialogue: Dialogue = Dialogue.show_lines(self, ["Primeira.", "Segunda."], style, "TESTE")
		var started: Array[int] = []
		dialogue.line_started.connect(func(i: int) -> void: started.append(i))
		var done: Array[bool] = [false]
		dialogue.finished.connect(func() -> void: done[0] = true)
		await get_tree().process_frame
		_check(dialogue.is_playing(), "Dialogue %d: está tocando depois do play" % style)
		await _wait(8.0)
		_check(done[0], "Dialogue %d: emitiu 'finished' ao terminar" % style)
		_check(started.size() == 2 and started[0] == 0 and started[1] == 1, "Dialogue %d: duas falas em ordem (%s)" % [style, str(started)])
	var empty: Dialogue = Dialogue.show_lines(self, PackedStringArray(), Dialogue.Style.BOX, "")
	var empty_done: Array[bool] = [false]
	empty.finished.connect(func() -> void: empty_done[0] = true)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(empty_done[0], "Dialogue: array vazio termina (não trava)")
	# Segurar ESC pula tudo.
	var long_one: Dialogue = Dialogue.show_lines(self, ["Fala um bem longa para dar tempo de pular.", "Fala dois."], Dialogue.Style.BOX, "TESTE")
	var skipped: Array[bool] = [false]
	long_one.skipped.connect(func() -> void: skipped[0] = true)
	await get_tree().process_frame
	var press: InputEventAction = InputEventAction.new()
	press.action = &"ui_cancel"
	press.pressed = true
	Input.parse_input_event(press)
	await _wait(Dialogue.SKIP_HOLD_TIME + 0.5)
	var release: InputEventAction = InputEventAction.new()
	release.action = &"ui_cancel"
	release.pressed = false
	Input.parse_input_event(release)
	_check(skipped[0], "Dialogue: segurar ESC pula o diálogo (sinal 'skipped')")


# --- Waves ---

func _test_waves() -> void:
	await _open_level()
	_check(_level.state == DefenseLevel.State.DEFENDING, "fase começa em DEFENDING")
	_check(_level.alive_count() == 0, "nenhum inimigo antes da wave 1")
	await _wait_wave_spawned(1)
	_check(_level.hud.get_banner_text() == "WAVE 1", "aviso de início da wave 1 (%s)" % _level.hud.get_banner_text())
	var k1: Dictionary = _kinds()
	_check(k1["drone"] == 3 and k1["robo"] == 0 and k1["tank"] == 0 and k1["outro"] == 0, "wave 1 = 3 Drones originais %s" % str(k1))
	_check(get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY).size() == 3, "os Drones estão no grupo 'enemy'")
	var all_target_portal: bool = true
	for enemy: EnemyBase in _level._enemies:
		if enemy.target != _level.portal:
			all_target_portal = false
	_check(all_target_portal, "os inimigos nascem mirando o portal")
	# A wave só avança quando todos morrem.
	await _wait(DefenseLevel.WAVE_BREAK + DefenseLevel.ANNOUNCE_TIME + 2.0)
	_check(_level.wave_number == 1, "com inimigos vivos a wave 2 NÃO começa")
	_kill_all()
	await _wait(0.5)
	_check(_level.alive_count() == 0 and _level.wave_phase == DefenseLevel.WavePhase.BREAK, "wave 1 limpa: pausa até a próxima")
	await _wait_wave_spawned(2)
	_check(_level.hud.get_banner_text() == "WAVE 2", "aviso de início da wave 2")
	var k2: Dictionary = _kinds()
	_check(k2["drone"] == 4 and k2["robo"] == 2 and k2["tank"] == 0, "wave 2 = Drones + Atiradores %s" % str(k2))
	_kill_all()
	await _wait_wave_spawned(3)
	var k3: Dictionary = _kinds()
	_check(k3["drone"] > 0 and k3["robo"] > 0 and k3["tank"] > 0 and k3["outro"] == 0, "wave 3 = os três tipos %s" % str(k3))
	var total_3: int = _level.alive_count()
	_kill_all()
	await _wait_wave_spawned(4)
	_check(_level.alive_count() > total_3, "wave 4 é maior que a 3 (%d > %d)" % [_level.alive_count(), total_3])
	_check(_level.alive_count() <= _level.wave_table.max_active, "nunca mais que o limite de ativos (%d)" % _level.alive_count())


# --- Pontos de nascimento ---

func _test_spawn_points() -> void:
	await _open_level()
	var points: Array[Marker2D] = []
	for child: Node in _level.spawn_points_root.get_children():
		points.append(child as Marker2D)
	_check(points.size() >= 6, "há pontos de nascimento fixos nas bordas (%d)" % points.size())
	var all_free: bool = true
	var all_in_floor: bool = true
	for point: Marker2D in points:
		if not _level.is_point_free(point.global_position):
			all_free = false
		var p: Vector2 = point.global_position
		if p.x < 48.0 or p.x > 1104.0 or p.y < 104.0 or p.y > 608.0:
			all_in_floor = false
	_check(all_free, "nenhum ponto de nascimento está dentro de parede")
	_check(all_in_floor, "todos os pontos ficam dentro do piso da arena")
	var far_enough: bool = true
	for spot: Vector2 in [Vector2(576.0, 456.0), Vector2(216.0, 168.0), Vector2(1040.0, 356.0), Vector2(576.0, 168.0)]:
		_level.player.global_position = spot
		for point: Marker2D in _level.valid_spawn_points():
			if point.global_position.distance_to(spot) < DefenseLevel.MIN_SPAWN_PLAYER_DISTANCE:
				far_enough = false
	_check(far_enough, "nunca nasce a menos de %d px do jogador" % int(DefenseLevel.MIN_SPAWN_PLAYER_DISTANCE))
	_level.player.global_position = Vector2(576.0, 456.0)
	var used: Dictionary = {}
	var kinds_by_order: Dictionary = {}
	for i: int in 6:
		_level._queue.clear()
		for n: int in 4:
			_level._queue.append(_level.drone_scene)
		_level.wave_phase = DefenseLevel.WavePhase.SPAWNING
		for n: int in 4:
			_level._spawn_next()
	for enemy: EnemyBase in _level._enemies:
		var best: float = INF
		var best_name: String = ""
		for point: Marker2D in points:
			var d: float = enemy.global_position.distance_to(point.global_position)
			if d < best:
				best = d
				best_name = point.name
		used[best_name] = true
		kinds_by_order[enemy.global_position.distance_to(_level.player.global_position) >= DefenseLevel.MIN_SPAWN_PLAYER_DISTANCE - DefenseLevel.SPAWN_JITTER * 1.5] = true
	_check(used.size() >= 3, "os pontos de nascimento são sorteados (usou %d diferentes)" % used.size())
	_check(kinds_by_order.size() == 1 and kinds_by_order.has(true), "todos os inimigos reais nasceram longe do jogador")
	# A mistura de tipos também é sorteada: 20 sorteios da wave 3 não podem sempre dar a mesma ordem.
	var orders: Dictionary = {}
	var table: DefenseWaveTable = _level.wave_table
	for i: int in 20:
		var queue: Array[String] = []
		var counts: Dictionary = table.get_counts(3)
		for kind: Variant in counts:
			for n: int in int(counts[kind]):
				queue.append(String(kind))
		queue.shuffle()
		orders[",".join(queue)] = true
	_check(orders.size() > 1, "a ordem dos tipos na wave é sorteada")


# --- Os três inimigos originais contra o portal e o jogador ---

func _spawn_kind(scene: PackedScene, at: Vector2) -> EnemyBase:
	_level._queue.clear()
	_level._queue.append(scene)
	_level.wave_phase = DefenseLevel.WavePhase.SPAWNING
	_level._spawn_next()
	var enemy: EnemyBase = _level._enemies.back()
	enemy.global_position = at
	return enemy


func _test_enemies_vs_portal() -> void:
	await _open_level()
	_level._stop_waves()
	var portal: DefensePortal = _level.portal
	var player: Player = _level.player
	player.global_position = Vector2(150.0, 200.0)  # Jogador longe: só o portal é alvo.
	var cases: Array = [["Drone", _level.drone_scene, Vector2(60.0, 0.0)], ["Atirador", _level.robo_scene, Vector2(260.0, 0.0)],
			["Tank", _level.tank_scene, Vector2(70.0, 0.0)]]
	for entry: Array in cases:
		portal.start()
		portal._last_hit_msec = -1000
		var enemy: EnemyBase = _spawn_kind(entry[1] as PackedScene, portal.global_position + (entry[2] as Vector2))
		enemy.target = portal
		await _wait(7.0)
		var lost: int = DefensePortal.MAX_HP - portal.hp
		_check(lost > 0 and lost % DefensePortal.HIT_DAMAGE == 0, "%s original ataca o portal em golpes de 10 (perdeu %d)" % [entry[0], lost])
		enemy.queue_free()
		_level._enemies.clear()
		await get_tree().process_frame
	# Jogador no caminho vira o alvo e é atacado.
	portal.start()
	_level.retarget_timer.start()
	player.global_position = Vector2(576.0, 470.0)
	var hp_before: int = player.hp
	var near: EnemyBase = _spawn_kind(_level.drone_scene, Vector2(576.0, 420.0))
	await _wait(1.0)
	_check(near.target == player, "jogador a menos de %d px vira o alvo" % int(DefenseLevel.PLAYER_AGGRO_RADIUS))
	await _wait(5.0)
	_check(player.hp < hp_before, "o inimigo ataca o jogador no caminho (hp %d -> %d)" % [hp_before, player.hp])
	near.global_position = Vector2(150.0, 200.0)
	player.global_position = Vector2(1000.0, 560.0)
	await _wait(1.0)
	_check(near.target == portal, "com o jogador longe o alvo volta a ser o portal")


# --- Carga, READY e saída ---

func _test_ready_and_exit() -> void:
	await _open_level()
	_level._stop_waves()
	var portal: DefensePortal = _level.portal
	var player: Player = _level.player
	_check(portal.state == DefensePortal.State.CHARGING, "portal começa CHARGING")
	_check(DefensePortal.CHARGE_TIME == 30.0 and DefensePortal.MAX_HP == 100 and DefensePortal.HIT_DAMAGE == 10, "portal: 30 s, 100 de vida, 10 por golpe")
	portal._charge_tween.custom_step(DefensePortal.CHARGE_TIME)  # Avança os 30 s da carga.
	await get_tree().process_frame
	_check(portal.state == DefensePortal.State.READY, "depois de 30 s o portal fica READY")
	_check(portal.sprite.frame_coords.y == DefensePortal.ROW_READY or portal._row == DefensePortal.ROW_READY, "o PNG passa para a linha 'pronto'")
	await _wait(1.0)
	_check(_level.state == DefenseLevel.State.DEFENDING, "READY NÃO encerra a fase")
	_check(_scene_requests.is_empty(), "nenhuma troca de cena enquanto o jogador não entra")
	portal.body_entered.emit(player)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(_level.state == DefenseLevel.State.EXITING, "jogador entrou no portal READY: fase em EXITING")
	await _wait(14.0)
	_check(_scene_requests.has(QUIZ), "depois do diálogo a próxima cena é o quiz (%s)" % str(_scene_requests))


func _test_denied_and_game_over() -> void:
	_scene_requests.clear()
	await _open_level()
	_level._stop_waves()
	var portal: DefensePortal = _level.portal
	portal.body_entered.emit(_level.player)
	await get_tree().process_frame
	_check(_level.state == DefenseLevel.State.DEFENDING, "entrar com o portal carregando não avança a fase")
	_check(_level.hud.get_hint_text() == DefenseLevel.DENIED_HINT, "aviso de portal carregando aparece")
	_game_overs = 0
	for i: int in 10:
		portal._last_hit_msec = -1000  # Ignora o intervalo mínimo entre golpes (o teste bate sem pausa).
		portal.take_damage(DefenseEnemy_HIT)
	_check(portal.hp == 0 and portal.state == DefensePortal.State.DESTROYED, "10 golpes de 10 destroem o portal")
	_check(_level.state == DefenseLevel.State.GAME_OVER, "portal destruído: fase em GAME_OVER")
	await _wait(DefenseLevel.GAME_OVER_DELAY + 0.5)
	_check(_game_overs == 1, "game over emitido uma vez pelo EventBus")
	_check(not portal.take_damage(10), "portal destruído não recebe mais dano")


const DefenseEnemy_HIT: int = 10  # Qualquer valor: cada golpe aceito vale HIT_DAMAGE.


# --- Sequência do cristal ---

func _test_crystal_sequence() -> void:
	_scene_requests.clear()
	if _level != null:
		_level.queue_free()
		_level = null
		await get_tree().process_frame
	var sala: SalaNova = (load(SALA_NOVA) as PackedScene).instantiate() as SalaNova
	add_child(sala)
	await get_tree().process_frame
	_check(sala.next_scene == DEFESA, "SalaNova leva à fase de defesa")
	var player: Node2D = sala.get_node("Player") as Node2D
	sala.nucleo.body_entered.emit(player)
	await get_tree().process_frame
	_check(_scene_requests.is_empty(), "sequência do cristal não troca de cena na hora")
	await _wait(30.0)
	_check(_scene_requests == [DEFESA], "depois da sequência pede a fase de defesa (%s)" % str(_scene_requests))
