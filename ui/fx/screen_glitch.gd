class_name ScreenGlitch
extends CanvasLayer
## Efeitos de tela por shader, todos procedurais (sem texturas): glitch (tremida + aberração de cor),
## chiado (ruído de TV) e distorção de teletransporte. Cada efeito é um ColorRect de tela cheia que só
## existe visível enquanto roda. Os métodos de duração são corrotinas: `await fx.glitch()`.

# ===== BALANCEAMENTO =====
## Acima do HUD (10) e do Pause (100); abaixo do diálogo (120) e do fade de cena (128).
const LAYER_INDEX: int = 118
const GLITCH_SHAKE_MAX: float = 0.018  # Tremida máxima da tela (fração da largura).
const STATIC_CELL_SIZE: float = 3.0  # Tamanho (px) de cada "grão" do chiado.

## Glitch: fatias de tela deslocadas + canais RGB separados + tremida global.
const GLITCH_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_nearest, repeat_disable;
uniform float intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec2 shake = vec2(0.0);
uniform float flash : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	float t = floor(TIME * 18.0);
	float band = floor(SCREEN_UV.y * 26.0);
	float pick = step(0.8, hash(vec2(band, t)));
	float slice = (hash(vec2(band + 9.0, t)) - 0.5) * 0.14 * intensity * pick;
	vec2 uv = vec2(SCREEN_UV.x + slice, SCREEN_UV.y) + shake;
	float ab = (0.004 + 0.022 * intensity) * (0.5 + hash(vec2(t, 3.0)));
	float r = texture(screen_tex, uv + vec2(ab, 0.0)).r;
	float g = texture(screen_tex, uv).g;
	float b = texture(screen_tex, uv - vec2(ab, 0.0)).b;
	vec3 col = vec3(r, g, b);
	col += pick * 0.12 * intensity;
	col = mix(col, vec3(0.7, 0.95, 1.0), flash * 0.5);
	col *= 0.93 + 0.07 * sin(FRAGCOORD.y * 1.6 + TIME * 30.0);
	COLOR = vec4(col, 1.0);
}
"""

## Chiado: ruído de TV animado, com faixas de varredura.
const STATIC_SHADER: String = """
shader_type canvas_item;
uniform float cell_size = 3.0;
uniform float alpha : hint_range(0.0, 1.0) = 1.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }
void fragment() {
	vec2 cell = floor(FRAGCOORD.xy / cell_size);
	float t = floor(TIME * 30.0);
	float n = hash(cell + vec2(t * 17.0, t * 5.0));
	float roll = step(0.93, hash(vec2(floor(FRAGCOORD.y / (cell_size * 6.0)), t)));
	float scan = 0.82 + 0.18 * sin(FRAGCOORD.y * 1.3 + TIME * 45.0);
	vec3 col = vec3(n) * scan;
	col = mix(col, vec3(1.0 - n), roll * 0.6);
	COLOR = vec4(col, alpha);
}
"""

## Teletransporte: redemoinho + zoom no centro + ondulação + clarão azul.
const TELEPORT_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform vec2 center = vec2(0.5);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
uniform float whiteout : hint_range(0.0, 1.0) = 0.0;
void fragment() {
	vec2 asp = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 d = (SCREEN_UV - center) * asp;
	float dist = length(d);
	float ang = strength * 7.0 * exp(-dist * 3.0);
	float s = sin(ang);
	float c = cos(ang);
	vec2 rot = vec2(d.x * c - d.y * s, d.x * s + d.y * c);
	float pull = 1.0 - strength * 0.65 * exp(-dist * 2.5);
	vec2 uv = center + (rot * pull) / asp;
	uv += normalize(d + vec2(1e-5)) * sin(dist * 42.0 - TIME * 20.0) * 0.007 * strength / asp;
	vec3 col = texture(screen_tex, clamp(uv, vec2(0.0), vec2(1.0))).rgb;
	col = mix(col, vec3(0.55, 0.85, 1.0), whiteout);
	COLOR = vec4(col, 1.0);
}
"""

var _glitch_rect: ColorRect = null  # Camada do glitch.
var _static_rect: ColorRect = null  # Camada do chiado.
var _teleport_rect: ColorRect = null  # Camada da distorção.
var _black_rect: ColorRect = null  # Fundo preto ABAIXO dos efeitos (aparece quando o chiado some).
var _cover_rect: ColorRect = null  # Cortina preta ACIMA dos efeitos (escurece por cima de tudo).
var _glitch_mat: ShaderMaterial = null
var _static_mat: ShaderMaterial = null
var _teleport_mat: ShaderMaterial = null
var _tween: Tween = null  # Animação do efeito em andamento.
var _black_tween: Tween = null  # Animação do fundo preto.
var _cover_tween: Tween = null  # Animação da cortina.


## Cria as camadas (todas escondidas).
func _init() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS  # Roda mesmo com o jogo pausado.


func _ready() -> void:
	_black_rect = _make_rect(null)
	_black_rect.color = Color.BLACK
	_black_rect.visible = true  # Sempre "ligado": a transparência (modulate.a) é quem esconde.
	_black_rect.modulate.a = 0.0
	_glitch_mat = _make_material(GLITCH_SHADER)
	_glitch_rect = _make_rect(_glitch_mat)
	_teleport_mat = _make_material(TELEPORT_SHADER)
	_teleport_rect = _make_rect(_teleport_mat)
	_static_mat = _make_material(STATIC_SHADER)
	_static_mat.set_shader_parameter(&"cell_size", STATIC_CELL_SIZE)
	_static_rect = _make_rect(_static_mat)
	_cover_rect = _make_rect(null)
	_cover_rect.color = Color.BLACK
	_cover_rect.visible = true
	_cover_rect.modulate.a = 0.0
	clear()


## Glitch curto: aberração de cor + fatias deslocadas + tremida. Termina com a tela normal.
func glitch(duration: float = 0.9) -> void:
	_stop_tween()
	_glitch_rect.visible = true
	_tween = create_tween()
	_tween.tween_method(_apply_glitch, 0.0, 1.0, duration)
	await _tween.finished
	_glitch_rect.visible = false


## Chiado de TV por `duration` segundos (a tela fica coberta). Esconde ao terminar, a menos que
## `keep` seja true (deixe ligado e use `stop_static()` depois).
func play_static(duration: float = 1.0, keep: bool = false) -> void:
	_static_mat.set_shader_parameter(&"alpha", 1.0)
	_static_rect.visible = true
	await get_tree().create_timer(duration, true, false, true).timeout
	if not keep:
		_static_rect.visible = false


## Some com o chiado em `fade` segundos.
func stop_static(fade: float = 0.25) -> void:
	if not _static_rect.visible:
		return
	_stop_tween()
	_tween = create_tween()
	_tween.tween_method(_set_static_alpha, 1.0, 0.0, fade)
	await _tween.finished
	_static_rect.visible = false


## Distorção de teletransporte em torno de `center_uv` (0..1 da tela), terminando em tela azul-clara.
func teleport(center_uv: Vector2, duration: float = 1.5) -> void:
	_stop_tween()
	_teleport_mat.set_shader_parameter(&"center", center_uv)
	_teleport_mat.set_shader_parameter(&"strength", 0.0)
	_teleport_mat.set_shader_parameter(&"whiteout", 0.0)
	_teleport_rect.visible = true
	_tween = create_tween()
	_tween.tween_method(_apply_teleport, 0.0, 1.0, duration)
	await _tween.finished


## Anima o fundo preto até `alpha`.
func fade_black(alpha: float, duration: float = 0.3) -> void:
	if _black_tween != null and _black_tween.is_valid():
		_black_tween.kill()
	_black_tween = create_tween()
	_black_tween.tween_property(_black_rect, "modulate:a", alpha, duration)
	await _black_tween.finished


## Escurece POR CIMA de todos os efeitos até `alpha` (use para sair de um efeito direto para o preto).
func cover(alpha: float, duration: float = 0.3) -> void:
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	_cover_tween = create_tween()
	_cover_tween.tween_property(_cover_rect, "modulate:a", alpha, duration)
	await _cover_tween.finished


## Esconde glitch, chiado e distorção (o fundo preto e a cortina ficam como estão).
func hide_effects() -> void:
	_stop_tween()
	_glitch_rect.visible = false
	_static_rect.visible = false
	_teleport_rect.visible = false


## Desliga todos os efeitos (o fundo preto e a cortina também).
func clear() -> void:
	hide_effects()
	if _black_tween != null and _black_tween.is_valid():
		_black_tween.kill()
	if _cover_tween != null and _cover_tween.is_valid():
		_cover_tween.kill()
	_black_rect.modulate.a = 0.0
	_cover_rect.modulate.a = 0.0


## True se algum efeito está na tela.
func is_active() -> bool:
	return _glitch_rect.visible or _static_rect.visible or _teleport_rect.visible \
			or _black_rect.modulate.a > 0.0 or _cover_rect.modulate.a > 0.0


## Curva do glitch: sobe rápido, treme e some (progresso 0..1).
func _apply_glitch(progress: float) -> void:
	var bell: float = sin(progress * PI)  # 0 -> 1 -> 0.
	var burst: float = clampf(bell * 1.6, 0.0, 1.0)
	_glitch_mat.set_shader_parameter(&"intensity", burst)
	_glitch_mat.set_shader_parameter(&"flash", burst * burst * burst)
	var jitter: Vector2 = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * GLITCH_SHAKE_MAX * burst
	_glitch_mat.set_shader_parameter(&"shake", jitter)


## Curva do teletransporte: redemoinho cresce e, no fim, clareia.
func _apply_teleport(progress: float) -> void:
	_teleport_mat.set_shader_parameter(&"strength", clampf(progress * 1.25, 0.0, 1.0))
	_teleport_mat.set_shader_parameter(&"whiteout", smoothstep(0.7, 1.0, progress))


func _set_static_alpha(value: float) -> void:
	_static_mat.set_shader_parameter(&"alpha", value)


func _stop_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null


## Retângulo de tela cheia (não bloqueia o mouse), começa escondido.
func _make_rect(material: ShaderMaterial) -> ColorRect:
	var rect: ColorRect = ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.material = material
	rect.visible = false
	add_child(rect)
	return rect


func _make_material(code: String) -> ShaderMaterial:
	var shader: Shader = Shader.new()
	shader.code = code
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = shader
	return material
