class_name DummyEspadaAtaque
extends Area2D
## Espada do Dummy: lâmina que gira em arco e some.

signal acertou(corpo: Node)

@export var comprimento: float = 48.0
@export var espessura: float = 10.0
@export var arco: float = 2.0944  ## radianos (120°)
@export var duracao: float = 0.25
@export var cor: Color = Color(0.85, 0.9, 1.0)

## CollisionShape2D filho (retângulo criado por código)
@export var collision_shape: CollisionShape2D

var angulo_central: float = 0.0

var _atingidos: Array[Node] = []


## Cria a forma e gira com Tween.
func _ready() -> void:
	monitorable = false
	if collision_shape == null:
		push_error("DummyEspadaAtaque: 'collision_shape' não foi atribuído no Inspector.")
		queue_free()
		return
	# Forma própria com o comprimento configurado
	var forma := RectangleShape2D.new()
	forma.size = Vector2(comprimento, espessura)
	collision_shape.shape = forma
	collision_shape.position = Vector2(comprimento * 0.5, 0.0)
	body_entered.connect(_registrar)
	area_entered.connect(_registrar)
	rotation = angulo_central - arco * 0.5
	var tween := create_tween()
	tween.tween_property(self, ^"rotation", angulo_central + arco * 0.5, maxf(duracao, 0.01))
	tween.finished.connect(queue_free)


## Desenha a lâmina.
func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(comprimento, 0.0), cor, espessura)
	draw_line(Vector2(0.0, -espessura), Vector2(0.0, espessura), cor, 3.0)


## Acerto único por alvo.
func _registrar(corpo: Node) -> void:
	if corpo in _atingidos:
		return
	_atingidos.append(corpo)
	acertou.emit(corpo)
