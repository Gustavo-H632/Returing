extends TesteBase
## REGRESSÃO do tutorial no computador (sem --mobile): continua com WASD, tecla de dash e mouse; não aparece
## nada do celular (nem lição de troca de arma, nem de modo comando). Rode SEM --mobile.

var tut: Tutorial = null
var _seen: Array[StringName] = []


func _wait_step(name: StringName, timeout: float = 40.0) -> bool:
	var start: int = Time.get_ticks_msec()
	while tut.step != name:
		await get_tree().process_frame
		if _seen.is_empty() or _seen[_seen.size() - 1] != tut.step:
			_seen.append(tut.step)
		if float(Time.get_ticks_msec() - start) / 1000.0 > timeout:
			return false
	return true


func rodar() -> void:
	await set_window()
	block_scene_changes()
	check(not Platform.is_mobile(), "modo computador")
	load_level("res://Scenes/Tutorial/tutorial.tscn")
	tut = level as Tutorial
	tut.player.conceder_invulnerabilidade(9999.0)
	check(await _wait_step(&"move"), "o tutorial chega ao passo de mover")
	await real_seconds(0.6)
	check(tut.ui.current_icon() == null, "passo 1: ilustração é o teclado WASD (nenhuma ilustração de celular)")
	check(tut.ui.has_panel(), "passo 1: painel 'Aperte W A S D para andar'")
	check(tut.ui._panel_keys.has(&"move_up") and tut.ui._panel_keys.has(&"move_left"), "passo 1: teclas W A S D no painel")
	check(not (tut.ui.get_node_or_null("UiLayer") == null), "interface do tutorial presente")
	var hold_label_visible: bool = false
	for l: Node in tut.ui.find_children("*", "Label", true, false):
		if (l as Label).text == "ou segure TAB" and (l as Label).visible:
			hold_label_visible = true
	check(hold_label_visible, "a dica 'ou segure TAB' continua no computador")
	check(MobileControls.highlight == &"", "nenhum controle de celular é destacado")
	for action: StringName in [&"move_up", &"move_left", &"move_down", &"move_right"]:
		Input.action_press(action)
		await real_seconds(0.3)
		Input.action_release(action)
		await real_seconds(0.15)
	check(await _wait_step(&"dash", 8.0), "WASD usadas avançam para o dash")
	await real_seconds(1.2)
	check(tut.ui._panel_keys.has(&"key"), "passo 2: tecla ESPAÇO no painel")
	Input.action_press(&"dash")
	await real_seconds(0.25)
	Input.action_release(&"dash")
	check(await _wait_step(&"droid_entry", 8.0), "o dash avança")
	check(await _wait_step(&"shoot", 40.0), "o droide entra e o passo de tiro (mouse direito) começa")
	await real_seconds(0.8)
	check(tut.ui.current_icon() == null and tut.ui.has_panel(), "passo 3: painel do mouse (sem ilustração de celular)")
	check(not _seen.has(&"weapon") and not _seen.has(&"command"), "até o passo de tiro o computador segue só as lições originais (as do celular ficam atrás de Platform.is_mobile())")
	tut.skip()
