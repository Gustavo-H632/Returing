class_name DummyOndaChoque
extends Area2D
## Onda de choque do Dummy: anel que cresce até raio_max.

signal acertou(corpo: Node)  # Avisa que a onda acertou algo.
signal finalizada  # Avisa que a onda terminou.

@export var raio_max: float = 160.0  # Raio máximo.
@export var duracao: float = 0.8  # Duração.
@export var largura: float = 6.0  # Espessura do anel.
@export var cor: Color = Color(1.0, 0.8, 0.2)  # Cor do anel.

## CollisionShape2D filho (círculo criado por código)
@export var collision_shape: CollisionShape2D

var _tempo: float = 0.0  # Tempo decorrido.
var _forma: CircleShape2D = null  # Forma circular que cresce.
## Alvos já atingidos.
var _atingidos: Dictionary[int, bool] = {}


## Forma própria e sinais.
func _ready() -> void:
	monitorable = false  # Só detecta; não precisa ser detectada.
	# Forma própria (sem compartilhar com outras ondas).
	if not CombatUtils.set_unique_circle_radius(collision_shape, 1.0):
		# Sem forma de colisão: erro.
		push_error("DummyOndaChoque: 'collision_shape' não foi atribuído no Inspector.")
		finalizada.emit()  # avisa o Dummy mesmo com erro
		queue_free()  # Remove a onda.
		return
	_forma = collision_shape.shape as CircleShape2D  # Guarda a forma.
	duracao = maxf(duracao, 0.01)  # Duração mínima.
	body_entered.connect(_registrar)  # Corpos que entram.
	area_entered.connect(_registrar)  # Áreas que entram.


## Cresce e some no fim.
func _physics_process(delta: float) -> void:
	_tempo += delta  # Soma o tempo.
	var t := clampf(_tempo / duracao, 0.0, 1.0)  # Progresso de 0 a 1.
	_forma.radius = maxf(raio_max * t, 1.0)  # Raio cresce com o progresso.
	queue_redraw()  # Redesenha o anel.
	if t >= 1.0:  # Terminou.
		set_physics_process(false)  # Para de processar.
		finalizada.emit()  # Avisa que acabou.
		queue_free()  # Remove a onda.


## Desenha o anel.
func _draw() -> void:
	var t := clampf(_tempo / maxf(duracao, 0.01), 0.0, 1.0)  # Progresso de 0 a 1.
	var c := cor  # Cor do anel.
	c.a = 1.0 - t  # O anel vai ficando transparente.
	draw_arc(Vector2.ZERO, maxf(raio_max * t, 1.0), 0.0, TAU, 48, c, largura)  # Desenha o anel.


## Acerto único por alvo.
func _registrar(corpo: Node) -> void:
	var id: int = corpo.get_instance_id()  # Identificador do alvo.
	if _atingidos.has(id):  # Já atingido: ignora.
		return
	_atingidos[id] = true  # Marca como atingido.
	acertou.emit(corpo)  # Avisa.
