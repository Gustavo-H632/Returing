extends TesteBase
## Cutscene que introduz a história (Cut1) no celular: fontes do projeto com sombra, botão "Avançar cutscene",
## logo RETURING no fim e, depois dele, o tutorial.
## Fluxo esperado: história -> logo -> tutorial -> Fase 1 -> cutscene 2 -> ... -> cutscene final.


func rodar() -> void:
	await set_window()
	load_level("res://Scenes/Cut1/cutscene1.tscn")
	await real_seconds(1.8)
	await snap("72_intro_ano")
	await real_seconds(13.0)  # o texto já está subindo (rolamento lento)
	await snap("73_intro_texto")
	var button: Node = level.find_child("BotaoAvancarCutscene", true, false)
	check(button != null, "celular: a cutscene da história tem o botão Avançar cutscene")
	if button == null:
		return
	check(level.get("_logo") == null, "o logo ainda não apareceu durante o texto")
	(button as Button).pressed.emit()  # pula o texto
	await real_seconds(0.8 + 1.2 + 1.0)  # some o texto, o logo entra e já está visível
	check(level.get("_logo") != null, "no fim da história aparece o logo")
	await snap("74_intro_logo")
	(button as Button).pressed.emit()  # pula o logo
	await real_seconds(2.0)
	var atual: Node = get_tree().current_scene
	check(atual != null and atual.scene_file_path == "res://Scenes/Tutorial/tutorial.tscn",
			"depois do logo vem o tutorial (%s)" % [atual.scene_file_path if atual != null else "nenhuma"])
