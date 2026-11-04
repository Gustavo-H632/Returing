extends Control
## Tela de controles: mostra a imagem e segue para a próxima cena pelo EventBus.

## Cena que abre depois do tutorial.
@export_file("*.tscn") var next_scene: String = "res://Scenes/Fase1/fase_1.tscn"
## Se a troca falhar, o botão volta depois deste tempo.
@export_range(0.1, 5.0, 0.1) var reenable_delay: float = 1.0

@onready var _continue_button: Button = $ContinueButton

## Evita pedir a troca de cena duas vezes.
var _leaving: bool = false


## Liga o clique e deixa o botão focado (Enter/Espaço também continuam).
func _ready() -> void:
	CombatUtils.connect_once(_continue_button.pressed, _on_continue_pressed)
	_continue_button.grab_focus()


## Pede a troca de cena uma vez.
func _on_continue_pressed() -> void:
	if _leaving or not is_inside_tree():
		return  # clique repetido durante a troca
	_leaving = true
	_continue_button.disabled = true
	# Timer criado antes de emitir o pedido
	get_tree().create_timer(reenable_delay).timeout.connect(_reenable)  # audit-ok: botão de menu, deve contar mesmo pausado
	EventBus.scene_change_requested.emit(next_scene)


## Reativa o botão se a troca falhou.
func _reenable() -> void:
	_leaving = false
	_continue_button.disabled = false
