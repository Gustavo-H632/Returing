@tool
class_name PixelTheme
extends Theme
## Tema de todos os menus (usado por res://themes/main_theme.tres).
## Todos os estilos saem de `Palette` e são montados aqui, então mudar uma cor ou medida
## é editar UM lugar. As fontes são carregadas se existirem em res://assets/fonts/; sem elas o
## menu continua funcionando com a fonte padrão do Godot (e avisa no console).
##
## Variações de tipo disponíveis nas cenas (propriedade "Theme Type Variation"):
##   Label:  TitleLabel (título grande), PanelTitleLabel (título de caixa), HintLabel (apoio, TEXT_DIM)
##   Button: DangerButton (ação destrutiva: hover/foco em DANGER)
##   Panel:  BackdropPanel (fundo de tela cheia)  |  PanelContainer: PanelRaised (caixa elevada)

## Fonte de título, em ordem de preferência (a primeira que existir é usada).
const TITLE_FONT_PATHS: PackedStringArray = [
	"res://assets/fonts/PixelifySans-Bold.ttf",
	"res://assets/fonts/PixelifySans-Regular.ttf",
	"res://assets/fonts/PixelifySans-VariableFont_wght.ttf",
	"res://assets/fonts/PixelifySans[wght].ttf",
]
## Fonte de texto e botões.
const BODY_FONT_PATHS: PackedStringArray = [
	"res://assets/fonts/VT323-Regular.ttf",
]

## Espaçamento padrão (px) entre itens de caixas.
const SEPARATION: int = Palette.UNIT * 2
## Margem interna (px) horizontal e vertical dos botões.
const BUTTON_PAD_X: int = Palette.UNIT * 3
const BUTTON_PAD_Y: int = 12  # Margem interna vertical dos botões.
## Margem interna (px) das caixas.
const PANEL_PAD: int = Palette.UNIT * 3
## Sombra dos botões: em repouso, com hover/foco (o botão sobe 2 px) e apertado (afunda 2 px).
## A base da sombra fica no mesmo lugar nos três estados, como se o botão saísse do chão.
const SHADOW_REST: Vector2i = Vector2i(0, 4)
const SHADOW_HOVER: Vector2i = Vector2i(0, 6)  # Sombra com hover ou foco (o botão sobe).
const SHADOW_PRESSED: Vector2i = Vector2i(0, 2)  # Sombra do botão apertado (o botão afunda).

const GRABBER_SIZE: Vector2i = Vector2i(16, 24)  # Tamanho do puxador do slider.
## Altura do trilho = 2 x esta margem (12 px: 4 de moldura de cada lado + 4 de miolo).
const SLIDER_TRACK_PAD: int = 6


## Monta o tema inteiro ao ser criado.
func _init() -> void:
	_build()  # Cria todos os estilos.


## Monta o tema: fontes, textos, botões, painéis, slider, separador, campos e espaçamentos.
func _build() -> void:
	var body_font: Font = _load_font(BODY_FONT_PATHS)  # Fonte do texto.
	var title_font: Font = _load_font(TITLE_FONT_PATHS)  # Fonte do título.
	if body_font != null:  # Só troca se a fonte foi encontrada.
		default_font = body_font  # Fonte padrão do tema.
	default_font_size = Palette.FONT_BODY  # Tamanho padrão.
	_build_labels(title_font)  # Textos.
	_build_button(&"Button", Palette.ACCENT, Palette.ACCENT_PRESSED)  # Botão normal (destaque dourado).
	set_type_variation(&"DangerButton", &"Button")  # O botão de perigo herda do botão normal.
	_build_button(&"DangerButton", Palette.DANGER, Palette.DANGER)  # Botão de perigo (destaque laranja).
	_build_panels()  # Painéis.
	_build_slider()  # Slider.
	_build_separator()  # Separador.
	_build_inputs()  # Campos de texto e barra.
	set_constant(&"separation", &"VBoxContainer", SEPARATION)  # Espaçamento das caixas verticais.
	set_constant(&"separation", &"HBoxContainer", SEPARATION)  # Espaçamento das caixas horizontais.


## Carrega a primeira fonte existente da lista e a deixa sem suavização (pixel nítido).
## Carrega a primeira fonte existente da lista e a deixa sem suavização (pixel nítido). Sem nenhuma, avisa e usa a fonte padrão.
func _load_font(paths: PackedStringArray) -> Font:
	for path: String in paths:  # Tenta cada caminho.
		if not ResourceLoader.exists(path):  # Arquivo inexistente: próximo.
			continue
		var font: FontFile = load(path) as FontFile  # Carrega a fonte.
		if font == null:  # Falhou: próximo.
			continue
		font.antialiasing = TextServer.FONT_ANTIALIASING_NONE  # Sem suavização (pixel nítido).
		font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED  # Sem posição por subpixel.
		return font  # Achou.
	# Nenhuma encontrada: avisa.
	push_warning("PixelTheme: fonte não encontrada (%s). Usando a fonte padrão; veja res://assets/fonts/LEIAME.md." % paths[0])
	return null  # Usa a fonte padrão.


# --- Textos ---

## Define os estilos de texto: rótulos, rótulo de apoio, título grande e título de caixa.
func _build_labels(title_font: Font) -> void:
	set_color(&"font_color", &"Label", Palette.TEXT)  # Cor do texto.
	set_font_size(&"font_size", &"Label", Palette.FONT_BODY)  # Tamanho do texto.
	set_color(&"default_color", &"RichTextLabel", Palette.TEXT)  # Texto formatado.
	set_font_size(&"normal_font_size", &"RichTextLabel", Palette.FONT_BODY)  # Tamanho do texto formatado.

	set_type_variation(&"HintLabel", &"Label")  # Rótulo de apoio (esmaecido).
	set_color(&"font_color", &"HintLabel", Palette.TEXT_DIM)  # Cor esmaecida.
	set_font_size(&"font_size", &"HintLabel", Palette.FONT_HINT)  # Tamanho de dica.

	set_type_variation(&"TitleLabel", &"Label")  # Título grande.
	set_color(&"font_color", &"TitleLabel", Palette.TEXT)  # Cor.
	set_font_size(&"font_size", &"TitleLabel", Palette.FONT_TITLE)  # Tamanho.
	set_color(&"font_shadow_color", &"TitleLabel", Palette.BORDER)  # sombra dura, sem blur
	set_constant(&"shadow_offset_x", &"TitleLabel", Palette.BORDER_THICK)  # Sombra horizontal.
	set_constant(&"shadow_offset_y", &"TitleLabel", Palette.BORDER_THICK)  # Sombra vertical.

	set_type_variation(&"PanelTitleLabel", &"Label")  # Título de caixa.
	set_color(&"font_color", &"PanelTitleLabel", Palette.TEXT)  # Cor.
	set_font_size(&"font_size", &"PanelTitleLabel", Palette.FONT_BODY)  # Tamanho.
	if title_font != null:  # Fonte do título, se existir.
		set_font(&"font", &"TitleLabel", title_font)  # Aplica ao título grande.
		set_font(&"font", &"PanelTitleLabel", title_font)  # Aplica ao título de caixa.


# --- Botões ---

## Monta os 5 estados de um botão. `hot` = cor de hover/foco; `hot_pressed` = cor ao apertar.
## Monta os cinco estados de um botão. `hot` é a cor de hover e foco; `hot_pressed` é a cor ao apertar.
func _build_button(type: StringName, hot: Color, hot_pressed: Color) -> void:
	# Normal.
	var normal: PixelBox = _box(Palette.PANEL_RAISED, Palette.BORDER, SHADOW_REST, BUTTON_PAD_X, BUTTON_PAD_Y)
	# Hover.
	var hover: PixelBox = _box(Palette.PANEL_RAISED, hot, SHADOW_HOVER, BUTTON_PAD_X, BUTTON_PAD_Y)
	# Apertado.
	var pressed: PixelBox = _box(Palette.PANEL, hot_pressed, SHADOW_PRESSED, BUTTON_PAD_X, BUTTON_PAD_Y)
	# Desabilitado.
	var disabled_box: PixelBox = _box(Palette.PANEL, Palette.DISABLED, SHADOW_REST, BUTTON_PAD_X, BUTTON_PAD_Y)
	set_stylebox(&"normal", type, normal)  # Normal.
	set_stylebox(&"hover", type, hover)  # Hover.
	# Foco com o mesmo visual do hover (o PixelButton troca por vazio e controla o destaque sozinho).
	set_stylebox(&"focus", type, hover)  # Foco.
	set_stylebox(&"pressed", type, pressed)  # Apertado.
	set_stylebox(&"hover_pressed", type, pressed)  # Apertado com o mouse em cima.
	set_stylebox(&"disabled", type, disabled_box)  # Desabilitado.
	set_color(&"font_color", type, Palette.TEXT)  # Cor do texto normal.
	set_color(&"font_hover_color", type, hot)  # Cor do texto com hover.
	set_color(&"font_focus_color", type, hot)  # Cor do texto com foco.
	set_color(&"font_pressed_color", type, hot_pressed)  # Cor do texto apertado.
	set_color(&"font_hover_pressed_color", type, hot_pressed)  # Cor do texto apertado com hover.
	set_color(&"font_disabled_color", type, Palette.DISABLED_TEXT)  # Cor do texto desabilitado.
	set_font_size(&"font_size", type, Palette.FONT_BODY)  # Tamanho do texto.
	set_constant(&"h_separation", type, Palette.UNIT)  # Espaço entre ícone e texto.
	set_constant(&"outline_size", type, 0)  # Sem contorno no texto.


# --- Painéis ---

## Define os painéis: normal, elevado e fundo de tela cheia.
func _build_panels() -> void:
	# Painel comum.
	var panel: PixelBox = _box(Palette.PANEL, Palette.BORDER, Palette.SHADOW_PANEL, PANEL_PAD, PANEL_PAD)
	set_stylebox(&"panel", &"PanelContainer", panel)  # Para caixas.
	set_stylebox(&"panel", &"Panel", panel)  # Para painéis.

	set_type_variation(&"PanelRaised", &"PanelContainer")  # Painel elevado.
	set_stylebox(&"panel", &"PanelRaised",
			_box(Palette.PANEL_RAISED, Palette.BORDER, Palette.SHADOW_PANEL, PANEL_PAD, PANEL_PAD))

	# Fundo de tela cheia: cor lisa, sem moldura.
	set_type_variation(&"BackdropPanel", &"Panel")  # Variação de painel.
	var backdrop: PixelBox = _box(Palette.BG, Palette.BG, Vector2i.ZERO, 0, 0)  # Cor lisa.
	backdrop.border_width = 0  # Sem borda.
	backdrop.outline_width = 0  # Sem contorno.
	backdrop.corner_cut = 0  # Sem canto cortado.
	set_stylebox(&"panel", &"BackdropPanel", backdrop)  # Aplica.


# --- Slider (HSlider): trilho em PANEL_RAISED, preenchimento e grabber em ACCENT ---

## Define o slider: trilho, preenchimento e puxador (que muda de aparência com foco e desabilitado).
func _build_slider() -> void:
	# Trilho.
	var track: PixelBox = _box(Palette.PANEL_RAISED, Palette.BORDER, Vector2i.ZERO, 0, SLIDER_TRACK_PAD)
	set_stylebox(&"slider", &"HSlider", track)  # Aplica.
	# Preenchimento: desenhado dentro do trilho (descontando contorno + borda = 4 px).
	var fill: PixelBox = PixelBox.new()  # Estilo do preenchimento.
	fill.fill_color = Palette.ACCENT  # Cor de destaque.
	fill.border_width = 0  # Sem borda.
	fill.outline_width = 0  # Sem contorno.
	fill.corner_cut = 0  # Sem canto cortado.
	fill.inset = Palette.BORDER_THICK  # Desconta contorno e borda.
	set_stylebox(&"grabber_area", &"HSlider", fill)  # Aplica (normal).
	set_stylebox(&"grabber_area_highlight", &"HSlider", fill)  # Aplica (destacado).
	set_icon(&"grabber", &"HSlider", _make_grabber(Palette.ACCENT, Palette.BG))  # Puxador normal.
	# Hover/foco/arraste: mesmo grabber com anel claro para o foco ficar visível.
	# Puxador com anel claro (foco ou arraste).
	set_icon(&"grabber_highlight", &"HSlider", _make_grabber(Palette.ACCENT, Palette.TEXT))
	# Puxador desabilitado.
	set_icon(&"grabber_disabled", &"HSlider", _make_grabber(Palette.DISABLED, Palette.BG))


## Grabber retangular com anel de 2 px e cantos cortados, gerado em código (sem arte).
## Gera o puxador do slider em código: retângulo com anel de 2 px e cantos cortados (sem usar arte).
func _make_grabber(fill: Color, ring: Color) -> ImageTexture:
	# Imagem vazia do tamanho do puxador.
	var image: Image = Image.create(GRABBER_SIZE.x, GRABBER_SIZE.y, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)  # Fundo transparente.
	image.fill_rect(Rect2i(Vector2i.ZERO, GRABBER_SIZE), ring)  # Anel.
	image.fill_rect(Rect2i(Vector2i(2, 2), GRABBER_SIZE - Vector2i(4, 4)), fill)  # Miolo.
	for corner: Vector2i in [Vector2i(0, 0), Vector2i(GRABBER_SIZE.x - 2, 0),  # Os quatro cantos.
			Vector2i(0, GRABBER_SIZE.y - 2), Vector2i(GRABBER_SIZE.x - 2, GRABBER_SIZE.y - 2)]:
		image.fill_rect(Rect2i(corner, Vector2i(2, 2)), Color.TRANSPARENT)  # Corta o canto.
	return ImageTexture.create_from_image(image)  # Cria a textura.


# --- Campo de texto (LineEdit) e barra de progresso ---

## Define os campos de texto e a barra de progresso.
func _build_inputs() -> void:
	var pad_x: int = Palette.UNIT * 2  # Margem horizontal.
	var pad_y: int = Palette.UNIT  # Margem vertical.
	# Normal.
	set_stylebox(&"normal", &"LineEdit", _box(Palette.PANEL, Palette.BORDER, Vector2i.ZERO, pad_x, pad_y))
	# Foco (borda de destaque).
	set_stylebox(&"focus", &"LineEdit", _box(Palette.PANEL, Palette.ACCENT, Vector2i.ZERO, pad_x, pad_y))
	# Somente leitura.
	set_stylebox(&"read_only", &"LineEdit", _box(Palette.PANEL, Palette.DISABLED, Vector2i.ZERO, pad_x, pad_y))
	set_color(&"font_color", &"LineEdit", Palette.TEXT)  # Cor do texto.
	set_color(&"font_selected_color", &"LineEdit", Palette.TEXT)  # Cor do texto selecionado.
	set_color(&"font_uneditable_color", &"LineEdit", Palette.DISABLED_TEXT)  # Cor do texto não editável.
	set_color(&"font_placeholder_color", &"LineEdit", Palette.TEXT_DIM)  # Cor do texto de ajuda.
	set_color(&"caret_color", &"LineEdit", Palette.ACCENT)  # Cor do cursor.
	set_color(&"selection_color", &"LineEdit", Palette.with_alpha(Palette.ACCENT, 0.35))  # Cor da seleção.
	set_font_size(&"font_size", &"LineEdit", Palette.FONT_BODY)  # Tamanho do texto.

	# Barra: trilho em PANEL_RAISED e preenchimento em ACCENT (a margem de 4 px deixa a moldura aparecer).
	set_stylebox(&"background", &"ProgressBar",  # Barra: trilho em painel elevado.
			_box(Palette.PANEL_RAISED, Palette.BORDER, Vector2i.ZERO, Palette.BORDER_THICK, Palette.BORDER_THICK))
	var bar_fill: PixelBox = PixelBox.new()  # Preenchimento da barra.
	bar_fill.fill_color = Palette.ACCENT  # Cor de destaque.
	bar_fill.border_width = 0  # Sem borda.
	bar_fill.outline_width = 0  # Sem contorno.
	bar_fill.corner_cut = 0  # Sem canto cortado.
	set_stylebox(&"fill", &"ProgressBar", bar_fill)  # Aplica.
	set_color(&"font_color", &"ProgressBar", Palette.TEXT)  # Cor do texto.
	set_font_size(&"font_size", &"ProgressBar", Palette.FONT_SMALL)  # Tamanho do texto.


# --- Separador ---

## Define a linha separadora fina.
func _build_separator() -> void:
	var line: PixelBox = PixelBox.new()  # Linha.
	line.fill_color = Palette.BORDER  # Cor da borda.
	line.border_width = 0  # Sem borda.
	line.outline_width = 0  # Sem contorno.
	line.corner_cut = 0  # Sem canto cortado.
	line.content_margin_top = Palette.BORDER_THIN / 2.0  # Margem de cima.
	line.content_margin_bottom = Palette.BORDER_THIN / 2.0  # Margem de baixo.
	set_stylebox(&"separator", &"HSeparator", line)  # Aplica.
	set_constant(&"separation", &"HSeparator", Palette.UNIT)  # Espaço em volta.


## Cria uma caixa. `fill`/`border` em cores da paleta; margens internas em px.
## Cria uma caixa pixelada com as cores, a sombra e as margens internas informadas.
func _box(fill: Color, border: Color, shadow: Vector2i, pad_x: int, pad_y: int) -> PixelBox:
	var box: PixelBox = PixelBox.new()  # Caixa nova.
	box.fill_color = fill  # Preenchimento.
	box.border_color = border  # Borda.
	box.shadow_offset = shadow  # Sombra.
	box.content_margin_left = pad_x  # Margem esquerda.
	box.content_margin_right = pad_x  # Margem direita.
	box.content_margin_top = pad_y  # Margem de cima.
	box.content_margin_bottom = pad_y  # Margem de baixo.
	return box  # Devolve a caixa.
