class_name MazeDoor
extends LabInteractable
## Porta do labirinto. Três estados: trancada -> destrancada (chave usada) -> aberta (sala liberada).
## A porta só ABRE de verdade quando a fase confirma chave usada E puzzle resolvido.

signal key_used  # A chave foi usada na porta (ela passou a "destrancada").

enum DoorState { TRANCADA, DESTRANCADA, ABERTA }

@export_group("Texturas (uma por estado)")
@export var tex_trancada: Texture2D
@export var tex_destrancada: Texture2D
@export var tex_aberta: Texture2D

@export_group("Referências (já ligadas na cena)")
@export var sprite: Sprite2D  # Sprite da porta.
@export var corpo_colisao: CollisionShape2D  # Colisão que fecha a passagem.
@export var oclusor: LightOccluder2D  # Oclusor de luz enquanto a porta está fechada.

var state: DoorState = DoorState.TRANCADA  # Estado atual.


## Entra no grupo de depuração e mostra a arte do estado inicial.
func _ready() -> void:
	super._ready()
	add_to_group(&"lab_porta")
	_apply_state()


## Usa a chave: TRANCADA -> DESTRANCADA. Devolve false se a porta já não estava trancada.
func unlock() -> bool:
	if state != DoorState.TRANCADA:
		return false
	state = DoorState.DESTRANCADA
	_apply_state()
	key_used.emit()
	return true


## Abre a porta de vez (some a colisão e o oclusor). Só a fase chama isto, depois da checagem única.
func open() -> void:
	if state == DoorState.ABERTA:
		return
	state = DoorState.ABERTA
	_apply_state()


## Troca a arte, a colisão e o oclusor conforme o estado.
func _apply_state() -> void:
	var aberta: bool = state == DoorState.ABERTA
	if sprite != null:
		match state:
			DoorState.TRANCADA:
				sprite.texture = tex_trancada
			DoorState.DESTRANCADA:
				sprite.texture = tex_destrancada
			DoorState.ABERTA:
				sprite.texture = tex_aberta
	if corpo_colisao != null:
		corpo_colisao.set_deferred(&"disabled", aberta)  # Aberta = a passagem fica livre.
	if oclusor != null:
		oclusor.visible = not aberta  # Aberta = a luz passa para o vestíbulo.
	enabled = not aberta
	refresh_prompt()
