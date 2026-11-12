class_name SettingsPanel
extends VBoxContainer
## Tela de configurações de áudio: um slider (0 a 100%) para efeitos sonoros e outro para a música.
## Reutilizável: o pause e o menu principal colocam esta caixa dentro do próprio painel e a
## alternam com a página principal. Quem usa só escuta `back_requested` (botão "Voltar").
## Os volumes ficam no autoload AudioSettings (buses "SFX" e "Music", salvos em user://settings.cfg).

## O jogador pediu para voltar (botão "Voltar").
signal back_requested

const TITLE: String = "CONFIGURAÇÕES"  # Textos fixos da tela.
const BACK_TEXT: String = "Voltar"
const TILT_BUTTON_TEXT: String = "Acelerômetro"
const TILT_TITLE: String = "ACELERÔMETRO"
const SFX_LABEL: String = "Efeitos sonoros"
const MUSIC_LABEL: String = "Música principal"
## Largura mínima (px) da caixa e altura (px) do botão e do slider.
const PANEL_WIDTH: float = 400.0
const BUTTON_HEIGHT: float = 56.0
const SLIDER_HEIGHT: float = 24.0
const PANEL_RESERVE: float = 88.0  # Celular: altura reservada para as bordas do painel e as margens da tela.
const PERCENT_WIDTH: float = 72.0

## Onde as linhas entram: o próprio painel no computador; no celular, uma coluna dentro de uma caixa de rolagem.
var _body: Control = self
var _sliders: Array[HSlider] = []  # Sliders de volume.
var _back_button: PixelButton = null  # Botão "Voltar".
# Celular: página do acelerômetro (sensibilidade, zona morta, intervalo e calibração).
var _tilt_page: VBoxContainer = null
var _tilt_button: PixelButton = null  # Botão "Acelerômetro" (só aparece com sensor presente).
var _audio_children: Array[Node] = []  # Peças da página de áudio (escondidas na página do acelerômetro).
var _calibrate_label: Label = null
var _calibrate_token: int = 0
var _preview: TiltPreview = null


## Monta a tela: título, dois sliders de volume e o botão de voltar.
func _ready() -> void:
	custom_minimum_size.x = PANEL_WIDTH  # Largura mínima.
	if Platform.is_mobile():  # No celular o conteúdo rola por toque quando não cabe na área segura.
		_body = VBoxContainer.new()
		_body.name = "Body"
		_body.add_theme_constant_override(&"separation", Palette.UNIT * 2)
		add_child(ScrollFit.new(_body, PANEL_RESERVE))
	add_theme_constant_override(&"separation", Palette.UNIT * 2)  # Espaço entre os blocos.

	var title: Label = Label.new()  # Título.
	title.text = TITLE
	title.theme_type_variation = &"PanelTitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(title)
	_body.add_child(HSeparator.new())  # Linha separadora.

	_add_slider_row(SFX_LABEL, &"SFX")  # Slider dos efeitos sonoros.
	_add_slider_row(MUSIC_LABEL, &"Music")  # Slider da música.

	if Platform.is_mobile():  # Só no celular: ajustes do acelerômetro numa página própria.
		var tilt_button: PixelButton = PixelButton.new()
		tilt_button.name = "TiltButton"
		tilt_button.text = TILT_BUTTON_TEXT
		tilt_button.custom_minimum_size.y = BUTTON_HEIGHT
		tilt_button.pressed.connect(_show_tilt_page.bind(true))
		_body.add_child(tilt_button)
		_tilt_button = tilt_button
		# Sem acelerômetro, nada de "Calibrar", sensibilidade, zona morta ou intervalo: o botão some.
		visibility_changed.connect(_refresh_tilt_availability)
		TiltInput.sensor_state_changed.connect(func(_on: bool) -> void: _refresh_tilt_availability())
		_refresh_tilt_availability()
	_body.add_child(HSeparator.new())
	_back_button = PixelButton.new()  # Botão de voltar.
	_back_button.text = BACK_TEXT
	_back_button.custom_minimum_size.y = BUTTON_HEIGHT
	_back_button.pressed.connect(_on_back_pressed)  # Voltar avisa quem usa a tela.
	_body.add_child(_back_button)
	_audio_children = _body.get_children()
	if Platform.is_mobile():
		_build_tilt_page()


## Altura do slider: no celular a faixa de toque tem o tamanho mínimo de um alvo de toque.
func _slider_height() -> float:
	return Platform.MIN_TOUCH if Platform.is_mobile() else SLIDER_HEIGHT


## Dá o foco ao primeiro slider (para navegar sem mouse).
## Dá o foco ao primeiro slider (para navegar sem mouse).
func focus_first() -> void:
	if not _sliders.is_empty():  # Só se existem sliders.
		_sliders[0].grab_focus()


## Uma linha: rótulo à esquerda, porcentagem à direita e o slider embaixo.
## Cria uma linha: rótulo à esquerda, porcentagem à direita e o slider embaixo.
func _add_slider_row(label_text: String, bus: StringName) -> void:
	var row: VBoxContainer = VBoxContainer.new()  # Coluna da linha.
	row.add_theme_constant_override(&"separation", Palette.UNIT)
	_body.add_child(row)

	var header: HBoxContainer = HBoxContainer.new()  # Cabeçalho com rótulo e porcentagem.
	row.add_child(header)
	var label: Label = Label.new()  # Rótulo.
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var percent: Label = Label.new()  # Porcentagem.
	percent.custom_minimum_size.x = PERCENT_WIDTH
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(percent)

	var slider: HSlider = HSlider.new()  # Slider de 0 a 100.
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = 1.0
	slider.custom_minimum_size.y = _slider_height()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL  # Aceita foco do teclado.
	# Valor inicial ANTES de conectar o sinal: abrir a tela não deve regravar o volume.
	# Valor inicial antes de conectar o sinal (abrir a tela não regrava o volume).
	slider.value = roundf(AudioSettings.get_volume(bus) * 100.0)
	_update_percent(percent, slider.value)  # Mostra a porcentagem inicial.
	# Ao mover, muda o volume e a porcentagem.
	slider.value_changed.connect(_on_slider_changed.bind(bus, percent))
	row.add_child(slider)  # Entra na linha.
	_sliders.append(slider)  # Guarda o slider.


## O slider mudou: aplica o volume (0 a 1) e atualiza o texto.
func _on_slider_changed(value: float, bus: StringName, percent: Label) -> void:
	AudioSettings.set_volume(bus, value / 100.0)  # Aplica o volume.
	_update_percent(percent, value)  # Atualiza a porcentagem.


## Atualiza o texto da porcentagem.
func _update_percent(percent: Label, value: float) -> void:
	percent.text = "%d%%" % roundi(value)


## Botão "Voltar": avisa quem usa a tela.
func _on_back_pressed() -> void:
	back_requested.emit()  # Avisa.


# --- Acelerômetro (só no celular) ---

## Monta a página do acelerômetro: três sliders, o indicador ao vivo e o botão "Calibrar".
func _build_tilt_page() -> void:
	_tilt_page = VBoxContainer.new()
	_tilt_page.name = "TiltPage"
	_tilt_page.visible = false
	_tilt_page.add_theme_constant_override(&"separation", Palette.UNIT)
	_body.add_child(_tilt_page)
	var title: Label = Label.new()
	title.text = TILT_TITLE
	title.theme_type_variation = &"PanelTitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tilt_page.add_child(title)
	_add_tilt_slider("Sensibilidade", 50.0, 250.0, 5.0, TiltInput.sensitivity * 100.0, "%d%%",
			func(v: float) -> void: TiltInput.sensitivity = v / 100.0)
	_add_tilt_slider("Zona morta", 50.0, 250.0, 5.0, TiltInput.deadzone * 100.0, "%d%%",
			func(v: float) -> void: TiltInput.deadzone = v / 100.0)
	_add_tilt_slider("Intervalo entre setas", 50.0, 1000.0, 10.0, TiltInput.cooldown * 1000.0, "%d ms",
			func(v: float) -> void: TiltInput.cooldown = v / 1000.0)
	var auto_check: CheckButton = CheckButton.new()
	auto_check.name = "AutoCalibrate"
	auto_check.text = "Calibrar ao abrir o modo comando"
	auto_check.button_pressed = TiltInput.auto_calibrate
	auto_check.focus_mode = Control.FOCUS_NONE
	auto_check.custom_minimum_size.y = Platform.MIN_TOUCH
	auto_check.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	auto_check.toggled.connect(func(on: bool) -> void:
		TiltInput.auto_calibrate = on
		TiltInput.save_settings())
	_tilt_page.add_child(auto_check)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override(&"separation", Palette.UNIT * 2)
	_tilt_page.add_child(row)
	_preview = TiltPreview.new()
	row.add_child(_preview)
	var calibrate_box: VBoxContainer = VBoxContainer.new()
	calibrate_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calibrate_box.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(calibrate_box)
	var calibrate: PixelButton = PixelButton.new()
	calibrate.name = "CalibrateButton"
	calibrate.text = "Calibrar"
	calibrate.custom_minimum_size.y = BUTTON_HEIGHT
	calibrate.pressed.connect(_on_calibrate_pressed)
	calibrate_box.add_child(calibrate)
	_calibrate_label = Label.new()
	_calibrate_label.theme_type_variation = &"HintLabel"
	_calibrate_label.text = "Segure o celular como for jogar."
	_calibrate_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	calibrate_box.add_child(_calibrate_label)
	_tilt_page.add_child(HSeparator.new())
	var back: PixelButton = PixelButton.new()
	back.name = "TiltBackButton"
	back.text = BACK_TEXT
	back.custom_minimum_size.y = BUTTON_HEIGHT
	back.pressed.connect(_show_tilt_page.bind(false))
	_tilt_page.add_child(back)


## Uma linha de slider do acelerômetro (aplica ao mover e grava ao soltar).
func _add_tilt_slider(label_text: String, min_v: float, max_v: float, step_v: float, value: float, fmt: String, apply: Callable) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override(&"separation", Palette.UNIT)
	_tilt_page.add_child(row)
	var header: HBoxContainer = HBoxContainer.new()
	row.add_child(header)
	var label: Label = Label.new()
	label.text = label_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var percent: Label = Label.new()
	percent.custom_minimum_size.x = PERCENT_WIDTH + 24.0
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	header.add_child(percent)
	var slider: HSlider = HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step_v
	slider.custom_minimum_size.y = _slider_height()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.focus_mode = Control.FOCUS_ALL
	slider.value = value
	percent.text = fmt % roundi(value)
	slider.value_changed.connect(func(v: float) -> void:
		apply.call(v)
		percent.text = fmt % roundi(v))
	slider.drag_ended.connect(func(_changed: bool) -> void: TiltInput.save_settings())
	row.add_child(slider)


## Esconde tudo do acelerômetro quando o aparelho não tem o sensor (e volta à página de áudio se ela estava aberta).
func _refresh_tilt_availability() -> void:
	if _tilt_button == null:
		return
	var has_sensor: bool = TiltInput.has_sensor()
	if not has_sensor and _tilt_page != null and _tilt_page.visible:
		_show_tilt_page(false)
	_tilt_button.visible = has_sensor and (_tilt_page == null or not _tilt_page.visible)


## Mostra a página do acelerômetro (true) ou volta à de áudio (false).
func _show_tilt_page(show: bool) -> void:
	for child: Node in _audio_children:
		(child as Control).visible = not show
	if not show and _tilt_button != null:
		_tilt_button.visible = TiltInput.has_sensor()
	_tilt_page.visible = show
	if show:
		TiltInput.acquire(self)  # liga o indicador ao vivo
	else:
		TiltInput.release(self)
		TiltInput.save_settings()


## Botão "Calibrar": a pose atual do celular vira o neutro.
func _on_calibrate_pressed() -> void:
	TiltInput.calibrate_now()
	_calibrate_label.text = "Calibrado!"
	_calibrate_token += 1
	var token: int = _calibrate_token
	await get_tree().create_timer(1.8, true, false, true).timeout
	if token == _calibrate_token and is_instance_valid(_calibrate_label):
		_calibrate_label.text = "Segure o celular como for jogar."


func _exit_tree() -> void:
	TiltInput.release(self)


## Indicador de inclinação ao vivo (anel + bolinha) usado na página do acelerômetro.
class TiltPreview extends Control:
	func _init() -> void:
		custom_minimum_size = Vector2(120.0, 120.0)

	func _ready() -> void:
		TiltInput.tilt_changed.connect(func(_t: Vector2) -> void: queue_redraw())

	func _draw() -> void:
		var rect: Rect2 = Rect2(Vector2.ZERO, size)
		draw_texture_rect(MobileDraw.tex("tilt_ring.png"), rect, false)
		var center: Vector2 = size * 0.5
		var offset: Vector2 = (TiltInput.current_tilt * (size.x * 0.4 / 0.5)).limit_length(size.x * 0.4)
		draw_texture_rect(MobileDraw.tex("tilt_dot.png"), Rect2(center + offset - Vector2(10.0, 10.0), Vector2(20.0, 20.0)), false)
