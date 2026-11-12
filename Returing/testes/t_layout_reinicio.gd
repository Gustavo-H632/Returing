extends TesteBase
## Editor de HUD (parte 2, processo NOVO depois do `t_layout.gd`): o layout salvo é carregado ao iniciar, "Restaurar
## padrão" volta ao print e "Voltar" descarta o que não foi salvo. No fim limpa o arquivo de teste.
## Use com: -- --mobile --mobile-config=user://teste_layout.cfg

var mc: Node = null


func rodar() -> void:
	mc = get_node("/root/MobileControls")
	check(FileAccess.file_exists("user://teste_layout.cfg"), "o arquivo salvo pela parte 1 existe depois de reiniciar")
	await set_window()
	var view: Vector2 = mc.view_size()
	# Ao iniciar, o layout salvo é carregado.
	check(is_equal_approx(mc.layout.get_scale(MobileLayout.DASH), 1.3), "reiniciou: escala salva do botão de dash = 1.3 (%.2f)" % mc.layout.get_scale(MobileLayout.DASH))
	check(mc.control_center(MobileLayout.DASH).distance_to(Vector2(900.0, 250.0)) < 2.0, "reiniciou: posição salva do botão de dash = (900, 250) (%s)" % mc.control_center(MobileLayout.DASH))
	check(mc.control_center(MobileLayout.MOVE).distance_to(Vector2(300.0, 500.0)) < 2.0, "reiniciou: joystick de movimento no lugar salvo (%s)" % mc.control_center(MobileLayout.MOVE))
	check(not mc.layout.is_default(), "o layout salvo não é o padrão")
	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(60)
	var p: Player = player()
	p.conceder_invulnerabilidade(9999.0)
	var hud: GameHUD = level.get_node("HUD") as GameHUD
	check(hud.player_health_bar.global_position.x < 100.0, "as barras de status seguem o layout carregado")
	# Os controles reais usam a posição salva (toque no lugar novo dá dash).
	var swung: bool = false
	touch(0, mc.control_center(MobileLayout.DASH), true)
	for i: int in 12:
		await get_tree().physics_frame
		if p.state == Player.State.DASH:
			swung = true
	touch(0, mc.control_center(MobileLayout.DASH), false)
	check(swung, "o botão de dash responde na posição salva")
	await frames(30)
	# Abre o editor, restaura o padrão e volta SEM salvar: o layout salvo volta.
	var pause_menu: Node = level.get_node("Pause")
	var editor: MobileHudEditor = pause_menu.get_node("MobileHudEditor") as MobileHudEditor
	pause_menu.pause()
	pause_menu.open_hud_editor()
	await frames(4)
	editor.restore_default()
	check(mc.layout.is_default(), "Restaurar padrão: layout igual ao do print")
	for id: StringName in MobileLayout.IDS:
		var expected: Vector2 = (MobileLayout.DEFS[id]["pos"] as Vector2) * view
		var got: Vector2 = mc.control_center(id)
		check(got.distance_to(expected) < 1.0, "restaurado: %s em %s (print %s)" % [id, got, expected])
	editor.close(false)  # "Voltar": descarta
	check(is_equal_approx(mc.layout.get_scale(MobileLayout.DASH), 1.3), "Voltar descarta a restauração não salva (volta ao salvo)")
	# Restaura e salva: o padrão fica gravado.
	pause_menu.open_hud_editor()
	await frames(4)
	editor.restore_default()
	editor.close(true)
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load("user://teste_layout.cfg")
	check((cfg.get_value("layout", "dash_pos") as Vector2).distance_to(MobileLayout.DEFS[MobileLayout.DASH]["pos"]) < 0.001, "restaurar + salvar grava o padrão")
	check(is_equal_approx(float(cfg.get_value("layout", "dash_scale")), 1.0), "escala padrão gravada")
	# Arquivo corrompido não quebra: valores inválidos viram o padrão.
	MobileSettings.set_value("layout", "dash_pos", Vector2(9.0, -3.0))
	MobileSettings.set_value("layout", "dash_scale", 55.0)
	var broken: MobileLayout = MobileLayout.new()
	broken.load_saved()
	check((broken.get_proportion(MobileLayout.DASH) as Vector2).distance_to(MobileLayout.DEFS[MobileLayout.DASH]["pos"]) < 0.001, "posição inválida no arquivo vira o padrão")
	check(is_equal_approx(broken.get_scale(MobileLayout.DASH), MobileLayout.MAX_SCALE), "escala fora dos limites é limitada")
	MobileSettings.wipe()
