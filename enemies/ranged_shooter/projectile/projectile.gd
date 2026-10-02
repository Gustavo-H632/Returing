class_name EnemyProjectile
extends Area2D
## Projétil do Shooter: o dano cresce com a distância percorrida.

@export var speed: float = 400.0
@export var min_damage: int = 5
@export var max_damage: int = 25
@export var max_damage_distance: float = 500.0
@export var lifetime: float = 3.0

## ShooterHitbox filha
@export var hitbox: ShooterHitbox

var shooter: Node = null

var _direction: Vector2 = Vector2.RIGHT
var _start_position: Vector2 = Vector2.ZERO
var _life_left: float = 0.0
var _damage_maxed: bool = false
var _consumed: bool = false


## Guarda a origem e configura a hitbox.
func _ready() -> void:
	monitorable = false
	# Posição já definida pelo spawn
	_start_position = global_position
	_life_left = lifetime
	rotation = _direction.angle()

	if hitbox == null:
		push_error("EnemyProjectile: 'hitbox' não foi atribuído no Inspector.")
		set_physics_process(false)
		queue_free()
		return
	if shooter != null:
		hitbox.source = shooter  # não acerta quem atirou
	hitbox.configure(min_damage, true)
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)
	body_entered.connect(_on_body_entered)


## Direção e atirador (antes ou depois de entrar na árvore).
func launch(direction: Vector2, from_shooter: Node = null) -> void:
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	rotation = _direction.angle()
	if from_shooter != null:
		shooter = from_shooter
		if hitbox != null:
			hitbox.source = shooter
	if is_inside_tree():
		_start_position = global_position


## Anda e atualiza o dano.
func _physics_process(delta: float) -> void:
	if _consumed:
		return
	position += _direction * speed * delta
	if not _damage_maxed and hitbox != null:
		hitbox.damage = _calculate_current_damage()

	_life_left -= delta
	if _life_left <= 0.0:
		_consume()


## Bateu em parede.
func _on_body_entered(body: Node) -> void:
	if body != shooter:
		_consume()  # parede


## Acertou: some.
func _on_hitbox_hit_landed(_target: Node, _damage_dealt: int) -> void:
	_consume()


## Dano pela distância percorrida.
func _calculate_current_damage() -> int:
	if max_damage_distance <= 0.0:
		_damage_maxed = true
		return max_damage
	var t := clampf(_start_position.distance_to(global_position) / max_damage_distance, 0.0, 1.0)
	_damage_maxed = t >= 1.0
	return roundi(lerpf(float(min_damage), float(max_damage), t))


## Some uma vez.
func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	set_physics_process(false)
	if hitbox != null:
		hitbox.set_active(false)
	queue_free()
