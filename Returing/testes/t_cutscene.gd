extends TesteBase
## Botão "Avançar cutscene" (só no celular): aparece nos diálogos e na cutscene 2, usa a caixa marrom e a fonte do
## jogo, e tocar nele pula a cena. Rode com --mobile.

func rodar() -> void:
	await set_window()
	check(Platform.is_mobile(), "modo celular")
	var theme: Theme = Palette.load_theme()
	# --- Diálogo (usado em cutscenes e falas) ---
	var root: Node = Node.new()
	get_tree().root.add_child(root)
	var finished: Array[bool] = []
	var skipped: Array[bool] = []
	var dialogue: Dialogue = Dialogue.show_lines(root, PackedStringArray(["Primeira fala da cutscene.", "Segunda fala."]), Dialogue.Style.BOX, "Sistema")
	dialogue.finished.connect(func() -> void: finished.append(true))
	dialogue.skipped.connect(func() -> void: skipped.append(true))
	await real_seconds(1.6)  # bem depois da tolerância de 180 ms do diálogo: o clique NÃO pode ser engolido por ele
	var button: SkipCutsceneButton = dialogue._skip_button
	check(button != null, "o diálogo tem o botão 'Avançar cutscene'")
	if button != null:
		check(button.text == "Avançar cutscene", "texto do botão: 'Avançar cutscene'")
		check(button.is_visible_in_tree(), "o botão está visível")
		check(not dialogue._skip_label.visible, "o aviso 'Segure ESC para pular' some no celular")
		var parent_theme: Theme = (button.get_parent() as Control).theme
		check(parent_theme == theme or parent_theme.resource_path == theme.resource_path, "o botão usa o tema (caixa marrom e fonte) do jogo")
		check(button.get_theme_stylebox(&"normal") != null and button.get_theme_font(&"font") != null, "estilo e fonte do tema aplicados ao botão")
		var rect: Rect2 = button.get_global_rect()
		var view: Vector2 = get_tree().root.get_visible_rect().size
		check(rect.end.x <= view.x and rect.position.x > view.x * 0.6 and rect.position.y < 80.0, "botão no canto superior direito (%s)" % rect)
		check(rect.size.x >= 150.0 and rect.size.y >= 44.0, "botão grande o bastante para o toque (%s)" % rect.size)
		await snap("50_botao_avancar_cutscene")
		await tap(0, rect.get_center())
		await frames(6)
		check(finished.size() == 1 and skipped.size() == 1, "tocar no botão pula o diálogo inteiro")
	root.queue_free()
	await frames(3)
	# --- Cutscene 2 ---
	var changes: Array[String] = block_scene_changes()
	load_level("res://Scenes/Cut2/cutscene2.tscn")
	await real_seconds(2.0)
	var cut_button: Button = level.find_child("BotaoAvancarCutscene", true, false) as Button
	check(cut_button != null and cut_button.text == "Avançar cutscene", "a cutscene 2 tem o botão 'Avançar cutscene'")
	var hint: Node = level.find_child("DicaPular", true, false)
	check(hint != null and not (hint as Label).visible, "a cutscene 2 esconde 'Segure ESC para pular' no celular")
	if cut_button != null:
		await tap(1, cut_button.get_global_rect().get_center())
		await real_seconds(1.0)
		check(level._finished, "tocar no botão termina a cutscene 2")
		check(changes.size() >= 1 and changes[0] == level.next_scene, "a cutscene 2 pede a próxima cena (%s)" % [changes])
