extends Node
## Captura as telas de menu para conferir o visual.
## godot --path . res://qa/menus_shot.tscn -- <acao> <png> [largura altura]
## acao: menu | menu_settings | menu_down | pause | pause_settings | levelup | tutorial | cutscene | complete | gameover | quiz

const LEVEL_1: String = "res://Scenes/Fase1/fase_1.tscn"  # Fase 1.
const LEVEL_2: String = "res://Scenes/Fase2/Fase2.tscn"  # Fase 2.


## Espera `n` quadros.
func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## Agenda a captura para o fim do quadro.
func _ready() -> void:
	_run.call_deferred()


## Lê os argumentos (ação, arquivo, tamanho), prepara a janela, abre a tela pedida e salva a captura.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()  # Argumentos de linha de comando.
	var action: String = args[0]  # Qual tela capturar.
	var png: String = args[1]  # Arquivo de saída.
	var width: int = int(args[2]) if args.size() > 3 else 1152  # Largura (padrão 1152).
	var height: int = int(args[3]) if args.size() > 3 else 648  # Altura (padrão 648).
	var win: Window = get_tree().root  # Janela.
	win.mode = Window.MODE_WINDOWED  # Modo janela.
	win.size = Vector2i(width, height)  # Tamanho pedido.
	await _frames(2)  # Espera dois quadros.

	match action:  # Cada ação abre uma tela diferente.
		"menu":  # Menu principal.
			await _open("res://Scenes/Start/menu_start.tscn")
		"menu_settings":  # Configurações do menu.
			var menu: Node = await _open("res://Scenes/Start/menu_start.tscn")
			# Aperta o botão de configurações.
			menu.get_node("Center/Column/MenuPanel/Buttons/Settings_button").pressed.emit()
			await _frames(20)
		"menu_down":  # Menu com o foco movido pelo teclado.
			# navega com o teclado: uma vez para baixo (foco em Configurações)
			await _open("res://Scenes/Start/menu_start.tscn")
			_press(&"ui_down")
			await _frames(20)
		"pause":  # Menu de pausa.
			await _open(LEVEL_1)
			_press(&"Pause")
			await _frames(25)
		"pause_settings":  # Configurações dentro da pausa.
			var level: Node = await _open(LEVEL_1)
			_press(&"Pause")
			await _frames(25)
			level.get_node("Pause/Root/Center/Panel/MainPage/SettingsButton").pressed.emit()
			await _frames(20)
		"levelup":  # Menu de level-up com três cartas de teste.
			var menu: LevelUpMenu = LevelUpMenu.new()
			menu.input_delay = 0.0
			get_tree().root.add_child(menu)
			var offer: Array[AbilityData] = []
			for file: String in ["cavaleiro_imbativel", "tiro_perfurante", "cura"]:
				offer.append(load("res://abilities/data/%s.tres" % file) as AbilityData)
			var owned: Array[AbilityData] = [offer[2]]
			menu.open(3, offer, owned)
			await _frames(60)
		"tutorial":  # Tutorial.
			await _open("res://Scenes/Tutorial/tutorial.tscn")
		"cutscene":  # Cutscene.
			await _open("res://Scenes/Cut1/cutscene1.tscn")
			await _frames(10)
		"complete":  # Fase concluída.
			await _open(LEVEL_1)
			EventBus.level_completed.emit(LEVEL_2)
			await _frames(20)
		"gameover":  # Game over.
			await _open(LEVEL_1)
			EventBus.game_over.emit()
			await _frames(20)
		"quiz":  # Quiz da Fase 2.
			var level: Node = await _open(LEVEL_2)
			var player: Player = level.get_node("Player")
			player.global_position = level.get_node("Terminal").global_position + Vector2(0, 40)
			await _frames(20)
			level.get_node("Terminal")._activate()
			await _frames(30)
	await RenderingServer.frame_post_draw  # Espera o quadro ser desenhado.
	get_tree().root.get_texture().get_image().save_png(png)  # Salva a imagem.
	print("saved ", png)  # Avisa.
	get_tree().quit()  # Fecha o jogo.


## Abre uma cena como cena atual, espera ela ficar pronta e a devolve.
func _open(path: String) -> Node:
	var scene: Node = (load(path) as PackedScene).instantiate()  # Cria a cena.
	get_tree().root.add_child(scene)  # Entra na árvore.
	get_tree().current_scene = scene  # É a cena atual.
	await _frames(45)  # Espera 45 quadros.
	return scene


## Simula o apertar de uma ação do Input Map.
func _press(action: StringName) -> void:
	var event: InputEventAction = InputEventAction.new()  # Evento de ação.
	event.action = action  # Qual ação.
	event.pressed = true  # Apertada.
	Input.parse_input_event(event)  # Envia.
