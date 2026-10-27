extends Button
## Botão Sair: pede o fim do jogo pelo EventBus.


## Liga o clique.
func _ready() -> void:
	CombatUtils.connect_once(pressed, _on_pressed)


## Pede para sair.
func _on_pressed() -> void:
	EventBus.quit_requested.emit()
