class_name Labirinto
extends Node2D
## Fase 2 (labirinto): visão limitada, chave escondida, fogo que só se atravessa em dash, puzzle e porta.
##
## Toda a arena (arte, colisões, oclusores, fogo, porta, chave, painéis, drones e rotas) está posicionada
## de forma ESTÁTICA em Labirinto.tscn. Este script só liga os sinais:
##   chave coletada -> inventário + aviso na HUD
##   [E] na porta com a chave -> MazeDoor.key_used
##   painéis na ordem certa -> PuzzleController.puzzle_solved
##   key_used E puzzle_solved -> UMA única checagem (_try_unlock) abre a porta e libera a sala nova.
## O drone e o Player são os do projeto, sem alterações de código.

signal room_unlocked  # A porta abriu: a sala nova está liberada (emitido uma única vez).

## Sala nova (destino depois da porta).
@export_file("*.tscn") var sala_nova_scene: String = "res://Scenes/Fase2/SalaNova.tscn"
## Pausa entre morrer e mostrar o game over (a HUD do projeto mostra a tela).
@export_range(0.0, 10.0, 0.1, "or_greater") var game_over_delay: float = 1.5

@export_group("Nós da cena")
@export var player: Player  # Alan Turing (o do projeto).
@export var chave: MazeKey  # Chave.
@export var porta: MazeDoor  # Porta da sala nova.
@export var puzzle: PuzzleController  # Puzzle dos 3 painéis.
@export var saida: Area2D  # Gatilho no fundo do vestíbulo, atrás da porta.
@export var hud: LabHud  # HUD do labirinto.

var has_key: bool = false  # Inventário: o jogador carrega a chave.

var _key_used: bool = false  # A chave já foi usada na porta.
var _puzzle_solved: bool = false  # O puzzle já foi resolvido.
var _unlocked: bool = false  # A sala nova já foi liberada (checagem única).
var _leaving: bool = false  # Já pediu a troca para a sala nova.


## Confere as referências, liga os sinais e anuncia o início da fase.
func _ready() -> void:
	var missing: PackedStringArray = []
	if player == null: missing.append("player")
	if chave == null: missing.append("chave")
	if porta == null: missing.append("porta")
	if puzzle == null: missing.append("puzzle")
	if saida == null: missing.append("saida")
	if hud == null: missing.append("hud")
	if not missing.is_empty():
		push_error("Labirinto: referências não atribuídas no Inspector: %s" % ", ".join(missing))
		return
	chave.collected.connect(_on_key_collected)
	porta.interacted.connect(_on_door_interacted)
	porta.key_used.connect(_on_key_used)  # Sinal key_used.
	puzzle.puzzle_solved.connect(_on_puzzle_solved)  # Sinal puzzle_solved.
	puzzle.puzzle_failed.connect(_on_puzzle_failed)
	puzzle.progress_changed.connect(_on_puzzle_progress)
	saida.body_entered.connect(_on_exit_entered)
	CombatUtils.connect_once(EventBus.player_died, _on_player_died)
	hud.set_puzzle_progress(0, puzzle.solution.size())
	_refresh_texts()
	EventBus.level_started.emit()  # Avisa a HUD e os controles do celular.


## Desliga o sinal do EventBus ao sair da cena.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.player_died, _on_player_died)


# --- Chave e porta ---

## O jogador pegou a chave: vai para o inventário e a HUD avisa.
func _on_key_collected() -> void:
	has_key = true
	hud.set_key_collected(true)
	hud.show_notice("Chave coletada! Leve-a até a porta.")
	_refresh_texts()


## [E] na porta: usa a chave, ou explica o que falta.
func _on_door_interacted() -> void:
	match porta.state:
		MazeDoor.DoorState.TRANCADA:
			if has_key:
				porta.unlock()  # Emite key_used (tratado em _on_key_used).
			else:
				hud.show_notice("Porta trancada. Procure a chave.")
		MazeDoor.DoorState.DESTRANCADA:
			hud.show_notice("Sem energia. Ligue os 3 painéis na ordem da dica.")


## A chave foi usada na porta (sinal key_used).
func _on_key_used() -> void:
	has_key = false  # A chave sai do inventário.
	_key_used = true
	hud.set_key_collected(false)
	if _puzzle_solved:
		hud.show_notice("Chave usada!")
	else:
		hud.show_notice("Chave usada! A porta ainda está sem energia.")
	_refresh_texts()
	_try_unlock()


# --- Puzzle ---

## O puzzle foi resolvido (sinal puzzle_solved).
func _on_puzzle_solved() -> void:
	_puzzle_solved = true
	hud.show_notice("Painéis alinhados!")
	_refresh_texts()
	_try_unlock()


## Ordem errada.
func _on_puzzle_failed() -> void:
	hud.show_notice("Ordem errada! Os painéis foram reiniciados.", 2.0)


## Progresso dos painéis na HUD.
func _on_puzzle_progress(count: int, total: int) -> void:
	hud.set_puzzle_progress(count, total)


# --- Sala nova ---

## CHECAGEM ÚNICA: a sala nova só abre quando a chave foi usada E o puzzle foi resolvido.
## É chamada pelos dois sinais; a primeira só confere, a segunda (que completa o par) abre.
func _try_unlock() -> void:
	if _unlocked:
		return  # Já aberta: não repete.
	if not (_key_used and _puzzle_solved):
		return  # Ainda falta um dos dois.
	_unlocked = true
	porta.open()
	hud.show_notice("Porta aberta! A sala nova está liberada.", 4.0)
	_refresh_texts()
	room_unlocked.emit()


## O jogador chegou ao fundo do vestíbulo: troca para a sala nova (só depois de liberada).
func _on_exit_entered(body: Node2D) -> void:
	if not _unlocked or _leaving or not CombatUtils.is_player(body):
		return
	_leaving = true
	EventBus.scene_change_requested.emit(sala_nova_scene)


# --- Texto da HUD ---

## Atualiza o objetivo e o texto da dica da porta conforme o progresso.
func _refresh_texts() -> void:
	if _unlocked:
		hud.set_objective("Atravesse a porta para a sala nova.")
	elif has_key:
		hud.set_objective("Leve a chave até a porta (nordeste).")
	elif _key_used and not _puzzle_solved:
		hud.set_objective("Ligue os 3 painéis na ordem da dica.")
	elif _puzzle_solved and not _key_used:
		hud.set_objective("Painéis ligados. Falta a chave.")
	else:
		hud.set_objective("Encontre a chave: está longe e no escuro.")
	if has_key and porta.state == MazeDoor.DoorState.TRANCADA:
		porta.prompt_text = "[E] Usar a chave"
	elif porta.state == MazeDoor.DoorState.TRANCADA:
		porta.prompt_text = "[E] Porta trancada"
	else:
		porta.prompt_text = "[E] Verificar a porta"
	porta.refresh_prompt()


# --- Morte ---

## O jogador morreu: depois de uma pausa a HUD do projeto mostra o game over ("Tentar de novo" recarrega a fase).
func _on_player_died() -> void:
	var timer: SceneTreeTimer = CombatUtils.game_timer(self, game_over_delay)
	if timer != null:
		timer.timeout.connect(func() -> void: EventBus.game_over.emit())
