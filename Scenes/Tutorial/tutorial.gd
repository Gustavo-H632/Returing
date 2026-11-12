class_name Tutorial
extends Node2D
## Tutorial de estudante (cena entre a cutscene e a Fase 1).
## Quem guia é um mentor invisível: só uma voz em texto. Cada lição só avança quando o jogador
## faz a ação pedida. Sequência:
##   1. cutscene escura -> luzes do chão acendem -> o jogador aparece
##   2. W A S D  3. dash  4. droide: tiro (botão direito) e espada (botão esquerdo)
##   5. aba de melhorias com a melhoria "Saída" -> seta para a direita -> despedida -> Fase 1
## O jogador pode pular tudo segurando TAB (ou pelo botão "Pular tutorial").

## Cena que abre depois do tutorial.
@export_file("*.tscn") var next_scene: String = "res://Scenes/Fase1/fase_1.tscn"

@export_group("Cutscene")
## Pausa (s) no escuro antes da primeira fala.
@export_range(0.0, 5.0, 0.1) var intro_pause: float = 0.9
## Linhas da abertura (a voz do mentor).
@export var intro_lines: PackedStringArray = [
	"Então você chegou... estudante.",
	"Vamos ver do que você é capaz.",
]

@export_group("Droide")
## Onde o droide nasce (embaixo da escotilha do teto).
@export var droid_spawn: Vector2 = Vector2(576.0, 46.0)
## Onde ele para de descer antes de começar a andar.
@export var droid_landing: Vector2 = Vector2(576.0, 118.0)

@export_group("Dash")
## Intervalo (s) entre as imagens-fantasma do dash.
@export_range(0.01, 0.1, 0.005) var ghost_interval: float = 0.03

## Lição atual (usado nos testes e na depuração).
var step: StringName = &"idle"
## Droide de treino (null antes de entrar e depois de morrer).
var droid: TutorialDroid = null

var _leaving: bool = false  # True quando o tutorial está indo embora (pular ou terminar).
var _shake: float = 0.0  # Força da tremida de tela (px).
var _hit_stop_active: bool = false  # Hit stop em andamento.
var _prev_state: int = Player.State.IDLE  # Estado anterior do jogador.
var _dash_done: bool = false  # O jogador deu um dash na lição do dash.
var _ranged_hits: int = 0  # Tiros que acertaram o droide.
var _melee_hits: int = 0  # Espadadas que acertaram o droide.
var _dealt_queue: int = 0  # Acertos do jogador ainda não classificados.
var _sword_queue: int = 0  # Acertos de espada ainda não classificados.
var _droid_dead: bool = false  # O droide foi destruído.
var _dust_clock: float = 0.0  # Intervalo da poeira dos passos.
var _ghost_clock: float = 0.0  # Intervalo das imagens-fantasma.
var _weapon_swapped: bool = false  # Celular: o jogador trocou a arma na lição da troca.
var _tilt_seen: Dictionary = {}  # Celular: direções de inclinação já feitas na lição do modo comando.

@onready var player: Player = $Player
@onready var arena: TutorialArena = $Arena
@onready var fx: TutorialFx = $Fx
@onready var camera: Camera2D = $Camera2D
@onready var ui: TutorialUi = $TutorialUi
@onready var sfx: TutorialSfx = $TutorialSfx
@onready var menu: TutorialUpgradeMenu = $TutorialUpgradeMenu
@onready var hud: CanvasLayer = $HUD


## Prepara a cena (jogador escondido, sala apagada) e começa a sequência.
func _ready() -> void:
	ui.sfx = sfx
	menu.sfx = sfx
	camera.global_position = TutorialArena.CENTER
	camera.make_current()
	player.global_position = TutorialArena.CENTER
	player.visible = false
	player.set_physics_process(false)  # Sem entrada até o jogador aparecer.
	hud.visible = false
	if Platform.is_mobile():  # Celular: os controles só aparecem junto com o jogador.
		MobileControls.reset_state()
		MobileControls.suspended = true
	arena.brightness = 0.04
	arena.light_turned_on.connect(_on_light_on)
	ui.skip_requested.connect(skip)
	menu.exit_selected.connect(_on_exit_selected)
	player.estado_mudou.connect(_on_player_state)
	player.causou_dano.connect(_on_player_dealt)
	if player.weapon != null:
		player.weapon.hit_landed.connect(_on_sword_hit)
	_run()


## Devolve o tempo ao normal se a cena sair no meio de um hit stop.
func _exit_tree() -> void:
	Engine.time_scale = 1.0
	if Platform.is_mobile():
		MobileControls.suspended = false
		MobileControls.set_highlight(&"")
		MobileControls.reset_state()
		var abilities: AbilityComponent = player.get_node_or_null(^"AbilityComponent") as AbilityComponent
		if abilities != null:
			abilities.practice = false


## Tremida da câmera e feedback do jogador (poeira, fantasmas do dash).
func _process(delta: float) -> void:
	_shake = maxf(_shake - 30.0 * delta, 0.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	if player.visible and not _leaving:
		_player_feedback(delta)


## Pula o tutorial: escurece e vai direto para a Fase 1.
func skip() -> void:
	if _leaving:
		return
	_leaving = true
	step = &"skipped"
	ui.clear_panel()
	player.set_physics_process(false)
	await ui.fade_darkness(1.0, 0.4).finished
	EventBus.scene_change_requested.emit(next_scene)


# --- Sequência ---

## Roda todas as lições em ordem. Cada uma só termina com uma ação do jogador.
func _run() -> void:
	await _cutscene()
	if _leaving:
		return
	await _lesson_move()
	if _leaving:
		return
	await _lesson_dash()
	if _leaving:
		return
	await _lesson_droid_entry()
	if _leaving:
		return
	await _lesson_shoot()
	if _leaving:
		return
	if Platform.is_mobile():
		await _lesson_weapon()
		if _leaving:
			return
	await _lesson_sword()
	if _leaving:
		return
	await _lesson_finish()
	if _leaving:
		return
	if Platform.is_mobile():
		await _lesson_command()
		if _leaving:
			return
	await _lesson_upgrades()
	if _leaving:
		return
	await _farewell()


## Parte 1: tela escura, a voz fala, as luzes do chão acendem e o jogador aparece no centro.
func _cutscene() -> void:
	step = &"cutscene"
	ui.set_vignette(1.1)
	await _sleep(intro_pause)
	for line: String in intro_lines:
		if _leaving:
			return
		await ui.speak(line, 1.2)
	if _leaving:
		return
	await _sleep(0.3)
	await arena.light_up_sequence()
	if _leaving:
		return
	_reveal_player()
	ui.fade_vignette(0.6, 1.5)
	hud.visible = true
	await _sleep(0.9)


## O jogador surge no centro com um anel de energia e passa a obedecer à entrada.
func _reveal_player() -> void:
	sfx.play(&"power_up")
	fx.ring(TutorialArena.CENTER, 110.0, 0.7)
	fx.flash(TutorialArena.CENTER, 60.0, 0.25, Color(0.6, 0.9, 1.0, 0.9))
	player.visible = true
	player.modulate.a = 0.0
	create_tween().tween_property(player, ^"modulate:a", 1.0, 0.45)
	player.set_physics_process(true)
	if Platform.is_mobile():
		MobileControls.suspended = false


## Parte 2: andar com W A S D. Cada tecla recebe um check quando usada.
func _lesson_move() -> void:
	step = &"move"
	if Platform.is_mobile():
		MobileControls.set_highlight(MobileLayout.MOVE)
		ui.show_panel(&"m_move", "Mova-se com o joystick", "", "Arraste o joystick esquerdo para os quatro lados.")
	else:
		ui.show_panel(&"wasd", "Aperte W A S D para andar")
	var actions: Array[StringName] = [&"move_up", &"move_left", &"move_down", &"move_right"]
	var used: int = 0
	while not _leaving and used < actions.size():
		used = 0
		for action: StringName in actions:
			var pressed: bool = Input.is_action_pressed(action)
			ui.set_key_pressed(action, pressed)
			if pressed:
				ui.mark_key(action)
			if ui.is_key_checked(action):
				used += 1
		await get_tree().process_frame
	if _leaving:
		return
	for action: StringName in actions:
		ui.set_key_pressed(action, false)
	_clear_highlight()
	await ui.complete_panel()
	if _leaving:
		return
	await ui.say("Seus pés funcionam. Ótimo.")


## Parte 3: dash.
func _lesson_dash() -> void:
	step = &"dash"
	_dash_done = false
	if Platform.is_mobile():
		MobileControls.set_highlight(MobileLayout.DASH)
		ui.show_panel(&"m_dash", "Use o dash", "", "Toque no botão de dash. Ele deixa você invulnerável por um instante.")
	else:
		ui.show_panel(&"key", "Aperte ESPAÇO para dar um dash", "ESPAÇO", "Ele também deixa você invulnerável por um instante.")
	while not _leaving and not _dash_done:
		ui.set_key_pressed(&"key", Input.is_action_pressed(&"dash"))
		await get_tree().process_frame
	if _leaving:
		return
	ui.mark_key(&"key")
	_clear_highlight()
	await ui.complete_panel()
	if _leaving:
		return
	await ui.say("Rápido. Bom.")


## Parte 4a: a escotilha abre, as luzes ficam mais fortes e o droide entra.
func _lesson_droid_entry() -> void:
	step = &"droid_entry"
	await ui.say("Um droide de treino. Lento... e fraco.")
	if _leaving:
		return
	await _sleep(0.5)
	sfx.play(&"hatch")
	arena.intensify()
	await arena.open_hatch()
	if _leaving:
		return
	droid = TutorialDroid.new()
	droid.position = droid_spawn
	droid.target = player
	droid.protected = true
	droid.hit_taken.connect(_on_droid_hit)
	droid.destroyed.connect(_on_droid_destroyed)
	add_child(droid)
	sfx.play(&"spawn")
	fx.ring(droid_spawn + Vector2(0.0, 30.0), 60.0, 0.5, Color(0.5, 0.8, 1.0, 0.9))
	fx.flash(droid_spawn + Vector2(0.0, 24.0), 30.0, 0.18, Color(0.6, 0.9, 1.0, 0.9))
	_shake = 2.5
	create_tween().tween_property(droid, ^"position", droid_landing, 0.8).set_trans(Tween.TRANS_SINE)
	await _sleep(1.0)
	arena.close_hatch()
	await _sleep(0.5)


## Parte 4b: tiro com o botão direito do mouse.
func _lesson_shoot() -> void:
	step = &"shoot"
	_ranged_hits = 0
	if Platform.is_mobile():
		MobileControls.weapon_ranged = true  # O joystick direito atira.
		MobileControls.set_highlight(MobileLayout.AIM)
		ui.show_panel(&"m_shoot", "Use o ataque de tiro", "",
				"Arraste o joystick direito para mirar e solte para atirar. Segurar carrega o tiro.")
	else:
		ui.show_panel(&"mouse_right", "Clique com o botão DIREITO para atirar", "",
				"Segure para carregar e solte para disparar na direção do cursor.")
	while not _leaving and _ranged_hits == 0:
		await get_tree().process_frame
	if _leaving:
		return
	_clear_highlight()
	await ui.complete_panel()
	if _leaving:
		return
	await ui.say("Na mosca. Agora de perto.")


## Parte 4c: espadada com o botão esquerdo do mouse.
func _lesson_sword() -> void:
	step = &"sword"
	_melee_hits = 0
	if Platform.is_mobile():
		MobileControls.weapon_ranged = false  # A lição anterior trocou a arma: o joystick direito golpeia.
		MobileControls.set_highlight(MobileLayout.AIM)
		ui.show_panel(&"m_sword", "Use o ataque de espada", "",
				"Com a espada escolhida, chegue perto do droide e use o joystick direito.")
	else:
		ui.show_panel(&"mouse_left", "Clique com o botão ESQUERDO para atacar com a espada", "",
				"Chegue perto do droide e golpeie na direção do cursor.")
	while not _leaving and not _droid_dead and _melee_hits == 0:
		await get_tree().process_frame
	if _leaving:
		return
	_clear_highlight()
	await ui.complete_panel()
	if _leaving:
		return
	await ui.say("Aço também fala. Termine o serviço.")


## Celular: troca de arma. O joystick direito começa no tiro; o botão troca para a espada.
func _lesson_weapon() -> void:
	step = &"weapon"
	_weapon_swapped = false
	MobileControls.weapon_ranged = true
	MobileControls.set_highlight(MobileLayout.WEAPON)
	ui.show_panel(&"m_weapon", "Troque a arma", "", "Toque no botão de trocar arma: o joystick direito passa a golpear com a espada.")
	var on_swap: Callable = func(ranged: bool) -> void:
		if not ranged:
			_weapon_swapped = true
	MobileControls.weapon_swapped.connect(on_swap)
	while not _leaving and not _weapon_swapped:
		await get_tree().process_frame
	MobileControls.weapon_swapped.disconnect(on_swap)
	if _leaving:
		return
	ui.mark_key(&"key")
	_clear_highlight()
	await ui.complete_panel()
	if _leaving:
		return
	await ui.say("Duas armas. Escolha com sabedoria.")


## Celular: modo comando. O botão abre o quadro de comandos; as setas vêm da inclinação do celular
## (ou do D-pad, se o aparelho não tiver acelerômetro). Cada uma das quatro direções recebe um check.
func _lesson_command() -> void:
	var abilities: AbilityComponent = player.get_node_or_null(^"AbilityComponent") as AbilityComponent
	if abilities == null:
		return
	step = &"command"
	abilities.practice = true  # abre sem habilidades e sem câmera lenta
	MobileControls.set_highlight(MobileLayout.COMMAND)
	ui.show_panel(&"m_command", "Abra o modo comando", "", "Toque no botão de modo comando.")
	while not _leaving and not abilities.command_active:
		await get_tree().process_frame
	if _leaving:
		return
	_clear_highlight()
	ui.mark_key(&"key")
	await ui.complete_panel()
	if _leaving:
		return
	step = &"tilt"
	_tilt_seen.clear()
	MobileControls.set_highlight(MobileLayout.BOARD)
	ui.show_panel(&"m_tilt", "Incline o celular", "",
			"Para cima, baixo, esquerda e direita. Volte ao centro entre uma seta e a próxima.")
	var actions: Dictionary = {
		AbilityData.Dir.UP: &"cmd_up", AbilityData.Dir.DOWN: &"cmd_down",
		AbilityData.Dir.LEFT: &"cmd_left", AbilityData.Dir.RIGHT: &"cmd_right",
	}
	var on_arrow: Callable = func(dir: int) -> void:
		var action: StringName = actions.get(dir, &"")
		if action != &"" and ui.mark_key(action):
			_tilt_seen[dir] = true
	abilities.arrow_input.connect(on_arrow)
	while not _leaving and _tilt_seen.size() < 4:
		await get_tree().process_frame
	abilities.arrow_input.disconnect(on_arrow)
	if _leaving:
		return
	_clear_highlight()
	await ui.complete_panel()
	abilities.close_command_mode()
	abilities.practice = false
	if _leaving:
		return
	await ui.say("É assim que você usa as habilidades.")



## Apaga o destaque do controle (só no celular).
func _clear_highlight() -> void:
	if Platform.is_mobile():
		MobileControls.set_highlight(&"")


## Libera o golpe final e espera o droide ser destruído (por qualquer ataque).
func _lesson_finish() -> void:
	step = &"finish"
	if droid != null and is_instance_valid(droid):
		droid.protected = false
	while not _leaving and not _droid_dead:
		await get_tree().process_frame
	if _leaving:
		return
	await _sleep(1.2)  # Pausa suave depois da explosão.
	if _leaving:
		return
	await ui.say("Nada mal, estudante.", 1.4)
	await _sleep(0.9)


## Parte 5: abre a aba de melhorias e espera o jogador selecionar "Saída" com a seta para a direita.
func _lesson_upgrades() -> void:
	step = &"upgrades"
	if Platform.is_mobile():
		MobileControls.suspended = true  # só o toque na carta "Saída"
	player.set_physics_process(false)  # O jogador fica parado enquanto escolhe.
	player.velocity = Vector2.ZERO
	arena.close_hatch()
	await menu.open()
	# O menu avisa por `exit_selected`; `_on_exit_selected` marca o passo.
	while not _leaving and step == &"upgrades":
		await get_tree().process_frame


## O jogador selecionou "Saída".
func _on_exit_selected() -> void:
	if step == &"upgrades":
		step = &"exit_selected"


## Despedida: a tela escurece, o mentor se despede e a Fase 1 carrega.
func _farewell() -> void:
	step = &"farewell"
	menu.fade_out(0.6)
	await ui.fade_darkness(1.0, 1.0).finished
	if _leaving:
		return
	await ui.speak("Agora prove seu valor.", 1.4)
	if _leaving:
		return
	_leaving = true
	step = &"done"
	EventBus.scene_change_requested.emit(next_scene)


# --- Eventos do jogador e do droide ---

## Cada luz do chão acesa toca um tique que sobe de tom.
func _on_light_on(index: int) -> void:
	sfx.play(&"light_on", -6.0, 0.8 + 0.04 * float(index))


## Reage às trocas de estado do jogador: dash, disparo e golpe.
func _on_player_state(new_state: int) -> void:
	var old_state: int = _prev_state
	_prev_state = new_state
	match new_state:
		Player.State.DASH:
			sfx.play(&"dash", -2.0)
			fx.wind(player.global_position, player.velocity.normalized(), 6)
			if step == &"dash":
				_dash_done = true
		Player.State.ATTACK_MELEE:
			var dir: Vector2 = player.get_sword_direction()
			sfx.play(&"slash", -4.0)
			fx.slash_arc(player.global_position + dir * 34.0, dir)
		_:
			# Saiu do tiro carregado sem ser por dash: o disparo acabou de sair.
			if old_state == Player.State.ATTACK_RANGED and new_state != Player.State.DASH:
				fx.muzzle_flash(player.get_muzzle_position(), player.get_shot_direction())


## O jogador causou dano (tiro ou espada): só guarda; a classificação roda no fim do quadro.
func _on_player_dealt(target: Node, _amount: int) -> void:
	if target != droid or droid == null:
		return
	_dealt_queue += 1
	_classify_hits.call_deferred()


## A espada acertou: marca como golpe de espada.
func _on_sword_hit(target: Node, _amount: int) -> void:
	if target == droid and droid != null:
		_sword_queue += 1


## Separa os acertos do quadro em espadadas e tiros. Espadada ganha hit stop.
func _classify_hits() -> void:
	if _dealt_queue <= 0:
		return
	var melee: int = mini(_sword_queue, _dealt_queue)
	_melee_hits += melee
	_ranged_hits += _dealt_queue - melee
	_dealt_queue = 0
	_sword_queue = 0
	if melee > 0:
		_hit_stop(0.07)


## O droide levou um golpe: faíscas, clarão, som metálico e tremidinha.
func _on_droid_hit(_amount: int, at: Vector2) -> void:
	fx.sparks(at, 12, Vector2.ZERO, TAU, 240.0)
	fx.flash(at, 18.0, 0.08)
	sfx.play(&"hit", -3.0, randf_range(0.9, 1.15))
	_shake = maxf(_shake, 2.5)


## O droide foi destruído: explosão, peças, fumaça, tremida de tela e som metálico.
func _on_droid_destroyed(at: Vector2) -> void:
	_droid_dead = true
	fx.explosion(at)
	sfx.play(&"explosion")
	_shake = 9.0
	droid = null


## Pausa o tempo por um instante para dar peso ao golpe (usa tempo real, não o do jogo).
func _hit_stop(duration: float) -> void:
	if _hit_stop_active:
		return
	_hit_stop_active = true
	Engine.time_scale = 0.05
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hit_stop_active = false


## Poeira dos passos e imagens-fantasma do dash.
func _player_feedback(delta: float) -> void:
	match player.state:
		Player.State.MOVE:
			_dust_clock -= delta
			if _dust_clock <= 0.0:
				_dust_clock = 0.11
				fx.dust(player.global_position + Vector2(0.0, 22.0), player.velocity.normalized())
		Player.State.DASH:
			_ghost_clock -= delta
			if _ghost_clock <= 0.0:
				_ghost_clock = ghost_interval
				_spawn_ghost()
				fx.wind(player.global_position, player.velocity.normalized(), 2)


## Deixa uma imagem do personagem para trás, que some rapidamente (rastro do dash).
func _spawn_ghost() -> void:
	var source: Sprite2D = player.sprite
	if source == null:
		return
	var ghost: Sprite2D = Sprite2D.new()
	ghost.texture = source.texture
	ghost.hframes = source.hframes
	ghost.vframes = source.vframes
	ghost.frame = source.frame
	ghost.offset = source.offset
	ghost.flip_h = source.flip_h
	ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(ghost)
	ghost.global_transform = source.global_transform
	ghost.modulate = Color(0.4, 0.85, 1.0, 0.6)
	move_child(ghost, player.get_index())  # Atrás do jogador, na frente da sala.
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, ^"modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)


## Espera `seconds` (respeita a pausa).
func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds, false).timeout
