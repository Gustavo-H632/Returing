extends CanvasLayer
## Menu de pause. Visual dos menus (tema compartilhado); a lógica de pausa é a de sempre:
## só abre com o jogo livre (pausa de outra tela, como quiz e menu de escolha, é respeitada).
## Tem duas páginas no mesmo painel: a principal e as configurações de áudio (SettingsPanel).

const ACTION_PAUSE: StringName = &"Pause"  # Nome da ação de pausa.
const ACTION_CANCEL: StringName = &"ui_cancel"  # Nome da ação de cancelar.
## Escala inicial do painel na abertura.
const OPEN_SCALE: float = 0.94

@export_group("Animação")
## Duração (s) da abertura e do fechamento (no máximo 0,2).
@export_range(0.05, 0.2, 0.01) var open_time: float = Palette.FADE_TIME
@export_range(0.05, 0.2, 0.01) var close_time: float = Palette.FADE_TIME  # Duração do fechamento.

@onready var _root: Control = $Root  # Raiz do menu.
@onready var _dim: ColorRect = $Root/Dim  # Fundo escurecido.
@onready var _panel: Control = $Root/Center/Panel  # Painel.
@onready var _main_page: Control = $Root/Center/Panel/MainPage  # Página principal.
@onready var _continue_button: Button = $Root/Center/Panel/MainPage/ContinueButton  # Botão "Continuar".
# Botão "Configurações".
@onready var _settings_button: Button = $Root/Center/Panel/MainPage/SettingsButton
@onready var _reset_button: Button = $Root/Center/Panel/MainPage/ResetButton  # Botão "Reiniciar".
@onready var _exit_button: Button = $Root/Center/Panel/MainPage/ExitButton  # Botão "Sair".

var _settings: SettingsPanel = null  # Painel de configurações de áudio.
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE  # Modo do mouse antes de pausar.
## True só quando foi ESTE menu que pausou a árvore.
var _paused_by_menu: bool = false
var _tween: Tween = null  # Animação do painel.


## Prepara o menu: camada acima da HUD, escuto a tecla com o jogo pausado e liga os botões.
func _ready() -> void:
	layer = 100  # Acima da HUD.
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua ouvindo a tecla com o jogo pausado
	visible = false  # Começa escondido.
	_dim.color = Palette.dim_color()  # Fundo escurecido.
	_settings = SettingsPanel.new()  # Cria a página de configurações.
	_settings.visible = false  # Começa escondida.
	_panel.add_child(_settings)  # Entra no painel.
	_settings.back_requested.connect(_show_main_page)  # Voltar das configurações mostra a página principal.
	_panel.resized.connect(_center_pivot)  # Mantém o centro do painel (para crescer a partir do meio).
	_continue_button.pressed.connect(resume)  # Continuar.
	_settings_button.pressed.connect(_show_settings_page)  # Configurações.
	_reset_button.pressed.connect(_on_reset_pressed)  # Reiniciar a fase.
	_exit_button.pressed.connect(_on_menu_pressed)  # Voltar ao menu.


## Ao sair da cena, se este menu pausou o jogo, despausa e devolve o mouse.
func _exit_tree() -> void:
	if _paused_by_menu and is_inside_tree():  # Só se foi este menu que pausou.
		get_tree().paused = false  # Despausa.
		Input.mouse_mode = _previous_mouse_mode  # Devolve o cursor.


## Alterna a pausa pela tecla; `ui_cancel` (ex.: botão B do controle) só fecha o menu aberto.
## Dentro das configurações, a mesma tecla volta para a página principal em vez de fechar.
## Trata a tecla de pausa (alterna) e o cancelar (só fecha). Pausas de outras telas são respeitadas.
func _unhandled_input(event: InputEvent) -> void:
	var toggles: bool = event.is_action_pressed(ACTION_PAUSE)  # A tecla de pausa alterna.
	# Cancelar só fecha o menu aberto.
	var closes: bool = _paused_by_menu and event.is_action_pressed(ACTION_CANCEL)
	if not toggles and not closes:  # Nenhum dos dois: ignora.
		return
	if get_tree().paused and not _paused_by_menu:  # Pausa de outra tela (quiz, menu de escolha): não mexe.
		return  # pausa de outra tela (quiz, menu de escolha): a tecla não mexe nela
	get_viewport().set_input_as_handled()  # Consome a tecla.
	if _paused_by_menu and _settings.visible:  # Nas configurações, volta para a página principal.
		_show_main_page()  # Volta.
	elif _paused_by_menu:  # Menu aberto: fecha.
		resume()  # Fecha.
	else:
		pause()  # Menu fechado: abre.


## Abre o menu: devolve o tempo normal, pausa o jogo, mostra o cursor e anima a abertura.
func pause() -> void:
	Engine.time_scale = 1.0  # a câmera lenta do modo comando não vale dentro do menu
	get_tree().paused = true  # Pausa o jogo.
	_paused_by_menu = true  # Marca que foi este menu.
	_set_page(false)  # Página principal.
	visible = true  # Mostra o menu.
	_previous_mouse_mode = Input.mouse_mode  # Guarda o modo do mouse.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # Mostra o cursor.
	_animate(true)  # Anima a abertura.
	_continue_button.grab_focus()  # Foco no botão "Continuar".


## Fecha o menu: despausa, devolve o mouse e anima o fechamento.
func resume() -> void:
	UiFx.swallow_attack_input()  # o clique em "Continuar" não pode virar um golpe
	get_tree().paused = false  # Despausa.
	_paused_by_menu = false  # Não é mais este menu que pausa.
	Input.mouse_mode = _previous_mouse_mode  # Devolve o cursor.
	get_viewport().gui_release_focus()  # o foco do botão não vaza para o jogo
	_animate(false)  # Anima o fechamento.


## Reiniciar: fecha o menu e pede para reiniciar a fase.
func _on_reset_pressed() -> void:
	resume()  # Fecha.
	EventBus.level_restart_requested.emit()  # Avisa o EventBus.


## Sair: fecha o menu e volta ao menu principal.
func _on_menu_pressed() -> void:
	resume()  # Fecha.
	EventBus.main_menu_requested.emit()  # Avisa o EventBus.


## Mostra a página de configurações de áudio.
func _show_settings_page() -> void:
	_set_page(true)  # Página de configurações.
	_settings.focus_first()  # Foco no primeiro slider.


## Volta à página principal.
func _show_main_page() -> void:
	_set_page(false)  # Página principal.
	_settings_button.grab_focus()  # Foco no botão de configurações.


## Alterna a página visível do painel (false = principal, true = configurações).
## Alterna a página visível do painel (false = principal, true = configurações).
func _set_page(settings: bool) -> void:
	_main_page.visible = not settings
	_settings.visible = settings


## Mantém o pivô no centro do painel.
func _center_pivot() -> void:
	_panel.pivot_offset = _panel.size * 0.5


## Abre (fade + o painel cresce um pouco) ou fecha (fade e some).
## Anima a abertura (fade e o painel cresce um pouco) ou o fechamento (fade e some).
func _animate(opening: bool) -> void:
	if _tween != null and _tween.is_valid():  # Cancela a animação anterior.
		_tween.kill()
	_tween = UiTween.create(self)  # Animação que roda com o jogo pausado.
	if opening:  # Abertura.
		_root.modulate.a = 0.0  # Começa transparente.
		_panel.scale = Vector2.ONE * OPEN_SCALE  # Começa um pouco menor.
		_tween.set_parallel(true)  # As duas animações juntas.
		_tween.tween_property(_root, ^"modulate:a", 1.0, open_time)  # Fade-in.
		# Cresce com um leve "pulo".
		_tween.tween_property(_panel, ^"scale", Vector2.ONE, open_time).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_tween.tween_property(_root, ^"modulate:a", 0.0, close_time)  # Fechamento: fade-out.
		_tween.tween_callback(func() -> void: visible = false)  # Ao fim, esconde.
