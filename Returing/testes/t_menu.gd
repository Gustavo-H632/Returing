extends TesteBase
## Tela inicial (seção 13): não tem mais nenhum elemento de dicas, os botões restantes funcionam por clique/toque
## e por teclado, o foco navega sem buracos e a coluna fica centralizada. Roda no computador e com --mobile.

const MENU: String = "res://Scenes/Start/menu_start.tscn"
const PROIBIDO: Array[String] = ["dica", "hint", "tip", "navegar", "w / s"]


func rodar() -> void:
	await set_window()
	var changes: Array[String] = block_scene_changes()
	var quits: Array[int] = [0]
	if EventBus.quit_requested.is_connected(Global.quit_game):
		EventBus.quit_requested.disconnect(Global.quit_game)
	EventBus.quit_requested.connect(func() -> void: quits[0] += 1)
	load_level(MENU)
	await real_seconds(0.5)
	var view: Vector2 = get_tree().root.get_visible_rect().size

	# 1. Nenhum elemento de dicas.
	var achados: Array[String] = []
	for no: Node in level.find_children("*", "", true, false):
		var nome: String = String(no.name).to_lower()
		var texto: String = str(no.get("text")).to_lower() if "text" in no else ""
		for p: String in PROIBIDO:
			if (nome.contains(p) or texto.contains(p)) and (no as CanvasItem) != null and (no as CanvasItem).is_visible_in_tree():
				achados.append("%s (%s)" % [no.get_path(), p])
	check(achados.is_empty(), "a tela inicial não tem nenhum elemento de dicas %s" % [achados])
	check(level.get_node_or_null("Center/Column/Hint") == null, "o nó Hint foi removido da cena")

	# 2. Botões restantes, visíveis, dentro da tela e centralizados.
	var start: Button = level.get_node("Center/Column/MenuPanel/Buttons/Start_button")
	var settings: Button = level.get_node("Center/Column/MenuPanel/Buttons/Settings_button")
	var quit: Button = level.get_node("Center/Column/MenuPanel/Buttons/Quit_button")
	var visiveis: Array[Button] = []
	for b: Button in [start, settings, quit]:
		if b.is_visible_in_tree():
			visiveis.append(b)
	check(start.is_visible_in_tree() and settings.is_visible_in_tree(), "Iniciar e Configurações aparecem")
	check(quit.is_visible_in_tree() == Platform.can_quit(), "Sair aparece onde o jogo pode fechar")
	var column: Control = level.get_node("Center/Column")
	var rect: Rect2 = column.get_global_rect()
	check(Rect2(Vector2.ZERO, view).encloses(rect), "a coluna do menu cabe inteira na tela (%s em %s)" % [rect, view])
	check(absf(rect.get_center().x - view.x * 0.5) < 2.0 and absf(rect.get_center().y - view.y * 0.5) < 2.0,
			"título + botões centralizados, sem buraco (%s)" % rect.get_center())
	var ultimo: Control = column.get_child(column.get_child_count() - 1)
	check(ultimo.name == &"MenuPanel", "a caixa de botões é o último item da coluna (nada sobrando abaixo)")
	for i: int in range(1, visiveis.size()):
		check(visiveis[i].get_global_rect().position.y >= visiveis[i - 1].get_global_rect().end.y, "botões empilhados sem sobreposição (%d)" % i)
	await snap("60_tela_inicial_%s" % ("mobile" if Platform.is_mobile() else "desktop"))

	# 3. Teclado: o foco começa em Iniciar e desce/sobe pelos vizinhos sem travar.
	await frames(3)
	check(start.has_focus(), "o foco começa em Iniciar")
	await _key(KEY_DOWN)
	check(settings.has_focus(), "seta para baixo: foco em Configurações")
	await _key(KEY_DOWN)
	check(quit.has_focus(), "seta para baixo: foco em Sair")
	await _key(KEY_UP)
	await _key(KEY_UP)
	check(start.has_focus(), "seta para cima duas vezes: volta a Iniciar")
	for b: Button in visiveis:
		for lado: Side in [SIDE_TOP, SIDE_BOTTOM]:
			var vizinho: Control = b.find_valid_focus_neighbor(lado)
			check(vizinho == null or vizinho in visiveis, "vizinho de foco de %s (%d) é um botão do menu" % [b.name, lado])

	# 4. Configurações abre e volta (teclado).
	settings.grab_focus()
	await _key(KEY_ENTER)
	check(not start.is_visible_in_tree() and level._settings.is_visible_in_tree(), "Enter em Configurações abre a página")
	check(Rect2(Vector2.ZERO, view).encloses(level.get_node("Center/Column/MenuPanel").get_global_rect()), "a página de configurações cabe na tela")
	await _key(KEY_ESCAPE)
	check(start.is_visible_in_tree() and settings.has_focus(), "Esc volta ao menu com o foco em Configurações")

	# 5. Clique/toque em Sair e em Iniciar.
	if quit.is_visible_in_tree():
		await _apertar(quit.get_global_rect().get_center())
		check(quits[0] == 1, "clique/toque em Sair pede para fechar o jogo")
	await _apertar(start.get_global_rect().get_center())
	await real_seconds(0.3)
	check(changes == [start.target_scene], "clique/toque em Iniciar pede a cutscene (%s)" % [changes])
	await real_seconds(1.2)
	start.grab_focus()
	await _key(KEY_ENTER)
	await real_seconds(0.3)
	check(changes.size() == 2, "Enter em Iniciar também pede a cutscene")


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.pressed = pressed
		Input.parse_input_event(e)
		await frames(2)


## Clique do mouse no computador; toque no celular.
func _apertar(pos: Vector2) -> void:
	if Platform.is_mobile():
		await tap(0, pos)
		return
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = to_window(pos)
		e.global_position = e.position
		Input.parse_input_event(e)
		await frames(2)
