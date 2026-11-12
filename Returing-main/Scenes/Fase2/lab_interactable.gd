class_name LabInteractable
extends Area2D
## Objeto do labirinto que o jogador aciona com [E] (ação "interagir") quando está perto.
## A dica "[E] ..." aparece na HUD do labirinto (a HUD não sofre o escuro do CanvasModulate).

signal interacted  # O jogador apertou [E] perto deste objeto.

## Texto da dica mostrada na HUD enquanto o jogador está por perto.
@export var prompt_text: String = "[E] Interagir"
## Desligado = ignora [E] e esconde a dica (ex.: painel já ativado, porta aberta).
@export var enabled: bool = true

var player_near: bool = false  # True se o jogador está dentro da área.
var _hud: LabHud = null  # HUD do labirinto (achada pelo grupo, sem caminho fixo).


## Liga os sinais de proximidade (a Area2D precisa ter máscara 2 = Player, ajustada na cena).
func _ready() -> void:
	body_entered.connect(_on_body_entered)  # Jogador entrou na área.
	body_exited.connect(_on_body_exited)  # Jogador saiu da área.
	_hud = get_tree().get_first_node_in_group(LabHud.GROUP) as LabHud  # HUD do labirinto, se existir.


## Ao sair da cena solta a dica para ela não ficar presa na tela.
func _exit_tree() -> void:
	if _hud != null and is_instance_valid(_hud):
		_hud.hide_prompt(self)


## Tecla de interagir: avisa quem escuta (e consome a tecla) se o jogador está por perto.
func _unhandled_input(event: InputEvent) -> void:
	if enabled and player_near and event.is_action_pressed(&"interagir"):
		get_viewport().set_input_as_handled()  # Consome a tecla (dois objetos juntos não disparam os dois).
		interacted.emit()


## Atualiza a dica na HUD (chame depois de mudar `prompt_text` ou `enabled`).
func refresh_prompt() -> void:
	if _hud == null or not is_instance_valid(_hud):
		return
	if player_near and enabled:
		_hud.show_prompt(self, prompt_text)
	else:
		_hud.hide_prompt(self)


## Um corpo entrou: se for o jogador, marca e mostra a dica.
func _on_body_entered(body: Node2D) -> void:
	if CombatUtils.is_player(body):
		player_near = true
		refresh_prompt()


## Um corpo saiu: basta estar no grupo do jogador (ele pode estar saindo da cena).
func _on_body_exited(body: Node2D) -> void:
	if CombatUtils.is_valid(body) and body.is_in_group(CombatUtils.GROUP_PLAYER):
		player_near = false
		refresh_prompt()
