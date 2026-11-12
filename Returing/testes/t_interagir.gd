extends TesteBase
## Botão temporário "E" (seção 2.1): aparece só com um objeto interativo ao alcance (a mesma condição do aviso
## "[E]" do computador), some quando o jogador se afasta, dispara a ação `interagir` e anima a entrada/saída em
## 3 quadros. Cobre o terminal do quiz (Fase 2) e os painéis/porta do labirinto. Rode com --mobile.

var mc: Node = null


func rodar() -> void:
	mc = get_node("/root/MobileControls")
	await set_window()
	block_scene_changes()
	await _terminal()
	await _labirinto()


func _terminal() -> void:
	load_level("res://Scenes/Fase2/Fase2.tscn")
	await frames(40)
	var p: Player = player()
	p.conceder_invulnerabilidade(9999.0)
	var terminal: QuizTerminal = level.terminal
	var e_center: Vector2 = mc.control_center(MobileLayout.INTERACT)
	var longe: Vector2 = p.global_position
	if longe.distance_to(terminal.global_position) < 200.0:
		longe = terminal.global_position + Vector2(-400.0, 0.0)
		p.global_position = longe
		await frames(20)
	check(not terminal.prompt.is_visible_in_tree(), "longe do terminal o aviso [E] do computador está apagado")
	check(not mc.is_control_active(MobileLayout.INTERACT) and mc.interact_anim_frame() == 0, "longe do terminal o botão E não aparece")
	# Tocar onde o botão ficaria não faz nada.
	var ativacoes: Array[int] = [0]
	terminal.terminal_ativado.connect(func() -> void: ativacoes[0] += 1)
	await tap(0, e_center)
	check(ativacoes[0] == 0, "tocar no lugar do botão E escondido não interage")

	# Chega perto: o botão entra em 3 quadros (escala/brilho) e fica.
	p.global_position = terminal.global_position + Vector2(0.0, 30.0)
	var vistos: Dictionary = {}
	for i: int in 40:
		await get_tree().process_frame
		vistos[mc.interact_anim_frame()] = true
	check(terminal.prompt.is_visible_in_tree(), "perto do terminal o aviso [E] aparece (condição do computador)")
	check(mc.is_control_active(MobileLayout.INTERACT), "perto do terminal o botão E aparece")
	check(vistos.has(1) and vistos.has(2) and mc.interact_anim_frame() == mc.INTERACT_ANIM_FRAMES,
			"a entrada passa pelos quadros 1, 2 e termina no 3 (%s)" % [vistos.keys()])
	await snap("23_botao_e")
	# Tocar no E dispara a mesma ação `interagir` do teclado: o terminal abre o quiz.
	await tap(0, e_center)
	await real_seconds(0.2)
	check(ativacoes[0] == 1, "tocar no botão E aciona o terminal (ação interagir)")
	check(get_tree().paused and level.quiz.visible, "o quiz abriu")
	check(not terminal.prompt.is_visible_in_tree(), "com a interação em curso o aviso [E] some")
	await real_seconds(0.4)
	check(not mc.is_control_active(MobileLayout.INTERACT) or mc.interact_anim_frame() == 0, "o botão E some quando a interação termina/abre")
	get_tree().paused = false
	level.quiz.hide()
	await unload_level()
	await frames(5)


func _labirinto() -> void:
	load_level("res://Scenes/Fase2/Labirinto.tscn")
	await frames(60)
	var p: Player = player()
	p.conceder_invulnerabilidade(9999.0)
	var painel: LabInteractable = level.get_node("Puzzle/PainelTriangulo") as LabInteractable
	var hud: LabHud = get_tree().get_first_node_in_group(LabHud.GROUP) as LabHud
	check(hud != null and not hud.prompt_label.is_visible_in_tree(), "labirinto: sem objeto ao alcance não há aviso [E]")
	check(not mc.is_control_active(MobileLayout.INTERACT), "labirinto: sem objeto ao alcance o botão E não aparece")
	var avisos: Array[int] = [0]
	painel.interacted.connect(func() -> void: avisos[0] += 1)
	p.global_position = painel.global_position
	p.velocity = Vector2.ZERO
	await real_seconds(0.5)
	check(painel.player_near and hud.prompt_label.is_visible_in_tree(), "labirinto: perto do painel o aviso [E] aparece")
	check(mc.is_control_active(MobileLayout.INTERACT) and mc.interact_anim_frame() == mc.INTERACT_ANIM_FRAMES, "labirinto: perto do painel o botão E aparece")
	await tap(0, mc.control_center(MobileLayout.INTERACT))
	await real_seconds(0.2)
	check(avisos[0] == 1, "labirinto: tocar no botão E aciona o painel")
	# Outro painel (o primeiro pode ter se desligado ao ser ativado): chega perto e depois se afasta.
	painel = level.get_node("Puzzle/PainelQuadrado") as LabInteractable
	p.global_position = painel.global_position
	await real_seconds(0.5)
	check(mc.is_control_active(MobileLayout.INTERACT) and mc.interact_anim_frame() == mc.INTERACT_ANIM_FRAMES, "labirinto: o botão E aparece no segundo painel")
	# Afasta: o botão sai em 3 quadros.
	p.global_position = painel.global_position + Vector2(0.0, 600.0)
	var vistos: Dictionary = {}
	for i: int in 60:
		await get_tree().process_frame
		vistos[mc.interact_anim_frame()] = true
	check(not painel.player_near or not hud.prompt_label.is_visible_in_tree(), "labirinto: longe do painel o aviso some")
	check(vistos.has(2) and vistos.has(1) and mc.interact_anim_frame() == 0, "a saída passa pelos quadros 2, 1 e some (%s)" % [vistos.keys()])
	check(not mc.is_control_active(MobileLayout.INTERACT), "labirinto: longe do painel o botão E some")
	await unload_level()
