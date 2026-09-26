class_name EnemyProjectile
extends Area2D
## Projétil do ataque à distância. 

@export var speed: float = 400.0
@export var min_damage: int = 5
@export var max_damage: int = 25
## Distância (em pixels) necessária para o projétil atingir max_damage.
## Abaixo disso o dano é interpolado linearmente a partir de min_damage.
@export var max_damage_distance: float = 500.0
@export var lifetime: float = 3.0

@onready var hitbox: ShooterHitbox = $ShooterHitbox

var _direction: Vector2 = Vector2.RIGHT
var _start_position: Vector2
var _life_timer: float = 0.0


func _ready() -> void:
	_start_position = global_position
	body_entered.connect(_on_wall_hit)
	hitbox.hit_landed.connect(_on_hitbox_hit_landed)


#definindo direção do projetio
func launch(direction: Vector2) -> void:
	_direction = direction.normalized()
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	position += _direction * speed * delta

	# Calculo Dano
	hitbox.damage = _calculate_current_damage()

	_life_timer += delta
	if _life_timer >= lifetime:
		queue_free()


func _on_wall_hit(_body: Node) -> void:
	
	queue_free()


func _on_hitbox_hit_landed(_target: Node, _damage_dealt: int) -> void:
	queue_free()


func _calculate_current_damage() -> int:
	var distance_travelled := _start_position.distance_to(global_position)
	var t: float = clamp(distance_travelled / max_damage_distance, 0.0, 1.0)
	return int(round(lerp(float(min_damage), float(max_damage), t)))
