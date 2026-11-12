class_name GuideWalls
extends StaticBody2D
## Gaiola de paredes (como as "Bounds" da fase 1) levantada em volta do Guide durante a transição.

@export_group("Tamanho")
## Metade do lado da área livre dentro da gaiola (a origem do nó é o centro).
@export var half_size: Vector2 = Vector2(120.0, 120.0)
## Espessura de cada parede.
@export_range(4.0, 128.0, 1.0, "or_greater") var thickness: float = 32.0

@export_group("Visual")
@export var fill_color: Color = Color(0.16, 0.17, 0.22, 1.0)  # Cor de dentro das paredes.
@export var border_color: Color = Color(0.55, 0.6, 0.75, 1.0)  # Cor da borda.
@export_range(0.0, 8.0, 0.5) var border_width: float = 2.0  # Largura da borda.
## Tempo do surgir e do sumir.
@export_range(0.05, 3.0, 0.05) var fade_time: float = 0.5
## Ladrilho das paredes (opcional: sem textura usa `fill_color`). Repete-se pelo retângulo de cada parede.
@export var wall_texture: Texture2D

var _rects: Array[Rect2] = []  # Retângulos das paredes (para desenhar).
var _tween: Tween = null  # Animação de fade.
var _dismantled: bool = false  # True depois de desmontada.


## Prepara a gaiola: só colide com o jogador e os inimigos (camada Mundo), cria as paredes e aparece com fade.
func _ready() -> void:
	collision_layer = 1 << (CombatUtils.LAYER_WORLD - 1)  # Fica na camada "Mundo".
	collision_mask = 0  # Não detecta nada.
	_build_walls()  # Cria as 4 paredes.
	modulate.a = 0.0  # Começa invisível.
	_fade_to(1.0)  # Aparece aos poucos.
	queue_redraw()  # Desenha.


## Área (em coordenadas de mundo) que a gaiola ocupa por fora.
func get_outer_rect() -> Rect2:
	var outer: Vector2 = half_size + Vector2.ONE * thickness  # Meio lado mais a espessura.
	return Rect2(global_position - outer, outer * 2.0)  # Retângulo externo em coordenadas de mundo.


## Desliga a colisão agora e some com fade (depois se libera).
func dismantle() -> void:
	if _dismantled:  # Já desmontada.
		return
	_dismantled = true  # Marca como desmontada.
	set_deferred(&"collision_layer", 0)  # Desliga a colisão (adiado).
	_fade_to(0.0)  # Some com fade.
	_tween.finished.connect(queue_free)  # Ao fim do fade, remove o nó.


## Cria os 4 retângulos de colisão (topo, base, esquerda, direita) em volta da área livre.
func _build_walls() -> void:
	# Parede horizontal (topo e base).
	var horizontal := Vector2((half_size.x + thickness) * 2.0, thickness)
	var vertical := Vector2(thickness, half_size.y * 2.0)  # Parede vertical (esquerda e direita).
	_add_wall(Vector2(0.0, -(half_size.y + thickness * 0.5)), horizontal)  # Topo.
	_add_wall(Vector2(0.0, half_size.y + thickness * 0.5), horizontal)  # Base.
	_add_wall(Vector2(-(half_size.x + thickness * 0.5), 0.0), vertical)  # Esquerda.
	_add_wall(Vector2(half_size.x + thickness * 0.5, 0.0), vertical)  # Direita.


## Cria uma parede: forma retangular na posição pedida e guarda o retângulo para desenhar.
func _add_wall(center: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()  # Forma retangular.
	shape.size = size  # Tamanho.
	var collision := CollisionShape2D.new()  # Nó de colisão.
	collision.shape = shape  # Aplica a forma.
	collision.position = center  # Posição.
	add_child(collision)  # Entra na cena.
	_rects.append(Rect2(center - size * 0.5, size))  # Guarda o retângulo para o desenho.


## Anima a transparência até `alpha` (cancelando o fade anterior).
func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():  # Cancela o fade anterior.
		_tween.kill()
	_tween = create_tween()  # Novo fade.
	_tween.tween_property(self, ^"modulate:a", alpha, fade_time)  # Anima a transparência.


## Desenha as paredes: preenchimento e borda.
func _draw() -> void:
	for rect: Rect2 in _rects:  # Cada parede.
		if wall_texture != null:  # Com sprite: ladrilho repetido.
			draw_texture_rect(wall_texture, rect, true)
		else:
			draw_rect(rect, fill_color)  # Preenchimento.
		if border_width > 0.0:  # Borda opcional.
			draw_rect(rect, border_color, false, border_width)
