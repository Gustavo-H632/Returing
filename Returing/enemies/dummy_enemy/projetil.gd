class_name DummyProjetil
extends Area2D
## Projétil do Dummy, desenhado por código.

signal acertou(corpo: Node)  # Avisa que o projétil acertou algo.

## Camadas tratadas como parede (1 = Mundo).
const MASCARA_PAREDE: int = 1

@export var direcao: Vector2 = Vector2.RIGHT  # Direção do voo.
@export var velocidade: float = 320.0  # Velocidade.
@export var raio: float = 5.0  # Raio da bolinha.
@export var vida: float = 3.0  # Tempo de vida.
@export var cor: Color = Color(1.0, 0.3, 0.3)  # Cor.

## CollisionShape2D filho.
@export var collision_shape: CollisionShape2D

var _usado: bool = false  # True depois de acertar.


## Forma própria e sinais.
func _ready() -> void:
	monitorable = false  # Só detecta; não precisa ser detectada.
	# Forma própria com o raio configurado.
	if not CombatUtils.set_unique_circle_radius(collision_shape, raio):
		push_error("DummyProjetil: 'collision_shape' não foi atribuído no Inspector.")  # Sem forma: erro.
		queue_free()  # Remove o projétil.
		return
	# Direção normalizada (zero vira direita).
	direcao = direcao.normalized() if direcao != Vector2.ZERO else Vector2.RIGHT
	body_entered.connect(_colidiu)  # Corpos que entram.
	area_entered.connect(_colidiu)  # Áreas que entram.


## Anda até acabar a vida.
func _physics_process(delta: float) -> void:
	# A máscara da área só enxerga o player; a parede é conferida por raio (como nos outros tiros).
	# Anda até a parede (a máscara da área só enxerga o jogador).
	if CombatUtils.move_until_wall(self, direcao * velocidade * delta, MASCARA_PAREDE, raio):
		queue_free()  # Bateu na parede: some.
		return
	vida -= delta  # Desconta a vida.
	if vida <= 0.0:  # Acabou: some.
		queue_free()


## Desenha a bolinha.
func _draw() -> void:
	draw_circle(Vector2.ZERO, raio, cor)  # Desenha a bolinha.


## Acertou: avisa e some.
func _colidiu(corpo: Node) -> void:
	if _usado:  # Já acertou: ignora.
		return
	_usado = true  # Marca como usado.
	set_physics_process(false)  # Para a física.
	acertou.emit(corpo)  # Avisa quem acertou.
	queue_free()  # Some.
