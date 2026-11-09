extends Node
## Capturas de telas de UI no formato de celular: godot --path . res://tests/ui_shot.tscn -- --mobile <cena> <png> [acao]
## acao: pause | quiz | gameover | complete

## Espera `n` quadros de física.
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Agenda a captura para o fim do quadro.
func _ready() -> void:
	_run.call_deferred()

## Abre uma fase no formato de celular, executa a ação pedida (pausa, quiz, game over, fase concluída) e salva a captura.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()  # Argumentos.
	var win: Window = get_tree().root  # Janela.
	win.mode = Window.MODE_WINDOWED  # Modo janela.
	win.size = Vector2i(1500, 675)  # Tamanho de celular (paisagem).
	await get_tree().process_frame  # Espera um quadro.
	var level: Node = load(args[1]).instantiate()  # Cria a fase.
	get_tree().root.add_child(level)  # Entra na árvore.
	get_tree().current_scene = level  # É a cena atual.
	await frames(50)  # Espera 50 quadros.
	var action: String = args[3] if args.size() > 3 else ""  # Ação pedida.
	match action:  # Cada ação.
		"pause":  # Pausa.
			var e := InputEventAction.new()
			e.action = &"Pause"
			e.pressed = true
			Input.parse_input_event(e)
			await frames(10)
		"quiz":  # Quiz.
			var player: Player = level.get_node("Player")
			player.global_position = level.get_node("Terminal").global_position + Vector2(0, 40)
			await frames(20)
			level.get_node("Terminal")._activate()
			await frames(20)
		"gameover":  # Game over.
			EventBus.game_over.emit()
			await frames(10)
		"wait":  # Espera 420 quadros.
			await frames(420)
		"complete":  # Fase concluída.
			EventBus.level_completed.emit("")
			await frames(10)
	await RenderingServer.frame_post_draw  # Espera o quadro ser desenhado.
	get_tree().root.get_texture().get_image().save_png(args[2])  # Salva.
	print("saved ", args[2])  # Avisa.
	get_tree().quit()  # Fecha.
