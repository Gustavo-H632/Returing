extends PixelButton
## Botão Avançar da cutscene: só emite o pedido no EventBus.
## (Estende PixelButton só para ganhar o visual de hover/foco.)


## Escuta o fim da cutscene.
func _enter_tree() -> void:
	EventBus.cutscene_finished.connect(_on_cutscene_finished)  # No fim da cutscene o botão é desativado.


## Liga o clique.
func _ready() -> void:
	super()  # Prepara o botão (classe base).
	disabled = false  # Garante que começa ativo.
	CombatUtils.connect_once(pressed, _on_pressed)  # Ao clicar, pede para avançar.


## Desconecta do EventBus.
func _exit_tree() -> void:
	# Só desconecta se ainda estiver conectado.
	if EventBus.cutscene_finished.is_connected(_on_cutscene_finished):
		EventBus.cutscene_finished.disconnect(_on_cutscene_finished)  # Desliga o sinal.


## Pede para avançar.
func _on_pressed() -> void:
	EventBus.cutscene_advance_requested.emit()  # Avisa o controlador da cutscene pelo EventBus.


## Desativa o botão no fim.
func _on_cutscene_finished() -> void:
	disabled = true  # evita cliques extras durante a troca de cena
