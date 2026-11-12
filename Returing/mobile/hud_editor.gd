class_name MobileHudEditor
extends CanvasLayer
## Editor de HUD do celular (aberto pelo menu de pausa). Mostra todos os controles, as barras de status e
## o quadro de comandos; cada um pode ser ARRASTADO (um dedo) e REDIMENSIONADO (pinça com dois dedos ou o
## slider), com limites mínimo/máximo e sem sair da tela. "Restaurar padrão" volta ao layout do print e
## "Salvar" grava em `user://` (ConfigFile, via `MobileSettings`). "Voltar" descarta o que não foi salvo.
##
## Trabalha direto no `MobileControls.layout`: as barras de status e o quadro de comandos acompanham ao vivo.

## A tela foi fechada (salvando ou não).
signal closed(saved: bool)

const LAYER_INDEX: int = 105  # Acima do menu de pausa (100), abaixo do botão de pausa (110).
const INSTRUCTION: String = "Amplie e arraste os controles para adicionar do seu jeito."
const SIM_FINGER: int = 98  # Dedo virtual do mouse (simulação no PC).
const PINCH_MIN_DISTANCE: float = 20.0  # Distância mínima entre os dedos para valer a pinça.

var layout: MobileLayout = null  # Layout em edição (o mesmo do MobileControls).
var selected: StringName = &""  # Controle selecionado.
var is_open: bool = false

var _canvas: Control = null
var _panel: PanelContainer = null
var _title: Label = null  # Instrução do alto.
var _name_label: Label = null
var _slider: HSlider = null
var _size_label: Label = null
var _fingers: Dictionary = {}  # índice do dedo -> posição atual
var _drag_id: StringName = &""  # Controle sendo arrastado.
var _drag_offset: Vector2 = Vector2.ZERO  # Diferença entre o dedo e o centro ao começar.
var _pinch_start_distance: float = 0.0
var _pinch_start_scale: float = 1.0
var _updating_slider: bool = false


func _ready() -> void:
	layer = LAYER_INDEX
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()


## Abre o editor (só no celular). O `MobileControls` fica parado enquanto isso.
func open() -> void:
	if not Platform.is_mobile() or is_open:
		return
	layout = MobileControls.layout
	is_open = true
	visible = true
	MobileControls.set_edit_mode(true)
	selected = MobileLayout.AIM
	_fingers.clear()
	_drag_id = &""
	_sync_panel()
	_place_panels()
	_canvas.queue_redraw()


## Fecha o editor. Com `save` grava o layout; sem ele volta ao que estava salvo.
func close(save: bool) -> void:
	if not is_open:
		return
	if save:
		layout.save_to_disk()
	else:
		layout.load_saved()
	MobileControls.refresh_layout()
	is_open = false
	visible = false
	MobileControls.set_edit_mode(false)
	closed.emit(save)


## Volta tudo ao padrão do print (ainda sem gravar).
func restore_default() -> void:
	layout.reset()
	MobileControls.refresh_layout()
	_sync_panel()
	_canvas.queue_redraw()


## Seleciona um controle (usado pelo toque e pelos testes).
func select(id: StringName) -> void:
	selected = id
	_sync_panel()
	_canvas.queue_redraw()


## Muda a escala do controle selecionado (slider) respeitando os limites e a tela.
func set_selected_scale(value: float) -> void:
	if selected == &"":
		return
	layout.set_scale_value(selected, value, MobileControls.view_size(), MobileControls.safe_margins())
	MobileControls.refresh_layout()
	_sync_panel()
	_canvas.queue_redraw()


## Move o controle `id` para `center_px` (usado pelo arrastar e pelos testes).
func move_to(id: StringName, center_px: Vector2) -> void:
	layout.set_center(id, center_px, MobileControls.view_size(), MobileControls.safe_margins())
	MobileControls.refresh_layout()
	_canvas.queue_redraw()


## Retângulo (px) do painel inferior (toques dentro dele não mexem nos controles).
func panel_rect() -> Rect2:
	return _panel.get_global_rect()


# --- Construção ---

func _build() -> void:
	var root: Control = Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = Palette.load_theme()
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	_canvas = Control.new()
	_canvas.name = "Canvas"
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_canvas)
	root.add_child(_canvas)
	# Instrução no alto (fonte do jogo), na faixa livre entre as barras de status e os botões da direita.
	_title = Label.new()
	_title.name = "Instrucao"
	_title.text = INSTRUCTION
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_font_size_override(&"font_size", 26)
	_title.add_theme_color_override(&"font_color", Palette.TEXT)
	_title.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_title.add_theme_constant_override(&"outline_size", 6)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_title)
	# Painel inferior: nome + tamanho numa linha, botões na outra. Fica na faixa livre do layout padrão, entre o
	# joystick de movimento e os botões da direita, dentro da área segura.
	_panel = PanelContainer.new()
	_panel.name = "Painel"
	root.add_child(_panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 6)
	_panel.add_child(box)
	var size_row: HBoxContainer = HBoxContainer.new()
	size_row.add_theme_constant_override(&"separation", 8)
	box.add_child(size_row)
	_name_label = Label.new()
	_name_label.custom_minimum_size.x = 150.0
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.add_theme_font_size_override(&"font_size", 20)
	size_row.add_child(_name_label)
	_slider = HSlider.new()
	_slider.name = "Tamanho"
	_slider.min_value = MobileLayout.MIN_SCALE
	_slider.max_value = MobileLayout.MAX_SCALE
	_slider.step = 0.02
	_slider.custom_minimum_size = Vector2(110.0, Platform.MIN_TOUCH)
	_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_slider.focus_mode = Control.FOCUS_NONE
	_slider.value_changed.connect(_on_slider_changed)
	size_row.add_child(_slider)
	_size_label = Label.new()
	_size_label.custom_minimum_size.x = 56.0
	_size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_size_label.add_theme_font_size_override(&"font_size", 20)
	size_row.add_child(_size_label)
	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 8)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	for entry: Array in [["Restaurar padrão", &"restore", 150.0], ["Salvar", &"save", 92.0], ["Voltar", &"back", 92.0]]:
		var button: PixelButton = PixelButton.new()
		button.text = entry[0]
		button.name = String(entry[1]).capitalize()
		button.custom_minimum_size = Vector2(entry[2], Platform.MIN_TOUCH)
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override(&"font_size", 18)
		button.pressed.connect(_on_button.bind(entry[1]))
		buttons.add_child(button)
	Platform.safe_area_changed.connect(_place_panels)
	_place_panels()


func _exit_tree() -> void:
	if Platform.safe_area_changed.is_connected(_place_panels):
		Platform.safe_area_changed.disconnect(_place_panels)


## Coloca a instrução e o painel nas faixas que o layout PADRÃO deixa livres, sempre dentro da área segura:
## instrução no alto, entre as barras de status e o botão E; painel embaixo, entre o joystick de movimento e o
## botão de trocar arma.
func _place_panels() -> void:
	if _panel == null:
		return
	var view: Vector2 = MobileControls.view_size()
	var margins: Vector4 = MobileControls.safe_margins()
	var safe: Rect2 = Platform.get_safe_rect()
	var padrao: MobileLayout = MobileLayout.new()
	const GAP: float = 10.0
	# Painel inferior.
	var left: float = padrao.get_rect(MobileLayout.MOVE, view, margins).end.x + GAP
	var right: float = padrao.get_rect(MobileLayout.WEAPON, view, margins).position.x - GAP
	var need: Vector2 = _panel.get_combined_minimum_size()
	var width: float = clampf(right - left, need.x, maxf(need.x, 560.0))
	_panel.size = Vector2(width, need.y)
	_panel.position = Vector2(clampf((left + right - width) * 0.5, safe.position.x, safe.end.x - width), safe.end.y - need.y - 8.0)
	# Instrução no alto.
	var t_left: float = padrao.get_rect(MobileLayout.STATUS, view, margins).end.x + GAP
	var t_right: float = padrao.get_rect(MobileLayout.INTERACT, view, margins).position.x - GAP
	_title.position = Vector2(t_left, safe.position.y + 10.0)
	_title.size = Vector2(maxf(t_right - t_left, 200.0), 0.0)
	_title.size.y = _title.get_minimum_size().y


func _on_button(kind: StringName) -> void:
	match kind:
		&"restore":
			restore_default()
		&"save":
			close(true)
		&"back":
			close(false)


func _on_slider_changed(value: float) -> void:
	if _updating_slider:
		return
	set_selected_scale(value)


## Atualiza o nome, o slider e o texto de tamanho do controle selecionado.
func _sync_panel() -> void:
	if selected == &"":
		_name_label.text = "Toque num controle"
		return
	_name_label.text = String(MobileLayout.LABELS.get(selected, selected))
	_updating_slider = true
	_slider.value = layout.get_scale(selected)
	_updating_slider = false
	_size_label.text = "%d%%" % roundi(layout.get_scale(selected) * 100.0)


# --- Entrada ---

func _input(event: InputEvent) -> void:
	if not is_open:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			_finger_down(touch.index, touch.position)
		else:
			_finger_up(touch.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		_finger_move(drag.index, drag.position)
		get_viewport().set_input_as_handled()
	elif (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == InputEvent.DEVICE_ID_EMULATION:
		pass  # O Godot também emite o clique emulado: ele chega aos botões do painel normalmente.
	elif event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and Platform.mouse_as_finger:
		var click := event as InputEventMouseButton
		if _panel.get_global_rect().has_point(click.position):
			return  # clique nos botões do painel
		if click.pressed:
			_finger_down(SIM_FINGER, click.position)
		else:
			_finger_up(SIM_FINGER)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and Platform.mouse_as_finger and _fingers.has(SIM_FINGER):
		_finger_move(SIM_FINGER, (event as InputEventMouseMotion).position)
		get_viewport().set_input_as_handled()


## Qual controle está sob `pos` (o último desenhado ganha).
func control_at(pos: Vector2) -> StringName:
	var ids: Array[StringName] = MobileLayout.IDS.duplicate()
	ids.reverse()
	var view: Vector2 = MobileControls.view_size()
	var margins: Vector4 = MobileControls.safe_margins()
	for id: StringName in ids:
		if layout.is_circle(id):
			if pos.distance_to(layout.get_center(id, view, margins)) <= layout.get_radius(id) * 1.1:
				return id
		elif layout.get_rect(id, view, margins).has_point(pos):
			return id
	return &""


func _finger_down(index: int, pos: Vector2) -> void:
	if _panel.get_global_rect().has_point(pos):
		return  # os botões do painel recebem o clique emulado
	_fingers[index] = pos
	if _fingers.size() == 1:
		var hit: StringName = control_at(pos)
		if hit != &"":
			selected = hit
			_drag_id = hit
			_drag_offset = pos - layout.get_center(hit, MobileControls.view_size(), MobileControls.safe_margins())
			_sync_panel()
	elif _fingers.size() == 2 and selected != &"":
		# Pinça: começa a medir a distância entre os dois dedos sobre o controle selecionado.
		var points: Array = _fingers.values()
		_pinch_start_distance = maxf((points[0] as Vector2).distance_to(points[1] as Vector2), PINCH_MIN_DISTANCE)
		_pinch_start_scale = layout.get_scale(selected)
		_drag_id = &""
	_canvas.queue_redraw()


func _finger_move(index: int, pos: Vector2) -> void:
	if not _fingers.has(index):
		return
	_fingers[index] = pos
	if _fingers.size() >= 2 and selected != &"" and _pinch_start_distance > 0.0:
		var points: Array = _fingers.values()
		var distance: float = (points[0] as Vector2).distance_to(points[1] as Vector2)
		set_selected_scale(_pinch_start_scale * distance / _pinch_start_distance)
	elif _drag_id != &"":
		move_to(_drag_id, pos - _drag_offset)


func _finger_up(index: int) -> void:
	_fingers.erase(index)
	if _fingers.size() < 2:
		_pinch_start_distance = 0.0
	if _fingers.is_empty():
		_drag_id = &""
	elif _fingers.size() == 1 and selected != &"":
		# Sobrou um dedo depois da pinça: volta a arrastar a partir da posição atual.
		var pos: Vector2 = _fingers.values()[0]
		_drag_id = selected
		_drag_offset = pos - layout.get_center(selected, MobileControls.view_size(), MobileControls.safe_margins())


# --- Desenho ---

func _draw_canvas() -> void:
	if layout == null:
		return
	var view: Vector2 = MobileControls.view_size()
	var margins: Vector4 = MobileControls.safe_margins()
	for id: StringName in MobileLayout.IDS:
		var center: Vector2 = layout.get_center(id, view, margins)
		var is_selected: bool = id == selected
		if id == MobileLayout.MOVE or id == MobileLayout.AIM:
			var radius: float = layout.get_radius(id)
			MobileDraw.stick(_canvas, center, radius, Vector2(radius * 0.25, -radius * 0.18))
			if is_selected:
				_canvas.draw_arc(center, radius + 3.0, 0.0, TAU, 48, MobileDraw.COLOR_SELECTED, 3.0, true)
		elif layout.is_circle(id):
			var radius: float = layout.get_radius(id)
			MobileDraw.button(_canvas, center, radius, id)
			if is_selected:
				_canvas.draw_arc(center, radius + 3.0, 0.0, TAU, 40, MobileDraw.COLOR_SELECTED, 3.0, true)
		else:
			MobileDraw.frame(_canvas, layout.get_rect(id, view, margins), String(MobileLayout.LABELS[id]), is_selected)
