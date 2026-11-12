extends TesteBase
## Cena após o Turing entrar no cristal (CrystalTransition) no celular: continua no estilo do tutorial
## (tela preta, fala em azul, Dialogue.Style.VOICE). Captura a tela durante a primeira fala.

var _next: String = ""


func rodar() -> void:
	await set_window()
	load_level("res://Scenes/Fase1/fase_1.tscn")  # Fundo qualquer: a transição roda em cima da cena atual.
	await frames(20)
	var changes: Array[String] = []
	EventBus.scene_change_requested.connect(func(path: String) -> void: changes.append(path))
	var transition: CrystalTransition = CrystalTransition.new()
	level.add_child(transition)
	transition.start()
	await real_seconds(6.0)  # glitch + chiado + fundo preto + primeira fala.
	var dialogues: Array[Node] = get_tree().root.find_children("*", "Dialogue", true, false)
	check(not dialogues.is_empty(), "a fala do cristal está na tela (Dialogue)")
	await snap("71_cristal_mobile")
	var center: Color = get_tree().root.get_texture().get_image().get_pixel(1100, 600) if DisplayServer.get_name() != "headless" else Color.BLACK
	check(center.get_luminance() < 0.05, "o fundo é preto (%s)" % [center])
