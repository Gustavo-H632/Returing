class_name EnergyWave
extends Area2D
## Onda circular que cresce e acerta cada player uma vez.

## CollisionShape2D filho (o círculo é criado por código)
@export var collision_shape: CollisionShape2D
@export var max_radius: float = 200.0
@export var expand_time: float = 0.6
@export var damage: int = 15
@export_group("Visual")
@export var draw_wave: bool = true
@export var wave_color: Color = Color(0.45, 0.8, 1.0, 0.8)
@export var wave_width: float = 3.0

var source: Node = null

var _shape: CircleShape2D = null
var _radius: float = 0.0
var _hit_actors: Array[Node] = []
var _tween: Tween = null


## Cria a forma e começa a crescer.
func _ready() -> void:
	monitorable = false
	if collision_shape == null:
		push_error("EnergyWave: 'collision_shape' não foi atribuído no Inspector.")
		queue_free()
		return

	# Forma própria desta onda
	_shape = CircleShape2D.new()
	_shape.radius = 0.01
	collision_shape.shape = _shape

	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_start_expansion()


## Raio, dano, tempo e origem (antes ou depois do _ready).
func setup(radius: float, wave_damage: int, time: float, wave_source: Node = null) -> void:
	max_radius = maxf(radius, 1.0)
	damage = wave_damage
	expand_time = maxf(time, 0.01)
	source = wave_source
	if is_node_ready():
		_start_expansion()  # reinicia com os novos valores


## Tween do raio e some no fim.
func _start_expansion() -> void:
	if _shape == null:
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_hit_actors.clear()
	_tween = create_tween()
	_tween.tween_method(_set_radius, 0.0, max_radius, maxf(expand_time, 0.01)) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_callback(queue_free)


## Aplica o raio na colisão e no desenho.
func _set_radius(value: float) -> void:
	_radius = value
	_shape.radius = maxf(value, 0.01)
	if draw_wave:
		queue_redraw()


## Desenha o anel.
func _draw() -> void:
	if draw_wave and _radius > 0.5:
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 48, wave_color, wave_width)


## Encostou em corpo.
func _on_body_entered(body: Node2D) -> void:
	_try_hit(body, body)


## Aceita também a Hurtbox do player.
func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group(CombatUtils.GROUP_HURTBOX):
		_try_hit(area, CombatUtils.get_actor(area))


## Dano no player uma vez.
func _try_hit(target: Node, actor: Node) -> void:
	# Um acerto por alvo
	if actor == null or actor in _hit_actors or not CombatUtils.is_player(actor):
		return
	if CombatUtils.apply_damage(target, damage, source if source != null else self):
		_hit_actors.append(actor)
