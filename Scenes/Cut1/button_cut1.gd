extends Button
## Botão Avançar da cutscene: só emite o pedido no EventBus.


## Escuta o fim da cutscene.
func _enter_tree() -> void:
	EventBus.cutscene_finished.connect(_on_cutscene_finished)


## Liga o clique.
func _ready() -> void:
	disabled = false
	CombatUtils.connect_once(pressed, _on_pressed)


## Desconecta do EventBus.
func _exit_tree() -> void:
	if EventBus.cutscene_finished.is_connected(_on_cutscene_finished):
		EventBus.cutscene_finished.disconnect(_on_cutscene_finished)


## Pede para avançar.
func _on_pressed() -> void:
	EventBus.cutscene_advance_requested.emit()


## Desativa o botão no fim.
func _on_cutscene_finished() -> void:
	disabled = true  # evita cliques extras durante a troca de cena
