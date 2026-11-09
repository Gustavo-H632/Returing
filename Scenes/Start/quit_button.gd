extends PixelButton
## Botão Sair: pede o fim do jogo pelo EventBus.
## (Estende PixelButton só para ganhar o visual de hover/foco; a lógica de clique é a de sempre.)


## Liga o clique.
func _ready() -> void:  # Prepara o botão (classe base).
	super()
	# iOS e navegador não deixam o jogo se fechar sozinho (o jogador usa a tela inicial / a aba).
	if OS.has_feature("ios") or OS.has_feature("web"):  # Nesses casos o botão some.
		hide()
		return
	CombatUtils.connect_once(pressed, _on_pressed)  # Ao clicar, pede para sair.


## Pede para sair.
func _on_pressed() -> void:
	EventBus.quit_requested.emit()  # Avisa o EventBus (o Global fecha o jogo).
