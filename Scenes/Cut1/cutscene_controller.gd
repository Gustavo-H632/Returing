class_name CutsceneController
extends Control
## Raiz da cutscene: dono do passo atual. Tudo pelo EventBus.

# Cena que abre quando a cutscene termina (o tutorial).
@export_file("*.tscn") var next_scene: String = "res://Scenes/Tutorial/tutorial.tscn"

var _step: int = 0  # Passo atual da cutscene.
var _step_count: int = 0  # Quantos passos existem (o menor número entre imagens e textos).
var _finished: bool = false  # True depois do último passo.


## Escuta os registros e o botão.
func _enter_tree() -> void:
	# Roda antes dos _ready dos filhos: nenhum registro é perdido
	# Os filhos (imagem e texto) informam quantos passos têm.
	EventBus.cutscene_content_registered.connect(_on_content_registered)
	EventBus.cutscene_advance_requested.connect(_on_advance_requested)  # O botão pede para avançar.


## Mostra o passo 0.
func _ready() -> void:
	if not ResourceLoader.exists(next_scene):  # Cena inexistente.
		# Avisa o erro no console.
		push_error("CutsceneController: next_scene '%s' não existe; a cutscene não conseguirá abrir a fase." % next_scene)
	# Filhos já registraram quantos passos têm
	# Os filhos já registraram quantos passos têm: mostra o passo 0.
	EventBus.cutscene_step_changed.emit(_step)


## Desconecta do EventBus.
func _exit_tree() -> void:
	if EventBus.cutscene_content_registered.is_connected(_on_content_registered):
		EventBus.cutscene_content_registered.disconnect(_on_content_registered)
	if EventBus.cutscene_advance_requested.is_connected(_on_advance_requested):
		EventBus.cutscene_advance_requested.disconnect(_on_advance_requested)


## Guarda o menor número de passos (evita índice fora).
## Guarda o menor número de passos informado (evita índice fora da lista de imagens ou de textos).
func _on_content_registered(step_count: int) -> void:
	if step_count <= 0:  # Valor inválido: ignora.
		return
	# Primeiro registro vale como está; os seguintes ficam com o menor.
	_step_count = step_count if _step_count == 0 else mini(_step_count, step_count)


## Avança o passo ou termina a cutscene.
## Avança o passo; depois do último, termina a cutscene e pede a próxima cena.
func _on_advance_requested() -> void:
	if _finished:  # Já terminou: ignora.
		return
	if _step + 1 >= _step_count:  # Era o último passo.
		if not ResourceLoader.exists(next_scene):  # Cena inválida: não trava o botão.
			return  # cena inválida: não trava o botão
		_finished = true  # Marca como terminada.
		EventBus.cutscene_finished.emit()  # Avisa o botão (ele se desativa).
		EventBus.scene_change_requested.emit(next_scene)  # Pede a troca de cena.
		return
	_step += 1  # Próximo passo.
	EventBus.cutscene_step_changed.emit(_step)  # Avisa imagem e texto.
