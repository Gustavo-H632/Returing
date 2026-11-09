extends TextureRect
## Fundo da cutscene: mostra a imagem do passo atual.

## Imagens de cada passo (Inspector)
@export var images: Array[Texture2D] = [
	preload("res://sprites/Cutscenes/London.png"),
	preload("res://sprites/Cutscenes/London.png"),
	preload("res://sprites/Cutscenes/ruined_london.svg"),
	preload("res://sprites/Cutscenes/ruined_london.svg"),
	preload("res://sprites/Cutscenes/Lab-Turing.png"),
]


## Escuta a troca de passo.
func _enter_tree() -> void:
	# Quando o passo muda, mostra a imagem correspondente.
	EventBus.cutscene_step_changed.connect(show_image)


## Informa quantas imagens existem.
func _ready() -> void:
	# Avisa quantas imagens existem (o controlador usa o menor número entre imagens e textos).
	EventBus.cutscene_content_registered.emit(images.size())


## Desconecta do EventBus.
func _exit_tree() -> void:
	if EventBus.cutscene_step_changed.is_connected(show_image):  # Só desconecta se ainda estiver conectado.
		EventBus.cutscene_step_changed.disconnect(show_image)  # Desliga o sinal.


## Mostra a imagem do passo (índice limitado).
func show_image(step: int = 0) -> void:
	if images.is_empty():  # Sem imagens: nada a mostrar.
		return
	# Usa o passo limitado ao tamanho da lista (evita índice fora).
	texture = images[clampi(step, 0, images.size() - 1)]
