class_name DummyOndaChoque
extends Area2D
## Onda de choque do Dummy: anel que cresce até raio_max.

signal acertou(corpo: Node)
signal finalizada

@export var raio_max: float = 160.0
@export var duracao: float = 0.8
@export var largura: float = 6.0
@export var cor: Color = Color(1.0, 0.8, 0.2)

## CollisionShape2D filho (círculo criado por código)
@export var collision_shape: CollisionShape2D

var _tempo: float = 0.0
var _forma: CircleShape2D = null
var _atingidos: Array[Node] = []


## Forma própria e sinais.
func _ready() -> void:
	monitorable = false
	if not CombatUtils.set_unique_circle_radius(collision_shape, 1.0):
		push_error("DummyOndaChoque: 'collision_shape' não foi atribuído no Inspector.")
		finalizada.emit()  # avisa o Dummy mesmo com erro
		queue_free()
		return
	_forma = collision_shape.shape as CircleShape2D
	duracao = maxf(duracao, 0.01)
	body_entered.connect(_registrar)
	area_entered.connect(_registrar)


## Cresce e some no fim.
func _physics_process(delta: float) -> void:
	_tempo += delta
	var t := clampf(_tempo / duracao, 0.0, 1.0)
	_forma.radius = maxf(raio_max * t, 1.0)
	queue_redraw()
	if t >= 1.0:
		set_physics_process(false)
		finalizada.emit()
		queue_free()


## Desenha o anel.
func _draw() -> void:
	var t := clampf(_tempo / maxf(duracao, 0.01), 0.0, 1.0)
	var c := cor
	c.a = 1.0 - t
	draw_arc(Vector2.ZERO, maxf(raio_max * t, 1.0), 0.0, TAU, 48, c, largura)


## Acerto único por alvo.
func _registrar(corpo: Node) -> void:
	if corpo in _atingidos:
		return
	_atingidos.append(corpo)
	acertou.emit(corpo)
