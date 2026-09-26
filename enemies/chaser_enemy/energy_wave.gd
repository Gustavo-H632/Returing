class_name EnergyWave
extends Area2D


@export var max_radius: float = 200.0
@export var expand_time: float = 0.6
@export var damage: int = 15

var _shape: CircleShape2D
var _hit_bodies: Array[Node] = []

@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	var original_shape := collision_shape.shape
	if original_shape == null:
		push_error("EnergyWave: CollisionShape2D sem Shape2D definido.")
		return

	_shape = original_shape.duplicate() as CircleShape2D
	if _shape == null:
		push_error("EnergyWave: o Shape2D da CollisionShape2D precisa ser um CircleShape2D.")
		return

	_shape.radius = 0.0
	collision_shape.shape = _shape
	body_entered.connect(_on_body_entered)

func setup(radius: float, wave_damage: int, time: float) -> void:
	max_radius = radius
	damage = wave_damage
	expand_time = time
	_start_expansion()


func _start_expansion() -> void:
	if _shape == null:
		return 
	var tween := create_tween()
	tween.tween_method(_set_radius, 0.0, max_radius, expand_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(queue_free)


func _set_radius(value: float) -> void:
	if _shape == null:
		return
	_shape.radius = value
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	# Garante qaue cada entidade tome somente um ataque
	if body in _hit_bodies:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_hit_bodies.append(body)
