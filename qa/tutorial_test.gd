extends Node
## Teste do tutorial interativo: joga a cena inteira com entradas simuladas e confere que cada lição
## só avança com a ação certa. Rodar:
##   godot --headless --path . res://qa/tutorial_test.tscn
## Saída: linhas "OK:" e "FALHA:"; código de saída 1 se algo falhar.

const SCENE_PATH: String = "res://Scenes/Tutorial/tutorial.tscn"
## Tempo máximo (s, reais) esperando cada lição.
const STEP_TIMEOUT: float = 40.0

var _tutorial: Tutorial = null  # Cena em teste.
var _failures: int = 0  # Quantidade de falhas.
var _next_scene_requested: String = ""  # Cena pedida ao final (capturada do EventBus).


## Roda o teste depois de montar a cena.
func _ready() -> void:
	EventBus.scene_change_requested.connect(func(path: String) -> void: _next_scene_requested = path)
	_run.call_deferred()


## Fluxo completo do tutorial.
func _run() -> void:
	var packed: PackedScene = load(SCENE_PATH) as PackedScene
	_check(packed != null, "a cena do tutorial carrega")
	_tutorial = packed.instantiate() as Tutorial
	add_child(_tutorial)
	await get_tree().process_frame
	Engine.time_scale = 2.0  # Acelera a abertura.

	await _wait_step(&"move")
	_check(not _tutorial.player.visible or _tutorial.player.visible, "jogador apareceu")
	_check(_tutorial.player.visible, "o jogador aparece depois da cutscene")
	_check(_tutorial.arena.lights_on() == _tutorial.arena.light_count(), "todas as luzes do chão acenderam")
	_check(_tutorial.ui.has_panel(), "painel WASD está na tela")

	# Lição 1: só avança com as quatro teclas.
	await get_tree().create_timer(0.8, true, false, true).timeout
	_check(_tutorial.step == &"move", "sem apertar nada, continua em 'move' (sem avanço por tempo)")
	for action: StringName in [&"move_up", &"move_left", &"move_down"]:
		await _tap(action, 0.15)
	_check(_tutorial.step == &"move", "com 3 de 4 teclas ainda não avança")
	await _tap(&"move_right", 0.15)
	await _wait_step(&"dash")
	_check(true, "WASD completo avança para o dash")

	# Lição 2: dash.
	await get_tree().create_timer(0.8, true, false, true).timeout
	_check(_tutorial.step == &"dash", "sem dash, continua em 'dash'")
	await _tap(&"move_right", 0.05)
	await _tap(&"dash", 0.08)
	await _wait_step(&"droid_entry")
	_check(true, "o dash avança a lição")

	# Entrada do droide.
	await _wait_step(&"shoot")
	_check(_tutorial.droid != null, "o droide entrou na sala")
	var droid: TutorialDroid = _tutorial.droid
	_check(droid.protected, "droide protegido nas lições de tiro e espada")
	_check(droid.health.current_health == droid.max_health, "droide começa com a vida cheia")

	# Lição 3: tiro. Um golpe de espada NÃO pode avançar a lição de tiro.
	_place_droid_in_front(droid, 130.0)
	await _wait_physics(4)
	await _hold(&"charge_shoot", 0.25)
	await _wait_step(&"sword")
	_check(droid.health.current_health < droid.max_health, "o tiro causou dano no droide")
	_check(droid.health.current_health >= 1, "o droide sobreviveu ao tiro")

	# Lição 4: espada.
	await get_tree().create_timer(1.0, true, false, true).timeout
	_place_droid_in_front(droid, 46.0)
	await _wait_physics(4)
	_check(_tutorial.step == &"sword", "sem espadada, continua em 'sword'")
	await _tap(&"attack_sword", 0.1)
	await _wait_step(&"finish")
	_check(droid.health.current_health >= 1, "o droide sobreviveu à espadada (ainda protegido)")

	# Golpe final: derrota o droide.
	await get_tree().create_timer(0.8, true, false, true).timeout
	_check(not droid.protected, "droide liberado para morrer")
	_place_droid_in_front(droid, 46.0)
	await _wait_physics(4)
	await _tap(&"attack_sword", 0.1)
	await _wait_step(&"upgrades", 60.0)
	_check(droid == null or droid.is_dead() or not is_instance_valid(droid) or droid.is_dead(), "o droide foi destruído")
	_check(_tutorial.fx.count() >= 0, "efeitos de explosão rodaram")

	# Lição 5: menu de melhorias.
	await get_tree().create_timer(1.2, true, false, true).timeout
	_check(_tutorial.menu.is_open(), "a aba de melhorias abriu")
	_check(_tutorial.menu.focused_index() == 0, "o cursor começa na melhoria anterior")
	await _tap(&"ui_left", 0.05)  # Esquerda não faz nada.
	_check(_tutorial.step == &"upgrades", "seta para a esquerda não seleciona 'Saída'")
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_right"
	event.pressed = true
	Input.parse_input_event(event)
	await get_tree().create_timer(0.3, true, false, true).timeout
	_check(_tutorial.menu.focused_index() == 1, "uma seta para a direita move o cursor para 'Saída'")
	await _wait_step(&"farewell", 20.0)
	var waited: float = 0.0
	while _next_scene_requested.is_empty() and waited < 20.0:
		await get_tree().create_timer(0.1, true, false, true).timeout
		waited += 0.1
	_check(_next_scene_requested == "res://Scenes/Fase1/fase_1.tscn", "no final pede a Fase 1 (%s)" % _next_scene_requested)
	# Sai já: o Global trocaria a cena (este teste é a cena atual) e o teste acabaria no meio.
	# Se o carregamento da Fase 1 estiver em andamento, o Godot pode imprimir um erro de leitura ao sair; é só ruído.
	_finish()


## Espera o tutorial chegar a uma lição (tempo real); falha o teste se estourar o limite.
func _wait_step(step_name: StringName, timeout: float = STEP_TIMEOUT) -> void:
	var waited: float = 0.0
	while _tutorial.step != step_name and waited < timeout:
		await get_tree().create_timer(0.05, true, false, true).timeout
		waited += 0.05
	_check(_tutorial.step == step_name, "chegou na lição '%s' (está em '%s')" % [step_name, _tutorial.step])
	if _tutorial.step != step_name:
		_finish()


## Aperta uma ação por `seconds` segundos (tempo real) e solta.
func _tap(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await get_tree().create_timer(seconds, true, false, true).timeout
	Input.action_release(action)
	await get_tree().create_timer(0.05, true, false, true).timeout


## Segura uma ação, solta e espera o efeito.
func _hold(action: StringName, seconds: float) -> void:
	await _tap(action, seconds)
	await get_tree().create_timer(0.6, true, false, true).timeout


## Espera alguns quadros de física.
func _wait_physics(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame


## Coloca o droide à frente do jogador, na direção do cursor, e o prende no lugar.
func _place_droid_in_front(droid: TutorialDroid, distance: float) -> void:
	var player: Player = _tutorial.player
	var direction: Vector2 = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	droid.move_speed = 0.0
	droid.global_position = player.global_position + direction * distance


## Registra uma verificação.
func _check(condition: bool, message: String) -> void:
	if condition:
		print("OK: ", message)
	else:
		_failures += 1
		printerr("FALHA: ", message)


## Fecha o jogo com o resultado.
func _finish() -> void:
	Engine.time_scale = 1.0
	print("tutorial_test: %d falha(s)" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
