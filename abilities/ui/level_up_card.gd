class_name LevelUpCard
extends PanelContainer
## Carta de habilidade do menu de level-up: amuleto, nome, efeito, recarga/duração e setas.
## Cartas lendárias ganham moldura dourada dupla, ornamentos nos cantos e o aviso de perda.

signal selected(ability: AbilityData)  # Avisa que o jogador escolheu esta carta.

const COLOR_TEXT: Color = Palette.TEXT  # Cores do texto, do aviso e do foco.
const COLOR_TEXT_MUTED: Color = Palette.TEXT_DIM
const COLOR_WARNING: Color = Palette.DANGER
const COLOR_WARNING_BG: Color = Palette.PANEL
## Anel de foco: mesmo destaque (ACCENT) dos botões.
const COLOR_FOCUS: Color = Palette.ACCENT

const CARD_WIDTH: float = 240.0  # Tamanhos da carta, do amuleto e do texto.
const AMULET_SIZE: float = 128.0
const TEXT_WIDTH: float = 210.0
const DESCRIPTION_HEIGHT: float = 72.0
## Tamanhos em múltiplos de 16 (fontes pixeladas).
const FONT_TITLE: int = Palette.FONT_BODY
const FONT_BODY: int = Palette.FONT_SMALL
const FONT_SMALL: int = Palette.FONT_SMALL
## Escala da carta em foco/hover e na entrada, e duração (s) das animações.
const HIGHLIGHT_SCALE: float = 1.04
const ENTER_SCALE: float = 0.92
const ENTER_TIME: float = 0.22
const HIGHLIGHT_TIME: float = 0.12
## Distância (px) da moldura dourada interna até a borda da carta.
const FRAME_INSET: float = 6.0
const CORNER_SIZE: float = 14.0  # Tamanho dos ornamentos dos cantos.
## Altura mínima do banner de aviso da lendária (3 linhas de texto pequeno).
const WARNING_HEIGHT: float = 88.0

const RARITY_NAMES: Dictionary = {  # Nome de cada raridade.
	AbilityData.Rarity.COMUM: "COMUM",
	AbilityData.Rarity.AVANCADA: "AVANÇADA",
	AbilityData.Rarity.LENDARIA: "LENDÁRIA",
}
# Aviso de perda das outras habilidades.
const WARNING_TEXT: String = "Ao escolher esta lendária você perde TODAS as outras habilidades desta run."

var ability: AbilityData = null  # Habilidade da carta.
var _color: Color = Color.WHITE  # Cor da raridade.
var _legendary: bool = false  # True se é lendária.
var _overlay: Control = null  # Camada que desenha moldura e foco.
var _read_only: bool = false  # Carta só de consulta (menu de build).
var _scale_target: float = 1.0  # Escala desejada (1.0 normal, maior com foco).
var _scale_tween: Tween = null  # Animação da escala.


## Triângulo de alerta desenhado por código.
class _AlertIcon extends Control:
	const COLOR: Color = Palette.DANGER
	const ICON_SIZE: float = 26.0

	## Define o tamanho mínimo do ícone e não captura cliques.
	func _init() -> void:
		custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Desenha o triângulo com a exclamação.
	func _draw() -> void:
		var w: float = size.x  # Largura.
		var h: float = size.y  # Altura.
		var tri: PackedVector2Array = PackedVector2Array([  # Pontos do triângulo.
			Vector2(w * 0.5, h * 0.06), Vector2(w * 0.97, h * 0.92), Vector2(w * 0.03, h * 0.92), Vector2(w * 0.5, h * 0.06),
		])
		draw_polyline(tri, COLOR, 2.5, true)  # Contorno.
		# Traço da exclamação.
		draw_line(Vector2(w * 0.5, h * 0.36), Vector2(w * 0.5, h * 0.62), COLOR, 2.5, true)
		draw_circle(Vector2(w * 0.5, h * 0.77), 1.8, COLOR)  # Ponto da exclamação.


## `reserve_warning_space`: reserva o espaço do banner (cartas comuns ao lado de uma lendária),
## para as setas de todas as cartas ficarem na mesma altura.
## `read_only`: carta de consulta (menu de build): navega e destaca, mas nunca emite `selected`.
## Monta a carta: guarda a habilidade, define cor e raridade, cria o conteúdo e liga foco, mouse e tamanho.
func setup(data: AbilityData, reserve_warning_space: bool = false, read_only: bool = false) -> void:
	_read_only = read_only  # Modo só leitura?
	ability = data  # Habilidade da carta.
	_legendary = data.rarity == AbilityData.Rarity.LENDARIA  # É lendária?
	_color = AmuletIcon.color_for_rarity(data.rarity)  # Cor da raridade.
	focus_mode = Control.FOCUS_ALL  # Aceita foco do teclado.
	mouse_filter = Control.MOUSE_FILTER_STOP  # Recebe cliques do mouse.
	custom_minimum_size.x = CARD_WIDTH  # Largura mínima.
	_build_content(reserve_warning_space)  # Cria os textos e o amuleto.
	_build_overlay()  # Cria a moldura.
	_ignore_mouse_in_children(self)  # Só a carta recebe o mouse.
	mouse_entered.connect(grab_focus)  # Passar o mouse dá foco.
	focus_entered.connect(_set_highlight.bind(true))  # Foco cresce a carta.
	focus_exited.connect(_set_highlight.bind(false))  # Perder o foco volta ao tamanho normal.
	resized.connect(_center_pivot)  # Mantém o pivô no centro.


## Cria o conteúdo da carta: raridade, amuleto, nome, descrição, recarga/duração, setas e aviso de perda (se lendária).
func _build_content(reserve_warning_space: bool) -> void:
	var box: VBoxContainer = VBoxContainer.new()  # Coluna do conteúdo.
	box.add_theme_constant_override(&"separation", 8)
	add_child(box)

	var rarity: Label = _label(str(RARITY_NAMES[ability.rarity]), FONT_SMALL, _color)  # Nome da raridade.
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(rarity)

	var amulet: AmuletIcon = AmuletIcon.new()  # Amuleto.
	amulet.custom_minimum_size = Vector2(AMULET_SIZE, AMULET_SIZE)
	amulet.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	amulet.set_ability(ability)
	box.add_child(amulet)

	var title: Label = _label(ability.display_name, FONT_TITLE,  # Nome da habilidade.
			AmuletIcon.COLOR_LEGENDARY_LIGHT if _legendary else COLOR_TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART  # nomes longos quebram em 2 linhas
	title.custom_minimum_size.x = TEXT_WIDTH
	box.add_child(title)

	var description: Label = _label(ability.description, FONT_BODY, COLOR_TEXT)  # Descrição do efeito.
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size = Vector2(TEXT_WIDTH, DESCRIPTION_HEIGHT)
	description.size_flags_vertical = Control.SIZE_EXPAND_FILL  # empurra recarga e setas para baixo
	box.add_child(description)

	var info: Label = _label(_info_text(), FONT_SMALL, COLOR_TEXT_MUTED)  # Linha de recarga e duração.
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(info)

	var arrows: ArrowSequenceView = ArrowSequenceView.new()  # Setas da sequência.
	arrows.set_sequence(ability.sequence)
	arrows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(arrows)

	if _legendary and not _read_only:  # o aviso de perda é da ESCOLHA; a build consultada já foi escolhida
		box.add_child(_build_warning())
	# Reserva o espaço do aviso para alinhar as setas das cartas ao lado.
	elif reserve_warning_space and not _read_only:
		var spacer: Control = Control.new()
		spacer.custom_minimum_size.y = WARNING_HEIGHT
		box.add_child(spacer)


## Texto de recarga e duração (ou "Instantânea").
func _info_text() -> String:
	var recarga: String = "Recarga %s s" % _fmt(ability.cooldown)  # Texto da recarga.
	if ability.duration > 0.0:  # Tem duração.
		return "%s  ·  Duração %s s" % [recarga, _fmt(ability.duration)]
	return "%s  ·  Instantânea" % recarga  # Sem duração: instantânea.


## Formata o número sem casas decimais quando é inteiro.
func _fmt(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, floorf(value)) else "%.1f" % value


## Banner de perda: obrigatório em toda carta lendária.
## Cria o aviso de que escolher a lendária apaga as outras habilidades.
func _build_warning() -> Control:
	var banner: PanelContainer = PanelContainer.new()  # Painel do aviso.
	var style: PixelBox = PixelBox.new()  # Estilo pixelado.
	style.fill_color = COLOR_WARNING_BG
	style.border_color = COLOR_WARNING
	style.outline_width = 0
	style.corner_cut = 0
	style.set_content_margin_all(8.0)
	banner.add_theme_stylebox_override(&"panel", style)
	banner.custom_minimum_size.y = WARNING_HEIGHT  # Altura mínima.
	var row: HBoxContainer = HBoxContainer.new()  # Linha com ícone e texto.
	row.add_theme_constant_override(&"separation", 8)
	banner.add_child(row)
	var icon: _AlertIcon = _AlertIcon.new()  # Ícone de alerta.
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)
	var text: Label = _label(WARNING_TEXT, FONT_SMALL, COLOR_WARNING)  # Texto do aviso.
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = TEXT_WIDTH - _AlertIcon.ICON_SIZE - 8.0
	row.add_child(text)
	return banner  # Devolve o aviso.


## Cria uma etiqueta com texto, tamanho e cor.
func _label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label


## Só a carta recebe o mouse: tudo o que está dentro dela deixa o clique passar.
## Só a carta recebe o mouse: tudo dentro dela deixa o clique passar.
func _ignore_mouse_in_children(node: Node) -> void:
	for child: Node in node.get_children():  # Para cada filho.
		var control: Control = child as Control
		if control != null:  # Só controles têm filtro de mouse.
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ignore_mouse_in_children(child)  # Desce para os filhos dos filhos.


## Clique esquerdo ou Enter escolhe a carta (cartas de consulta ignoram).
func _gui_input(event: InputEvent) -> void:
	if _read_only:  # Carta de consulta: ignora.
		return
	var click: InputEventMouseButton = event as InputEventMouseButton  # Clique de mouse.
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:  # Clique esquerdo.
		accept_event()  # Consome o clique.
		selected.emit(ability)  # Avisa a escolha.
	elif event.is_action_pressed(&"ui_accept"):  # Enter ou espaço (ui_accept).
		accept_event()  # Consome a tecla.
		selected.emit(ability)  # Avisa a escolha.


## Moldura e foco ficam num filho que cobre o conteúdo: ele é desenhado por cima do fundo da carta.
func _build_overlay() -> void:
	_overlay = Control.new()  # Camada por cima do conteúdo.
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.draw.connect(_paint_overlay)  # Desenha com `_paint_overlay`.


## Desenha a moldura (se lendária) e o anel de foco sobre a carta inteira.
func _paint_overlay() -> void:
	# O filho cobre só a área de conteúdo: a carta inteira começa nas margens do estilo para fora dele.
	var style: StyleBox = get_theme_stylebox(&"panel")  # Estilo do painel.
	# Margens do estilo.
	var margin: Vector2 = Vector2(style.get_margin(SIDE_LEFT), style.get_margin(SIDE_TOP))
	var card_rect: Rect2 = Rect2(-margin, _overlay.size + margin * 2.0)  # Retângulo da carta inteira.
	if _legendary:  # Lendária: moldura dourada.
		_paint_legendary_frame(card_rect)
	if has_focus():  # Foco: anel.
		_overlay.draw_rect(card_rect, COLOR_FOCUS, false, 2.0)


## Moldura dourada dupla com ornamentos nos cantos.
## Desenha a moldura dourada interna e os ornamentos nos quatro cantos.
func _paint_legendary_frame(card_rect: Rect2) -> void:
	var gold: Color = AmuletIcon.COLOR_LEGENDARY  # Cor dourada.
	var light: Color = AmuletIcon.COLOR_LEGENDARY_LIGHT  # Cor clara.
	var inner: Rect2 = card_rect.grow(-FRAME_INSET)  # Retângulo interno.
	var line: Color = gold  # Linha dourada.
	line.a = 0.8  # Transparência.
	_overlay.draw_rect(inner, line, false, 1.0)  # Desenha o retângulo.
	var corners: Array[Vector2] = [  # Os quatro cantos.
		inner.position,
		Vector2(inner.end.x, inner.position.y),
		inner.end,
		Vector2(inner.position.x, inner.end.y),
	]
	# Sentido de cada canto.
	var signs: Array[Vector2] = [Vector2(1.0, 1.0), Vector2(-1.0, 1.0), Vector2(-1.0, -1.0), Vector2(1.0, -1.0)]
	for i: int in corners.size():  # Para cada canto.
		var corner: Vector2 = corners[i]
		var sign_v: Vector2 = signs[i]
		# Traço horizontal do canto.
		_overlay.draw_line(corner, corner + Vector2(sign_v.x * CORNER_SIZE, 0.0), light, 2.5, true)
		# Traço vertical do canto.
		_overlay.draw_line(corner, corner + Vector2(0.0, sign_v.y * CORNER_SIZE), light, 2.5, true)
		var d: float = CORNER_SIZE * 0.32  # Tamanho do losango.
		var c: Vector2 = corner - sign_v * 3.0  # Centro do losango.
		_overlay.draw_colored_polygon(PackedVector2Array([  # Losango.
			c + Vector2(0.0, -d), c + Vector2(d, 0.0), c + Vector2(0.0, d), c + Vector2(-d, 0.0),
		]), gold)


## Mantém o ponto de giro no centro da carta (para crescer a partir do meio).
func _center_pivot() -> void:
	pivot_offset = size * 0.5


## Foco e hover: a carta cresce um pouco (o anel branco é desenhado pelo overlay).
## Foco e passar o mouse: a carta cresce um pouco e a moldura é redesenhada.
func _set_highlight(on: bool) -> void:
	_overlay.queue_redraw()  # Redesenha o anel de foco.
	_scale_target = HIGHLIGHT_SCALE if on else 1.0  # Escala desejada.
	_animate_scale(HIGHLIGHT_TIME, 0.0, false)  # Anima.


## Entrada: a carta aparece (fade + cresce) depois de `delay` segundos.
## Entrada da carta: aparece com fade e crescendo depois de `delay` segundos.
func play_entrance(delay: float) -> void:
	modulate.a = 0.0  # Começa transparente.
	scale = Vector2.ONE * ENTER_SCALE  # Começa menor.
	var fade: Tween = UiTween.create(self)  # Animação do fade.
	fade.tween_property(self, ^"modulate:a", 1.0, ENTER_TIME).set_delay(delay)  # Aparece depois do atraso.
	_animate_scale(ENTER_TIME, delay, true)  # Cresce com um leve "pulo".


## Uma única animação de escala por vez: foco durante a entrada não briga com ela.
## Uma única animação de escala por vez: o foco durante a entrada não briga com ela.
func _animate_scale(time: float, delay: float, pop: bool) -> void:
	if _scale_tween != null and _scale_tween.is_valid():  # Cancela a anterior.
		_scale_tween.kill()
	_scale_tween = UiTween.create(self)  # Nova animação.
	# Anima até a escala desejada.
	var step: PropertyTweener = _scale_tween.tween_property(self, ^"scale", Vector2.ONE * _scale_target, time).set_delay(delay)
	if pop:  # Entrada: efeito de "pulo".
		step.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
