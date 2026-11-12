class_name FootageFilter
extends CanvasLayer
## Filtro de "filmagem antiga" (found footage) para a cutscene final: tom desbotado, aberração de cor,
## linhas de varredura, granulação, vinheta e uma faixa de rastreamento que sobe. Por cima ficam o
## ícone "REC" piscando, o relógio da gravação e os cantos do visor.
## Tudo é um filtro de tela: funciona sobre qualquer coisa desenhada nas camadas abaixo dele.

const LAYER_INDEX: int = 61  # Acima da filmagem (60), abaixo da tela de resultado (90) e dos diálogos (120).
const REC_BLINK_TIME: float = 0.55  # Meio ciclo do "REC" piscando (s).
const MARGIN: float = 40.0  # Distância das informações até a borda da tela.
const FONT_SIZE: int = 32
const COLOR_REC: Color = Color("#ff3b30")
const COLOR_INFO: Color = Color("#e6efe0")
const COLOR_BRACKET: Color = Color(0.9, 0.95, 0.9, 0.7)
const BRACKET_SIZE: float = 36.0
const CAMERA_NAME: String = "CAM 03 - LAB A.E.G.I.S."
const START_CLOCK_S: float = 14.0 * 3600.0 + 32.0 * 60.0 + 7.0  # Relógio começa em 14:32:07.
const DATE_TEXT: String = "12/03/1945"

const SHADER_CODE: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform float grain : hint_range(0.0, 1.0) = 0.14;
uniform float scan : hint_range(0.0, 1.0) = 0.28;
uniform float vignette : hint_range(0.0, 1.0) = 0.6;
uniform float chroma : hint_range(0.0, 0.02) = 0.003;
uniform float burst : hint_range(0.0, 1.0) = 0.0;
uniform vec3 tint = vec3(0.88, 1.0, 0.84);

float rand(vec2 co) {
	return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	// Tremida leve por faixas + estouros de falha (burst).
	float band = floor(uv.y * 70.0);
	float n = rand(vec2(band, floor(TIME * 14.0)));
	uv.x += (n - 0.5) * 0.003 + burst * (n - 0.5) * 0.06 * step(0.7, n);
	// Faixa de rastreamento que sobe pela tela.
	float roll = 1.0 - fract(TIME * 0.12);
	float bar = smoothstep(0.05, 0.0, abs(uv.y - roll));
	uv.x += bar * 0.012;
	float c = chroma * (1.0 + burst * 4.0);
	float r = texture(screen_tex, uv + vec2(c, 0.0)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(c, 0.0)).b;
	vec3 col = vec3(r, g, b);
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(lum), col, 0.5) * tint;
	col += bar * 0.07;
	// Linhas de varredura e granulação.
	col *= 1.0 - scan * step(1.0, mod(FRAGCOORD.y, 3.0)) * 0.45;
	col += (rand(SCREEN_UV * 1000.0 + fract(TIME) * 37.0) - 0.5) * grain;
	// Vinheta.
	float d = distance(SCREEN_UV, vec2(0.5));
	col *= 1.0 - vignette * smoothstep(0.3, 0.85, d);
	COLOR = vec4(col, 1.0);
}
"""

var _material: ShaderMaterial = null
var _rec_group: Control = null  # Ícone e texto "REC".
var _clock_label: Label = null
var _clock_s: float = START_CLOCK_S
var _blink_tween: Tween = null
var _burst_tween: Tween = null


func _init() -> void:
	layer = LAYER_INDEX
	follow_viewport_enabled = false


func _ready() -> void:
	var root := Control.new()
	root.name = "Raiz"
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Palette.load_theme()  # Fonte padrão do jogo (VT323).
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var screen := ColorRect.new()  # Filtro de tela cheia.
	screen.name = "Filtro"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	screen.material = _material
	root.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	root.add_child(_make_brackets())
	_build_rec(root)
	_build_info(root)
	_start_blink()
	set_process(true)


## Relógio da gravação: corre em tempo real.
func _process(delta: float) -> void:
	_clock_s += delta
	var total: int = int(_clock_s) % 86400
	_clock_label.text = "%s\n%02d:%02d:%02d" % [DATE_TEXT, floori(total / 3600.0), floori(total / 60.0) % 60, total % 60]


## Estouro de falha (tremida horizontal + aberração de cor mais forte) por `duration` segundos.
func burst(duration: float = 0.25) -> void:
	if _burst_tween != null and _burst_tween.is_valid():
		_burst_tween.kill()
	_burst_tween = create_tween()
	_burst_tween.tween_method(_set_burst, 1.0, 0.0, duration)


func _set_burst(value: float) -> void:
	_material.set_shader_parameter(&"burst", value)


## Ícone vermelho + "REC" no canto superior esquerdo.
func _build_rec(root: Control) -> void:
	_rec_group = HBoxContainer.new()
	_rec_group.name = "Rec"
	_rec_group.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rec_group.add_theme_constant_override(&"separation", 10)
	root.add_child(_rec_group)
	_rec_group.position = Vector2(MARGIN, MARGIN)

	var dot := RecDot.new()
	dot.custom_minimum_size = Vector2(FONT_SIZE * 0.7, FONT_SIZE)
	_rec_group.add_child(dot)

	var label := Label.new()
	label.text = "REC"
	label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	label.add_theme_color_override(&"font_color", COLOR_REC)
	_rec_group.add_child(label)


## Nome da câmera (canto superior direito) e data/hora (canto inferior esquerdo).
func _build_info(root: Control) -> void:
	var cam := Label.new()
	cam.text = CAMERA_NAME
	cam.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cam.add_theme_font_size_override(&"font_size", FONT_SIZE)
	cam.add_theme_color_override(&"font_color", COLOR_INFO)
	cam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(cam)
	cam.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	cam.offset_left = -MARGIN - 520.0
	cam.offset_right = -MARGIN
	cam.offset_top = MARGIN
	cam.offset_bottom = MARGIN + FONT_SIZE * 1.4

	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_clock_label.add_theme_color_override(&"font_color", COLOR_INFO)
	_clock_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_clock_label)
	_clock_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_clock_label.offset_left = MARGIN
	_clock_label.offset_right = MARGIN + 260.0
	_clock_label.offset_bottom = -MARGIN
	_clock_label.offset_top = -MARGIN - FONT_SIZE * 2.6


## Cantos do visor da câmera.
func _make_brackets() -> Control:
	var brackets := Brackets.new()
	brackets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brackets.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return brackets


func _start_blink() -> void:
	_blink_tween = create_tween().set_loops()
	_blink_tween.tween_property(_rec_group, "modulate:a", 0.0, 0.05).set_delay(REC_BLINK_TIME)
	_blink_tween.tween_property(_rec_group, "modulate:a", 1.0, 0.05).set_delay(REC_BLINK_TIME)


## Bolinha vermelha do "REC".
class RecDot extends Control:
	func _draw() -> void:
		draw_circle(size * 0.5, minf(size.x, size.y) * 0.5, COLOR_REC)


## Quatro cantos em "L" do visor.
class Brackets extends Control:
	func _draw() -> void:
		var m: float = MARGIN * 0.6
		var l: float = BRACKET_SIZE
		var w: float = size.x
		var h: float = size.y
		for corner: Vector2 in [Vector2(m, m), Vector2(w - m, m), Vector2(m, h - m), Vector2(w - m, h - m)]:
			var sx: float = 1.0 if corner.x < w * 0.5 else -1.0
			var sy: float = 1.0 if corner.y < h * 0.5 else -1.0
			draw_line(corner, corner + Vector2(l * sx, 0.0), COLOR_BRACKET, 3.0)
			draw_line(corner, corner + Vector2(0.0, l * sy), COLOR_BRACKET, 3.0)
