class_name MobileDraw
extends RefCounted
## Desenho dos controles de toque com os assets gerados (`res://assets/gerados/`). Usado pelo
## `MobileControls`, pelo editor de HUD e pelas ilustrações do tutorial: tudo parece igual.

const DIR: String = "res://assets/gerados/"
const COLOR_SELECTED: Color = Color("#fed232")  # Contorno do controle selecionado no editor.

static var _cache: Dictionary = {}


## Textura do pacote de assets gerados (cache). `name` sem pasta, ex.: "ic_sword.png".
static func tex(name: String) -> Texture2D:
	if not _cache.has(name):
		_cache[name] = load(DIR + name) as Texture2D
	return _cache[name]


## Ícone do papel (`MobileLayout.*`).
static func icon_for(id: StringName) -> String:
	match id:
		MobileLayout.DASH: return "ic_dash.png"
		MobileLayout.WEAPON: return "ic_swap.png"
		MobileLayout.COMMAND: return "ic_command.png"
		MobileLayout.PAUSE: return "ic_pause.png"
		MobileLayout.INTERACT: return "ic_interact.png"
	return ""


## Botão redondo: base translúcida + ícone. `active` realça o botão (modo comando aberto, arma atual...).
static func button(ci: CanvasItem, center: Vector2, radius: float, id: StringName, pressed: bool = false, active: bool = false) -> void:
	var rect: Rect2 = Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
	ci.draw_texture_rect(tex("btn_base_pressed.png" if pressed else "btn_base.png"), rect, false)
	if active:
		ci.draw_arc(center, radius + 3.0, 0.0, TAU, 40, Color(COLOR_SELECTED, 0.9), 3.0, true)
	var icon: String = icon_for(id)
	if icon != "":
		var inner: Rect2 = Rect2(center - Vector2(radius, radius) * 0.9, Vector2(radius, radius) * 1.8)
		ci.draw_texture_rect(tex(icon), inner, false)


## Joystick: base grande e bolinha na posição `thumb` (já em px, relativa ao centro).
## `icon` (opcional) é desenhado sobre a bolinha: no joystick direito mostra a arma atual (tiro ou espada).
static func stick(ci: CanvasItem, center: Vector2, radius: float, thumb: Vector2 = Vector2.ZERO, pressed: bool = false, icon: String = "") -> void:
	ci.draw_texture_rect(tex("stick_base.png"), Rect2(center - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false)
	var thumb_r: float = radius * 0.42
	var thumb_center: Vector2 = center + thumb
	ci.draw_texture_rect(tex("stick_thumb_pressed.png" if pressed else "stick_thumb.png"),
			Rect2(thumb_center - Vector2(thumb_r, thumb_r), Vector2(thumb_r, thumb_r) * 2.0), false)
	if icon != "":
		ci.draw_texture_rect(tex(icon), Rect2(thumb_center - Vector2(thumb_r, thumb_r), Vector2(thumb_r, thumb_r) * 2.0), false)


## Intensidade (0 a 1) do pisca do destaque no instante `phase` (s): ~1,6 piscadas por segundo.
static func pulse(phase: float) -> float:
	return 0.5 + 0.5 * sin(phase * TAU * 1.6)


## Anel dourado que pisca em volta do controle da vez (tutorial). `phase` em segundos.
static func glow(ci: CanvasItem, center: Vector2, radius: float, phase: float) -> void:
	var amount: float = pulse(phase)
	var frame_name: String = "glow_1.png" if amount > 0.5 else "glow_0.png"
	var r: float = radius * (1.18 + 0.1 * amount)
	var rect: Rect2 = Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
	ci.draw_texture_rect(tex(frame_name), rect, false, Color(1.0, 1.0, 1.0, 0.45 + 0.55 * amount))


## Moldura retangular (quadro de comandos, barras de status no editor).
static func frame(ci: CanvasItem, rect: Rect2, label: String = "", selected: bool = false) -> void:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = tex("board_frame.png")
	style.set_texture_margin_all(12.0)
	ci.draw_style_box(style, rect)
	if selected:
		ci.draw_rect(rect.grow(2.0), COLOR_SELECTED, false, 2.0)
	if label != "":
		var font: Font = ThemeDB.fallback_font
		ci.draw_string(font, rect.position + Vector2(0.0, rect.size.y * 0.5 + 6.0), label,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, 18, Color("#ebddba"))
