extends TesteBase
## Editor de HUD (parte 1): abre pelo menu de pausa, arrasta e redimensiona (um dedo, pinça e slider), confere os limites,
## move as barras de status e o quadro de comandos, salva em user:// e confere o arquivo. A parte 2
## (`t_layout_reinicio.gd`) roda num processo novo e confere que o layout foi restaurado.
## Use com: -- --mobile --mobile-config=user://teste_layout.cfg

var mc: Node = null
var editor: MobileHudEditor = null
var pause_menu: Node = null


func _open_editor() -> void:
	await tap(0, mc.control_center(MobileLayout.PAUSE))
	await frames(8)
	check(get_tree().paused, "menu de pausa aberto")
	var button: Button = pause_menu.get_node("Root/Center/Panel/MainPage/EditControlsButton") as Button
	check(button != null and button.visible, "o menu de pausa tem o botão 'Editar controles' (só no celular)")
	await tap(1, button.get_global_rect().get_center())
	await frames(6)


func rodar() -> void:
	mc = get_node("/root/MobileControls")
	check(MobileSettings.path == "user://teste_layout.cfg", "usa o arquivo de preferências de teste")
	MobileSettings.wipe()
	mc.layout.load_saved()
	await set_window()
	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(60)
	var p: Player = player()
	p.conceder_invulnerabilidade(9999.0)
	pause_menu = level.get_node("Pause")
	editor = pause_menu.get_node("MobileHudEditor") as MobileHudEditor
	check(editor != null, "o menu de pausa tem o editor de HUD")
	await _open_editor()
	check(editor.is_open and mc.edit_mode, "o editor de HUD abriu e os controles de jogo pararam")
	var instruction: Label = editor.get_node("Root/Instrucao") as Label
	check(instruction.text == "Amplie e arraste os controles para adicionar do seu jeito.", "texto de instrução na fonte do jogo")
	check(editor.get_node("Root").theme == Palette.load_theme(), "a tela usa o tema do jogo (mesma fonte e caixas dos menus)")
	check(instruction.get_theme_font(&"font") == Palette.load_theme().get_default_font(), "a instrução usa a fonte padrão do jogo")
	await snap("30_editor_hud")
	var view: Vector2 = mc.view_size()
	var margins: Vector4 = mc.safe_margins()
	var layout: MobileLayout = mc.layout

	# Arrastar um controle (botão de dash) com um dedo.
	var start: Vector2 = mc.control_center(MobileLayout.DASH)
	var target: Vector2 = Vector2(700.0, 300.0)
	touch(2, start, true)
	await frames(2)
	drag(2, start.lerp(target, 0.5))
	await frames(2)
	drag(2, target)
	await frames(2)
	touch(2, start, false)
	await frames(2)
	check(editor.selected == MobileLayout.DASH, "tocar no controle o seleciona")
	check(mc.control_center(MobileLayout.DASH).distance_to(target) < 4.0, "arrastar move o botão de dash para %s (%s)" % [target, mc.control_center(MobileLayout.DASH)])

	# Não sai da tela: arrastar para fora fica preso na borda.
	for far: Vector2 in [Vector2(-900, -900), Vector2(5000, 5000), Vector2(5000, -900), Vector2(-900, 5000)]:
		editor.move_to(MobileLayout.DASH, far)
		var rect: Rect2 = mc.control_rect(MobileLayout.DASH)
		check(rect.position.x >= margins.x - 0.5 and rect.position.y >= margins.y - 0.5 \
				and rect.end.x <= view.x - margins.z + 0.5 and rect.end.y <= view.y - margins.w + 0.5,
				"botão fica dentro da tela ao arrastar para %s (%s)" % [far, rect])
	editor.move_to(MobileLayout.DASH, target)

	# Pinça: dois dedos sobre o controle selecionado.
	var base_scale: float = layout.get_scale(MobileLayout.DASH)
	var c: Vector2 = mc.control_center(MobileLayout.DASH)
	touch(3, c, true)
	touch(4, c + Vector2(40, 0), true)
	await frames(2)
	drag(4, c + Vector2(80, 0))
	await frames(2)
	touch(4, c + Vector2(80, 0), false)
	touch(3, c, false)
	await frames(2)
	var grown: float = layout.get_scale(MobileLayout.DASH)
	check(grown > base_scale * 1.5, "pinça abrindo amplia o controle (%.2f -> %.2f)" % [base_scale, grown])
	c = mc.control_center(MobileLayout.DASH)
	touch(3, c, true)
	touch(4, c + Vector2(200, 0), true)
	await frames(2)
	drag(4, c + Vector2(2, 0))
	await frames(2)
	touch(4, c + Vector2(2, 0), false)
	touch(3, c, false)
	await frames(2)
	check(is_equal_approx(layout.get_scale(MobileLayout.DASH), MobileLayout.MIN_SCALE), "pinça fechando respeita o tamanho mínimo (%.2f)" % layout.get_scale(MobileLayout.DASH))
	editor.select(MobileLayout.DASH)
	editor.set_selected_scale(99.0)
	check(is_equal_approx(layout.get_scale(MobileLayout.DASH), MobileLayout.MAX_SCALE), "o tamanho máximo é respeitado (%.2f)" % layout.get_scale(MobileLayout.DASH))
	var rect_big: Rect2 = mc.control_rect(MobileLayout.DASH)
	check(rect_big.position.x >= margins.x - 0.5 and rect_big.end.x <= view.x - margins.z + 0.5, "ampliado ainda cabe na tela")

	# Slider.
	editor._slider.value = 1.2
	check(is_equal_approx(layout.get_scale(MobileLayout.DASH), 1.2), "o slider muda o tamanho do controle selecionado")

	# Barras de status e quadro de comandos também se movem e se redimensionam.
	var hud: GameHUD = level.get_node("HUD") as GameHUD
	var bar_before: Vector2 = hud.player_health_bar.global_position
	var status_c: Vector2 = mc.control_center(MobileLayout.STATUS)
	touch(5, status_c, true)
	await frames(2)
	drag(5, status_c + Vector2(300.0, 120.0))
	await frames(2)
	touch(5, status_c + Vector2(300.0, 120.0), false)
	await frames(3)
	check(editor.selected == MobileLayout.STATUS, "tocar nas barras de status as seleciona")
	check(hud.player_health_bar.global_position.distance_to(bar_before) > 100.0, "as barras de status de verdade acompanham o arraste (%s -> %s)" % [bar_before, hud.player_health_bar.global_position])
	editor.set_selected_scale(0.8)
	await frames(3)
	check(hud.player_health_bar.size.x < 240.0, "as barras de status são redimensionadas (largura %.0f)" % hud.player_health_bar.size.x)
	var board_before: Rect2 = mc.control_rect(MobileLayout.BOARD)
	editor.select(MobileLayout.BOARD)
	editor.move_to(MobileLayout.BOARD, Vector2(500.0, 300.0))
	editor.set_selected_scale(0.7)
	check(mc.control_rect(MobileLayout.BOARD).position != board_before.position, "o quadro de comandos é arrastável")
	check(is_equal_approx(layout.get_scale(MobileLayout.BOARD), 0.7), "o quadro de comandos é redimensionável")

	# Restaurar padrão volta ao print.
	var buttons: Node = editor.get_node("Root/Painel")
	var restore: Button = buttons.find_child("Restore", true, false) as Button
	check(restore != null and restore.text == "Restaurar padrão", "botão 'Restaurar padrão'")
	await tap(6, restore.get_global_rect().get_center())
	await frames(4)
	check(layout.is_default(), "Restaurar padrão volta ao layout do print")
	check(mc.control_center(MobileLayout.DASH).distance_to(Vector2(0.763, 0.852) * view) < 1.0, "botão de dash de volta à posição do print")

	# Edita de novo e salva.
	editor.select(MobileLayout.DASH)
	editor.move_to(MobileLayout.DASH, Vector2(900.0, 250.0))
	editor.set_selected_scale(1.3)
	editor.select(MobileLayout.MOVE)
	editor.move_to(MobileLayout.MOVE, Vector2(300.0, 500.0))
	var save: Button = buttons.find_child("Save", true, false) as Button
	check(save != null and save.text == "Salvar", "botão 'Salvar'")
	await tap(7, save.get_global_rect().get_center())
	await frames(6)
	check(not editor.is_open and not mc.edit_mode, "Salvar fecha o editor e devolve os controles de jogo")
	check(pause_menu.get_node("Root").visible, "volta ao menu de pausa")
	check(FileAccess.file_exists("user://teste_layout.cfg"), "arquivo user://teste_layout.cfg gravado")
	var cfg: ConfigFile = ConfigFile.new()
	check(cfg.load("user://teste_layout.cfg") == OK, "o arquivo é um ConfigFile válido")
	check(is_equal_approx(float(cfg.get_value("layout", "dash_scale", 0.0)), 1.3), "escala salva = 1.3")
	var saved_pos: Vector2 = cfg.get_value("layout", "dash_pos", Vector2.ZERO)
	check(saved_pos.distance_to(Vector2(900.0, 250.0) / view) < 0.01, "posição salva = onde o botão foi solto")
	# Com o jogo de volta, os controles funcionam na nova posição.
	pause_menu.resume()
	await frames(10)
	var swung: bool = false
	touch(8, mc.control_center(MobileLayout.DASH), true)
	for i: int in 12:
		await get_tree().physics_frame
		if p.state == Player.State.DASH:
			swung = true
	touch(8, mc.control_center(MobileLayout.DASH), false)
	check(swung, "o botão de dash funciona na posição nova (%s)" % mc.control_center(MobileLayout.DASH))
