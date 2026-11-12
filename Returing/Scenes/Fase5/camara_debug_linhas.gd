class_name CamaraDebugLinhas
extends Node2D
## Desenha, em coordenadas de mundo, o que a depuração da Câmara de Provas mostra (ver CamaraDebug):
## colisões, faixas, hurtboxes, linha do raio e linhas de tiro. Só desenha enquanto o CamaraDebug está ligado.

const COR_PAREDE: Color = Color(0.2, 1.0, 0.3)
const COR_FAIXA: Color = Color(1.0, 0.7, 0.2)
const COR_HURTBOX: Color = Color(1.0, 0.9, 0.2)
const COR_RAIO: Color = Color(1.0, 0.15, 0.15)
const COR_TIRO_LIVRE: Color = Color(0.2, 1.0, 0.4)
const COR_TIRO_BLOQUEADO: Color = Color(1.0, 0.3, 0.3)
## Camadas que bloqueiam o tiro (Mundo).
const MASCARA_PAREDE: int = 1


## Desenha tudo.
func _draw() -> void:
	var overlay := get_parent() as CamaraDebug
	if overlay == null or not overlay.ligado:
		return
	if overlay.colisoes != null:
		for filho: Node in overlay.colisoes.get_children():
			_contorno(filho as CollisionShape2D, COR_PAREDE)
	var jogador: Node2D = CombatUtils.get_player(self)
	for no: Node in get_tree().get_nodes_in_group(&"camara_maquina"):
		var m := no as CamaraMaquina
		if m == null:
			continue
		_faixa(m)
		if m.hurtbox != null:
			for filho: Node in m.hurtbox.get_children():
				_contorno(filho as CollisionShape2D, COR_HURTBOX)
		var seg: Rect2 = m.segmento_global()
		if seg.size != Vector2.ZERO:
			draw_rect(seg, Color(COR_RAIO, 0.45), true)
			draw_rect(seg, COR_RAIO, false, 1.0)
		if jogador != null and m.destrutivel and not m.is_dead():
			_linha_de_tiro(jogador as Player, m)


## Contorno da faixa que a máquina cobre (a arte do aviso ocupa exatamente a faixa).
func _faixa(m: CamaraMaquina) -> void:
	if m.aviso == null or m.aviso.texture == null:
		return
	var tamanho := Vector2(float(m.aviso.texture.get_width()) / float(maxi(m.aviso.hframes, 1)),
			float(m.aviso.texture.get_height())) * m.aviso.global_scale
	draw_rect(Rect2(m.aviso.global_position - tamanho * 0.5, tamanho), COR_FAIXA, false, 1.0)


## Linha de tiro: da boca do cano do Player até o alvo da máquina (raycast só contra as paredes).
func _linha_de_tiro(jogador: Player, m: CamaraMaquina) -> void:
	if jogador == null:
		return
	var de: Vector2 = jogador.get_muzzle_position()
	var para: Vector2 = m.alvo_global()
	var consulta := PhysicsRayQueryParameters2D.create(de, para, MASCARA_PAREDE)
	consulta.collide_with_areas = false
	var batida: Dictionary = get_world_2d().direct_space_state.intersect_ray(consulta)
	if batida.is_empty():
		draw_line(de, para, COR_TIRO_LIVRE, 1.0)
	else:
		draw_line(de, batida["position"] as Vector2, COR_TIRO_BLOQUEADO, 1.0)


## Contorno de uma colisão retangular ou circular.
func _contorno(no: CollisionShape2D, cor: Color) -> void:
	if no == null or no.shape == null:
		return
	if no.shape is RectangleShape2D:
		var tamanho: Vector2 = (no.shape as RectangleShape2D).size
		var r := Rect2(no.global_position - tamanho * 0.5, tamanho)
		draw_rect(r, Color(cor, 0.18), true)
		draw_rect(r, cor, false, 1.0)
	elif no.shape is CircleShape2D:
		draw_arc(no.global_position, (no.shape as CircleShape2D).radius, 0.0, TAU, 32, cor, 1.0)
