class_name FinalCutscene
extends Node
## Cutscene final, depois de derrotar o chefão da última fase. Roda em cima da fase, sem trocar de cena:
##   1. a HUD some e o jogador perde o controle
##   2. tela preta + voz do tutorial: "Você conseguiu salvar o futuro."
##   3. glitch/chiado de TV
##   4. filmagem antiga (REC, relógio, granulação...): o chefão ainda protótipo (só o corpo), em montagem
##   5. o Turing chega ao computador, ao lado do protótipo, e a fala vem numa caixa com o nome de quem fala
##   6. fade para preto e, só então, a tela final da run (RunRecorder escuta `cutscene_finished`)
## Cada etapa é uma função com `await`, na ordem de `_run()`: para ajustar o ritmo, mexa nas constantes e
## nos @export abaixo.

signal finished  # A sequência acabou (a tela final da run abre em seguida).

## Grupo que avisa o RunRecorder de que a fase tem cutscene final (a tela de resultado espera por ela).
const GROUP: StringName = &"final_cutscene"

# ===== BALANCEAMENTO (tempos em segundos) =====
const START_DELAY: float = 0.8  # Pausa depois da morte do chefão, antes de escurecer.
const BLACK_FADE: float = 1.0  # Tempo para escurecer a fase.
const TV_STATIC_TIME: float = 0.6  # Chiado de TV cobrindo a tela.
const TV_REVEAL_FADE: float = 0.25  # Tempo do chiado sumindo.
const TV_GLITCH_TIME: float = 0.55  # Glitch (fatias + aberração de cor) sobre a filmagem.
const FOOTAGE_BEAT: float = 2.6  # O chefão sozinho na filmagem.
const TYPING_BEAT: float = 0.9  # O Turing digitando antes de falar.
const DIALOGUE_HOLD: float = 2.4  # Quanto a fala fica na tela depois de digitada.
const END_FADE: float = 1.4  # Fade para preto no fim.
const BURST_INTERVAL: float = 1.1  # De quanto em quanto tempo a filmagem "falha".

# ===== CENÁRIO (pixels da imagem do laboratório, 1600 x 880) =====
const LAB_SIZE: Vector2 = Vector2(1600.0, 880.0)
const ROBOT_FEET: Vector2 = Vector2(1000.0, 770.0)  # Base do protótipo, no chão ao lado do Turing.
const TURING_FEET: Vector2 = Vector2(815.0, 795.0)  # Pés do Turing, diante do computador.
const TURING_START: Vector2 = Vector2(815.0, 960.0)  # De onde ele entra (fora da imagem, embaixo).
const TURING_SCALE: float = 0.5
const TURING_WALK_SPEED: float = 110.0
const ROBOT_SCALE: float = 3.0
const ROBOT_FRAME_BODY: int = 24  # Quadro da folha Guide_sprite só com a cabeça e o tronco (cabos expostos).
const ROBOT_FRAME_ON: int = 34  # O mesmo corpo com a luz verde do peito acesa (módulo ligado).
const ROBOT_CELL: Vector2 = Vector2(500.0 / 6.0, 500.0 / 6.0)  # Quadro da folha Guide_sprite (6 x 6).
const ROBOT_BODY_BOTTOM: float = 34.0  # Linha (no quadro) onde o tronco termina.
const ROBOT_STAND_HEIGHT: float = 48.0  # Altura do suporte de montagem (px do cenário).
const ZOOM_START: float = 1.0
const ZOOM_END: float = 1.18

const LAB_IMAGE: String = "res://sprites/Cutscenes/Lab-Turing.png"
const TURING_SHEET: String = "res://sprites/turing.png"
const ROBOT_SHEET: String = "res://sprites/Enemies/Guide_sprite.png"
const LAYER_FOOTAGE: int = 60  # Acima da HUD (10), abaixo do filtro (61) e da tela de resultado (90).
const LAYER_COVER: int = 62  # Preto que fica por baixo da tela de resultado.

@export_group("Falas")
@export var voice_lines: PackedStringArray = ["Você conseguiu salvar o futuro."]
@export var speaker_name: String = "Turing"
@export var dialogue_lines: PackedStringArray = ["Teste do módulo A.E.G.I.S. 1"]

# Câmera da filmagem (movida por tweens; _process aplica no cenário).
var _cam_center: Vector2 = LAB_SIZE * 0.5
var _cam_zoom_mul: float = ZOOM_START

var _running: bool = false
var _fx: ScreenGlitch = null
var _footage_layer: CanvasLayer = null
var _world: Node2D = null
var _robot: Node2D = null  # O protótipo do chefão (suporte + corpo).
var _robot_sprite: Sprite2D = null
var _turing: CutsceneTeleporte.Actor = null
var _filter: FootageFilter = null
var _cover_layer: CanvasLayer = null
var _cam_tween: Tween = null
var _burst_timer: float = 0.0
var _filming: bool = false


func _enter_tree() -> void:
	add_to_group(GROUP)  # Antes de qualquer sinal: o RunRecorder confere o grupo ao fechar a run.
	CombatUtils.connect_once(EventBus.level_completed, _on_level_completed)


func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.level_completed, _on_level_completed)


## Última fase concluída (sem próxima cena): começa a cutscene.
func _on_level_completed(next_scene: String) -> void:
	if next_scene.is_empty():
		start()


## Dispara a sequência (uma vez só). Devolve na hora; use `await finished` para esperar.
func start() -> void:
	if _running:
		return
	_running = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_lock_game()
	_build()
	_run()


func _process(delta: float) -> void:
	if _world == null:
		return
	_apply_camera()
	if _filming:  # A filmagem "falha" de vez em quando.
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = BURST_INTERVAL * randf_range(0.6, 1.6)
			_filter.burst(randf_range(0.12, 0.3))


# ---------------------------------------------------------------------------
# ROTEIRO (a cutscene inteira, em ordem)
# ---------------------------------------------------------------------------

func _run() -> void:
	await _step_voice()
	await _step_tv_transition()
	await _step_footage()
	await _step_dialogue()
	await _step_end()


## 2. Tela preta e a voz do tutorial.
func _step_voice() -> void:
	await get_tree().create_timer(START_DELAY, true, false, true).timeout
	await _fx.fade_black(1.0, BLACK_FADE)
	var dialogue: Dialogue = Dialogue.show_lines(self, voice_lines, Dialogue.Style.VOICE)
	await dialogue.finished


## 3. Chiado e glitch de TV; por baixo dele a filmagem aparece.
func _step_tv_transition() -> void:
	await _fx.play_static(TV_STATIC_TIME, true)
	_footage_layer.visible = true
	_filter.visible = true
	_filming = true
	_start_camera_push(Vector2(900.0, 620.0), FOOTAGE_BEAT + TYPING_BEAT + 3.0)
	await _fx.fade_black(0.0, 0.01)  # Por baixo do chiado.
	await _fx.stop_static(TV_REVEAL_FADE)  # Antes do glitch: os dois dividem o mesmo Tween do ScreenGlitch.
	await _fx.glitch(TV_GLITCH_TIME)


## 4. Filmagem: o chefão sozinho no laboratório; depois o Turing chega ao computador.
func _step_footage() -> void:
	await get_tree().create_timer(FOOTAGE_BEAT, true, false, true).timeout
	_turing.visible = true
	await _turing.walk_path([TURING_FEET], TURING_WALK_SPEED)
	_turing.stand("up")
	_start_typing()
	await get_tree().create_timer(TYPING_BEAT, true, false, true).timeout


## 5. A fala, em caixa com o nome de quem fala (sem botão de avançar).
func _step_dialogue() -> void:
	_robot_sprite.frame = ROBOT_FRAME_ON  # O módulo liga: luz verde no peito.
	# Caixa no alto: embaixo ficam o Turing e o protótipo.
	var dialogue: Dialogue = Dialogue.show_lines(self, dialogue_lines, Dialogue.Style.BOX, speaker_name, null, false, true)
	dialogue.hold_time = DIALOGUE_HOLD
	await dialogue.finished


## 6. Fade para preto e fim: a tela final da run abre por cima.
func _step_end() -> void:
	await _fx.fade_black(1.0, END_FADE)
	_filming = false
	_footage_layer.visible = false
	_filter.visible = false
	_cover_layer.visible = true  # Preto fixo por baixo da tela de resultado.
	_fx.clear()
	_fx.queue_free()
	finished.emit()
	EventBus.cutscene_finished.emit()  # O RunRecorder abre a tela final.


# ---------------------------------------------------------------------------
# Controle do jogo
# ---------------------------------------------------------------------------

## HUD escondida, pausa desligada e jogador parado (sem controle durante toda a sequência).
func _lock_game() -> void:
	var level: Node = get_parent()
	var hud: CanvasLayer = level.get_node_or_null("HUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var pause: Node = level.get_node_or_null("Pause")  # Sem menu de pausa durante a cutscene.
	if pause != null:
		pause.process_mode = Node.PROCESS_MODE_DISABLED
	var player: Node = get_tree().get_first_node_in_group(CombatUtils.GROUP_PLAYER)
	if player != null:
		player.set_physics_process(false)  # Nada de andar, atirar ou dar dash.
		player.set_process_input(false)
		player.set_process_unhandled_input(false)
		var abilities: Node = player.get(&"abilities") as Node
		if abilities != null:  # Nem o modo comando (Ctrl).
			abilities.set_process_input(false)
			if abilities.has_method(&"close_command_mode"):
				abilities.call(&"close_command_mode")
	Engine.time_scale = 1.0


# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------

func _build() -> void:
	_fx = ScreenGlitch.new()
	add_child(_fx)

	_footage_layer = CanvasLayer.new()
	_footage_layer.name = "Filmagem"
	_footage_layer.layer = LAYER_FOOTAGE
	_footage_layer.visible = false
	add_child(_footage_layer)

	_world = Node2D.new()
	_world.name = "Laboratorio"
	_footage_layer.add_child(_world)
	var bg := Sprite2D.new()
	bg.texture = _load_texture(LAB_IMAGE)
	bg.centered = false
	_world.add_child(bg)

	_build_prototype()

	_turing = CutsceneTeleporte.Actor.new()  # Mesmo personagem da cutscene da Fase 1.
	_turing.name = "Turing"
	_turing.setup(_load_texture(TURING_SHEET))
	_turing.scale = Vector2.ONE * TURING_SCALE
	_turing.position = TURING_START
	_turing.visible = false
	_turing.stand("up")
	_world.add_child(_turing)

	_filter = FootageFilter.new()
	_filter.visible = false
	add_child(_filter)

	_cover_layer = CanvasLayer.new()
	_cover_layer.name = "Preto"
	_cover_layer.layer = LAYER_COVER
	_cover_layer.visible = false
	add_child(_cover_layer)
	var black := ColorRect.new()
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover_layer.add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_cam_center = Vector2(920.0, 540.0)
	_apply_camera()


## O chefão ainda protótipo: só o corpo (cabeça e tronco, com os cabos à mostra) sobre um suporte de montagem.
func _build_prototype() -> void:
	_robot = Node2D.new()
	_robot.name = "Prototipo"
	_robot.position = ROBOT_FEET
	_world.add_child(_robot)

	var shadow := Polygon2D.new()  # Sombra no chão, como a do Turing.
	var pts := PackedVector2Array()
	for i: int in 24:
		var angle: float = TAU * float(i) / 24.0
		pts.append(Vector2(cos(angle) * 70.0, sin(angle) * 16.0))
	shadow.polygon = pts
	shadow.color = Color(0.0, 0.0, 0.0, 0.35)
	_robot.add_child(shadow)

	var base := Polygon2D.new()  # Base do suporte.
	base.polygon = PackedVector2Array([Vector2(-56, 6), Vector2(56, 6), Vector2(46, -10), Vector2(-46, -10)])
	base.color = Color("#5b6472")
	_robot.add_child(base)
	var post := Polygon2D.new()  # Haste do suporte, até o tronco.
	post.polygon = PackedVector2Array([Vector2(-13, -8), Vector2(13, -8), Vector2(13, -ROBOT_STAND_HEIGHT), Vector2(-13, -ROBOT_STAND_HEIGHT)])
	post.color = Color("#8a93a3")
	_robot.add_child(post)

	_robot_sprite = Sprite2D.new()
	_robot_sprite.texture = _load_texture(ROBOT_SHEET)
	_robot_sprite.hframes = 6
	_robot_sprite.vframes = 6
	_robot_sprite.frame = ROBOT_FRAME_BODY
	_robot_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_robot_sprite.scale = Vector2.ONE * ROBOT_SCALE
	# Centro do quadro de modo que o fim do tronco fique no topo da haste.
	var rest_y: float = -ROBOT_STAND_HEIGHT - (ROBOT_BODY_BOTTOM - ROBOT_CELL.y * 0.5) * ROBOT_SCALE + 6.0
	_robot_sprite.position = Vector2(0.0, rest_y)
	_robot.add_child(_robot_sprite)
	var hover := create_tween().set_loops()  # Balança de leve, como preso por cabos.
	hover.tween_property(_robot_sprite, "position:y", rest_y - 2.0, 1.1).set_trans(Tween.TRANS_SINE)
	hover.tween_property(_robot_sprite, "position:y", rest_y, 1.1).set_trans(Tween.TRANS_SINE)


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("FinalCutscene: arquivo '%s' não encontrado." % path)
		return null
	return load(path) as Texture2D


# ---------------------------------------------------------------------------
# Câmera e animações
# ---------------------------------------------------------------------------

## Zoom que faz a imagem do laboratório cobrir a tela inteira.
func _cover_zoom(vp: Vector2) -> float:
	return maxf(vp.x / LAB_SIZE.x, vp.y / LAB_SIZE.y)


## Posiciona o cenário como uma câmera: centro + zoom, sem mostrar fora da imagem.
func _apply_camera() -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var zoom: float = _cover_zoom(vp) * _cam_zoom_mul
	var half: Vector2 = vp / (2.0 * zoom)
	var center := Vector2(
		clampf(_cam_center.x, half.x, maxf(LAB_SIZE.x - half.x, half.x)),
		clampf(_cam_center.y, half.y, maxf(LAB_SIZE.y - half.y, half.y)))
	_world.scale = Vector2.ONE * zoom
	_world.position = vp * 0.5 - center * zoom


## Aproximação lenta da câmera (efeito de filmagem).
func _start_camera_push(center: Vector2, duration: float) -> void:
	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(self, "_cam_center", center, duration)
	_cam_tween.tween_property(self, "_cam_zoom_mul", ZOOM_END, duration)


## O Turing "mexe no computador": passos curtos no lugar, em rajadas, como quem digita.
func _start_typing() -> void:
	var loop := create_tween().set_loops()
	loop.tween_callback(func() -> void: _turing.walking = true)
	loop.tween_interval(0.35)
	loop.tween_callback(func() -> void: _turing.stand("up"))
	loop.tween_interval(0.3)
