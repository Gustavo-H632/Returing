class_name AmuletIcon
extends Control
## Amuleto hexagonal desenhado por código: contorno duplo, glifo no centro e cor por raridade.
## Lendária ganha adorno dourado (3º hexágono, losangos nos vértices e brilho pulsando).

const COLOR_COMMON: Color = Color("#8c97a3")  # Cor do amuleto comum (cinza).
const COLOR_ADVANCED: Color = Color("#8fd0f0")  # Cor do amuleto avançado (azul).
const COLOR_LEGENDARY: Color = Color("#e8c15a")  # Cor do amuleto lendário (dourado).
const COLOR_LEGENDARY_LIGHT: Color = Color("#fff0b0")  # Cor clara do adorno lendário.
const COLOR_FILL: Color = Color(0.04, 0.05, 0.07, 0.9)  # Cor do fundo do amuleto.
const COLOR_BLOOD: Color = Color("#c0392b")  # Cor do sangue (usada no glifo do Modo Sanguinário).
# Cor que escurece o amuleto em recarga.
const COLOR_COOLDOWN_OVERLAY: Color = Color(0.0, 0.0, 0.0, 0.58)

const HEX_SIDES: int = 6  # Lados do hexágono.
## Raio do hexágono principal em relação à metade do controle (lendária precisa de espaço para o adorno).
const RADIUS_NORMAL: float = 0.92
const RADIUS_LEGENDARY: float = 0.7  # Raio do hexágono lendário (menor para caber o adorno).
const INNER_RATIO: float = 0.8  # Raio do contorno interno.
const OUTER_RING_RATIO: float = 1.17  # Raio do anel externo lendário.
const GLOW_RATIO: float = 1.3  # Raio do brilho lendário.
const GLOW_SPEED: float = 3.0  # Velocidade do brilho pulsante.
## Meia-altura do glifo em relação ao raio do hexágono.
const GLYPH_RATIO: float = 0.5

## Habilidade mostrada (null = amuleto vazio).
var ability: AbilityData = null:
	set(value):
		ability = value
		_update_process()
		queue_redraw()
## 0 = pronta; 1 = recarga cheia (escurece o amuleto).
var cooldown_ratio: float = 0.0:
	set(value):
		var was_cooling: bool = cooldown_ratio > 0.0
		cooldown_ratio = clampf(value, 0.0, 1.0)
		if (cooldown_ratio > 0.0) != was_cooling:  # o escurecimento é tudo-ou-nada: só redesenha ao ligar/desligar
			queue_redraw()

var _glow: float = 0.0  # Intensidade atual do brilho (0 a 1).
var _glow_time: float = 0.0  # Tempo acumulado do brilho.


## Não captura cliques (só desenha).
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Decide se o brilho precisa animar.
func _ready() -> void:
	_update_process()


## Quando a visibilidade muda, liga ou desliga a animação do brilho.
func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		_update_process()


## Cor principal da raridade (usada também pelas cartas).
## Cor principal da raridade (usada também pelas cartas).
static func color_for_rarity(rarity: AbilityData.Rarity) -> Color:
	match rarity:
		AbilityData.Rarity.AVANCADA:
			return COLOR_ADVANCED
		AbilityData.Rarity.LENDARIA:
			return COLOR_LEGENDARY
	return COLOR_COMMON


## Atalho para trocar a habilidade mostrada.
func set_ability(data: AbilityData) -> void:
	ability = data


## Diz se o amuleto mostrado é lendário.
func _is_legendary() -> bool:
	return ability != null and ability.rarity == AbilityData.Rarity.LENDARIA


## O brilho só anima enquanto o amuleto lendário está visível.
## Liga o processamento só se o amuleto lendário está visível (economiza CPU).
func _update_process() -> void:
	set_process(is_visible_in_tree() and _is_legendary())


## A cada quadro atualiza o brilho pulsante e redesenha.
func _process(delta: float) -> void:
	_glow_time += delta  # Soma o tempo.
	_glow = 0.5 + 0.5 * sin(_glow_time * GLOW_SPEED)  # Seno de 0 a 1.
	queue_redraw()


## Desenha o amuleto: adorno (se lendário), hexágono duplo, ícone ou glifo e a película escura da recarga.
func _draw() -> void:
	if ability == null:  # Sem habilidade não há o que desenhar.
		return
	var center: Vector2 = size * 0.5  # Centro do controle.
	var legendary: bool = _is_legendary()  # É lendário?
	# Raio do hexágono.
	var radius: float = minf(size.x, size.y) * 0.5 * (RADIUS_LEGENDARY if legendary else RADIUS_NORMAL)
	var color: Color = color_for_rarity(ability.rarity)  # Cor da raridade.

	if legendary:  # Adorno por trás do hexágono.
		_draw_legendary_ornament(center, radius)

	draw_colored_polygon(_hexagon(center, radius), COLOR_FILL)  # Fundo do hexágono.
	draw_polyline(_closed(_hexagon(center, radius)), color, 2.5, true)  # Contorno externo.
	var inner: Color = color  # Cor do contorno interno (mais transparente).
	inner.a = 0.65
	draw_polyline(_closed(_hexagon(center, radius * INNER_RATIO)), inner, 1.2, true)  # Contorno interno.

	if ability.icon != null:  # Ícone da habilidade (se houver).
		var lado: float = radius * 1.1  # Lado do ícone.
		# Desenha o ícone.
		draw_texture_rect(ability.icon, Rect2(center - Vector2(lado, lado) * 0.5, Vector2(lado, lado)), false)
	else:
		# Senão desenha o glifo por código.
		_draw_glyph(ability.glyph, center, radius * GLYPH_RATIO, COLOR_LEGENDARY_LIGHT if legendary else color)

	if cooldown_ratio > 0.0:  # Em recarga: escurece o amuleto.
		draw_colored_polygon(_hexagon(center, radius), COLOR_COOLDOWN_OVERLAY)  # Película escura.


## Desenha o adorno lendário: brilho, anel externo e losangos nos vértices.
func _draw_legendary_ornament(center: Vector2, radius: float) -> void:
	var glow: Color = COLOR_LEGENDARY  # Cor do brilho.
	glow.a = 0.06 + 0.14 * _glow  # Pulsa com o tempo.
	draw_colored_polygon(_hexagon(center, radius * GLOW_RATIO), glow)  # Hexágono de brilho.
	var ring_radius: float = radius * OUTER_RING_RATIO  # Raio do anel externo.
	var ring: Color = COLOR_LEGENDARY_LIGHT  # Cor do anel.
	ring.a = 0.55 + 0.35 * _glow  # Pulsa com o tempo.
	draw_polyline(_closed(_hexagon(center, ring_radius)), ring, 1.5, true)  # Anel externo.
	var rombo: float = radius * 0.13  # Tamanho dos losangos.
	for vertex: Vector2 in _hexagon(center, ring_radius):  # Um losango em cada vértice.
		var spike: Vector2 = (vertex - center).normalized()  # Direção do vértice.
		var tip: Vector2 = vertex + spike * rombo * 1.6  # Ponta do losango.
		var lado: Vector2 = Vector2(-spike.y, spike.x) * rombo  # Lado do losango.
		# Desenha o losango.
		draw_colored_polygon(PackedVector2Array([tip, vertex + lado, vertex - spike * rombo * 0.4, vertex - lado]),
				COLOR_LEGENDARY)


# --- Geometria ---

## Pontos de um hexágono com o topo para cima.
func _hexagon(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()  # Lista de pontos.
	for i: int in HEX_SIDES:  # Seis vértices, 60° entre eles.
		# Cada vértice.
		points.append(center + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / float(HEX_SIDES)) * radius)
	return points


## Fecha o polígono repetindo o primeiro ponto (para desenhar o contorno com polyline).
## Fecha o polígono repetindo o primeiro ponto (para polyline).
func _closed(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()  # Cópia dos pontos.
	result.append(points[0])  # Repete o primeiro.
	return result


## Converte pontos em coordenadas de glifo (-1 a 1) para a tela.
## Converte pontos em coordenadas de glifo (-1..1) para a tela.
func _pts(center: Vector2, g: float, raw: Array) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()  # Pontos em pixels.
	for p: Vector2 in raw:  # Cada ponto.
		points.append(center + p * g)  # Escala e desloca.
	return points


# --- Glifos ---

## Desenha o glifo (símbolo) do amuleto: cada caso abaixo é um desenho diferente feito só com linhas, arcos e polígonos.
func _draw_glyph(glyph: AbilityData.Glyph, c: Vector2, g: float, col: Color) -> void:
	var w: float = maxf(g * 0.2, 2.0)  # Espessura das linhas.
	match glyph:  # Escolhe o desenho pelo tipo de glifo.
		AbilityData.Glyph.DOUBLE_CHEVRON:  # Duas setas duplas (Passo Ágil).
			for x: float in [-0.45, 0.35]:
				draw_polyline(_pts(c, g, [Vector2(x - 0.35, -0.7), Vector2(x + 0.35, 0.0), Vector2(x - 0.35, 0.7)]), col, w, true)
		AbilityData.Glyph.SPEED_LINES:  # Linhas de velocidade.
			draw_line(c + Vector2(-0.9, -0.55) * g, c + Vector2(0.5, -0.55) * g, col, w, true)
			draw_line(c + Vector2(-0.6, 0.0) * g, c + Vector2(0.95, 0.0) * g, col, w, true)
			draw_line(c + Vector2(-0.9, 0.55) * g, c + Vector2(0.2, 0.55) * g, col, w, true)
		AbilityData.Glyph.BLADE_ARC:  # Arco de lâmina.
			draw_arc(c + Vector2(0.0, 0.35) * g, g * 1.05, deg_to_rad(205.0), deg_to_rad(335.0), 20, col, w, true)
			draw_arc(c + Vector2(0.0, 0.35) * g, g * 0.65, deg_to_rad(215.0), deg_to_rad(325.0), 16, col, w * 0.7, true)
			draw_line(c + Vector2(0.0, -0.45) * g, c + Vector2(0.0, 0.95) * g, col, w * 0.7, true)
		AbilityData.Glyph.DROP:  # Gota (Roubo de Vida).
			draw_colored_polygon(_pts(c, g, [Vector2(0.0, -1.0), Vector2(-0.58, 0.15), Vector2(0.58, 0.15)]), col)
			draw_circle(c + Vector2(0.0, 0.3) * g, g * 0.62, col)
		AbilityData.Glyph.FLAME:  # Chama (Rastro de Fogo).
			draw_colored_polygon(_pts(c, g, [
				Vector2(0.05, -1.0), Vector2(0.55, -0.25), Vector2(0.7, 0.35), Vector2(0.35, 0.9),
				Vector2(-0.35, 0.9), Vector2(-0.7, 0.35), Vector2(-0.45, -0.1), Vector2(-0.2, -0.35),
			]), col)
			draw_colored_polygon(_pts(c, g, [
				Vector2(0.0, 0.0), Vector2(0.3, 0.45), Vector2(0.15, 0.82),
				Vector2(-0.15, 0.82), Vector2(-0.3, 0.45),
			]), COLOR_FILL)
		AbilityData.Glyph.CONCENTRIC:  # Círculos concêntricos (Pulso EMP).
			draw_circle(c, g * 0.14, col)
			draw_arc(c, g * 0.5, 0.0, TAU, 24, col, w * 0.8, true)
			draw_arc(c, g * 0.95, 0.0, TAU, 32, col, w * 0.8, true)
		AbilityData.Glyph.SHIELD:  # Escudo.
			var contorno: PackedVector2Array = _pts(c, g, [
				Vector2(-0.8, -0.8), Vector2(0.8, -0.8), Vector2(0.8, 0.1), Vector2(0.0, 1.0), Vector2(-0.8, 0.1),
			])
			draw_polyline(_closed(contorno), col, w, true)
			draw_line(c + Vector2(0.0, -0.8) * g, c + Vector2(0.0, 0.95) * g, col, w * 0.6, true)
		AbilityData.Glyph.CROSS:  # Cruz (Cura).
			draw_rect(Rect2(c + Vector2(-0.22, -0.85) * g, Vector2(0.44, 1.7) * g), col)
			draw_rect(Rect2(c + Vector2(-0.85, -0.22) * g, Vector2(1.7, 0.44) * g), col)
		AbilityData.Glyph.PIERCE_ARROW:  # Flecha que atravessa (Tiro Perfurante).
			draw_line(c + Vector2(0.0, -0.85) * g, c + Vector2(0.0, 0.85) * g, col.darkened(0.35), w, true)
			draw_line(c + Vector2(-1.0, 0.0) * g, c + Vector2(0.55, 0.0) * g, col, w, true)
			draw_colored_polygon(_pts(c, g, [Vector2(1.0, 0.0), Vector2(0.45, -0.42), Vector2(0.45, 0.42)]), col)
		AbilityData.Glyph.HELM:  # Elmo (Cavaleiro Imbatível).
			# cúpula, laterais afunilando até o queixo e fresta do visor
			draw_arc(c + Vector2(0.0, -0.1) * g, g * 0.78, PI, TAU, 18, col, w, true)
			draw_polyline(_pts(c, g, [
				Vector2(-0.78, -0.1), Vector2(-0.78, 0.5), Vector2(-0.4, 0.95),
				Vector2(0.4, 0.95), Vector2(0.78, 0.5), Vector2(0.78, -0.1),
			]), col, w, true)
			draw_rect(Rect2(c + Vector2(-0.6, 0.02) * g, Vector2(1.2, 0.2) * g), col)
			draw_line(c + Vector2(0.0, 0.22) * g, c + Vector2(0.0, 0.9) * g, col, w * 0.6, true)
			draw_line(c + Vector2(0.0, -0.88) * g, c + Vector2(0.0, -0.45) * g, col, w, true)
		AbilityData.Glyph.BLOOD_BLADE:  # Lâmina com sangue (Modo Sanguinário).
			draw_colored_polygon(_pts(c, g, [Vector2(0.0, -1.0), Vector2(0.26, 0.4), Vector2(-0.26, 0.4)]), col)
			draw_rect(Rect2(c + Vector2(-0.6, 0.4) * g, Vector2(1.2, 0.16) * g), col)
			draw_line(c + Vector2(0.0, 0.56) * g, c + Vector2(0.0, 1.0) * g, col, w, true)
			draw_circle(c + Vector2(0.62, -0.2) * g, g * 0.17, COLOR_BLOOD)
			draw_colored_polygon(_pts(c, g, [Vector2(0.62, -0.62), Vector2(0.48, -0.25), Vector2(0.76, -0.25)]), COLOR_BLOOD)
		AbilityData.Glyph.MASK:  # Máscara (Ninja Furtivo).
			var mascara: PackedVector2Array = _pts(c, g, [
				Vector2(-0.9, -0.5), Vector2(0.9, -0.5), Vector2(0.7, 0.5), Vector2(0.0, 0.95), Vector2(-0.7, 0.5),
			])
			draw_colored_polygon(mascara, col)
			draw_colored_polygon(_pts(c, g, [Vector2(-0.65, -0.2), Vector2(-0.12, -0.05), Vector2(-0.3, 0.2)]), COLOR_FILL)
			draw_colored_polygon(_pts(c, g, [Vector2(0.65, -0.2), Vector2(0.12, -0.05), Vector2(0.3, 0.2)]), COLOR_FILL)
		_:  # Qualquer outro: círculo simples.
			draw_circle(c, g * 0.3, col)
