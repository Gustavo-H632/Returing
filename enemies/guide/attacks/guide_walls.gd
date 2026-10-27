class_name GuideWalls
extends StaticBody2D
## Gaiola de paredes (como as "Bounds" da fase 1) levantada em volta do Guide durante a transição.

@export_group("Tamanho")
## Metade do lado da área livre dentro da gaiola (a origem do nó é o centro).
@export var half_size: Vector2 = Vector2(120.0, 120.0)
## Espessura de cada parede.
@export_range(4.0, 128.0, 1.0, "or_greater") var thickness: float = 32.0

@export_group("Visual")
@export var fill_color: Color = Color(0.16, 0.17, 0.22, 1.0)
@export var border_color: Color = Color(0.55, 0.6, 0.75, 1.0)
@export_range(0.0, 8.0, 0.5) var border_width: float = 2.0
## Tempo do surgir e do sumir.
@export_range(0.05, 3.0, 0.05) var fade_time: float = 0.5

var _rects: Array[Rect2] = []
var _tween: Tween = null
var _dismantled: bool = false


func _ready() -> void:
	collision_layer = 1 << (CombatUtils.LAYER_WORLD - 1)
	collision_mask = 0
	_build_walls()
	modulate.a = 0.0
	_fade_to(1.0)
	queue_redraw()


## Área (em coordenadas de mundo) que a gaiola ocupa por fora.
func get_outer_rect() -> Rect2:
	var outer: Vector2 = half_size + Vector2.ONE * thickness
	return Rect2(global_position - outer, outer * 2.0)


## Desliga a colisão agora e some com fade (depois se libera).
func dismantle() -> void:
	if _dismantled:
		return
	_dismantled = true
	set_deferred(&"collision_layer", 0)
	_fade_to(0.0)
	_tween.finished.connect(queue_free)


## Cria os 4 retângulos de colisão (topo, base, esquerda, direita) em volta da área livre.
func _build_walls() -> void:
	var horizontal := Vector2((half_size.x + thickness) * 2.0, thickness)
	var vertical := Vector2(thickness, half_size.y * 2.0)
	_add_wall(Vector2(0.0, -(half_size.y + thickness * 0.5)), horizontal)
	_add_wall(Vector2(0.0, half_size.y + thickness * 0.5), horizontal)
	_add_wall(Vector2(-(half_size.x + thickness * 0.5), 0.0), vertical)
	_add_wall(Vector2(half_size.x + thickness * 0.5, 0.0), vertical)


func _add_wall(center: Vector2, size: Vector2) -> void:
	var shape := RectangleShape2D.new()
	shape.size = size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = center
	add_child(collision)
	_rects.append(Rect2(center - size * 0.5, size))


func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", alpha, fade_time)


func _draw() -> void:
	for rect: Rect2 in _rects:
		draw_rect(rect, fill_color)
		if border_width > 0.0:
			draw_rect(rect, border_color, false, border_width)
