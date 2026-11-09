class_name DummyEspadaAtaque
extends Area2D
## Espada do Dummy: lâmina que gira em arco e some.

signal acertou(corpo: Node)  # Avisa que a espada acertou algo.

@export var comprimento: float = 48.0  # Comprimento da lâmina.
@export var espessura: float = 10.0  # Espessura da lâmina.
@export var arco: float = 2.0944  # radianos (120°)
@export var duracao: float = 0.25  # Tempo do golpe.
@export var cor: Color = Color(0.85, 0.9, 1.0)  # Cor da lâmina.

## CollisionShape2D filho (retângulo criado por código)
@export var collision_shape: CollisionShape2D

var angulo_central: float = 0.0  # Ângulo central do golpe.

## Alvos já atingidos.
var _atingidos: Dictionary[int, bool] = {}


## Cria a forma e gira com Tween.
func _ready() -> void:
	monitorable = false  # Só detecta; não precisa ser detectada.
	if collision_shape == null:  # Sem forma de colisão não funciona.
		push_error("DummyEspadaAtaque: 'collision_shape' não foi atribuído no Inspector.")  # Avisa o erro.
		queue_free()  # Remove a espada.
		return
	# Forma própria com o comprimento configurado
	var forma := RectangleShape2D.new()  # Cria a forma retangular com o comprimento configurado.
	forma.size = Vector2(comprimento, espessura)  # Tamanho.
	collision_shape.shape = forma  # Aplica.
	collision_shape.position = Vector2(comprimento * 0.5, 0.0)  # Centraliza ao longo da lâmina.
	body_entered.connect(_registrar)  # Corpos que entram.
	area_entered.connect(_registrar)  # Áreas que entram.
	rotation = angulo_central - arco * 0.5  # Começa na ponta esquerda do arco.
	var tween := create_tween()  # Animação de giro.
	# Gira até a ponta direita do arco.
	tween.tween_property(self, ^"rotation", angulo_central + arco * 0.5, maxf(duracao, 0.01))
	tween.finished.connect(queue_free)  # Ao terminar, remove.


## Desenha a lâmina.
func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(comprimento, 0.0), cor, espessura)  # Lâmina.
	draw_line(Vector2(0.0, -espessura), Vector2(0.0, espessura), cor, 3.0)  # Guarda da lâmina.


## Acerto único por alvo.
func _registrar(corpo: Node) -> void:
	var id: int = corpo.get_instance_id()  # Identificador do alvo.
	if _atingidos.has(id):  # Já atingido: ignora.
		return
	_atingidos[id] = true  # Marca como atingido.
	acertou.emit(corpo)  # Avisa.
