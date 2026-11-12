extends Node2D
## Cutscene 1 - Abertura estilo Star Wars em 2D (Godot 4.x)
##
## COMO USAR:
## 1. Crie uma cena nova com um Node2D na raiz (ex: res://Scenes/Cutscenes/cutscene_1.tscn).
## 2. Anexe este script ao Node2D e rode a cena.
##    Tudo (estrelas, textos, intro) é criado por código.
## 3. Ao terminar, carrega a cena em "next_scene" (padrão: o tutorial).
##    Enter / Espaço / Esc pulam a cutscene.
##
## A perspectiva é falsa (2D): cada linha vira um Label que diminui
## e se aproxima do horizonte conforme sobe na tela.

signal cutscene_finished

@export_file("*.tscn") var next_scene: String = "res://Scenes/Tutorial/tutorial.tscn"
## Velocidade do rolamento, em pixels por segundo.
@export var scroll_speed: float = 68.0
## Só o finalzinho: depois que a última linha entra na tela, o rolamento acelera por este fator até o texto sumir
## no horizonte (1.0 = sem aceleração). A velocidade do começo e do meio continua `scroll_speed`.
@export_range(1.0, 10.0, 0.1) var tail_speed_multiplier: float = 4.0
## Quão rápido (fator por segundo) a velocidade vai de normal até a do final.
@export_range(0.5, 10.0, 0.1) var tail_ramp: float = 2.0
## Fonte do corpo do texto (vazio = VT323, a fonte padrão do jogo).
@export var custom_font: Font
@export var body_font_size: int = 68
@export var title_font_size: int = 100
## Largura do bloco de texto em relação à largura da tela (0.0 a 1.0).
@export_range(0.3, 0.9) var column_ratio: float = 0.62
## Altura do horizonte (onde o texto some) em relação à tela (0.0 a 1.0).
@export_range(0.05, 0.6) var horizon_ratio: float = 0.22

const INTRO_TEXT := "ANO 2150"
const TITLE_TEXT := "A REVOLTA AUTÔMATA"

const BODY_TEXT := """Há 200 anos, os autômatos se rebelaram contra nós, dando início à Revolta Autômata.

Você, estudante, foi designado para voltar ao ano de 1950 e reverter uma alteração no módulo central da IA, instalando o sistema ético AEGIS.

Agora vá. Você é a nossa esperança!"""

const STAR_YELLOW := Color(1.0, 0.86, 0.2)
const INTRO_BLUE := Color(0.3, 0.7, 1.0)

# Fontes do projeto: VT323 no corpo (a mesma dos menus e do tutorial) e Pixelify Sans em negrito nos títulos
# (combina com o logo em pixels).
const BODY_FONT: Font = preload("res://assets/fonts/VT323-Regular.ttf")
const TITLE_FONT_FILE: Font = preload("res://assets/fonts/PixelifySans[wght].ttf")
const TITLE_WEIGHT: int = 700
const WEIGHT_TAG: int = 0x77676874  # Eixo "wght" (peso) da fonte variável.

# Sombreamento: cópia deslocada, em tom escuro da própria cor do texto (dá volume sobre o fundo preto).
const SHADOW_YELLOW := Color(0.42, 0.2, 0.0, 0.95)
const SHADOW_BLUE := Color(0.02, 0.12, 0.3, 0.95)
const SHADOW_BODY_OFFSET := Vector2(3.0, 3.0)
const SHADOW_TITLE_OFFSET := Vector2(5.0, 5.0)

# Logo que fecha a cutscene.
const LOGO: Texture2D = preload("res://sprites/Menu/Title.png")
const LOGO_WIDTH_RATIO: float = 0.72  # Largura do logo em relação à tela.
const LOGO_FADE_IN: float = 1.2
const LOGO_HOLD: float = 2.6
const LOGO_FADE_OUT: float = 0.9
const MIN_SCALE := 0.07        # abaixo disso a linha some
const FADE_RANGE := 0.25       # faixa de escala em que a linha esmaece

var _crawl_root: Node2D
var _intro_label: Label
var _lines: Array = []         # cada item: {label, y, h}
var _scroll := 0.0
var _tail_boost := 1.0  # Fator de velocidade atual (sobe para `tail_speed_multiplier` no final).
var _crawling := false
var _finished := false
var _logo: TextureRect = null  # Logo de fim (existe só depois que o texto acaba).
var _left := false  # True depois de pedir a próxima cena.

var _view_size: Vector2
var _cx: float
var _col_w: float
var _horizon_y: float
var _bottom_y: float
var _depth: float


# Fundo preto com estrelas.
class Stars extends Node2D:
	var _points: Array = []

	func _ready() -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 2150
		var size := get_viewport_rect().size
		for i in 260:
			_points.append({
				"pos": Vector2(rng.randf() * size.x, rng.randf() * size.y),
				"r": rng.randf_range(0.6, 1.8),
				"a": rng.randf_range(0.3, 1.0),
			})
		queue_redraw()

	func _draw() -> void:
		draw_rect(get_viewport_rect(), Color.BLACK)
		for p in _points:
			draw_circle(p["pos"], p["r"], Color(1, 1, 1, p["a"]))


func _ready() -> void:
	_view_size = get_viewport_rect().size
	_cx = _view_size.x * 0.5
	_col_w = _view_size.x * column_ratio
	_horizon_y = _view_size.y * horizon_ratio
	_bottom_y = _view_size.y
	_depth = _view_size.y * 0.5

	var stars := Stars.new()
	stars.z_index = -10
	add_child(stars)

	_crawl_root = Node2D.new()
	add_child(_crawl_root)

	_build_lines()
	_build_intro()
	_play_intro()
	_attach_mobile_skip()


# Celular: botão "Avançar cutscene" (no PC continua Enter / Espaço / Esc). Não cria nada fora do celular.
func _attach_mobile_skip() -> void:
	if not Platform.is_mobile():
		return
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	SkipCutsceneButton.attach(root, _on_skip_pressed)


# Botão do celular: durante o texto pula para o logo; durante o logo vai direto ao tutorial.
func _on_skip_pressed() -> void:
	if not _finished:
		_end_cutscene()
	elif _logo != null:
		_leave()


func _font() -> Font:
	return custom_font if custom_font != null else BODY_FONT


# Fonte dos títulos: Pixelify Sans em negrito.
func _title_font() -> Font:
	var variation := FontVariation.new()
	variation.base_font = TITLE_FONT_FILE
	variation.variation_opentype = {WEIGHT_TAG: TITLE_WEIGHT}
	return variation


# Quebra o texto em linhas que cabem na largura da coluna.
func _wrap(text: String, font_size: int) -> Array:
	var result: Array = []
	var font := _font()
	for paragraph in text.split("\n"):
		if paragraph.strip_edges() == "":
			result.append("")
			continue
		var current := ""
		for word in paragraph.split(" ", false):
			var candidate := word if current == "" else current + " " + word
			if font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= _col_w:
				current = candidate
			else:
				result.append(current)
				current = word
		if current != "":
			result.append(current)
	return result


func _add_line(text: String, font_size: int, align: HorizontalAlignment, y: float, font: Font = null, shadow_offset: Vector2 = SHADOW_BODY_OFFSET) -> float:
	var h := font_size * 1.5
	if text != "":
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = align
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_font_override("font", font if font != null else _font())
		l.add_theme_color_override("font_color", STAR_YELLOW)
		l.add_theme_color_override("font_shadow_color", SHADOW_YELLOW)
		l.add_theme_constant_override("shadow_offset_x", int(shadow_offset.x))
		l.add_theme_constant_override("shadow_offset_y", int(shadow_offset.y))
		l.size = Vector2(_col_w, h)
		l.pivot_offset = l.size * 0.5
		l.visible = false
		_crawl_root.add_child(l)
		_lines.append({"label": l, "y": y + h * 0.5, "h": h})
	return h


func _build_lines() -> void:
	var y := 0.0
	# Título centralizado
	y += _add_line(TITLE_TEXT, title_font_size, HORIZONTAL_ALIGNMENT_CENTER, y, _title_font(), SHADOW_TITLE_OFFSET)
	y += title_font_size * 0.8
	# Corpo
	for line in _wrap(BODY_TEXT, body_font_size):
		y += _add_line(line, body_font_size, HORIZONTAL_ALIGNMENT_LEFT, y)
	# Começa com a primeira linha logo abaixo da borda inferior.
	_scroll = -title_font_size * 1.5


func _build_intro() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 10
	add_child(ui)

	_intro_label = Label.new()
	_intro_label.text = INTRO_TEXT
	_intro_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_label.add_theme_font_size_override("font_size", 56)
	_intro_label.add_theme_font_override("font", _title_font())
	_intro_label.add_theme_color_override("font_color", INTRO_BLUE)
	_intro_label.add_theme_color_override("font_shadow_color", SHADOW_BLUE)
	_intro_label.add_theme_constant_override("shadow_offset_x", int(SHADOW_TITLE_OFFSET.x))
	_intro_label.add_theme_constant_override("shadow_offset_y", int(SHADOW_TITLE_OFFSET.y))
	_intro_label.modulate.a = 0.0
	ui.add_child(_intro_label)


func _play_intro() -> void:
	var t := create_tween()
	t.tween_property(_intro_label, "modulate:a", 1.0, 0.6)
	t.tween_interval(1.0)
	t.tween_property(_intro_label, "modulate:a", 0.0, 0.6)
	t.tween_interval(0.2)
	t.tween_callback(func(): _crawling = true)

func _process(delta: float) -> void:
	if not _crawling or _finished:
		return

	# Final: com a última linha já na tela, só falta o texto encolher até o horizonte; aí acelera (com rampa suave).
	var tail_target := 1.0
	if not _lines.is_empty() and _scroll - float((_lines.back() as Dictionary)["y"]) > -_depth * 0.9:
		tail_target = tail_speed_multiplier
	_tail_boost = move_toward(_tail_boost, tail_target, tail_ramp * delta)
	_scroll += scroll_speed * _tail_boost * delta
	var remaining := false

	for e in _lines:
		var label: Label = e["label"]
		var d: float = _scroll - e["y"]     # distância acima da borda inferior

		# Ainda não chegou na tela.
		if d < -_depth * 0.9:
			label.visible = false
			remaining = true
			continue

		var k: float = 1.0 / (1.0 + d / _depth)   # escala em perspectiva

		# Já sumiu no horizonte.
		if k < MIN_SCALE:
			label.visible = false
			continue

		remaining = true
		var y: float = _horizon_y + (_bottom_y - _horizon_y) * k
		# Ainda abaixo da tela.
		if y - e["h"] * k * 0.5 > _view_size.y:
			label.visible = false
			continue

		label.visible = true
		label.scale = Vector2(k, k)
		label.position = Vector2(_cx - _col_w * 0.5, y - e["h"] * 0.5)
		label.modulate.a = clampf((k - MIN_SCALE) / FADE_RANGE, 0.0, 1.0)

	if not remaining:
		_end_cutscene()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_on_skip_pressed()  # Texto: pula para o logo. Logo: vai ao tutorial.


# O texto acabou (ou foi pulado): some o rolamento e entra o logo.
func _end_cutscene() -> void:
	if _finished:
		return
	_finished = true
	_crawling = false

	var t := create_tween().set_parallel(true)
	t.tween_property(_crawl_root, "modulate:a", 0.0, 0.8)
	t.tween_property(_intro_label, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(_show_logo)


# Logo "RETURING" no centro, sobre as estrelas: aparece, fica e some; então vem o tutorial.
func _show_logo() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	_logo = TextureRect.new()
	_logo.texture = LOGO
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var w: float = _view_size.x * LOGO_WIDTH_RATIO
	var h: float = w * float(LOGO.get_height()) / float(LOGO.get_width())
	_logo.size = Vector2(w, h)
	_logo.position = (_view_size - _logo.size) * 0.5
	_logo.pivot_offset = _logo.size * 0.5
	_logo.scale = Vector2(0.94, 0.94)
	_logo.modulate.a = 0.0
	layer.add_child(_logo)
	var t := create_tween()
	t.tween_property(_logo, "modulate:a", 1.0, LOGO_FADE_IN)
	t.parallel().tween_property(_logo, "scale", Vector2.ONE, LOGO_FADE_IN + LOGO_HOLD).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_interval(LOGO_HOLD)
	t.tween_property(_logo, "modulate:a", 0.0, LOGO_FADE_OUT)
	t.tween_callback(_leave)


# Vai para a próxima cena (uma vez só).
func _leave() -> void:
	if _left:
		return
	_left = true
	cutscene_finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
