class_name CenariosResolucao
extends RefCounted
## Telas conferidas pela matriz de resoluções (`t_resolucoes.gd`). Cada função abre uma tela do jogo de verdade e
## devolve o contexto: {"raizes": nós cuja interface é conferida, "controles": os controles de toque fazem parte,
## "atualizar": chamado depois de cada troca de resolução, "fechar": limpeza, "extras": retângulos desenhados por código}.

## [nome (também é o prefixo da captura), função]
const LISTA: Array = [
	["tela_inicial", &"tela_inicial"],
	["tela_inicial_config", &"tela_inicial_config"],
	["hud_jogo", &"hud_jogo"],
	["quadro_comandos", &"quadro_comandos"],
	["quadro_comandos_dpad", &"quadro_comandos_dpad"],
	["pause", &"pause"],
	["pause_config", &"pause_config"],
	["pause_acelerometro", &"pause_acelerometro"],
	["editor_hud", &"editor_hud"],
	["dialogo", &"dialogo"],
	["dialogo_voz", &"dialogo_voz"],
	["cutscene", &"cutscene"],
	["tutorial_mover", &"tutorial_passo"],
	["tutorial_melhorias", &"tutorial_melhorias"],
	["hud_chefao", &"hud_chefao"],
	["hud_defesa", &"hud_defesa"],
	["fim_game_over", &"fim_game_over"],
	["fim_fase_concluida", &"fim_fase_concluida"],
	["fim_resultado", &"fim_resultado"],
	["subir_de_nivel", &"subir_de_nivel"],
	["quiz", &"quiz"],
	["labirinto_hud", &"labirinto_hud"],
	["camara_hud", &"camara_hud"],
]


func tela_inicial(t: TesteBase) -> Dictionary:
	t.load_level("res://Scenes/Start/menu_start.tscn")
	await t.real_seconds(0.4)
	return {"raizes": [t.level]}


func tela_inicial_config(t: TesteBase) -> Dictionary:
	t.load_level("res://Scenes/Start/menu_start.tscn")
	await t.real_seconds(0.4)
	t.level._show_settings_page()
	await t.frames(3)
	return {"raizes": [t.level]}


func _fase(t: TesteBase, caminho: String = "res://Scenes/Fase1/fase_1.tscn", espera: int = 50) -> void:
	t.load_level(caminho)
	await t.frames(espera)
	if t.player() != null:
		t.player().conceder_invulnerabilidade(99999.0)


func hud_jogo(t: TesteBase) -> Dictionary:
	await _fase(t)
	return {"raizes": [_hud(t)], "controles": true}


func quadro_comandos(t: TesteBase) -> Dictionary:
	await _fase(t)
	var mc: Node = t.get_node("/root/MobileControls")
	await t.tap(0, mc.control_center(MobileLayout.COMMAND))
	await t.real_seconds(0.4)
	return {"raizes": [_hud(t)], "controles": true, "fechar": func() -> void:
		if mc._command_open():
			mc._command_press()
		Engine.time_scale = 1.0}


func quadro_comandos_dpad(t: TesteBase) -> Dictionary:
	await _fase(t)
	var mc: Node = t.get_node("/root/MobileControls")
	var ti: Node = t.get_node("/root/TiltInput")
	ti.simulate_with_keys = false
	Input.set_accelerometer(Vector3.ZERO)
	await t.tap(0, mc.control_center(MobileLayout.COMMAND))
	await t.real_seconds(ti.missing_after + 0.6)
	return {"raizes": [_hud(t)], "controles": true,
		"extras": func() -> Array:
			var out: Array = []
			for b: Dictionary in mc.dpad_buttons():
				var r: float = b["radius"]
				out.append({"nome": "D-pad %d" % b["dir"], "rect": Rect2((b["center"] as Vector2) - Vector2(r, r), Vector2(r, r) * 2.0), "interativo": true, "circulo": true})
			return out,
		"fechar": func() -> void:
			if mc._command_open():
				mc._command_press()
			ti.simulate_with_keys = true
			Input.set_accelerometer(TesteBase.gravity())
			Engine.time_scale = 1.0}


func pause(t: TesteBase) -> Dictionary:
	await _fase(t)
	var menu: Node = t.level.get_node("Pause")
	menu.pause()
	await t.real_seconds(0.4)
	return {"raizes": [menu], "modal": true}


func pause_config(t: TesteBase) -> Dictionary:
	var ctx: Dictionary = await pause(t)
	t.level.get_node("Pause")._show_settings_page()
	await t.frames(4)
	return ctx


func pause_acelerometro(t: TesteBase) -> Dictionary:
	var ctx: Dictionary = await pause_config(t)
	var settings: SettingsPanel = t.level.get_node("Pause").find_children("*", "SettingsPanel", true, false)[0]
	settings._show_tilt_page(true)
	await t.frames(4)
	ctx["fechar"] = func() -> void: settings._show_tilt_page(false)
	return ctx


func editor_hud(t: TesteBase) -> Dictionary:
	await _fase(t)
	var menu: Node = t.level.get_node("Pause")
	menu.pause()
	await t.real_seconds(0.3)
	menu.open_hud_editor()
	await t.frames(5)
	var editor: MobileHudEditor = menu.get_node("MobileHudEditor")
	return {"raizes": [editor], "controles": true, "editor": true,
		"rect_editor": func(id: StringName) -> Rect2: return editor.layout.get_rect(id, MobileControls.view_size(), MobileControls.safe_margins()),
		"fechar": func() -> void: editor.close(false)}


func dialogo(t: TesteBase) -> Dictionary:
	await _fase(t)
	var d: Dialogue = Dialogue.show_lines(t.level, PackedStringArray([
		"Não esperava por essa... Mas agora estamos cada vez mais perto de Aegis, e eu preciso que você escute com atenção o que vou dizer antes que o portal feche de vez.",
		"Segunda fala."]), Dialogue.Style.BOX, "Alan Turing", load("res://sprites/Cutscenes/Lab-Turing.png"))
	await t.real_seconds(1.2)
	return {"raizes": [d], "fechar": func() -> void:
		if is_instance_valid(d):
			d.stop()}


func dialogo_voz(t: TesteBase) -> Dictionary:
	await _fase(t)
	var d: Dialogue = Dialogue.show_lines(t.level, PackedStringArray([
		"Turing. Você me criou para proteger a humanidade. Estou apenas concluindo o que você começou em 1945."]), Dialogue.Style.VOICE)
	await t.real_seconds(1.2)
	return {"raizes": [d], "fechar": func() -> void:
		if is_instance_valid(d):
			d.stop()}


func cutscene(t: TesteBase) -> Dictionary:
	t.load_level("res://Scenes/Cut2/cutscene2.tscn")
	await t.real_seconds(2.5)
	return {"raizes": [t.level]}


func tutorial_passo(t: TesteBase) -> Dictionary:
	t.load_level("res://Scenes/Tutorial/tutorial.tscn")
	var tut: Tutorial = t.level as Tutorial
	tut.player.conceder_invulnerabilidade(99999.0)
	var inicio: int = Time.get_ticks_msec()
	while tut.step != &"move" and Time.get_ticks_msec() - inicio < 40000:
		await t.get_tree().process_frame
	await t.real_seconds(1.0)
	return {"raizes": [tut.ui, _hud(t)], "controles": true}


func tutorial_melhorias(t: TesteBase) -> Dictionary:
	t.load_level("res://Scenes/Tutorial/tutorial.tscn")
	var tut: Tutorial = t.level as Tutorial
	tut.player.conceder_invulnerabilidade(99999.0)
	await t.real_seconds(0.5)
	var menu: TutorialUpgradeMenu = t.level.find_children("*", "TutorialUpgradeMenu", true, false)[0]
	menu.open()
	await t.real_seconds(1.2)
	return {"raizes": [menu]}


func hud_chefao(t: TesteBase) -> Dictionary:
	await _fase(t, "res://Scenes/Fase3/fase_3.tscn", 80)
	return {"raizes": [_hud(t)], "controles": true}


func hud_defesa(t: TesteBase) -> Dictionary:
	await _fase(t, "res://Scenes/Defesa/Defesa.tscn", 60)
	var hud: DefenseHud = t.level.hud
	hud.show_hint("Defenda o portal até ele carregar!", 600.0)
	hud.show_wave_banner(7, {"drone": 8, "robo": 6, "tank": 3})
	await t.frames(5)
	return {"raizes": [_hud(t), hud], "controles": true}


func fim_game_over(t: TesteBase) -> Dictionary:
	await _fase(t)
	EventBus.game_over.emit()
	await t.real_seconds(_hud(t).retry_delay + 0.5)
	return {"raizes": [_hud(t)], "modal": true}


func fim_fase_concluida(t: TesteBase) -> Dictionary:
	await _fase(t)
	EventBus.level_completed.emit("res://Scenes/Fase2/Fase2.tscn")
	await t.real_seconds(0.8)
	return {"raizes": [_hud(t)], "modal": true}


func fim_resultado(t: TesteBase) -> Dictionary:
	t.load_level("res://Scenes/Start/menu_start.tscn")
	await t.frames(5)
	var cfg: ScoreConfig = ScoreConfig.carregar()
	var run := RunSnapshot.new()
	run.tempo_s = 780.0
	run.tempos_por_fase = [190.0, 220.0, 370.0]
	run.abates_por_tipo = {&"drone": 8, &"robo": 9, &"tank": 6, &"guide": 1}
	run.maior_sequencia_abates = 5
	run.dano_causado = 5400.0
	run.dano_tomado = 200.0
	run.acertos_quiz = 3
	run.vida_max_inicial_jogador = 100.0
	var resultado: ScoreResult = ScoreCalculator.calcular(run, cfg)
	var recorde: Dictionary = {"novo_recorde": true, "anterior": {"total": 12000, "rank": &"B", "tempo_s": 900.0},
			"atual": {"total": resultado.total, "rank": resultado.rank, "tempo_s": run.tempo_s}}
	var tela: ResultScreen = ResultScreen.abrir(t.level, resultado, recorde, false)
	t.get_tree().paused = false
	await t.real_seconds(0.6)
	return {"raizes": [tela], "modal": true, "fechar": func() -> void:
		if is_instance_valid(tela):
			tela.queue_free()}


func subir_de_nivel(t: TesteBase) -> Dictionary:
	await _fase(t)
	var menu: LevelUpMenu = t.level.find_children("*", "LevelUpMenu", true, false)[0]
	var catalogo: AbilityCatalog = load("res://abilities/data/ability_catalog.tres")
	var oferta: Array[AbilityData] = []
	for a: AbilityData in catalogo.abilities.slice(0, 3):
		oferta.append(a)
	var tem: Array[AbilityData] = []
	t.get_tree().paused = true  # no jogo a escolha acontece com a partida pausada (controles de toque escondidos)
	menu.open(2, oferta, tem)
	await t.real_seconds(1.0)
	return {"raizes": [menu], "modal": true, "fechar": func() -> void: t.get_tree().paused = false}


func quiz(t: TesteBase) -> Dictionary:
	await _fase(t, "res://Scenes/Fase2/Fase2.tscn", 40)
	t.level._open_quiz()
	await t.real_seconds(1.0)
	return {"raizes": [t.level.quiz]}


func labirinto_hud(t: TesteBase) -> Dictionary:
	await _fase(t, "res://Scenes/Fase2/Labirinto.tscn", 60)
	var hud: LabHud = t.get_tree().get_first_node_in_group(LabHud.GROUP)
	var painel: Node2D = t.level.get_node("Puzzle/PainelTriangulo")
	t.player().global_position = painel.global_position
	await t.real_seconds(0.5)
	return {"raizes": [_hud(t), hud], "controles": true}


func camara_hud(t: TesteBase) -> Dictionary:
	await _fase(t, "res://Scenes/Fase5/Camara.tscn", 60)
	var huds: Array[Node] = t.level.find_children("*", "CamaraHud", true, false)
	var raizes: Array = [_hud(t)]
	raizes.append_array(huds)
	return {"raizes": raizes, "controles": true}


func _hud(t: TesteBase) -> Node:
	var achados: Array[Node] = t.level.find_children("*", "GameHUD", true, false)
	return achados[0] if not achados.is_empty() else null
