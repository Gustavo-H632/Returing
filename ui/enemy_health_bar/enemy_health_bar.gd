class_name EnemyHealthBar
extends ProgressBar
## Barra de vida acoplada ao inimigo (filha do CharacterBody2D).
## - Estilo próprio por inimigo (cores exportadas, aplicadas em StyleBoxFlat).
## - "Rastro" de dano: o trecho perdido fica visível e encolhe com atraso.
## - Oculta com vida cheia (opcional) e some com fade quando o dono morre.
## Ligação: HealthComponent.health_changed -> set_health (conexão gravada na cena).

@export_group("Cores")
@export var fill_color: Color = Color(0.86, 0.2, 0.2):
	set(value):
		fill_color = value
		_apply_styles()
@export var background_color: Color = Color(0.08, 0.08, 0.1, 0.85):
	set(value):
		background_color = value
		_apply_styles()
@export var border_color: Color = Color(0.0, 0.0, 0.0, 1.0):
	set(value):
		border_color = value
		_apply_styles()
@export var trail_color: Color = Color(1.0, 0.92, 0.55, 0.95)

@export_group("Tamanho")
## Altura fixa da barra (o tamanho mínimo do tema não pode esticá-la).
@export var bar_height: float = 5.0

@export_group("Comportamento")
@export var hide_when_full: bool = true
@export_range(0.0, 2.0, 0.05) var trail_delay: float = 0.35
@export_range(0.05, 2.0, 0.05) var trail_duration: float = 0.4
@export_range(0.05, 2.0, 0.05) var fade_out_time: float = 0.3

var _trail_value: float = 0.0
var _trail_tween: Tween = null
var _fade_tween: Tween = null
var _dying: bool = false


func _init() -> void:
	show_percentage = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	min_value = 0.0
	step = 1.0


func _ready() -> void:
	_apply_styles()
	custom_minimum_size = Vector2.ZERO
	size = Vector2(size.x, bar_height)
	_trail_value = value
	_update_visibility()


## Slot de HealthComponent.health_changed. Seguro antes do _ready (só altera valores).
func set_health(current: int, maximum: int) -> void:
	if _dying:
		return
	var previous: float = value
	max_value = maxf(float(maximum), 1.0)
	value = clampf(float(current), 0.0, max_value)
	if value < previous and is_inside_tree():
		_start_trail(previous)
	else:
		_kill_trail()
		_trail_value = value
	_update_visibility()
	queue_redraw()


## Chamado pelo dono na morte: zera e some.
func fade_out() -> void:
	if _dying:
		return
	_dying = true
	_kill_trail()
	value = min_value
	_trail_value = min_value
	visible = true
	if not is_inside_tree():
		visible = false
		return
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, ^"modulate:a", 0.0, fade_out_time)
	_fade_tween.tween_callback(hide)


## Desenha o trecho de dano recente (do valor atual até o rastro).
func _draw() -> void:
	if _trail_value <= value or max_value <= 0.0:
		return
	var inner: Rect2 = Rect2(Vector2.ONE, size - Vector2.ONE * 2.0)
	var from_x: float = inner.position.x + inner.size.x * (value / max_value)
	var to_x: float = inner.position.x + inner.size.x * (_trail_value / max_value)
	draw_rect(Rect2(from_x, inner.position.y, to_x - from_x, inner.size.y), trail_color)


func _start_trail(from_value: float) -> void:
	_kill_trail()
	_trail_value = maxf(_trail_value, from_value)
	_trail_tween = create_tween()
	_trail_tween.tween_interval(trail_delay)
	_trail_tween.tween_method(_set_trail_value, _trail_value, value, trail_duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _set_trail_value(v: float) -> void:
	_trail_value = v
	queue_redraw()


func _kill_trail() -> void:
	if _trail_tween != null and _trail_tween.is_valid():
		_trail_tween.kill()
	_trail_tween = null


func _update_visibility() -> void:
	if _dying:
		return
	visible = not (hide_when_full and value >= max_value)


func _apply_styles() -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = background_color
	bg.border_color = border_color
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(1)
	var fill: StyleBoxFlat = StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_expand_margin_all(-1.0)  # preenchimento dentro da borda
	fill.set_corner_radius_all(1)
	add_theme_stylebox_override(&"background", bg)
	add_theme_stylebox_override(&"fill", fill)
