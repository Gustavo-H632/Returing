class_name CamaraPorta
extends Node2D
## Porta da Câmara de Provas: trancada (com o contador de máquinas restantes) ou aberta.
## A arte e a colisão estão posicionadas de forma estática no .tscn; a fase só chama `abrir()` e `definir_restantes()`.

signal aberta  # A porta abriu (emitido uma vez).

@export_group("Estado")
## True = a porta já nasce aberta (passagem entre salas sem desafio).
@export var aberta_ao_iniciar: bool = false

@export_group("Texturas")
@export var tex_trancada: Texture2D  # Porta fechada (com a tela do contador).
@export var tex_aberta: Texture2D  # Só os batentes.

@export_group("Referências (já ligadas na cena)")
@export var sprite: Sprite2D  # Arte da porta.
@export var colisao: CollisionShape2D  # Fecha a passagem (camada 1) enquanto trancada.
@export var contador: Label  # Número de máquinas restantes, sobre a tela da porta.

var esta_aberta: bool = false  # Estado atual.


## Mostra a arte do estado inicial.
func _ready() -> void:
	add_to_group(&"camara_porta")
	_aplicar(aberta_ao_iniciar)


## Abre a porta (some a colisão e o contador).
func abrir() -> void:
	if esta_aberta:
		return
	_aplicar(true)
	aberta.emit()


## Número de máquinas que ainda faltam para esta porta abrir.
func definir_restantes(n: int) -> void:
	if contador != null:
		contador.text = str(maxi(n, 0))


## Troca a arte, a colisão e o contador conforme o estado.
func _aplicar(abrir_agora: bool) -> void:
	esta_aberta = abrir_agora
	if sprite != null:
		sprite.texture = tex_aberta if abrir_agora else tex_trancada
	if colisao != null:
		colisao.set_deferred(&"disabled", abrir_agora)  # Aberta = passagem livre.
	if contador != null:
		contador.visible = not abrir_agora
