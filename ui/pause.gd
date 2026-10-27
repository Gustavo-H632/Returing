extends CanvasLayer
## Menu de pausa.

const ACTION_PAUSE: StringName = &"Pause"

@onready var _continue_button: Button = $Continue_button
@onready var _reset_button: Button = $Reset_button
@onready var _bye_button: Button = $Bye_button

var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
## True só quando foi ESTE menu que pausou a árvore.
var _paused_by_menu: bool = false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS  # continua ouvindo a tecla com o jogo pausado
	visible = false
	_continue_button.pressed.connect(resume)
	_reset_button.pressed.connect(_on_reset_pressed)
	_bye_button.pressed.connect(_on_menu_pressed)


## Alterna a pausa pela tecla.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(ACTION_PAUSE):
		return
	if get_tree().paused and not _paused_by_menu:
		return  # pausa de outra tela (quiz): a tecla não mexe nela
	get_viewport().set_input_as_handled()
	if _paused_by_menu:
		resume()
	else:
		pause()


func pause() -> void:
	get_tree().paused = true
	_paused_by_menu = true
	visible = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_continue_button.grab_focus()


func resume() -> void:
	get_tree().paused = false
	_paused_by_menu = false
	visible = false
	Input.mouse_mode = _previous_mouse_mode


func _on_reset_pressed() -> void:
	resume()
	EventBus.level_restart_requested.emit()


func _on_menu_pressed() -> void:
	resume()
	EventBus.main_menu_requested.emit()
