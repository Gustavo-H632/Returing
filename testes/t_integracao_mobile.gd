extends TesteBase
## Integração mobile: vida do Turing (100 em todas as plataformas) e fonte padrão do jogo no quadro
## de comandos. Rode com `--mobile` (celular) e sem (PC): `godot --path . res://testes/executor.tscn -- --teste=res://testes/t_integracao_mobile.gd [--mobile]`.


func rodar() -> void:
	await set_window()
	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(30)
	var p: Player = player()
	check(p != null, "o Turing existe na Fase 1")
	check(p.hp_maximo == 100, "vida máxima do Turing = 100 (%d)" % p.hp_maximo)
	check(p.hp == 100, "vida inicial do Turing = 100 (%d)" % p.hp)
	if not Platform.is_mobile():
		return
	# Quadro de comandos com a fonte padrão do jogo (VT323).
	var abilities: AbilityComponent = p.get_node("AbilityComponent") as AbilityComponent
	var board: CommandBoard = (p.get_node("AbilitiesUI") as Node).get_node("CommandBoard") as CommandBoard
	abilities.learn(load("res://abilities/data/escudo.tres") as AbilityData)
	abilities.learn(load("res://abilities/data/passo_agil.tres") as AbilityData)
	await frames(5)
	var mc: Node = get_node("/root/MobileControls")
	await tap(0, mc.control_center(MobileLayout.COMMAND))
	await frames(10)
	check(board.visible, "o quadro de comandos abriu")
	var font: Font = board.theme.default_font
	check(font != null and font.resource_path.ends_with("VT323-Regular.ttf"),
			"o quadro usa a fonte padrão do jogo (%s)" % [font.resource_path if font != null else "nenhuma"])
	await snap("70_quadro_comando_fonte_padrao")
