class_name SkipCutsceneButton
extends PixelButton
## Botão "Avançar cutscene" (só no celular): no lugar de "segure TAB/ESC para pular". Usa a caixa marrom
## do tema do jogo (mesmo estilo dos botões e das caixas de diálogo) e a fonte do jogo.

## Texto do botão.
const LABEL: String = "Avançar cutscene"
const FONT_SIZE: int = 26  # Tamanho da fonte (múltiplo do pixel da fonte do jogo).
const SIZE: Vector2 = Vector2(264.0, 72.0)  # Tamanho mínimo (toque confortável).
const MARGIN: float = 16.0  # Distância das bordas (canto superior direito).
const GAP: float = 10.0  # Folga entre este botão e o de pausa.

## O jogador tocou no botão.
signal skip_requested


## Cria o botão dentro de `parent` (um Control com o tema do jogo) e liga `on_press`. No computador não cria
## nada e devolve null: lá continua "segure TAB/ESC para pular".
static func attach(parent: Node, on_press: Callable) -> SkipCutsceneButton:
	if not Platform.is_mobile():
		return null
	var button: SkipCutsceneButton = SkipCutsceneButton.new()
	button.name = &"BotaoAvancarCutscene"
	button.text = LABEL
	button.custom_minimum_size = SIZE
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -SIZE.x - MARGIN
	button.offset_right = -MARGIN
	button.offset_top = MARGIN
	button.offset_bottom = MARGIN + SIZE.y
	button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	button.add_theme_font_size_override(&"font_size", FONT_SIZE)
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	if parent is Control and (parent as Control).theme == null:
		button.theme = Palette.load_theme()
	button.pressed.connect(func() -> void:
		button.skip_requested.emit()
		on_press.call())
	parent.add_child(button)
	SafeArea.fit(button)  # fora do notch e das barras
	button._avoid_pause()
	Platform.safe_area_changed.connect(button._avoid_pause)
	button.tree_exiting.connect(func() -> void:
		if Platform.safe_area_changed.is_connected(button._avoid_pause):
			Platform.safe_area_changed.disconnect(button._avoid_pause))
	return button


## O botão de pausa fica por cima de tudo no canto superior direito: o "Avançar cutscene" se encosta à esquerda dele
## (ou onde o jogador o tiver colocado pelo editor de HUD) em vez de ficar por baixo.
func _avoid_pause() -> void:
	if not is_inside_tree():
		return
	SafeArea.fit(self)  # volta ao lugar de fábrica (canto superior direito da área segura) antes de medir
	var pause: Rect2 = MobileControls.control_rect(MobileLayout.PAUSE).grow(GAP)
	var mine: Rect2 = get_global_rect()
	if not mine.intersects(pause):
		return
	var target: float = pause.position.x - mine.size.x  # à esquerda da pausa
	if target < Platform.get_safe_rect().position.x:  # pausa movida para a esquerda pelo jogador: vai para a direita dela
		target = minf(pause.end.x, Platform.get_safe_rect().end.x - mine.size.x)
	var delta: float = target - mine.position.x
	offset_left += delta
	offset_right += delta
