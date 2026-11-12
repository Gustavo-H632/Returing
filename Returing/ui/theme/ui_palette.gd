class_name UiPalette
extends RefCounted
## Cores e medidas compartilhadas das HUDs e menus (linguagem dourada). Uma única fonte da verdade.

const GOLD: Color = Color("#e8c15a")  # Dourado principal.
const GOLD_BRIGHT: Color = Color("#fee286")  # Dourado brilhante.
const TEXT: Color = Color("#f6f1df")  # Cor do texto.
const TEXT_MUTED: Color = Color("#b4b0a2")  # Texto esmaecido.
const TEXT_DISABLED: Color = Color("#8a8a8a")  # Texto desabilitado.
const LIFE: Color = Color("#f62626")  # Cor da vida.
const XP: Color = Color("#86befe")  # Cor do XP.
const DANGER: Color = Color("#ff9a3c")  # Cor de perigo.
const DANGER_BG: Color = Color(0.35, 0.16, 0.0, 0.55)  # Fundo do perigo.
const PANEL_BG: Color = Color(0.03, 0.03, 0.05, 0.86)  # Fundo dos painéis.
const DIM: Color = Color(0.0, 0.0, 0.0, 0.62)  # Película escura.
const OUTLINE: Color = Color(0.0, 0.0, 0.0, 0.9)  # Contorno do texto.

## Unidade de espaçamento: margens, separações e paddings são múltiplos dela.
const UNIT: int = 8
## Tamanhos de fonte da hierarquia (título, corpo, dica).
const FONT_TITLE: int = 34
const FONT_BODY: int = 16  # Tamanho de fonte do corpo.
const FONT_HINT: int = 12  # Tamanho de fonte da dica.
## Margem de segurança (px) das HUDs em relação às bordas da tela.
const SAFE_MARGIN: int = 16
## Duração (s) das animações curtas (fade, slide, brilho).
const ANIM_TIME: float = 0.2

const THEME_PATH: String = "res://ui/theme/returing_theme.tres"  # Caminho do tema compartilhado.


## Carrega o tema compartilhado (aplicar só na raiz de cada HUD ou menu).
## Carrega o tema compartilhado (aplicar só na raiz de cada HUD ou menu).
static func load_theme() -> Theme:
	return load(THEME_PATH) as Theme  # Carrega o arquivo do tema.


## Razão de contraste WCAG entre duas cores opacas.
## Calcula a razão de contraste WCAG entre duas cores opacas (usada para conferir legibilidade).
static func contrast(a: Color, b: Color) -> float:
	var la: float = _luminance(a)  # Luminância da primeira.
	var lb: float = _luminance(b)  # Luminância da segunda.
	# Razão: a mais clara mais 0,05 sobre a mais escura mais 0,05.
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


## Luminância relativa de uma cor (fórmula WCAG).
static func _luminance(c: Color) -> float:
	# Soma ponderada dos canais lineares.
	return 0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b)


## Converte um canal sRGB para linear (parte da fórmula WCAG).
static func _lin(v: float) -> float:
	# Trecho linear ou curva de potência.
	return v / 12.92 if v <= 0.03928 else pow((v + 0.055) / 1.055, 2.4)
