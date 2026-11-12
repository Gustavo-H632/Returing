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
@export var scroll_speed: float = 95.0
## Fonte opcional (deixe vazio para usar a fonte padrão da Godot).
@export var custom_font: Font
@export var body_font_size: int = 44
@export var title_font_size: int = 72
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
const MIN_SCALE := 0.07        # abaixo disso a linha some
const FADE_RANGE := 0.25       # faixa de escala em que a linha esmaece

var _crawl_root: Node2D
var _intro_label: Label
var _lines: Array = []         # cada item: {label, y, h}
var _scroll := 0.0
var _crawling := false
var _finished := false

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


func _font() -> Font:
	return custom_font if custom_font != null else ThemeDB.fallback_font


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


func _add_line(text: String, font_size: int, align: HorizontalAlignment, y: float) -> float:
	var h := font_size * 1.5
	if text != "":
		var l := Label.new()
		l.text = text
		l.horizontal_alignment = align
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_OFF
		l.add_theme_font_size_override("font_size", font_size)
		l.add_theme_color_override("font_color", STAR_YELLOW)
		if custom_font != null:
			l.add_theme_font_override("font", custom_font)
		l.size = Vector2(_col_w, h)
		l.pivot_offset = l.size * 0.5
		l.visible = false
		_crawl_root.add_child(l)
		_lines.append({"label": l, "y": y + h * 0.5, "h": h})
	return h


func _build_lines() -> void:
	var y := 0.0
	# Título centralizado
	y += _add_line(TITLE_TEXT, title_font_size, HORIZONTAL_ALIGNMENT_CENTER, y)
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
	_intro_label.add_theme_font_size_override("font_size", 36)
	_intro_label.add_theme_color_override("font_color", INTRO_BLUE)
	if custom_font != null:
		_intro_label.add_theme_font_override("font", custom_font)
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

	_scroll += scroll_speed * delta
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
	if _finished:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		_end_cutscene()


func _end_cutscene() -> void:
	if _finished:
		return
	_finished = true
	_crawling = false

	var t := create_tween().set_parallel(true)
	t.tween_property(_crawl_root, "modulate:a", 0.0, 0.8)
	t.tween_property(_intro_label, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(_on_finished)


func _on_finished() -> void:
	cutscene_finished.emit()
	if next_scene != "":
		get_tree().change_scene_to_file(next_scene)
