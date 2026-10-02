class_name CutsceneController
extends Control
## Raiz da cutscene: dono do passo atual. Tudo pelo EventBus.

@export_file("*.tscn") var next_scene: String = "res://Scenes/Fase1/fase_1.tscn"

var _step: int = 0
var _step_count: int = 0
var _finished: bool = false


## Escuta os registros e o botão.
func _enter_tree() -> void:
	# Roda antes dos _ready dos filhos: nenhum registro é perdido
	EventBus.cutscene_content_registered.connect(_on_content_registered)
	EventBus.cutscene_advance_requested.connect(_on_advance_requested)


## Mostra o passo 0.
func _ready() -> void:
	if not ResourceLoader.exists(next_scene):
		push_error("CutsceneController: next_scene '%s' não existe; a cutscene não conseguirá abrir a fase." % next_scene)
	# Filhos já registraram quantos passos têm
	EventBus.cutscene_step_changed.emit(_step)


## Desconecta do EventBus.
func _exit_tree() -> void:
	if EventBus.cutscene_content_registered.is_connected(_on_content_registered):
		EventBus.cutscene_content_registered.disconnect(_on_content_registered)
	if EventBus.cutscene_advance_requested.is_connected(_on_advance_requested):
		EventBus.cutscene_advance_requested.disconnect(_on_advance_requested)


## Guarda o menor número de passos (evita índice fora).
func _on_content_registered(step_count: int) -> void:
	if step_count <= 0:
		return
	_step_count = step_count if _step_count == 0 else mini(_step_count, step_count)


## Avança o passo ou termina a cutscene.
func _on_advance_requested() -> void:
	if _finished:
		return
	if _step + 1 >= _step_count:
		if not ResourceLoader.exists(next_scene):
			return  # cena inválida: não trava o botão
		_finished = true
		EventBus.cutscene_finished.emit()
		EventBus.scene_change_requested.emit(next_scene)
		return
	_step += 1
	EventBus.cutscene_step_changed.emit(_step)
