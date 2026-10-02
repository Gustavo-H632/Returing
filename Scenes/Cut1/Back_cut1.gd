extends TextureRect
## Fundo da cutscene: mostra a imagem do passo atual.

## Imagens de cada passo (Inspector)
@export var images: Array[Texture2D] = [
	preload("res://Sprites/Cutscenes/London.png"),
	preload("res://Sprites/Cutscenes/pxArt.png"),
	preload("res://Sprites/Tilemap/TheComputer.png"),
	preload("res://icon.svg"),
	preload("res://Sprites/Cutscenes/Lab-Turing.png"),
]


## Escuta a troca de passo.
func _enter_tree() -> void:
	EventBus.cutscene_step_changed.connect(show_image)


## Informa quantas imagens existem.
func _ready() -> void:
	EventBus.cutscene_content_registered.emit(images.size())


## Desconecta do EventBus.
func _exit_tree() -> void:
	if EventBus.cutscene_step_changed.is_connected(show_image):
		EventBus.cutscene_step_changed.disconnect(show_image)


## Mostra a imagem do passo (índice limitado).
func show_image(step: int = 0) -> void:
	if images.is_empty():
		return
	texture = images[clampi(step, 0, images.size() - 1)]
