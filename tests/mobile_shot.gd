extends Node
## Tira capturas do modo celular: godot --path . res://tests/mobile_shot.tscn -- --mobile <cena> <prefixo> [pc]

var root: Window = null  # Janela raiz.

## Converte uma posição da tela lógica para a da janela.
func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos  # Aplica a transformação final.

## Simula um toque (apertar ou soltar) na posição lógica.
func touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()  # Evento de toque.
	e.index = index  # Dedo.
	e.position = _to_window(pos)  # Posição da janela.
	e.pressed = pressed  # Apertado ou solto.
	Input.parse_input_event(e)  # Envia.

## Simula o arrastar de um dedo.
func drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()  # Evento de arrasto.
	e.index = index  # Dedo.
	e.position = _to_window(pos)  # Posição da janela.
	Input.parse_input_event(e)  # Envia.

## Espera `n` quadros de física.
func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

## Salva uma captura da janela.
func snap(path: String) -> void:
	await RenderingServer.frame_post_draw  # Espera o quadro ser desenhado.
	root.get_texture().get_image().save_png(path)  # Salva.
	print("saved ", path)  # Avisa.

## Guarda a janela e agenda a captura.
func _ready() -> void:
	root = get_tree().root
	_run.call_deferred()

## Abre a fase no modo celular e captura: início, carga do tiro na diagonal e tiro em voo.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()  # Argumentos.
	var scene_path: String = args[1]  # Cena.
	var prefix: String = args[2]  # Prefixo dos arquivos.
	var win: Window = root  # Janela.
	win.mode = Window.MODE_WINDOWED  # Modo janela.
	win.size = Vector2i(1500, 675)  # Tamanho de celular (paisagem).
	await get_tree().process_frame  # Espera um quadro.
	var level: Node = load(scene_path).instantiate()  # Cria a fase.
	root.add_child(level)  # Entra na árvore.
	get_tree().current_scene = level  # como no jogo: tiros e efeitos nascem sob a fase
	await frames(60)  # Espera 60 quadros.
	var mc = MobileControls  # Controles de toque.
	var _player: Player = level.get_node("Player")  # Jogador.
	await snap(prefix + "_a_start.png")  # Captura do início.
	if mc.ativo:  # Modo celular ligado.
		var c: Vector2 = mc._rest_aim()  # Centro do analógico de mira.
		var sword_mode: bool = args.size() > 3 and args[3] == "sword"  # Modo espada?
		if not sword_mode:  # Troca para o tiro.
			touch(1, mc._button_center(&"weapon"), true)  # Toca no botão de arma.
			await frames(2)
			touch(1, mc._button_center(&"weapon"), false)  # Solta.
			await frames(2)
		touch(0, c + Vector2(55, -30), true)  # Segura o analógico na diagonal.
		await frames(50)  # Espera a carga.
		await snap(prefix + "_b_charging_diag.png")  # Captura da carga.
		touch(0, c + Vector2(55, -30), false)  # Solta.
		await frames(3)  # Espera.
		await snap(prefix + "_c_shot_flying.png")  # Captura do tiro em voo.
	else:  # Sem celular: usa o botão do mouse.
		Input.action_press(&"charge_shoot")  # Carrega o tiro.
		await frames(50)  # Espera.
		await snap(prefix + "_b_charging.png")  # Captura.
		Input.action_release(&"charge_shoot")  # Solta.
		await frames(10)  # Espera.
		await snap(prefix + "_c_shot_flying.png")  # Captura.
	get_tree().quit()  # Fecha o jogo.
