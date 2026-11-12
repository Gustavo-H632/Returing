extends Node
## Capturas da HUD de habilidades: faixa compacta com a colinha e painel do modo comando.
## Rodar (com janela): godot --path . res://qa/ctrl_hud_shot.tscn -- <pasta_de_saida>


## Agenda a captura para o fim do quadro.
func _ready() -> void:
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Espera `n` quadros.
func _frames(n: int) -> void:
	for i: int in n:  # Cada quadro.
		await get_tree().process_frame


## Simula apertar ou soltar uma tecla.
func _tecla(keycode: Key, apertada: bool) -> void:
	var ev := InputEventKey.new()  # Evento de tecla.
	ev.physical_keycode = keycode  # Código físico.
	ev.keycode = keycode  # Código lógico.
	ev.pressed = apertada  # Apertada ou solta.
	ev.ctrl_pressed = keycode == KEY_CTRL  # Marca o Ctrl.
	Input.parse_input_event(ev)  # Envia o evento.


## Salva uma captura de tela e um recorte ampliado do canto da HUD de habilidades.
func _salvar(caminho: String) -> void:
	await RenderingServer.frame_post_draw  # Espera o quadro ser desenhado.
	var imagem: Image = get_tree().root.get_texture().get_image()  # Imagem da janela.
	imagem.save_png(caminho)  # Salva a imagem inteira.
	# Recorte ampliado do canto da HUD de habilidades (a colinha é pequena).
	# Recorta o canto.
	var canto: Image = imagem.get_region(Rect2i(imagem.get_width() - 322, imagem.get_height() - 118, 322, 118))
	# Amplia sem borrar.
	canto.resize(canto.get_width() * 3, canto.get_height() * 3, Image.INTERPOLATE_NEAREST)
	canto.save_png(caminho.replace(".png", "_zoom.png"))  # Salva o recorte.
	print("salvo ", caminho)  # Avisa.


## Monta a Fase 1 com três habilidades e tira as capturas: faixa compacta, em recarga e modo comando.
func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]  # Pasta de saída (primeiro argumento).
	var janela: Window = get_tree().root  # Janela.
	janela.mode = Window.MODE_WINDOWED  # Modo janela.
	janela.size = Vector2i(1152, 648)  # Tamanho padrão do jogo.
	await _frames(2)  # Espera dois quadros.
	RunState.reset()  # Run nova.
	var fase: Node = (load("res://Scenes/Fase1/fase_1.tscn") as PackedScene).instantiate()  # Cria a Fase 1.
	get_tree().root.add_child(fase)  # Entra na árvore.
	get_tree().current_scene = fase  # É a cena atual.
	await _frames(30)  # Espera 30 quadros.
	var player: Player = fase.find_child("Player", true, false) as Player  # Jogador.
	# Componente de habilidades.
	var hab: AbilityComponent = player.get_node("AbilityComponent") as AbilityComponent
	player.conceder_invulnerabilidade(99999.0)  # Jogador invulnerável (não morre durante o teste).
	hab.abilities = [  # Três habilidades.
		hab.catalog.find_by_id(&"escudo"),
		hab.catalog.find_by_id(&"cavaleiro_imbativel"),
		hab.catalog.find_by_id(&"passo_agil"),
	]
	hab.abilities_changed.emit()  # Avisa a HUD.
	await _frames(20)  # Espera 20 quadros.
	await _salvar(pasta + "/hud_compacta.png")  # Captura da faixa compacta.
	hab._cooldowns[&"escudo"] = 8.0  # Escudo em recarga.
	hab.cooldown_changed.emit(hab.abilities[0], 8.0, 20.0)  # Avisa a HUD.
	await _frames(10)  # Espera 10 quadros.
	await _salvar(pasta + "/hud_recarga.png")  # Captura em recarga.
	_tecla(KEY_CTRL, true)  # Aperta Ctrl.
	await _frames(2)  # Espera 2 quadros.
	_tecla(KEY_CTRL, false)  # Solta Ctrl.
	await _frames(2)  # Espera 2 quadros.
	for k: Key in [KEY_UP, KEY_DOWN]:  # Digita cima e baixo.
		_tecla(k, true)  # Aperta.
		await _frames(2)  # Espera.
		_tecla(k, false)  # Solta.
		await _frames(2)  # Espera.
	await _frames(10)  # Espera 10 quadros.
	await _salvar(pasta + "/hud_modo_comando.png")  # Captura do modo comando.
	Engine.time_scale = 1.0  # Devolve o tempo normal.
	get_tree().quit()  # Fecha o jogo.
