class_name DummyProjetil
extends Area2D
## Projétil do Dummy, desenhado por código.

signal acertou(corpo: Node)

@export var direcao: Vector2 = Vector2.RIGHT
@export var velocidade: float = 320.0
@export var raio: float = 5.0
@export var vida: float = 3.0
@export var cor: Color = Color(1.0, 0.3, 0.3)

## CollisionShape2D filho
@export var collision_shape: CollisionShape2D

var _usado: bool = false


## Forma própria e sinais.
func _ready() -> void:
	monitorable = false
	if not CombatUtils.set_unique_circle_radius(collision_shape, raio):
		push_error("DummyProjetil: 'collision_shape' não foi atribuído no Inspector.")
		queue_free()
		return
	direcao = direcao.normalized() if direcao != Vector2.ZERO else Vector2.RIGHT
	body_entered.connect(_colidiu)
	area_entered.connect(_colidiu)


## Anda até acabar a vida.
func _physics_process(delta: float) -> void:
	global_position += direcao * velocidade * delta
	vida -= delta
	if vida <= 0.0:
		queue_free()


## Desenha a bolinha.
func _draw() -> void:
	draw_circle(Vector2.ZERO, raio, cor)


## Acertou: avisa e some.
func _colidiu(corpo: Node) -> void:
	if _usado:
		return
	_usado = true
	set_physics_process(false)
	acertou.emit(corpo)
	queue_free()
