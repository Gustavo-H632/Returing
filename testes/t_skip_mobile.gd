extends TesteBase
## "Pular tutorial" no celular: o botão responde ao TOQUE (o clique emulado não é engolido pelos controles de toque)
## e exige confirmação (toque duplo em até 3 s). Rode com --mobile.

func rodar() -> void:
	await set_window()
	var changes: Array[String] = block_scene_changes()
	load_level("res://Scenes/Tutorial/tutorial.tscn")
	var tut: Tutorial = level as Tutorial
	tut.player.conceder_invulnerabilidade(9999.0)
	var start: int = Time.get_ticks_msec()
	while tut.step != &"move" and Time.get_ticks_msec() - start < 40000:
		await get_tree().process_frame
	check(tut.step == &"move", "o tutorial chegou ao primeiro passo")
	await real_seconds(1.0)
	check(MobileControls._shown, "os controles de toque estão visíveis (o caso que engolia o clique)")
	var button: Button = tut.ui._skip_button
	check(button != null and button.is_visible_in_tree() and button.text == "Pular tutorial", "o botão 'Pular tutorial' está na tela")
	var rect: Rect2 = button.get_global_rect()
	var view: Vector2 = get_tree().root.get_visible_rect().size
	check(rect.end.x < view.x * 0.8 and not rect.intersects(Rect2(MobileControls.control_center(MobileLayout.PAUSE) - Vector2(40, 40), Vector2(80, 80))),
			"o botão não fica em cima da pausa nem do quadro de comandos (%s)" % rect)
	await tap(0, rect.get_center())
	await real_seconds(0.3)
	check(button.text == "Clique de novo para pular" and tut.step == &"move", "primeiro toque pede confirmação")
	await tap(0, rect.get_center())
	await real_seconds(1.5)
	check(tut.step == &"skipped" or tut._leaving, "segundo toque pula o tutorial")
	await real_seconds(1.5)
	check(changes == [tut.next_scene], "o tutorial pede a Fase 1 (%s)" % [changes])
