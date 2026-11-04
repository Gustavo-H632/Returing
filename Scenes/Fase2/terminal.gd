class_name QuizTerminal
extends Area2D
## Terminal interativo da Fase 2.

signal terminal_ativado

## Telas do terminal (cada uma é um quadro da sheet AEGIS_sprite, 3 x 3).
enum Screen { IDLE, NEAR, ACTIVE, DONE }

const SCREEN_FRAMES: Dictionary[Screen, int] = {
	Screen.IDLE: 0,  # tela apagada
	Screen.NEAR: 2,  # "ALAN TURING"
	Screen.ACTIVE: 5,  # "A.E.G.I.S" (quiz aberto)
	Screen.DONE: 6,  # "CONCLUÍDO"
}

## Dica "[E] Terminal" mostrada só enquanto o player está por perto.
@export var prompt: Control
## Sprite da tela (spritesheet 3 x 3 do AEGIS).
@export var screen: Sprite2D

var _player_nearby: bool = false
## True enquanto o cursor está sobre o terminal.
var _mouse_over: bool = false
var _screen_state: Screen = Screen.IDLE


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	# Ponteiro: o Area2D precisa ser "pickable" e ter uma CollisionShape2D.
	input_pickable = true
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	_set_nearby(false)


func _exit_tree() -> void:
	# Não deixa o cursor de "mãozinha" preso ao trocar de cena.
	if _mouse_over:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


func _on_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		_set_nearby(true)


## O player pode estar sendo liberado ao mesmo tempo.
func _on_body_exited(body: Node2D) -> void:
	if CombatUtils.is_valid(body) and body.is_in_group(CombatUtils.GROUP_PLAYER):
		_set_nearby(false)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed(&"interagir"):
		get_viewport().set_input_as_handled()
		_activate()


## Clique esquerdo sobre o terminal (com o player por perto) abre o quiz.
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	if _player_nearby:
		get_viewport().set_input_as_handled()
		_activate()


func _on_mouse_entered() -> void:
	_mouse_over = true
	_atualizar_cursor()


func _on_mouse_exited() -> void:
	_mouse_over = false
	_atualizar_cursor()


## Cursor de "mãozinha" só quando o clique realmente funciona.
func _atualizar_cursor() -> void:
	var clicavel: bool = _mouse_over and _player_nearby
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if clicavel else Input.CURSOR_ARROW)


## Mostra "A.E.G.I.S" na tela e avisa a fase para abrir o quiz.
func _activate() -> void:
	_show_screen(Screen.ACTIVE)
	terminal_ativado.emit()


## O quiz terminou: a tela passa a mostrar "CONCLUÍDO".
func mark_completed() -> void:
	_show_screen(Screen.DONE)


## Troca a tela (depois de concluído ou com o quiz aberto, a aproximação não muda mais a tela).
func _show_screen(state: Screen) -> void:
	if _screen_state == Screen.DONE:
		return
	_screen_state = state
	if screen != null:
		screen.frame = SCREEN_FRAMES[state]


func _set_nearby(value: bool) -> void:
	_player_nearby = value
	if prompt != null:
		prompt.visible = value
	if _screen_state != Screen.ACTIVE:
		_show_screen(Screen.NEAR if value else Screen.IDLE)
	_atualizar_cursor()
