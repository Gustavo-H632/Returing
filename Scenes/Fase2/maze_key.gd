class_name MazeKey
extends Area2D
## Chave do labirinto: o jogador encosta e ela vai para o inventário (quem escuta é a fase).

signal collected  # O jogador pegou a chave.

## Quanto a chave flutua para cima e para baixo (px de tela).
@export_range(0.0, 8.0, 0.5) var bob_height: float = 2.0
## Velocidade da flutuação.
@export_range(0.5, 8.0, 0.1) var bob_speed: float = 3.0
@export var sprite: Sprite2D  # Sprite da chave.

var _taken: bool = false  # True depois de coletada (não coleta duas vezes).
var _time: float = 0.0  # Relógio da flutuação.
var _base_y: float = 0.0  # Altura original do sprite.


## Liga a coleta e guarda a altura do sprite.
func _ready() -> void:
	add_to_group(&"lab_chave")
	body_entered.connect(_on_body_entered)
	if sprite != null:
		_base_y = sprite.position.y


## Flutua suavemente (movimento em seno, sem aleatoriedade).
func _process(delta: float) -> void:
	_time += delta
	if sprite != null:
		sprite.position.y = _base_y + roundf(sin(_time * bob_speed) * bob_height)


## O jogador encostou: coleta uma única vez.
func _on_body_entered(body: Node2D) -> void:
	if _taken or not CombatUtils.is_player(body):
		return
	_taken = true
	set_deferred(&"monitoring", false)  # Não detecta mais ninguém.
	set_process(false)
	hide()  # Some da cena (fica no inventário).
	collected.emit()
