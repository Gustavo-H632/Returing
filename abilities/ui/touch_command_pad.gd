class_name TouchCommandPad
extends Control
## Controles de toque do modo comando (só no celular): um botão "CMD" que abre/fecha o modo e,
## com o modo aberto, quatro botões de seta. Fica na faixa do topo da tela, onde o `MobileControls`
## não inicia analógicos (as barras de vida e o botão de pausa ficam nos cantos).
## Trata o toque por conta própria porque o `MobileControls` consome os cliques emulados do toque.

## Toque no amuleto de uma habilidade da faixa compacta (abre o menu de build).
signal build_requested(ability: AbilityData)

const COLOR_FILL: Color = Color(0.62, 0.62, 0.62, 0.5)  # Cor dos botões (cinza translúcido).
const COLOR_FILL_ACTIVE: Color = Color(0.91, 0.76, 0.35, 0.65)  # Cor do botão CMD com o modo aberto.
const COLOR_RING: Color = Color(0.85, 0.85, 0.85, 0.5)  # Cor do contorno.
const COLOR_ICON: Color = Color(1.0, 1.0, 1.0, 0.9)  # Cor dos ícones.
const BUTTON_RADIUS: float = 24.0  # Raio dos botões.
const BUTTON_SPACING: float = 62.0  # Distância entre os centros dos botões.
## Centro vertical da fileira: abaixo da barra de XP e dentro da faixa sem analógicos do topo.
const ROW_Y: float = 52.0
## Folga na área de toque.
const HIT_SLACK: float = 1.2
const FONT_SIZE: int = 12  # Tamanho da fonte do texto CMD.
## Ordem dos botões de seta na fileira.
const ARROWS: Array = [
	AbilityData.Dir.UP, AbilityData.Dir.DOWN, AbilityData.Dir.LEFT, AbilityData.Dir.RIGHT,
]

var _abilities: AbilityComponent = null  # Componente de habilidades.
var _hud: CommandHud = null  # HUD de comando (fornece as áreas dos slots).


## Cobre a tela inteira sem capturar cliques; no PC (sem `--mobile`) fica escondido.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # Não bloqueia cliques do jogo.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # Ocupa a tela toda.
	if not Platform.is_mobile:  # Fora do celular não aparece nem escuta toques.
		visible = false
		set_process_input(false)


## Liga o painel ao componente de habilidades e redesenha quando o modo ou as habilidades mudam.
func setup(abilities: AbilityComponent, hud: CommandHud = null) -> void:
	_abilities = abilities  # Guarda o componente.
	_hud = hud  # Guarda a HUD.
	# Redesenha quando o modo comando abre ou fecha.
	CombatUtils.connect_once(abilities.command_mode_changed, _on_state_changed)
	# Redesenha quando as habilidades mudam.
	CombatUtils.connect_once(abilities.abilities_changed, queue_redraw)
	get_viewport().size_changed.connect(queue_redraw)  # Redesenha quando a janela muda de tamanho.
	queue_redraw()


## Ao sair da cena desliga os sinais do componente.
func _exit_tree() -> void:
	if is_instance_valid(_abilities):
		CombatUtils.disconnect_if_connected(_abilities.command_mode_changed, _on_state_changed)
		CombatUtils.disconnect_if_connected(_abilities.abilities_changed, queue_redraw)


## O modo comando abriu ou fechou: redesenha os botões.
func _on_state_changed(_active: bool) -> void:
	queue_redraw()


## Centro do botão `index` (0 = CMD; 1 a 4 = setas), com a fileira centralizada na parte de cima da tela.
## Centro do botão `index` (0 = CMD; 1 a 4 = setas), com a fileira centralizada na tela.
func _button_center(index: int) -> Vector2:
	var view: Vector2 = get_viewport().get_visible_rect().size  # Tamanho visível da tela.
	# Centro do primeiro botão (a fileira de 5 fica centralizada).
	var first: float = view.x * 0.5 - BUTTON_SPACING * 2.0
	return Vector2(first + BUTTON_SPACING * float(index), ROW_Y)  # Posição do botão.


## Diz se o painel deve aparecer: só no celular e com pelo menos uma habilidade.
func _is_shown() -> bool:
	return Platform.is_mobile and _abilities != null and not _abilities.abilities.is_empty()


## Recebe os toques (ou o clique do mouse na simulação) e consome o que cair num botão.
func _input(event: InputEvent) -> void:
	if not _is_shown():  # Escondido: ignora.
		return
	var pos: Vector2 = Vector2.ZERO  # Posição do toque.
	var touch: InputEventScreenTouch = event as InputEventScreenTouch  # Evento de toque.
	var click: InputEventMouseButton = event as InputEventMouseButton  # Evento de clique.
	if touch != null and touch.pressed:  # Toque na tela: pega a posição.
		pos = touch.position
	elif click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT \
			and Platform.mouse_as_finger and click.device != InputEvent.DEVICE_ID_EMULATION:
		pos = click.position  # PC com `--mobile`: o mouse faz o papel do dedo
	else:
		return  # Qualquer outro evento: ignora.
	if _handle_press(pos):  # Tocou num botão: consome o evento.
		get_viewport().set_input_as_handled()


## True se o toque caiu num botão.
## Trata o toque: CMD alterna o modo; com o modo aberto, cada seta digita; com o modo fechado, o toque num amuleto abre o menu.
func _handle_press(pos: Vector2) -> bool:
	if pos.distance_to(_button_center(0)) <= BUTTON_RADIUS * HIT_SLACK:  # Toque no botão CMD.
		_abilities.toggle_command_mode()  # Abre ou fecha o modo comando.
		return true
	if not _abilities.command_active:  # Modo fechado: só os amuletos reagem.
		return _try_slot_tap(pos)
	for i: int in ARROWS.size():  # Modo aberto: confere cada botão de seta.
		if pos.distance_to(_button_center(i + 1)) <= BUTTON_RADIUS * HIT_SLACK:  # Toque dentro do botão.
			_abilities.press_arrow(ARROWS[i])  # Digita a seta.
			return true
	return false


## True se o toque caiu num amuleto da faixa compacta.
## Confere se o toque caiu num amuleto da faixa compacta e, se sim, pede o menu de build.
func _try_slot_tap(pos: Vector2) -> bool:
	if _hud == null:  # Sem HUD não há amuletos.
		return false
	for entry: Dictionary in _hud.get_slot_hit_rects():  # Passa pelas áreas dos slots.
		if (entry["rect"] as Rect2).has_point(pos):  # Toque dentro da área.
			build_requested.emit(entry["ability"] as AbilityData)  # Avisa qual habilidade foi tocada.
			return true
	return false


## Desenha o botão CMD e, com o modo aberto, os quatro botões de seta.
func _draw() -> void:
	if not _is_shown():  # Sem habilidades: não desenha.
		return
	var active: bool = _abilities.command_active  # Modo aberto?
	var cmd_center: Vector2 = _button_center(0)  # Centro do CMD.
	# Círculo (dourado se o modo está aberto).
	draw_circle(cmd_center, BUTTON_RADIUS, COLOR_FILL_ACTIVE if active else COLOR_FILL)
	draw_arc(cmd_center, BUTTON_RADIUS, 0.0, TAU, 32, COLOR_RING, 2.0, true)  # Contorno.
	var font: Font = ThemeDB.fallback_font  # Fonte padrão.
	# Tamanho do texto, para centralizar.
	var label_size: Vector2 = font.get_string_size("CMD", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE)
	draw_string(font, cmd_center + Vector2(-label_size.x * 0.5, FONT_SIZE * 0.35), "CMD",  # Texto "CMD".
			HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, COLOR_ICON)
	if not active:  # Modo fechado: só o CMD aparece.
		return
	for i: int in ARROWS.size():  # Um botão por seta.
		var center: Vector2 = _button_center(i + 1)  # Centro do botão.
		draw_circle(center, BUTTON_RADIUS, COLOR_FILL)  # Círculo.
		draw_arc(center, BUTTON_RADIUS, 0.0, TAU, 32, COLOR_RING, 2.0, true)  # Contorno.
		var angle: float = float(ArrowSequenceView.DIR_ANGLE.get(ARROWS[i], 0.0))  # Ângulo da seta.
		var points: PackedVector2Array = PackedVector2Array()  # Pontos do polígono da seta.
		for corner: Vector2 in ArrowSequenceView.ARROW_SHAPE:  # Gira e escala cada ponto da forma base.
			points.append(center + corner.rotated(angle) * BUTTON_RADIUS * 0.5)
		draw_colored_polygon(points, COLOR_ICON)  # Desenha a seta.
