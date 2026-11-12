extends TesteBase
## REGRESSÃO NO COMPUTADOR (modo celular desligado): nenhum controle de toque aparece, teclado/mouse/atalhos
## funcionam como antes, o layout das barras é o original e os menus não ganham nada de celular.
## Rode SEM --mobile.

var p: Player = null


func rodar() -> void:
	var mc: Node = get_node("/root/MobileControls")
	check(not Platform.is_mobile() and Platform.is_desktop(), "Platform: computador (is_mobile=false, is_desktop=true)")
	check(Platform.platform_name() in ["windows", "linux", "macos"], "nome da plataforma é de computador (%s)" % Platform.platform_name())
	check(not mc.ativo and not mc.visible, "MobileControls inativo e invisível no computador")
	check(mc.get_node_or_null("TouchCanvas") == null, "nenhum canvas de toque foi criado")
	check(Platform.sprite_scale == 1.0 and Platform.camera_zoom == 1.0 and not Platform.aim_assist and Platform.min_shot_charge == 0.0,
			"ajustes de sprite, câmera e mira do computador inalterados")
	# O mouse continua ligado aos ataques (no celular esses eventos são removidos).
	check(InputMap.action_get_events(&"attack_sword").size() >= 1 and InputMap.action_get_events(&"charge_shoot").size() >= 1,
			"botões do mouse continuam ligados à espada e ao tiro")
	check(InputMap.has_action(&"move_up") and InputMap.has_action(&"dash") and InputMap.has_action(&"command_mode"), "ações do InputMap intactas")
	await set_window()
	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(60)
	p = player()
	p.conceder_invulnerabilidade(9999.0)
	check(p != null, "jogador existe")
	check(p.scale.is_equal_approx(Vector2.ONE) or p.scale == Vector2.ONE * 1.0, "sprites no tamanho original (%s)" % p.scale)
	check(not mc._shown and not mc._pause_shown, "nenhum controle de toque (joysticks/botões/pausa) aparece")
	# HUD no lugar original: barras ancoradas embaixo à esquerda.
	var hud: GameHUD = level.get_node("HUD") as GameHUD
	check(is_equal_approx(hud.player_health_bar.anchor_top, 1.0), "barra de vida continua ancorada embaixo (layout original)")
	var board: Node = p.get_node("AbilitiesUI").get_node("CommandBoard")
	check(not board.visible, "quadro de comandos do celular não aparece")
	# Toques são ignorados: um toque onde ficaria o joystick não move nada.
	var start: Vector2 = p.global_position
	touch(0, Vector2(157, 520), true)
	await frames(20)
	touch(0, Vector2(157, 520), false)
	check(p.global_position.distance_to(start) < 2.0, "toque de tela não move o jogador no computador")
	# Teclado: WASD (ações) move.
	for pair: Array in [[&"move_right", Vector2.RIGHT], [&"move_down", Vector2.DOWN], [&"move_left", Vector2.LEFT], [&"move_up", Vector2.UP]]:
		var s: Vector2 = p.global_position
		Input.action_press(pair[0])
		await frames(15)
		Input.action_release(pair[0])
		check((p.global_position - s).dot(pair[1]) > 10.0, "tecla %s move o jogador" % pair[0])
		await frames(8)
	# Dash (Espaço).
	var dashed: bool = false
	Input.action_press(&"dash")
	for i: int in 8:
		await get_tree().physics_frame
		if p.state == Player.State.DASH:
			dashed = true
	Input.action_release(&"dash")
	check(dashed, "ação de dash (Espaço) funciona")
	await frames(40)
	# Espada (clique esquerdo = ação attack_sword).
	var swung: bool = false
	Input.action_press(&"attack_sword")
	for i: int in 8:
		await get_tree().physics_frame
		if p.state == Player.State.ATTACK_MELEE:
			swung = true
	Input.action_release(&"attack_sword")
	check(swung, "ação de espada (clique esquerdo) funciona")
	await frames(40)
	# Tiro (clique direito): segura e solta.
	var charging: bool = false
	Input.action_press(&"charge_shoot")
	for i: int in 12:
		await get_tree().physics_frame
		if p.state == Player.State.ATTACK_RANGED:
			charging = true
	Input.action_release(&"charge_shoot")
	await frames(10)
	check(charging, "ação de tiro (clique direito) carrega e dispara")
	await frames(30)
	# Modo comando por teclado (Ctrl, setas, Enter).
	var abilities: AbilityComponent = p.get_node("AbilityComponent") as AbilityComponent
	var activated: Array[StringName] = []
	abilities.ability_activated.connect(func(d: AbilityData) -> void: activated.append(d.id))
	abilities.learn(load("res://abilities/data/passo_agil.tres") as AbilityData)
	await frames(3)
	_action(&"command_mode")
	await frames(3)
	check(abilities.command_active, "Ctrl abre o modo comando")
	check(not board.visible, "no computador o modo comando não mostra o quadro do celular")
	var hud_cmd: CommandHud = p.get_node("AbilitiesUI").get_node("CommandHud") as CommandHud
	check(hud_cmd._panel.visible, "o painel de comando do computador aparece (embaixo à direita)")
	check(not get_node("/root/TiltInput").is_active(), "o acelerômetro não é ligado no computador")
	for a: StringName in [&"cmd_left", &"cmd_right", &"cmd_left"]:
		_action(a)
		await frames(3)
	_action(&"cmd_confirm")
	await frames(3)
	check(activated == [&"passo_agil"], "setas + Enter disparam a habilidade (teclado)")
	# Pausa (ESC) e menus sem itens de celular.
	var pause_menu: Node = level.get_node("Pause")
	_action(&"Pause")
	await frames(6)
	check(get_tree().paused and pause_menu.visible, "ESC abre o menu de pausa")
	check(pause_menu.get_node_or_null("Root/Center/Panel/MainPage/EditControlsButton") == null, "o menu de pausa não tem 'Editar controles'")
	check(pause_menu.get_node_or_null("MobileHudEditor") == null, "o menu de pausa não tem editor de HUD")
	var settings: SettingsPanel = pause_menu.get_node("Root/Center/Panel").find_children("*", "SettingsPanel", true, false)[0] as SettingsPanel
	check(settings.find_child("TiltButton", true, false) == null and settings.find_child("TiltPage", true, false) == null, "as configurações não mostram o acelerômetro")
	_action(&"Pause")
	await frames(10)
	check(not get_tree().paused, "ESC fecha o menu")
	# Diálogos continuam com 'Segure ESC para pular' e sem o botão do celular.
	var dialogue: Dialogue = Dialogue.show_lines(level, PackedStringArray(["Teste de regressão."]), Dialogue.Style.BOX, "Teste")
	await frames(6)
	check(dialogue._skip_button == null, "diálogo no computador não tem o botão 'Avançar cutscene'")
	check(dialogue._skip_label.visible and dialogue._skip_label.text == "Segure ESC para pular", "diálogo no computador mantém 'Segure ESC para pular'")
	dialogue.stop()


## Envia uma ação do InputMap como um evento (aperta e solta).
func _action(action: StringName) -> void:
	var down := InputEventAction.new()
	down.action = action
	down.pressed = true
	Input.parse_input_event(down)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event.call_deferred(up)
