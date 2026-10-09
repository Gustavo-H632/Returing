extends Button
## Botão Start: pede a troca para a cutscene pelo EventBus.

@export_file("*.tscn") var target_scene: String = "res://Scenes/Cut1/cutscene1.tscn"
## Se a troca falhar, o botão volta depois deste tempo
@export_range(0.1, 5.0, 0.1) var reenable_delay: float = 1.0


## Liga o clique.
func _ready() -> void:
	CombatUtils.connect_once(pressed, _on_pressed)


## Pede a troca de cena uma vez.
func _on_pressed() -> void:
	if disabled or not is_inside_tree():
		return  # clique repetido durante a troca
	disabled = true  # evita clique duplo
	# Timer criado antes de emitir o pedido
	get_tree().create_timer(reenable_delay).timeout.connect(_reenable)  # audit-ok: botão de menu, deve contar mesmo pausado
	EventBus.scene_change_requested.emit(target_scene)


## Reativa o botão se a troca falhou.
func _reenable() -> void:
	# Método: se o botão sumir, a conexão é desfeita sozinha
	disabled = false
