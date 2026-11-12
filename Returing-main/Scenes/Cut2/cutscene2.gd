class_name CutsceneTeleporte
extends Node2D
## Cutscene animada: o Estudante anda por Londres até a cabine telefônica,
## é teleportado para o laboratório e conversa com o Sistema.
##
## Tudo é montado por código (a cena só precisa do nó raiz com este script).
## O personagem usa a folha corrigida res://sprites/turing.png.
##
## Controles: clique / Espaço / Enter / E = avançar (ou completar a frase).
##            Segurar ESC (ação "Pause") = pular a cutscene.

## Fase que abre quando a cutscene termina (depois da Fase 1 vem o labirinto).
@export_file("*.tscn") var next_scene: String = "res://Scenes/Fase2/Labirinto.tscn"
## Música de fundo (opcional).
@export var music: AudioStream
## Som do teleporte (opcional). Se vazio, usa o arquivo de SFX_TELEPORT.
@export var teleport_sound: AudioStream
## Velocidade da digitação (caracteres por segundo).
@export var chars_per_second: float = 38.0
## Se ligado, avança as falas sozinho.
@export var auto_advance: bool = false
@export var auto_delay: float = 2.0
## Suaviza o sprite do personagem ao reduzir. Desligue para pixel art "crua".
@export var smooth_actor: bool = true

# --- Arquivos ---
const IMG_LONDON := "res://sprites/Cutscenes/London.png"
const IMG_LAB := "res://sprites/Cutscenes/Lab-Turing.png"
const IMG_SHEET := "res://sprites/turing.png"
const SFX_TELEPORT := "res://Sounds/Sound_Effects/freesound_community-teleport-sound-95186.mp3"

# --- Falas (edite aqui) ---
const SPEAKER_STUDENT := "Estudante"
const SPEAKER_SYSTEM := "Sistema"
const LINE_1 := "Não acho o laboratório em lugar nenhum."
const LINE_2 := "Espera, o que é..."
const LINE_3 := "Você.. me... encontrou."
const LINE_4 := "É agora ou nada."

# --- Cores ---
const COLOR_STUDENT := Color("e8c15a")
const COLOR_SYSTEM := Color("5be0ff")

# --- Mapa (coordenadas em pixels das imagens) ---
const LONDON_SIZE := Vector2(1125, 607)
const LAB_SIZE := Vector2(1600, 880)
const LAB_ORIGIN := Vector2(3000, 0)       # o laboratório fica longe, no mesmo mundo
const LAB_ARRIVAL := Vector2(815, 790)     # pés do personagem ao chegar (dentro do lab)
const BOOTH_GLOW_POS := Vector2(490, 335)  # centro da cabine
const LONDON_START := Vector2(150, 690)    # fora da tela, embaixo
const LONDON_WALK := [Vector2(300, 575), Vector2(430, 515)]
const LONDON_TO_BOOTH := [Vector2(478, 470), Vector2(490, 428)]

# --- Escala e velocidade do personagem ---
const SCALE_LONDON := 0.36
const SCALE_LAB := 0.5
const SPEED_LONDON := 95.0
const SPEED_LAB := 70.0

# --- Interface ---
const BAR_SIZE := 0.08   # altura das barras de cinema (fração da tela)
const SKIP_HOLD := 1.0   # segundos segurando ESC para pular
const BOX_MARGIN_X := 120.0  # margem lateral da caixa de fala (igual à cutscene antiga)
const BOX_MARGIN_Y := 68.0   # distância da borda da tela (deixa as barras de cinema livres)
const BOX_HEIGHT := 128.0    # altura da caixa de fala
const FONT_NAME_SIZE := 28   # mesmos tamanhos da caixa da cutscene antiga
const FONT_TEXT_SIZE := 32
const FONT_HINT_SIZE := 22

const GLITCH_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float band = floor(uv.y * 36.0);
	float n = rand(vec2(band, floor(TIME * 20.0)));
	float jump = (n - 0.5) * 0.12 * intensity * step(0.72, n);
	vec2 p = vec2(uv.x + jump, uv.y);
	float split = 0.012 * intensity;
	float r = texture(screen_tex, p + vec2(split, 0.0)).r;
	float g = texture(screen_tex, p).g;
	float b = texture(screen_tex, p - vec2(split, 0.0)).b;
	float scan = 1.0 - 0.12 * intensity * sin(uv.y * 900.0);
	COLOR = vec4(vec3(r, g, b) * scan, 1.0);
}
"""

signal line_typed
signal line_advanced

enum LineState { NONE, TYPING, WAITING }

## Câmera (animada por tweens; o _process aplica com limites).
var cam_center: Vector2 = LONDON_SIZE / 2.0
var cam_zoom: float = 1.0
## Brilho dos monitores do laboratório (0 a 1).
var monitor_alpha: float = 0.0

var _finished: bool = false
var _line_state: LineState = LineState.NONE
var _wait_start_ms: int = 0
var _sys_talking: bool = false
var _cam_bounds: Rect2 = Rect2(Vector2.ZERO, LONDON_SIZE)
var _bars_progress: float = 0.0
var _skip_held: float = 0.0
var _shake_strength: float = 0.0
var _shake_left: float = 0.0
var _shake_total: float = 0.001

# Mundo
var _camera: Camera2D
var _actor: Actor
var _booth_glow: Sprite2D
var _glow_tween: Tween
var _lab: Node2D
var _beam: Polygon2D
var _monitors: Array[Polygon2D] = []
var _cam_tween: Tween

# Interface
var _ui: Control
var _glitch: ColorRect
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _panel: Control
var _speaker: Label
var _text: RichTextLabel
var _prompt: Control
var _skip_label: Label
var _skip_button_node: Control = null  # Celular: botão "Avançar cutscene".
var _skip_bar: ColorRect
var _flash: ColorRect
var _fade: ColorRect
var _music_player: AudioStreamPlayer
var _type_tween: Tween
var _blink_tween: Tween


func _ready() -> void:
	if not ResourceLoader.exists(next_scene):
		push_error("CutsceneTeleporte: next_scene '%s' não existe; a cutscene não conseguirá abrir a fase." % next_scene)
	_build_world()
	_build_ui()
	_ui.resized.connect(_layout)
	_layout()
	_start_music()
	_run()


func _process(delta: float) -> void:
	# --- Câmera com limites (nunca mostra fora da imagem) ---
	var half := get_viewport_rect().size / (2.0 * cam_zoom)
	var c := cam_center
	c.x = _clamp_axis(c.x, _cam_bounds.position.x + half.x, _cam_bounds.end.x - half.x)
	c.y = _clamp_axis(c.y, _cam_bounds.position.y + half.y, _cam_bounds.end.y - half.y)
	_camera.position = c
	_camera.zoom = Vector2.ONE * cam_zoom

	# --- Tremor ---
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		var k := _shake_left / _shake_total
		_camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * k / cam_zoom
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO

	# --- Monitores do laboratório (tremem enquanto o Sistema fala) ---
	var a := monitor_alpha
	if _sys_talking:
		a *= randf_range(0.55, 1.0)
	for m in _monitors:
		m.modulate.a = a

	# --- Segurar ESC para pular ---
	if not _finished and InputMap.has_action("Pause") and Input.is_action_pressed("Pause"):
		_skip_held += delta
		_skip_label.modulate.a = 1.0
		_skip_bar.size = Vector2(_ui.size.x * clampf(_skip_held / SKIP_HOLD, 0.0, 1.0), 3.0)
		if _skip_held >= SKIP_HOLD:
			_finish(true)
	elif _skip_held > 0.0:
		_skip_held = 0.0
		_skip_label.modulate.a = 0.35
		_skip_bar.size = Vector2(0.0, 3.0)


func _input(event: InputEvent) -> void:
	if _finished:
		return
	var pressed := false
	var mouse := event as InputEventMouseButton
	if mouse:
		pressed = mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	elif event.is_action_pressed("ui_accept") and not event.is_echo():
		pressed = true
	if pressed and mouse and _skip_button_node != null and is_instance_valid(_skip_button_node) \
			and _skip_button_node.get_global_rect().has_point(mouse.position):
		return  # o clique é do botão "Avançar cutscene"
	if pressed:
		get_viewport().set_input_as_handled()
		_advance()


# ---------------------------------------------------------------------------
# ROTEIRO (a cutscene inteira, em ordem)
# ---------------------------------------------------------------------------

func _run() -> void:
	await get_tree().process_frame
	_layout()

	# ===== LONDRES =====
	_cam_bounds = Rect2(Vector2.ZERO, LONDON_SIZE)
	cam_center = LONDON_SIZE / 2.0
	cam_zoom = _cover_zoom(LONDON_SIZE)
	_actor.position = LONDON_START
	_actor.scale = Vector2.ONE * SCALE_LONDON
	_actor.stand("up")

	var intro := create_tween().set_parallel(true)
	intro.tween_property(_fade, "modulate:a", 0.0, 1.4)
	intro.tween_method(_apply_bars, 0.0, 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_cam_move(Vector2(520, 360), _cover_zoom(LONDON_SIZE) * 1.12, 7.0)
	await _wait(1.0)
	if _finished:
		return

	# Entra andando pela calçada
	await _actor.walk_path(LONDON_WALK, SPEED_LONDON)
	if _finished:
		return

	# Olha ao redor, procurando
	_actor.stand("side", false)
	await _wait(0.8)
	_actor.stand("side", true)
	await _wait(0.8)
	_actor.stand("down")
	await _wait(0.4)
	await _say(SPEAKER_STUDENT, LINE_1, COLOR_STUDENT)
	if _finished:
		return

	# Anda até a cabine telefônica
	_cam_move(Vector2(505, 390), _cover_zoom(LONDON_SIZE) * 1.4, 2.8)
	await _actor.walk_path(LONDON_TO_BOOTH, SPEED_LONDON)
	if _finished:
		return
	await _wait(0.4)

	# A cabine começa a brilhar
	_start_booth_glow()
	_shake(2.5, 0.9)
	await _wait(0.7)
	await _say(SPEAKER_STUDENT, LINE_2, COLOR_STUDENT)
	if _finished:
		return

	# ===== TELEPORTE =====
	await _teleport_out()
	_cut_to_lab()
	await _wait(0.2)
	await _teleport_in()
	if _finished:
		return

	# ===== LABORATÓRIO =====
	_cam_move(LAB_ORIGIN + Vector2(815, 556), 1.0, 5.0)
	await _wait(1.0)
	_monitors_on()
	await _wait(1.3)
	_glitch_burst(0.4, 0.2)
	_sys_talking = true
	await _say(SPEAKER_SYSTEM, LINE_3, COLOR_SYSTEM, 14.0)
	_sys_talking = false
	if _finished:
		return
	await _wait(0.4)

	# O Estudante dá um passo em direção ao console
	await _actor.walk_path([LAB_ORIGIN + Vector2(815, 750)], SPEED_LAB)
	await _wait(0.4)
	await _say(SPEAKER_STUDENT, LINE_4, COLOR_STUDENT)
	if _finished:
		return

	# Fim
	_cam_move(cam_center + Vector2(0, -30), cam_zoom * 1.1, 2.6)
	await _wait(0.8)
	_finish(false)


## Estudante dissolve em feixe de luz dentro da cabine.
func _teleport_out() -> void:
	if _glow_tween:
		_glow_tween.kill()
	var s := _actor.scale
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_actor, "scale", Vector2(s.x * 0.15, s.y * 1.5), 0.55).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_actor, "modulate", Color(1.6, 3.5, 4.0, 0.0), 0.55)
	tw.tween_method(_set_glitch, 0.0, 1.0, 0.55)
	tw.tween_property(_flash, "modulate:a", 1.0, 0.45).set_delay(0.15)
	tw.tween_property(_booth_glow, "modulate:a", 1.0, 0.4)
	_shake(6.0, 0.7)
	# O som dura ~1,9 s: acompanha a dissolução, o flash e a chegada no laboratório
	_play_sfx(teleport_sound if teleport_sound else _load_audio(SFX_TELEPORT))
	await tw.finished


## Corte seco para o laboratório (a tela está toda branca neste momento).
func _cut_to_lab() -> void:
	_booth_glow.modulate.a = 0.0
	_cam_bounds = Rect2(LAB_ORIGIN, LAB_SIZE)
	cam_zoom = 0.85
	cam_center = LAB_ORIGIN + Vector2(815, 520)
	_actor.position = LAB_ORIGIN + LAB_ARRIVAL
	_actor.scale = Vector2(SCALE_LAB * 0.15, SCALE_LAB * 1.5)
	_actor.modulate = Color(1.6, 3.5, 4.0, 0.0)
	_actor.stand("up")


## O flash some e o Estudante se materializa na frente do console.
func _teleport_in() -> void:
	_beam.modulate.a = 1.0
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_flash, "modulate:a", 0.0, 0.8)
	tw.tween_method(_set_glitch, 1.0, 0.0, 1.0)
	tw.tween_property(_beam, "modulate:a", 0.0, 1.0).set_delay(0.2)
	tw.tween_property(_actor, "scale", Vector2.ONE * SCALE_LAB, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	tw.tween_property(_actor, "modulate", Color(1, 1, 1, 1), 0.7).set_delay(0.25)
	_shake(4.0, 0.5)
	await tw.finished


## Os monitores acendem com falhas, como se ligassem.
func _monitors_on() -> void:
	var tw := create_tween()
	tw.tween_property(self, "monitor_alpha", 0.5, 0.08)
	tw.tween_property(self, "monitor_alpha", 0.05, 0.07)
	tw.tween_property(self, "monitor_alpha", 0.6, 0.1)
	tw.tween_property(self, "monitor_alpha", 0.15, 0.08)
	tw.tween_property(self, "monitor_alpha", 0.55, 0.25)


func _start_booth_glow() -> void:
	if _glow_tween:
		_glow_tween.kill()
	_glow_tween = create_tween().set_loops()
	_glow_tween.tween_property(_booth_glow, "modulate:a", 0.75, 0.45).set_trans(Tween.TRANS_SINE)
	_glow_tween.tween_property(_booth_glow, "modulate:a", 0.25, 0.45).set_trans(Tween.TRANS_SINE)


# ---------------------------------------------------------------------------
# Diálogo
# ---------------------------------------------------------------------------

func _say(who: String, line: String, accent: Color, cps: float = 0.0) -> void:
	if _finished:
		return
	# As cutscenes não dizem quem fala (só a cutscene final mostra o autor): o nome fica escondido e a cor de
	# destaque continua distinguindo as vozes.
	_speaker.text = ""
	_speaker.visible = false
	_speaker.set_meta(&"falante", who)
	_speaker.add_theme_color_override("font_color", accent)
	_text.text = line
	_text.visible_ratio = 0.0
	# Se o personagem está embaixo na tela, a caixa vai para cima (para não cobri-lo)
	_place_panel(_actor_feet_screen_y() > get_viewport_rect().size.y * 0.68)
	create_tween().tween_property(_panel, "modulate:a", 1.0, 0.18)

	_line_state = LineState.TYPING
	var speed := cps if cps > 0.0 else chars_per_second
	var duration := maxf(float(line.length()) / speed, 0.25)
	if _type_tween:
		_type_tween.kill()
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, duration)
	_type_tween.tween_callback(_on_typed)
	await line_typed

	if auto_advance:
		await _wait(auto_delay)
		_line_state = LineState.NONE
	else:
		await line_advanced

	_set_prompt(false)
	var out := create_tween()
	out.tween_property(_panel, "modulate:a", 0.0, 0.15)
	await out.finished


func _on_typed() -> void:
	_line_state = LineState.WAITING
	_wait_start_ms = Time.get_ticks_msec()
	_set_prompt(true)
	line_typed.emit()


func _complete_typing() -> void:
	if _type_tween:
		_type_tween.kill()
	_text.visible_ratio = 1.0
	_on_typed()


func _advance() -> void:
	match _line_state:
		LineState.TYPING:
			_complete_typing()
		LineState.WAITING:
			# Trava curta: um clique duplo não pula a fala sem ler
			if Time.get_ticks_msec() - _wait_start_ms < 150:
				return
			_line_state = LineState.NONE
			line_advanced.emit()


func _set_prompt(on: bool) -> void:
	if _blink_tween:
		_blink_tween.kill()
	if on:
		_prompt.modulate.a = 1.0
		_blink_tween = create_tween().set_loops()
		_blink_tween.tween_property(_prompt, "modulate:a", 0.2, 0.55)
		_blink_tween.tween_property(_prompt, "modulate:a", 1.0, 0.55)
	else:
		_prompt.modulate.a = 0.0


func _place_panel(top: bool) -> void:
	# Mesma caixa da cutscene antiga (margens de 120 px, 128 px de altura), fora das barras de cinema.
	if top:
		_set_anchors(_panel, Vector4(0, 0, 1, 0), Vector4(BOX_MARGIN_X, BOX_MARGIN_Y, -BOX_MARGIN_X, BOX_MARGIN_Y + BOX_HEIGHT))
	else:
		_set_anchors(_panel, Vector4(0, 1, 1, 1), Vector4(BOX_MARGIN_X, -(BOX_MARGIN_Y + BOX_HEIGHT), -BOX_MARGIN_X, -BOX_MARGIN_Y))


## Altura (em pixels da tela) dos pés do personagem.
func _actor_feet_screen_y() -> float:
	var vp := get_viewport_rect().size
	return (_actor.position.y - _camera.position.y) * cam_zoom + vp.y * 0.5


# ---------------------------------------------------------------------------
# Câmera e efeitos
# ---------------------------------------------------------------------------

func _cover_zoom(img_size: Vector2) -> float:
	var vp := get_viewport_rect().size
	return maxf(vp.x / img_size.x, vp.y / img_size.y)


func _clamp_axis(v: float, lo: float, hi: float) -> float:
	if lo > hi:
		return (lo + hi) * 0.5
	return clampf(v, lo, hi)


func _cam_move(center: Vector2, zoom: float, duration: float) -> void:
	if _cam_tween:
		_cam_tween.kill()
	_cam_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_cam_tween.tween_property(self, "cam_center", center, duration)
	_cam_tween.tween_property(self, "cam_zoom", zoom, duration)


func _shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_total = duration
	_shake_left = duration


func _set_glitch(v: float) -> void:
	_glitch.visible = v > 0.001
	(_glitch.material as ShaderMaterial).set_shader_parameter("intensity", v)


func _glitch_burst(strength: float, duration: float) -> void:
	var tw := create_tween()
	tw.tween_method(_set_glitch, 0.0, strength, duration * 0.3)
	tw.tween_method(_set_glitch, strength, 0.0, duration * 0.7)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


# ---------------------------------------------------------------------------
# Montagem: mundo
# ---------------------------------------------------------------------------

func _build_world() -> void:
	# Londres
	var london := Sprite2D.new()
	london.name = "Londres"
	london.texture = _load_texture(IMG_LONDON)
	london.centered = false
	add_child(london)

	# Brilho da cabine (luz aditiva)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_booth_glow = Sprite2D.new()
	_booth_glow.name = "BrilhoCabine"
	_booth_glow.texture = _make_glow_texture()
	_booth_glow.material = add
	_booth_glow.position = BOOTH_GLOW_POS
	_booth_glow.scale = Vector2(1.3, 1.7)
	_booth_glow.modulate = Color(0.45, 0.95, 1.0, 0.0)
	add_child(_booth_glow)

	# Laboratório (longe, no mesmo mundo)
	_lab = Node2D.new()
	_lab.name = "Laboratorio"
	_lab.position = LAB_ORIGIN
	add_child(_lab)
	var lab_bg := Sprite2D.new()
	lab_bg.texture = _load_texture(IMG_LAB)
	lab_bg.centered = false
	_lab.add_child(lab_bg)

	# Telas dos monitores do console central
	var screens := [
		PackedVector2Array([Vector2(711, 587), Vector2(756, 579), Vector2(756, 636), Vector2(711, 647)]),
		PackedVector2Array([Vector2(770, 570), Vector2(869, 570), Vector2(869, 628), Vector2(770, 628)]),
		PackedVector2Array([Vector2(884, 580), Vector2(931, 600), Vector2(931, 646), Vector2(884, 636)]),
	]
	for pts in screens:
		var m := Polygon2D.new()
		m.polygon = pts
		m.color = COLOR_SYSTEM
		m.modulate.a = 0.0
		_lab.add_child(m)
		_monitors.append(m)

	# Feixe de luz da chegada
	_beam = Polygon2D.new()
	_beam.name = "Feixe"
	_beam.polygon = PackedVector2Array([Vector2(-48, 0), Vector2(48, 0), Vector2(48, -340), Vector2(-48, -340)])
	_beam.vertex_colors = PackedColorArray([
		Color(0.45, 0.95, 1.0, 0.9), Color(0.45, 0.95, 1.0, 0.9),
		Color(0.45, 0.95, 1.0, 0.0), Color(0.45, 0.95, 1.0, 0.0),
	])
	_beam.material = add
	_beam.position = LAB_ARRIVAL
	_beam.modulate.a = 0.0
	_lab.add_child(_beam)

	# Personagem
	_actor = Actor.new()
	_actor.name = "Estudante"
	_actor.setup(_load_texture(IMG_SHEET), smooth_actor)
	add_child(_actor)

	# Câmera
	_camera = Camera2D.new()
	_camera.name = "Camera"
	add_child(_camera)
	_camera.enabled = true


func _make_glow_texture() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	grad.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		push_warning("CutsceneTeleporte: arquivo '%s' não encontrado." % path)
		return null
	return load(path) as Texture2D


func _load_audio(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		push_warning("CutsceneTeleporte: som '%s' não encontrado." % path)
		return null
	return load(path) as AudioStream


## Toca um efeito sonoro uma vez e se remove ao terminar.
func _play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func _start_music() -> void:
	if music == null:
		return
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Musica"
	_music_player.stream = music
	add_child(_music_player)
	_music_player.play()


# ---------------------------------------------------------------------------
# Montagem: interface
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "Interface"
	layer.layer = 10
	add_child(layer)

	_ui = Control.new()
	_ui.name = "Raiz"
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.theme = Palette.load_theme()  # fonte e caixa padrão do jogo (main_theme)
	layer.add_child(_ui)
	_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Glitch (só aparece durante o teleporte e quando o Sistema fala)
	_glitch = _new_rect("Glitch", Color.WHITE)
	var shader := Shader.new()
	shader.code = GLITCH_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = shader
	_glitch.material = mat
	_glitch.visible = false
	_ui.add_child(_glitch)
	_glitch.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Vinheta
	var vignette := TextureRect.new()
	vignette.name = "Vinheta"
	vignette.texture = _make_vignette()
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(vignette)
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Barras de cinema
	_bar_top = _new_rect("BarraCima", Color.BLACK)
	_bar_bottom = _new_rect("BarraBaixo", Color.BLACK)
	_ui.add_child(_bar_top)
	_ui.add_child(_bar_bottom)

	# Caixa de diálogo
	# Caixa da cutscene antiga: Panel do main_theme (marrom com borda dourada), sem botão de avançar.
	_panel = Panel.new()
	_panel.name = "Dialogo"
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.modulate.a = 0.0
	_ui.add_child(_panel)
	_place_panel(false)

	var box := VBoxContainer.new()
	box.name = "Caixa"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 0)
	_panel.add_child(box)
	_set_anchors(box, Vector4(0, 0, 1, 1), Vector4(32, 6, -48, -12))

	_speaker = Label.new()
	_speaker.name = "Nome"
	_speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speaker.add_theme_font_size_override("font_size", FONT_NAME_SIZE)
	box.add_child(_speaker)

	_text = RichTextLabel.new()
	_text.name = "Texto"
	_text.scroll_active = false
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.add_theme_font_size_override("normal_font_size", FONT_TEXT_SIZE)
	_text.add_theme_color_override("default_color", Palette.TEXT)
	_text.add_theme_constant_override("line_separation", 0)
	box.add_child(_text)

	# Setinha piscando = "clique para continuar"
	_prompt = Control.new()
	_prompt.name = "Seta"
	_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_prompt)
	_prompt.anchor_left = 1.0  # canto inferior direito da caixa
	_prompt.anchor_top = 1.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_left = -34.0
	_prompt.offset_top = -26.0
	_prompt.offset_right = -20.0
	_prompt.offset_bottom = -16.0
	var tri := Polygon2D.new()
	tri.polygon = PackedVector2Array([Vector2(0, 0), Vector2(14, 0), Vector2(7, 10)])
	_prompt.add_child(tri)
	_prompt.modulate.a = 0.0

	# Dica e barra de "segure para pular"
	_skip_label = Label.new()
	_skip_label.name = "DicaPular"
	_skip_label.text = "Segure ESC para pular"
	_skip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skip_label.add_theme_font_size_override("font_size", FONT_HINT_SIZE)
	_skip_label.modulate.a = 0.35
	_ui.add_child(_skip_label)
	_set_anchors(_skip_label, Vector4(1, 0, 1, 0), Vector4(-300, 8, -20, 36))
	if Platform.is_mobile():  # Celular: botão "Avançar cutscene" no lugar do "segure ESC".
		_skip_label.visible = false
		_skip_button_node = SkipCutsceneButton.attach(_ui, func() -> void: _finish(true))

	_skip_bar = _new_rect("BarraPular", Color(1, 1, 1, 0.85))
	_skip_bar.size = Vector2(0.0, 3.0)
	_ui.add_child(_skip_bar)

	# Flash e fade por cima de tudo
	_flash = _new_rect("Flash", Color.WHITE)
	_flash.modulate.a = 0.0
	_ui.add_child(_flash)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	_fade = _new_rect("Fade", Color.BLACK)
	_ui.add_child(_fade)
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.modulate.a = 1.0


func _new_rect(node_name: String, color: Color) -> ColorRect:
	var r := ColorRect.new()
	r.name = node_name
	r.color = color
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## anchors e offsets como (esquerda, topo, direita, baixo).
func _set_anchors(c: Control, a: Vector4, o: Vector4 = Vector4.ZERO) -> void:
	# Primeiro as quatro âncoras, depois os quatro offsets: trocar um lado de cada vez deixa o
	# retângulo inválido por um instante e o Control "conserta" o tamanho (a caixa esticava).
	c.anchor_left = a.x
	c.anchor_top = a.y
	c.anchor_right = a.z
	c.anchor_bottom = a.w
	c.offset_left = o.x
	c.offset_top = o.y
	c.offset_right = o.z
	c.offset_bottom = o.w


func _make_vignette() -> GradientTexture2D:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.45, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.65)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


func _layout() -> void:
	_apply_bars(_bars_progress)


func _apply_bars(p: float) -> void:
	_bars_progress = p
	var h := _ui.size.y * BAR_SIZE * p
	_bar_top.position = Vector2.ZERO
	_bar_top.size = Vector2(_ui.size.x, h)
	_bar_bottom.size = Vector2(_ui.size.x, h)
	_bar_bottom.position = Vector2(0.0, _ui.size.y - h)


# ---------------------------------------------------------------------------
# Final
# ---------------------------------------------------------------------------

## Fade final e troca de cena. fast = o jogador pulou a cutscene.
func _finish(fast: bool) -> void:
	if _finished:
		return
	if not ResourceLoader.exists(next_scene):
		push_error("CutsceneTeleporte: next_scene '%s' não existe." % next_scene)
		return  # não trava a cutscene
	_finished = true
	_set_prompt(false)
	if _type_tween:
		_type_tween.kill()
	var duration := 0.4 if fast else 1.6
	var t := create_tween().set_parallel(true)
	t.tween_property(_fade, "modulate:a", 1.0, duration)
	t.tween_property(_panel, "modulate:a", 0.0, duration * 0.5)
	if _music_player:
		t.tween_property(_music_player, "volume_db", -40.0, duration)
	t.chain().tween_callback(_go_next)


func _go_next() -> void:
	EventBus.cutscene_finished.emit()
	EventBus.scene_change_requested.emit(next_scene)


# ---------------------------------------------------------------------------
# Personagem (usa a folha corrigida do Turing)
# ---------------------------------------------------------------------------

## Ator da cutscene: anda, para, vira e pisca usando os quadros da folha.
## A origem do nó fica nos PÉS do personagem.
class Actor extends Node2D:
	const WALK := {
		"down": [6, 2, 10, 2],
		"side": [18, 14, 21, 14],  # os quadros laterais olham para a ESQUERDA
		"up": [32, 3, 33, 3],
	}
	const IDLE := {"down": 2, "side": 14, "up": 3}
	const BLINK := {"down": 0, "side": 15, "up": 3}
	const BOB := [0.8, -1.2, 0.8, -1.2]
	const STEP := 0.11
	const FEET := Vector2(18.0, -103.0)  # desloca o sprite para a origem ficar nos pés

	var facing: String = "down"
	var flipped: bool = false
	var walking: bool = false
	var _sprite: Sprite2D
	var _t: float = 0.0

	func setup(tex: Texture2D, smooth: bool = true) -> void:
		var shadow := Polygon2D.new()
		var pts := PackedVector2Array()
		for i in 24:
			var a := TAU * float(i) / 24.0
			pts.append(Vector2(cos(a) * 62.0, sin(a) * 16.0))
		shadow.polygon = pts
		shadow.color = Color(0, 0, 0, 0.32)
		add_child(shadow)

		_sprite = Sprite2D.new()
		_sprite.texture = tex
		_sprite.hframes = 6
		_sprite.vframes = 6
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR if smooth else CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_sprite)
		_apply()

	## Fica parado olhando para "down", "side" ou "up".
	## Em "side", flip = true olha para a direita.
	func stand(face: String, flip: bool = false) -> void:
		facing = face
		flipped = flip
		walking = false
		_t = 0.0
		_apply()

	## Anda por uma lista de pontos (sem parar entre eles).
	func walk_path(points: Array, speed: float) -> void:
		walking = true
		for p in points:
			var target: Vector2 = p
			var d := target - position
			var dist := d.length()
			if dist < 1.0:
				continue
			_face(d)
			var tw := create_tween()
			tw.tween_property(self, "position", target, dist / speed)
			await tw.finished
		walking = false
		_t = 0.0
		_apply()

	func _face(d: Vector2) -> void:
		if absf(d.x) >= absf(d.y) * 0.8:
			facing = "side"
			flipped = d.x > 0.0
		else:
			facing = "up" if d.y < 0.0 else "down"
			flipped = false
		_apply()

	func _apply() -> void:
		if _sprite == null:
			return
		var flip := flipped and facing == "side"
		_sprite.flip_h = flip
		_sprite.offset = Vector2(-FEET.x if flip else FEET.x, FEET.y)

	func _process(delta: float) -> void:
		if _sprite == null:
			return
		_t += delta
		if walking:
			var frames: Array = WALK[facing]
			var i := int(_t / STEP) % frames.size()
			_sprite.frame = frames[i]
			_sprite.position.y = BOB[i] * 2.0
		else:
			# parado: olhos abertos, piscando de vez em quando
			var blink := fmod(_t, 3.4) > 3.28
			_sprite.frame = BLINK[facing] if blink else IDLE[facing]
			_sprite.position.y = 0.0
