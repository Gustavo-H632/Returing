class_name DebugLines
extends Node2D
## Desenha, em coordenadas de mundo, as colisões, oclusores, fogo, porta, chave, painéis e rotas
## (ver DebugOverlay). Só desenha enquanto o DebugOverlay pede.

const COR_PAREDE: Color = Color(0.2, 1.0, 0.3)
const COR_OCLUSOR: Color = Color(0.1, 0.9, 1.0)
const COR_FOGO: Color = Color(1.0, 0.25, 0.2)
const COR_OBJETO: Color = Color(1.0, 0.9, 0.2)
const COR_ROTA: Color = Color(1.0, 0.3, 1.0)
const COR_LUZ: Color = Color(1.0, 1.0, 1.0, 0.8)


## Desenha tudo.
func _draw() -> void:
	var overlay := get_parent() as DebugOverlay
	if overlay == null or overlay.mode == DebugOverlay.Mode.OFF:
		return
	if overlay.colisoes != null:
		for child: Node in overlay.colisoes.get_children():
			_draw_shape(child as CollisionShape2D, COR_PAREDE)
	if overlay.oclusores != null:
		for child: Node in overlay.oclusores.get_children():
			_draw_occluder(child as LightOccluder2D)
	for group: Array in [[&"lab_fogo", COR_FOGO], [&"lab_porta", COR_OBJETO], [&"lab_chave", COR_OBJETO],
			[&"lab_painel", COR_OBJETO]]:
		for node: Node in get_tree().get_nodes_in_group(group[0]):
			for child: Node in node.get_children():
				_draw_shape(child as CollisionShape2D, group[1])
				if child is StaticBody2D:  # A porta guarda a colisão dentro de um corpo.
					for inner: Node in child.get_children():
						_draw_shape(inner as CollisionShape2D, group[1])
	for marker: Node in get_tree().get_nodes_in_group(&"lab_waypoint"):
		var point := marker as Marker2D
		if point != null:
			draw_circle(point.global_position, 6.0, COR_ROTA)
	if overlay.luz != null:
		draw_arc(overlay.luz.global_position, overlay.luz.light_range, 0.0, TAU, 64, COR_LUZ, 1.0)


## Contorno de uma colisão retangular ou circular.
func _draw_shape(node: CollisionShape2D, color: Color) -> void:
	if node == null or node.shape == null:
		return
	if node.shape is RectangleShape2D:
		var size: Vector2 = (node.shape as RectangleShape2D).size
		var rect := Rect2(node.global_position - size * 0.5, size)
		draw_rect(rect, Color(color, 0.18), true)
		draw_rect(rect, color, false, 1.0)
	elif node.shape is CircleShape2D:
		draw_arc(node.global_position, (node.shape as CircleShape2D).radius, 0.0, TAU, 32, color, 1.0)


## Contorno de um oclusor de luz.
func _draw_occluder(node: LightOccluder2D) -> void:
	if node == null or node.occluder == null:
		return
	var points: PackedVector2Array = node.occluder.polygon
	if points.size() < 2:
		return
	var closed := PackedVector2Array()
	for p: Vector2 in points:
		closed.append(node.global_position + p)
	closed.append(closed[0])
	draw_polyline(closed, COR_OCLUSOR, 1.0)
