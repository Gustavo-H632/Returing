class_name LabHud
extends CanvasLayer
## HUD própria do labirinto: objetivo, inventário (chave), progresso do puzzle, avisos curtos e a dica "[E]".
## Fica numa CanvasLayer, por isso o escuro do CanvasModulate não afeta estes textos.
## A HUD principal (vida, game over, fase concluída) continua sendo a do projeto (ui/hud/hud.tscn).

## Grupo pelo qual os objetos interativos acham esta HUD.
const GROUP: StringName = &"lab_hud"
## Opacidade do ícone da chave com o inventário vazio.
const KEY_EMPTY_ALPHA: float = 0.18

## Quanto tempo um aviso fica na tela antes de sumir.
@export_range(0.5, 10.0, 0.1) var notice_time: float = 3.0

@export_group("Referências (já ligadas na cena)")
@export var notice_label: Label  # Aviso curto no centro de baixo.
@export var prompt_label: Label  # Dica "[E] ...".
@export var objective_label: Label  # Objetivo atual (canto de cima, à esquerda).
@export var puzzle_label: Label  # Progresso dos painéis.
@export var key_slot: Control  # Caixa do inventário (canto de cima, à direita).
@export var key_icon: TextureRect  # Ícone da chave dentro da caixa.

var _prompt_owner: Object = null  # Quem pediu a dica atual (só ele pode apagá-la).
var _notice_tween: Tween = null  # Animação do aviso (guardada para cancelar).


## Registra a HUD no grupo já ao entrar na árvore (antes do _ready dos objetos interativos, que a procuram).
func _enter_tree() -> void:
	add_to_group(GROUP)


## Começa com tudo limpo.
func _ready() -> void:
	SafeArea.fit(get_node_or_null(^"Raiz") as Control)  # Celular: textos e slot da chave dentro da área segura.
	SafeArea.stack_top_band(get_node_or_null(^"Raiz") as Control, [objective_label, puzzle_label], key_slot)  # fora das barras de status e da pausa
	if notice_label != null:
		notice_label.modulate.a = 0.0
	if prompt_label != null:
		prompt_label.hide()
	if puzzle_label != null:
		puzzle_label.hide()
	set_key_collected(false)


## Mostra um aviso curto (some sozinho). `seconds` <= 0 usa `notice_time`.
func show_notice(text: String, seconds: float = -1.0) -> void:
	if notice_label == null:
		return
	if _notice_tween != null and _notice_tween.is_valid():
		_notice_tween.kill()
	notice_label.text = text
	notice_label.modulate.a = 1.0
	_notice_tween = create_tween()
	_notice_tween.tween_interval(seconds if seconds > 0.0 else notice_time)
	_notice_tween.tween_property(notice_label, "modulate:a", 0.0, 0.4)


## Mostra a dica de interação pedida por `owner`.
func show_prompt(owner_node: Object, text: String) -> void:
	if prompt_label == null:
		return
	_prompt_owner = owner_node
	prompt_label.text = text
	prompt_label.show()


## Esconde a dica, mas só se ela ainda é de `owner` (outro objeto pode ter assumido).
func hide_prompt(owner_node: Object) -> void:
	if prompt_label != null and _prompt_owner == owner_node:
		_prompt_owner = null
		prompt_label.hide()


## Inventário: acende o ícone da chave quando o jogador a carrega.
func set_key_collected(has_key: bool) -> void:
	if key_icon != null:
		key_icon.modulate = Color(1.0, 1.0, 1.0, 1.0 if has_key else KEY_EMPTY_ALPHA)


## Texto do objetivo atual.
func set_objective(text: String) -> void:
	if objective_label != null:
		objective_label.text = text


## Progresso dos painéis ("Painéis 1/3"). `total` <= 0 esconde o texto.
func set_puzzle_progress(count: int, total: int) -> void:
	if puzzle_label == null:
		return
	puzzle_label.visible = total > 0
	puzzle_label.text = "Painéis %d/%d" % [count, total]
