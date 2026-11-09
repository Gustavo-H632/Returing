class_name CooldownSlot
extends Control
## Slot de uma habilidade na HUD de cooldown: amuleto, varredura radial da recarga, tempo restante,
## anel de duração (efeito ativo) e pulso dourado ao ficar pronta. Sem habilidade, vira um slot vazio.
## Só mostra o que recebe em `update_cooldown`: quem manda os valores é a HUD (sinais do componente).

## Tamanho do slot (maior no celular, para o toque ser confortável).
const SLOT_SIZE: float = 56.0
const TOUCH_SLOT_SIZE: float = 64.0  # Tamanho do slot no celular (maior para o toque).
const COLOR_SWEEP: Color = Color(0.82, 0.85, 0.95, 0.34)  # Cor da varredura radial.
const COLOR_SWEEP_EDGE: Color = Color(1.0, 1.0, 1.0, 0.7)  # Cor da linha do ponteiro.
const COLOR_COOLING_TINT: Color = Color(0.0, 0.0, 0.0, 0.3)  # Cor que escurece o amuleto em recarga.
const COLOR_EMPTY: Color = Color(0.72, 0.7, 0.62, 0.28)  # Cor do slot vazio.
const RING_WIDTH: float = 3.0  # Espessura do anel.
const RING_GAP: float = 4.0  # Folga do anel de duração.
const SWEEP_POINTS: int = 48  # Pontos da varredura.
const PULSE_TIME: float = 0.55  # Duração do pulso.
const PULSE_GROWTH: float = 0.45  # Crescimento do pulso.
const FONT_SIZE: int = 15  # Tamanho da fonte.
const OUTLINE_SIZE: int = 4  # Espessura do contorno do texto.
## Abaixo disto (s) o tempo mostra uma casa decimal.
const DECIMAL_BELOW: float = 10.0

## Clique (ou toque) no amuleto: a HUD repassa para quem abre o menu de build.
signal pressed(ability: AbilityData)

var ability: AbilityData = null  # Habilidade do slot (null = vazio).

var _amulet: AmuletIcon = null  # Amuleto desenhado.
var _overlay: Control = null  # Camada que desenha a recarga.
var _label: Label = null  # Texto do tempo restante.
var _remaining: float = 0.0  # Segundos restantes.
var _total: float = 1.0  # Segundos totais.
var _cooling: bool = false  # True durante a recarga.
var _pulse: float = 0.0  # Intensidade do pulso.
var _pulse_tween: Tween = null  # Animação do pulso.


## Define o tamanho mínimo (maior no celular) e ignora cliques por padrão.
func _init() -> void:
	var side: float = TOUCH_SLOT_SIZE if Platform.is_mobile else SLOT_SIZE  # Tamanho conforme a plataforma.
	custom_minimum_size = Vector2(side, side)  # Tamanho mínimo do slot.
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Só slots com habilidade recebem clique.


## Monta os filhos por código: amuleto, camada de recarga e texto do tempo.
func _ready() -> void:
	_amulet = AmuletIcon.new()  # Amuleto.
	add_child(_amulet)
	_amulet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay = Control.new()  # Camada por cima do amuleto.
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.draw.connect(_draw_overlay)  # A camada desenha a recarga.
	_label = Label.new()  # Texto do tempo.
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", FONT_SIZE)
	_label.add_theme_color_override(&"font_color", UiPalette.TEXT)
	_label.add_theme_color_override(&"font_outline_color", UiPalette.OUTLINE)
	_label.add_theme_constant_override(&"outline_size", OUTLINE_SIZE)
	add_child(_label)
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_amulet.set_ability(ability)  # Mostra a habilidade.
	_update_clickable()  # Atualiza se o slot é clicável.


## Ao sair da cena cancela o pulso.
func _exit_tree() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()


## Define a habilidade do slot (null = slot vazio).
## Define a habilidade do slot (null = vazio) e zera o estado de recarga.
func set_ability(data: AbilityData) -> void:
	ability = data  # Guarda a habilidade.
	_remaining = 0.0  # Zera a recarga.
	_cooling = false  # Não está em recarga.
	_update_clickable()  # Atualiza o clique.
	if _amulet != null:  # Só se os filhos já existem.
		_amulet.set_ability(data)  # Troca o amuleto.
		_label.text = ""  # Limpa o texto.
		_overlay.queue_redraw()  # Redesenha.


## Só slot com habilidade recebe clique (STOP: o clique é consumido aqui e não chega ao jogo).
func _update_clickable() -> void:  # Slot com habilidade recebe clique (STOP consome o clique).
	# Cursor de mãozinha no slot com habilidade.
	mouse_filter = Control.MOUSE_FILTER_STOP if ability != null else Control.MOUSE_FILTER_IGNORE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if ability != null else Control.CURSOR_ARROW


## Clique esquerdo no amuleto: avisa a HUD para abrir o menu de build.
func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton  # Clique de mouse.
	# Só com habilidade e botão esquerdo.
	if ability != null and click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		accept_event()  # Consome o clique.
		pressed.emit(ability)  # Avisa.


## Estado atual da recarga (segundos restantes e total). Com `animate`, o fim da recarga pulsa.
## Atualiza a recarga mostrada. Com `animate`, o fim da recarga dispara o pulso dourado.
func update_cooldown(remaining: float, total: float, animate: bool = true) -> void:
	if ability == null:  # Slot vazio: nada a fazer.
		return
	var was_cooling: bool = _cooling  # Estava em recarga antes?
	_remaining = remaining  # Segundos restantes.
	_total = maxf(total, 0.01)  # Total (nunca zero).
	_cooling = remaining > 0.0  # Está em recarga agora?
	_label.text = _format_time(remaining) if _cooling else ""  # Texto do tempo (vazio quando pronta).
	_overlay.queue_redraw()  # Redesenha a recarga.
	if animate and was_cooling and not _cooling:  # Acabou a recarga: pulso.
		_start_pulse()


## True enquanto o efeito da habilidade ainda está ativo (a recarga conta desde a ativação).
func is_effect_active() -> bool:
	## Diz se o efeito ainda está ativo: a recarga conta desde a ativação, então o efeito dura enquanto o tempo passado é menor que a duração.
	return ability != null and _cooling and ability.duration > 0.0 and (_total - _remaining) < ability.duration


## Texto do tempo: inteiro a partir de 10 s e uma casa decimal abaixo disso.
## Formata o tempo: inteiro (arredondado para cima) a partir de 10 s e uma casa decimal abaixo disso.
static func _format_time(seconds: float) -> String:
	if seconds >= DECIMAL_BELOW:  # 10 s ou mais.
		return "%d" % ceili(seconds)
	return "%.1f" % maxf(seconds, 0.0)  # Menos de 10 s.


## Começa o pulso dourado de "habilidade pronta".
func _start_pulse() -> void:
	if _pulse_tween != null and _pulse_tween.is_valid():  # Cancela o pulso anterior.
		_pulse_tween.kill()
	_pulse_tween = UiTween.create_pausable(self)  # o pulso congela junto com o jogo pausado
	_pulse_tween.tween_method(_set_pulse, 1.0, 0.0, PULSE_TIME)  # Anima de 1 a 0.


## Passo da animação do pulso.
func _set_pulse(value: float) -> void:
	_pulse = value  # Guarda o valor.
	_overlay.queue_redraw()  # Redesenha.


# --- Desenho ---

## Pontos de um hexágono (mesmo formato do amuleto), começando no topo.
func _hex(center: Vector2, radius: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()  # Lista de pontos.
	for i: int in AmuletIcon.HEX_SIDES:  # Seis vértices.
		# Cada vértice a 60° do anterior.
		points.append(center + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / float(AmuletIcon.HEX_SIDES)) * radius)
	return points


## Raio do hexágono do amuleto (menor para lendárias, que têm adorno).
func _hex_radius() -> float:
	var legendary: bool = ability != null and ability.rarity == AbilityData.Rarity.LENDARIA  # Lendária?
	# Metade do menor lado vezes a razão do tipo.
	return minf(size.x, size.y) * 0.5 * (AmuletIcon.RADIUS_LEGENDARY if legendary else AmuletIcon.RADIUS_NORMAL)


## Desenha a camada da recarga: contorno do slot vazio, escurecimento, varredura radial, anel de duração e pulso.
func _draw_overlay() -> void:
	var center: Vector2 = size * 0.5  # Centro do slot.
	var radius: float = _hex_radius()  # Raio do hexágono.
	if ability == null:  # slot vazio: contorno discreto
		var outline: PackedVector2Array = _hex(center, radius)  # Pontos do hexágono.
		outline.append(outline[0])  # Fecha o contorno.
		_overlay.draw_polyline(outline, COLOR_EMPTY, 2.0, true)  # Desenha o contorno.
		return
	if _cooling:  # Em recarga.
		var hex: PackedVector2Array = _hex(center, radius)  # Hexágono do amuleto.
		_overlay.draw_colored_polygon(hex, COLOR_COOLING_TINT)  # Escurece o amuleto.
		var fraction: float = clampf(_remaining / _total, 0.0, 1.0)  # Fração da recarga que falta.
		# Recorta a varredura no formato do hexágono.
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(_sweep_polygon(center, radius * 1.2, fraction), hex):
			_overlay.draw_colored_polygon(piece, COLOR_SWEEP)  # Desenha cada pedaço.
		# linha do ponteiro: marca até onde a recarga já andou
		var edge_angle: float = -PI * 0.5 + (1.0 - fraction) * TAU  # Ângulo do ponteiro.
		# Desenha o ponteiro.
		_overlay.draw_line(center, center + Vector2.from_angle(edge_angle) * radius, COLOR_SWEEP_EDGE, 2.0, true)
		if is_effect_active():  # anel de duração: encolhe até o efeito acabar
			var left: float = 1.0 - (_total - _remaining) / ability.duration  # Fração do efeito que falta.
			# Desenha o anel.
			_overlay.draw_arc(center, radius + RING_GAP, -PI * 0.5, -PI * 0.5 + TAU * clampf(left, 0.0, 1.0),
					SWEEP_POINTS, UiPalette.GOLD, RING_WIDTH, true)
	if _pulse > 0.0:  # pulso: o contorno dourado se expande e some
		# Contorno ampliado.
		var ring: PackedVector2Array = _hex(center, radius * (1.0 + PULSE_GROWTH * (1.0 - _pulse)))
		ring.append(ring[0])  # Fecha o contorno.
		var color: Color = UiPalette.GOLD_BRIGHT  # Cor dourada.
		color.a = _pulse  # Some com o pulso.
		_overlay.draw_polyline(ring, color, RING_WIDTH, true)  # Desenha o contorno.


## Setor que cobre a fração `fraction` da volta, no sentido horário, terminando no topo.
func _sweep_polygon(center: Vector2, radius: float, fraction: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array([center])  # Começa no centro.
	var start: float = -PI * 0.5 + (1.0 - fraction) * TAU  # Ângulo inicial.
	var steps: int = maxi(2, int(ceilf(float(SWEEP_POINTS) * fraction)))  # Quantidade de passos (mínimo 2).
	for i: int in range(steps + 1):  # Um ponto por passo.
		# Ponto no arco.
		points.append(center + Vector2.from_angle(start + TAU * fraction * float(i) / float(steps)) * radius)
	return points
