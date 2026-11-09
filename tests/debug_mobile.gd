extends Node
## Abre a Fase 2, toca no botão de arma e imprime o estado dos controles de toque (depuração).
func _ready() -> void:
	var level: Node = load("res://Scenes/Fase2/Fase2.tscn").instantiate()  # Cria a fase.
	get_tree().root.add_child.call_deferred(level)  # Adiciona no fim do quadro.
	for i in 40: await get_tree().physics_frame  # Espera 40 quadros de física.
	var mc = MobileControls  # Controles de toque.
	print("shown=", mc._shown, " blocked=", mc._blocked, " player=", mc._player, " paused=", get_tree().paused, " view=", mc._view, " ativo=", mc.ativo)
	var wb: Vector2 = mc._button_center(&"weapon")  # Centro do botão de arma.
	# Quantas conexões o EventBus tem.
	print("conns=", EventBus.player_registered.get_connections().size(), " player node=", level.get_node_or_null("Player"))
	# Toque que aperta o botão.
	var e := InputEventScreenTouch.new(); e.index = 1; e.position = wb; e.pressed = true
	Input.parse_input_event(e)  # Envia.
	for i in 3: await get_tree().physics_frame  # Espera 3 quadros.
	print("fingers=", mc._fingers, " ranged=", mc.weapon_ranged)  # Estado depois do toque.
	# Toque que solta o botão.
	var e2 := InputEventScreenTouch.new(); e2.index = 1; e2.position = wb; e2.pressed = false
	Input.parse_input_event(e2)  # Envia.
	for i in 3: await get_tree().physics_frame  # Espera 3 quadros.
	print("after release fingers=", mc._fingers, " ranged=", mc.weapon_ranged)  # Estado depois de soltar.
	get_tree().quit()  # Fecha o jogo.
