class_name MobileGuideIcon
extends Control
## Ilustração do tutorial no celular: no lugar das teclas e do mouse, mostra o CONTROLE da vez, que pisca ou
## se anima (joystick com a bolinha se movendo, botão piscando, celular inclinando). Usa os mesmos assets e o
## mesmo desenho dos controles reais (`MobileDraw`).
##
## Tipos (`kind`): `m_move`, `m_dash`, `m_shoot`, `m_weapon`, `m_sword`, `m_command`, `m_tilt`.
## Para os tipos de quatro direções (`m_move`, `m_tilt`) o painel registra uma "tecla" por direção em
## `dir_keys` (com `pressed` e `checked`); os demais usam o próprio ícone (`pressed`/`checked`).

const SIZE_BOX: Vector2 = Vector2(230.0, 176.0)  # Tamanho do ícone.
const CYCLE_TIME: float = 0.85  # Segundos em cada direção na animação.
const COLOR_OK: Color = Color("#43e07a")  # Check verde (mesma cor do tutorial de teclado).
const ARROW_NAMES: Array[String] = ["up", "right", "down", "left"]
const MOVE_ACTIONS: Array[StringName] = [&"move_up", &"move_right", &"move_down", &"move_left"]
const TILT_ACTIONS: Array[StringName] = [&"cmd_up", &"cmd_right", &"cmd_down", &"cmd_left"]

var kind: StringName = &""  # Tipo do ícone.
var pressed: bool = false  # Realce de "apertado" (usado pelos tipos de um controle só).
var checked: bool = false  # Check verde (idem).
var dir_keys: Dictionary = {}  # ação -> GuideKey (tipos de quatro direções).

var _clock: float = 0.0  # Relógio das animações.


## Tecla invisível que guarda `pressed`/`checked` de uma direção (o painel do tutorial escreve nela).
class GuideKey extends Control:
	var pressed: bool = false
	var checked: bool = false

	func _init() -> void:
		custom_minimum_size = Vector2.ZERO
		mouse_filter = Control.MOUSE_FILTER_IGNORE


func _init(new_kind: StringName = &"") -> void:
	kind = new_kind
	custom_minimum_size = SIZE_BOX
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if kind == &"m_move" or kind == &"m_tilt":
		var actions: Array[StringName] = MOVE_ACTIONS if kind == &"m_move" else TILT_ACTIONS
		for action: StringName in actions:
			var key: GuideKey = GuideKey.new()
			dir_keys[action] = key
			add_child(key)


func _process(delta: float) -> void:
	_clock += delta
	queue_redraw()


## Índice (0 a 3 = cima, direita, baixo, esquerda) da direção que a animação mostra agora.
func current_direction() -> int:
	return int(_clock / CYCLE_TIME) % 4


func _draw() -> void:
	var center: Vector2 = SIZE_BOX * 0.5
	match kind:
		&"m_move":
			_draw_stick_demo(center, true)
		&"m_shoot":
			_draw_stick_demo(center, false)
		&"m_dash":
			_draw_button(center, MobileLayout.DASH)
		&"m_weapon":
			_draw_button(center, MobileLayout.WEAPON)
		&"m_sword":
			_draw_stick_demo(center, false)
		&"m_command":
			_draw_button(center, MobileLayout.COMMAND)
		&"m_tilt":
			_draw_phone(center)


## Botão da vez com o anel dourado pulsando.
func _draw_button(center: Vector2, id: StringName) -> void:
	var radius: float = 54.0
	MobileDraw.glow(self, center, radius, _clock)
	MobileDraw.button(self, center, radius, id, pressed)
	if checked:
		_draw_check(center + Vector2(radius * 0.75, -radius * 0.75), 14.0)


## Joystick com a bolinha andando para cima, direita, baixo e esquerda; as setas em volta mostram o que já foi feito.
func _draw_stick_demo(center: Vector2, with_checks: bool) -> void:
	var radius: float = 52.0
	var phase: float = fposmod(_clock, CYCLE_TIME) / CYCLE_TIME  # 0..1 dentro da direção atual
	var dir_index: int = current_direction()
	var vectors: Array[Vector2] = [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	var reach: float = sin(clampf(phase * 1.4, 0.0, 1.0) * PI * 0.5)  # sobe rápido e fica
	MobileDraw.glow(self, center, radius, _clock)
	MobileDraw.stick(self, center, radius, vectors[dir_index] * radius * 0.62 * reach, false)
	if not with_checks:
		# Tiro: pequena mira que acompanha o sentido da bolinha.
		var tip: Vector2 = center + vectors[dir_index] * radius * 1.25
		draw_texture_rect(MobileDraw.tex("ic_shot.png"), Rect2(tip - Vector2(14.0, 14.0), Vector2(28.0, 28.0)), false)
		return
	_draw_direction_marks(center, radius + 24.0, MOVE_ACTIONS, dir_index)


## Celular inclinando para cima, direita, baixo e esquerda (e voltando ao neutro entre eles).
func _draw_phone(center: Vector2) -> void:
	var total: float = CYCLE_TIME * 2.0
	var slot: int = int(_clock / CYCLE_TIME) % 8  # pares: pose inclinada; ímpares: neutro
	var dir_index: int = (slot / 2) % 4
	var tilted: bool = slot % 2 == 0
	var pose: String = ARROW_NAMES[dir_index] if tilted else "neutral"
	var texture: Texture2D = MobileDraw.tex("phone_%s.png" % pose)
	var rect: Rect2 = Rect2(center - Vector2(72.0, 48.0), Vector2(144.0, 96.0))
	draw_texture_rect(texture, rect, false)
	_draw_direction_marks(center, 80.0, TILT_ACTIONS, dir_index if tilted else -1)
	if total <= 0.0:
		return


## Quatro setas em volta do ícone: acesa a da vez, e um check verde nas direções já feitas.
func _draw_direction_marks(center: Vector2, distance: float, actions: Array[StringName], lit_index: int) -> void:
	var offsets: Array[Vector2] = [Vector2(0.0, -distance), Vector2(distance, 0.0), Vector2(0.0, distance), Vector2(-distance, 0.0)]
	for i: int in 4:
		var key: GuideKey = dir_keys.get(actions[i]) as GuideKey
		var done: bool = key != null and key.checked
		var held: bool = key != null and key.pressed
		var at: Vector2 = center + offsets[i]
		var tile: String = "_lit" if (i == lit_index or held) else ""
		var texture: Texture2D = MobileDraw.tex("arrow_%s%s.png" % [ARROW_NAMES[i], tile])
		draw_texture_rect(texture, Rect2(at - Vector2(13.0, 13.0), Vector2(26.0, 26.0)), false)
		if done:
			_draw_check(at + Vector2(14.0, -14.0), 11.0)


## Check verde em círculo.
func _draw_check(at: Vector2, radius: float) -> void:
	draw_circle(at, radius, Color("#17492b"))
	draw_arc(at, radius, 0.0, TAU, 20, COLOR_OK, 2.0, true)
	draw_polyline(PackedVector2Array([at + Vector2(-radius * 0.45, 0.0), at + Vector2(-radius * 0.1, radius * 0.4), at + Vector2(radius * 0.5, -radius * 0.4)]),
			COLOR_OK, 2.5, true)
