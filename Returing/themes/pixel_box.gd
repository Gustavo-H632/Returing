@tool
class_name PixelBox
extends StyleBox
## Caixa pixelada: sombra dura (sem blur) + contorno escuro + borda + preenchimento, com cantos
## "chanfrados" de alguns pixels. Cada camada é um retângulo opaco alinhado ao pixel, então a
## moldura é dupla (contorno escuro por fora, linha de borda mais clara por dentro) e nunca borra.
## Configure as propriedades ANTES de usar; as margens de conteúdo são as do StyleBox (content_margin_*).

## Preenchimento.
@export var fill_color: Color = Palette.PANEL
## Linha de borda (a camada de dentro da moldura).
@export var border_color: Color = Palette.BORDER
## Contorno escuro (a camada de fora da moldura).
@export var outline_color: Color = Palette.BG
## Cor da sombra dura.
@export var shadow_color: Color = Palette.BG
@export_range(0, 8) var border_width: int = Palette.BORDER_THIN  # Espessura da borda.
@export_range(0, 8) var outline_width: int = Palette.BORDER_THIN  # Espessura do contorno.
## Tamanho (px) do canto cortado. 0 = canto reto.
@export_range(0, 8) var corner_cut: int = 2
## Deslocamento da sombra. (0, 0) = sem sombra.
@export var shadow_offset: Vector2i = Vector2i.ZERO
## Encolhe a caixa dentro do retângulo (ex.: preenchimento de slider dentro do trilho).
@export_range(0, 16) var inset: int = 0


## Desenha as camadas da caixa: sombra, contorno, borda e preenchimento, cada uma um retângulo alinhado ao pixel.
func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	# Retângulo em pixels inteiros, já encolhido pelo `inset`.
	var base: Rect2i = Rect2i(Vector2i(rect.position.round()), Vector2i(rect.size.round())).grow(-inset)
	if base.size.x <= 0 or base.size.y <= 0:  # Pequeno demais para desenhar.
		return
	if shadow_offset != Vector2i.ZERO:  # Sombra dura (sem blur).
		# Camada da sombra.
		_draw_layer(to_canvas_item, Rect2i(base.position + shadow_offset, base.size), shadow_color)
	var layer: Rect2i = base  # Camada atual.
	if outline_width > 0:  # Contorno escuro.
		_draw_layer(to_canvas_item, layer, outline_color)  # Desenha o contorno.
		layer = layer.grow(-outline_width)  # Encolhe para a próxima camada.
	if border_width > 0:  # Borda.
		_draw_layer(to_canvas_item, layer, border_color)  # Desenha a borda.
		layer = layer.grow(-border_width)  # Encolhe para o preenchimento.
	_draw_layer(to_canvas_item, layer, fill_color)  # Preenchimento.


## A sombra também é desenhada, então a área de desenho a inclui.
## Área de desenho: o retângulo mais a sombra.
func _get_draw_rect(rect: Rect2) -> Rect2:
	# Une o retângulo com a sombra deslocada.
	return rect.merge(Rect2(rect.position + Vector2(shadow_offset), rect.size))


## Um retângulo com os 4 cantos cortados (dois retângulos que se cruzam).
## Desenha um retângulo com os 4 cantos cortados (dois retângulos que se cruzam).
func _draw_layer(canvas_item: RID, area: Rect2i, color: Color) -> void:
	if area.size.x <= 0 or area.size.y <= 0:  # Área inválida.
		return
	# Corte limitado à metade do menor lado.
	var cut: int = mini(corner_cut, mini(area.size.x, area.size.y) >> 1)
	if cut <= 0:  # Sem corte: retângulo simples.
		RenderingServer.canvas_item_add_rect(canvas_item, Rect2(area), color)  # Retângulo simples.
		return
	var x: float = area.position.x  # Posição e tamanho em decimais.
	var y: float = area.position.y
	var w: float = area.size.x
	var h: float = area.size.y
	# Retângulo mais largo (sem os cantos de cima e de baixo).
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(x + cut, y, w - 2.0 * cut, h), color)
	# Retângulo mais alto (sem os cantos laterais).
	RenderingServer.canvas_item_add_rect(canvas_item, Rect2(x, y + cut, w, h - 2.0 * cut), color)
