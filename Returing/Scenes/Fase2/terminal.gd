class_name QuizTerminal
extends Area2D
## Terminal interativo da Fase 2.

signal terminal_ativado  # Avisa que o jogador ativou o terminal (a fase abre o quiz).

## Telas do terminal (cada uma é um quadro da sheet AEGIS_sprite, 3 x 3).
enum Screen { IDLE, NEAR, ACTIVE, DONE }

const SCREEN_FRAMES: Dictionary[Screen, int] = {  # Quadro da spritesheet de cada tela.
	Screen.IDLE: 0,  # tela apagada
	Screen.NEAR: 2,  # "ALAN TURING"
	Screen.ACTIVE: 5,  # "A.E.G.I.S" (quiz aberto)
	Screen.DONE: 6,  # "CONCLUÍDO"
}

## Dica "[E] Terminal" mostrada só enquanto o player está por perto.
@export var prompt: Control
## Sprite da tela (spritesheet 3 x 3 do AEGIS).
@export var screen: Sprite2D

var _player_nearby: bool = false  # True se o jogador está por perto.
## True enquanto o cursor está sobre o terminal.
var _mouse_over: bool = false
var _screen_state: Screen = Screen.IDLE  # Tela mostrada agora.


## Liga os sinais de proximidade e de mouse e começa com a tela apagada.
func _ready() -> void:
	body_entered.connect(_on_body_entered)  # Jogador entrou na área.
	body_exited.connect(_on_body_exited)  # Jogador saiu da área.
	# Ponteiro: o Area2D precisa ser "pickable" e ter uma CollisionShape2D.
	input_pickable = true  # O Area2D precisa ser "pickable" para receber cliques.
	input_event.connect(_on_input_event)  # Clique no terminal.
	mouse_entered.connect(_on_mouse_entered)  # Cursor entrou.
	mouse_exited.connect(_on_mouse_exited)  # Cursor saiu.
	_set_nearby(false)  # Começa longe do jogador.


## Ao sair da cena devolve o cursor normal (não deixa a "mãozinha" presa).
func _exit_tree() -> void:
	# Não deixa o cursor de "mãozinha" preso ao trocar de cena.
	if _mouse_over:  # Cursor estava sobre o terminal.
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)  # Cursor normal.


## Um corpo entrou na área: se for o jogador, mostra a dica.
func _on_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):  # Só o jogador conta.
		_set_nearby(true)  # Marca que está por perto.


## O player pode estar sendo liberado ao mesmo tempo.
func _on_body_exited(body: Node2D) -> void:  # Basta estar no grupo do jogador.
	if CombatUtils.is_valid(body) and body.is_in_group(CombatUtils.GROUP_PLAYER):  # Só o jogador conta.
		_set_nearby(false)  # Marca que saiu.


## Tecla de interagir: abre o quiz se o jogador está por perto.
func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed(&"interagir"):  # Só com o jogador por perto.
		get_viewport().set_input_as_handled()  # Consome a tecla.
		_activate()  # Ativa o terminal.


## Clique esquerdo sobre o terminal (com o player por perto) abre o quiz.
func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return  # Só o clique esquerdo.
	if _player_nearby:  # Só com o jogador por perto.
		get_viewport().set_input_as_handled()  # Consome o clique.
		_activate()  # Ativa o terminal.


## O cursor entrou no terminal.
func _on_mouse_entered() -> void:
	_mouse_over = true  # Marca.
	_atualizar_cursor()  # Atualiza o cursor.


## O cursor saiu do terminal.
func _on_mouse_exited() -> void:
	_mouse_over = false  # Desmarca.
	_atualizar_cursor()  # Atualiza o cursor.


## Cursor de "mãozinha" só quando o clique realmente funciona.
func _atualizar_cursor() -> void:
	# Clicável só com o cursor em cima e o jogador por perto.
	var clicavel: bool = _mouse_over and _player_nearby
	# "Mãozinha" quando o clique funciona.
	Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if clicavel else Input.CURSOR_ARROW)


## Mostra "A.E.G.I.S" na tela e avisa a fase para abrir o quiz.
func _activate() -> void:
	_show_screen(Screen.ACTIVE)  # Mostra a tela do quiz.
	terminal_ativado.emit()  # Avisa a fase.


## O quiz terminou: a tela passa a mostrar "CONCLUÍDO".
func mark_completed() -> void:
	_show_screen(Screen.DONE)  # Mostra "CONCLUÍDO".


## Troca a tela (depois de concluído ou com o quiz aberto, a aproximação não muda mais a tela).
func _show_screen(state: Screen) -> void:
	if _screen_state == Screen.DONE:  # Depois de concluído a tela não muda mais.
		return
	_screen_state = state  # Guarda a tela atual.
	if screen != null:  # Tem sprite.
		screen.frame = SCREEN_FRAMES[state]  # Troca o quadro da sheet.
	_atualizar_prompt()  # Atualiza a dica.


## Marca se o jogador está por perto e ajusta tela, dica e cursor.
func _set_nearby(value: bool) -> void:
	_player_nearby = value  # Guarda o valor.
	_atualizar_prompt()  # Atualiza a dica.
	if _screen_state != Screen.ACTIVE:  # Com o quiz aberto a tela não muda.
		_show_screen(Screen.NEAR if value else Screen.IDLE)  # Tela acesa quando perto, apagada quando longe.
	_atualizar_cursor()  # Atualiza o cursor.


## A dica "[E] Terminal" some enquanto o quiz está aberto (não fica por cima das perguntas).
func _atualizar_prompt() -> void:
	if prompt != null:  # Dica só aparece com o jogador por perto e o quiz fechado.
		prompt.visible = _player_nearby and _screen_state != Screen.ACTIVE  # Só se existe a dica.
