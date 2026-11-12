class_name Palette
extends RefCounted
## Paleta "terminal de criptografia, anos 1940". ÚNICA fonte de verdade das cores dos menus:
## nenhuma cena ou script deve ter cor escrita à mão. Sem branco nem preto puros.

# --- Superfícies ---
## Fundo da tela.
const BG: Color = Color("#14100C")
## Caixas e painéis.
const PANEL: Color = Color("#221A13")
## Elementos elevados (botões, trilhos).
const PANEL_RAISED: Color = Color("#2E2319")
## Bordas.
const BORDER: Color = Color("#5A4326")

# --- Texto ---
const TEXT: Color = Color("#EBDDBA")  # Cor do texto.
const TEXT_DIM: Color = Color("#A8957A")  # Texto esmaecido.

# --- Interação (um único acento) ---
## Hover, foco, slider.
const ACCENT: Color = Color("#F2A93B")
const ACCENT_PRESSED: Color = Color("#C9791E")  # Destaque quando apertado.
## Só para ações destrutivas (sair, apagar). Ajustado de #C8553D para #E06A50: o texto de DANGER
## aparece sobre PANEL_RAISED (hover do botão) e lá o #DB674E dava 4,42:1; o #E06A50 dá 4,63:1.
const DANGER: Color = Color("#E06A50")

# --- Desabilitado ---
## Bordas e preenchimentos desabilitados.
const DISABLED: Color = Color("#5B5043")
## Texto desabilitado (o #5B5043 só chega a 2,18:1 sobre o painel).
const DISABLED_TEXT: Color = Color("#8A7B64")

# --- Medidas (tudo em múltiplos de 8 px, exceto bordas) ---
const UNIT: int = 8  # Unidade de espaçamento (8 px).
const BORDER_THIN: int = 2  # Borda fina.
const BORDER_THICK: int = 4  # Borda grossa.
## Deslocamento da sombra dura de painéis.
const SHADOW_PANEL: Vector2i = Vector2i(4, 4)

# --- Fontes: tamanhos são múltiplos inteiros de FONT_BASE para preservar o pixel ---
const FONT_BASE: int = 16  # Tamanho base da fonte; os outros são múltiplos inteiros dele.
const FONT_HINT: int = FONT_BASE  # Fonte de dica.
const FONT_SMALL: int = FONT_BASE  # Fonte pequena.
const FONT_BODY: int = FONT_BASE * 2  # Fonte do corpo.
const FONT_TITLE: int = FONT_BASE * 3  # Fonte do título.

# --- Animação (segundos) ---
## Hover/foco dos botões (entre 0,10 e 0,15).
const HOVER_TIME: float = 0.12
const PRESS_TIME: float = 0.08  # Duração do clique.
## Fade de abertura/fechamento de menus (máximo 0,2).
const FADE_TIME: float = 0.15

# --- Efeitos de fundo (opacidade máxima 8%) ---
const SCANLINE_ALPHA: float = 0.05  # Opacidade das linhas de varredura.

## Opacidade do escurecimento (dim) atrás de menus que abrem sobre o jogo.
const DIM_ALPHA: float = 0.8

const THEME_PATH: String = "res://themes/main_theme.tres"  # Caminho do tema dos menus.


## Carrega o tema único dos menus (aplicar só na raiz de cada menu).
## Carrega o tema único dos menus (aplicar só na raiz de cada menu).
static func load_theme() -> Theme:
	return load(THEME_PATH) as Theme  # Carrega o arquivo do tema.


## A mesma cor com outra opacidade (para fundos translúcidos).
## Devolve a mesma cor com outra opacidade (para fundos translúcidos).
static func with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)  # Mesmos canais, novo alfa.


## Fundo escurecido que fica atrás de menus sobre o jogo (cor BG, nunca preto puro).
## Fundo escurecido que fica atrás de menus sobre o jogo (cor de fundo, nunca preto puro).
static func dim_color() -> Color:
	return with_alpha(BG, DIM_ALPHA)  # Cor de fundo com a opacidade do escurecimento.


## Razão de contraste WCAG entre duas cores opacas.
## Razão de contraste WCAG entre duas cores opacas (usada para conferir a legibilidade).
static func contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)  # Luminância da primeira.
	var lb: float = _luminance(b)  # Luminância da segunda.
	# Razão: mais clara + 0,05 sobre a mais escura + 0,05.
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Luminância relativa de uma cor (fórmula WCAG).
static func _luminance(c: Color) -> float:
	# Soma ponderada dos canais lineares.
	return 0.2126 * _linear(c.r) + 0.7152 * _linear(c.g) + 0.0722 * _linear(c.b)


## Converte um canal sRGB em linear (parte da fórmula WCAG).
static func _linear(v: float) -> float:
	# Trecho linear ou curva de potência.
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
