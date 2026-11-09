extends Control
## Menu principal. Só cuida do visual (cores da Palette em imagens que a cena não pode colorir
## sozinha, fade e foco inicial) e de alternar entre a página principal e as configurações de áudio.
## A navegação continua nos botões Start e Quit.

@onready var _stars: TextureRect = $Stars  # Fundo de estrelas.
@onready var _title: TextureRect = $Center/Column/Title  # Título do jogo.
@onready var _column: Control = $Center/Column  # Coluna central.
@onready var _hint: Control = $Center/Column/Hint  # Dica.
@onready var _menu_panel: Control = $Center/Column/MenuPanel  # Painel dos botões.
@onready var _buttons: Control = $Center/Column/MenuPanel/Buttons  # Botões da página principal.
# Primeiro botão (começa com o foco).
@onready var _first_button: Button = $Center/Column/MenuPanel/Buttons/Start_button
# Botão de configurações.
@onready var _settings_button: Button = $Center/Column/MenuPanel/Buttons/Settings_button

var _settings: SettingsPanel = null  # Painel de configurações de áudio.


## Tinge as imagens com a paleta, cria a página de configurações, dá foco ao primeiro botão e faz o fade de entrada.
func _ready() -> void:
	# As imagens são brancas: tinge com a paleta (nada de branco puro na tela).
	_stars.modulate = Palette.TEXT_DIM  # Estrelas esmaecidas.
	_title.modulate = Palette.TEXT  # Título na cor do texto.
	_settings = SettingsPanel.new()  # Cria a página de configurações.
	_settings.visible = false  # Começa escondida.
	_menu_panel.add_child(_settings)  # Entra no painel.
	_settings.back_requested.connect(_show_main_page)  # Voltar das configurações mostra a página principal.
	_settings_button.pressed.connect(_show_settings_page)  # Botão de configurações.
	# Todos os botões são alcançáveis sem mouse; o foco começa no primeiro.
	_first_button.grab_focus.call_deferred()  # Foco no primeiro botão (tudo é alcançável sem mouse).
	_fade_in()  # Aparece com fade.


## Nas configurações, `ui_cancel` (Esc, botão B) volta para a página principal.
func _unhandled_input(event: InputEvent) -> void:
	if _settings.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_show_main_page()


## Mostra a página de configurações e dá foco ao primeiro slider.
func _show_settings_page() -> void:
	_set_page(true)  # Página de configurações.
	_settings.focus_first()  # Foco no primeiro slider.


## Volta à página principal e devolve o foco ao botão de configurações.
func _show_main_page() -> void:
	_set_page(false)  # Página principal.
	_settings_button.grab_focus()  # Foco no botão de configurações.


## Alterna a página visível da caixa (false = principal, true = configurações).
## Nas configurações o logo e a dica saem para a caixa caber na tela.
func _set_page(settings: bool) -> void:
	_buttons.visible = not settings  # Botões só na página principal.
	_settings.visible = settings  # Configurações só na página de configurações.
	_title.visible = not settings  # Título só na página principal.
	_hint.visible = not settings  # Dica só na página principal.


## Fade rápido (<= 0,2 s) do conteúdo ao abrir o menu.
func _fade_in() -> void:
	_column.modulate.a = 0.0  # Começa transparente.
	var tween: Tween = UiTween.create(self)  # Animação que roda mesmo pausado.
	tween.tween_property(_column, ^"modulate:a", 1.0, Palette.FADE_TIME)  # Aparece em `Palette.FADE_TIME`.
