class_name EnemyProjectile
extends PooledArea
## Projétil do Robo: o dano cresce com a distância percorrida (reaproveitado pelo PoolHub).

@export var speed: float = 400.0
@export var min_damage: int = 5
@export var max_damage: int = 25
@export var max_damage_distance: float = 500.0
@export var lifetime: float = 3.0
## Camadas tratadas como parede (1 = Mundo).
@export_flags_2d_physics var wall_mask: int = 1

## Hitbox filha.
@export var hitbox: Hitbox

var shooter: Node = null

var _direction: Vector2 = Vector2.RIGHT
var _start_position: Vector2 = Vector2.ZERO
var _life_left: float = 0.0
var _damage_maxed: bool = false
var _consumed: bool = false


## Liga os sinais uma única vez (a instância é reaproveitada).
func _ready() -> void:
	super._ready()
	if hitbox == null:
		push_error("EnemyProjectile: 'hitbox' não foi atribuído no Inspector.")
		set_physics_process(false)
		return
	hitbox.set_active(false)
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)
	body_entered.connect(_on_body_entered)


## Dispara de `origin` na direção `direction` (vetor de mundo) em nome de `from_shooter`.
func launch(origin: Vector2, direction: Vector2, from_shooter: Node = null) -> void:
	global_position = origin
	_direction = direction.normalized() if direction != Vector2.ZERO else Vector2.RIGHT
	global_rotation = _direction.angle()
	shooter = from_shooter
	_start_position = origin
	_life_left = lifetime
	_damage_maxed = false
	_consumed = false
	if hitbox == null:
		return
	hitbox.source = shooter  # não acerta quem atirou
	hitbox.configure(min_damage, true)
	hitbox.set_active(true)


func _on_pool_deactivate() -> void:
	if hitbox != null:
		hitbox.set_active(false)


## Anda e atualiza o dano.
func _physics_process(delta: float) -> void:
	if _consumed:
		return
	if CombatUtils.move_until_wall(self, _direction * speed * delta, wall_mask):
		_consume()
		return
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


## Volta ao pool uma vez.
func _consume() -> void:
	if _consumed:
		return
	_consumed = true
	recycle()
