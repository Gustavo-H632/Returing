extends TesteBase
## Tutorial do celular, do começo ao fim, com toques reais e inclinação simulada:
## 1 mover (joystick), 2 dash, 3 tiro (joystick direito), 4 trocar arma, 5 espada, 6 modo comando + inclinar o celular.
## Confere que cada passo só avança quando a ação é feita, que o controle da vez pisca e que o tutorial termina.

var mc: Node = null
var tut: Tutorial = null
var p: Player = null
var _transitions: Array[StringName] = []  # passos vistos, em ordem


## Espera o tutorial chegar ao passo `name` (relógio real). Devolve true se chegou.
func _wait_step(name: StringName, timeout: float = 40.0) -> bool:
	var start: int = Time.get_ticks_msec()
	while tut.step != name:
		await get_tree().process_frame
		_track()
		if float(Time.get_ticks_msec() - start) / 1000.0 > timeout:
			return false
	return true


func _track() -> void:
	if _transitions.is_empty() or _transitions[_transitions.size() - 1] != tut.step:
		_transitions.append(tut.step)


## Confere que o controle `id` está destacado e que o destaque pisca (intensidade varia de baixa a alta).
func _check_blink(id: StringName, label: String) -> void:
	check(mc.highlight == id, "%s: o controle %s está destacado" % [label, id])
	var low: float = 1.0
	var high: float = 0.0
	for i: int in 12:
		var amount: float = MobileDraw.pulse(mc._hl_clock)
		low = minf(low, amount)
		high = maxf(high, amount)
		await real_seconds(0.07)
	check(low < 0.3 and high > 0.7, "%s: o destaque pisca (%.2f a %.2f)" % [label, low, high])


## A ilustração do painel é a do celular (e não teclado/mouse) e anima.
func _check_icon(kind: StringName, label: String) -> void:
	var icon: MobileGuideIcon = tut.ui.current_icon() as MobileGuideIcon
	check(icon != null and icon.kind == kind, "%s: o painel mostra a ilustração do celular (%s)" % [label, kind])
	if icon == null:
		return
	var first: int = icon.current_direction()
	var seen: Dictionary = {first: true}
	for i: int in 14:
		await real_seconds(0.15)
		seen[icon.current_direction()] = true
	check(seen.size() >= 2 or kind in [&"m_dash", &"m_weapon", &"m_sword", &"m_command"], "%s: a ilustração se anima" % label)


func rodar() -> void:
	mc = get_node("/root/MobileControls")
	var ti: Node = get_node("/root/TiltInput")
	ti.simulate_with_keys = false
	ti.cooldown = 0.25
	Input.set_accelerometer(gravity())
	await set_window()
	var changes: Array[String] = block_scene_changes()
	load_level("res://Scenes/Tutorial/tutorial.tscn")
	tut = level as Tutorial
	p = tut.player
	p.conceder_invulnerabilidade(9999.0)
	check(Platform.is_mobile(), "tutorial no modo celular")
	check(not mc._shown, "durante a abertura escura os controles de toque ficam escondidos")
	check(await _wait_step(&"move"), "o tutorial chega ao passo de mover")
	await real_seconds(0.8)
	check(mc._shown, "os controles de toque aparecem junto com o jogador")
	var icon: Control = tut.ui.current_icon()
	check(icon is MobileGuideIcon, "passo 1: ilustração do joystick (e não WASD)")
	check(tut.ui.has_panel(), "passo 1: painel 'Mova-se com o joystick' na tela")

	# --- 1) Mover ---
	await _check_blink(MobileLayout.MOVE, "passo 1")
	await _check_icon(&"m_move", "passo 1")
	await snap("41_tutorial_1_mover")
	var move_c: Vector2 = mc.control_center(MobileLayout.MOVE)
	# Tocar em outro controle (mira) não conta.
	await tap(5, mc.control_center(MobileLayout.AIM))
	await real_seconds(0.5)
	check(tut.step == &"move", "passo 1: usar outro controle não avança")
	# Só uma direção: ainda não avança.
	touch(0, move_c + Vector2(60, 0), true)
	await real_seconds(0.7)
	touch(0, move_c + Vector2(60, 0), false)
	await real_seconds(0.4)
	check(tut.step == &"move" and tut.ui.is_key_checked(&"move_right") and not tut.ui.is_key_checked(&"move_left"),
			"passo 1: só a direita foi feita, o passo continua (check na direita)")
	for dir: Vector2 in [Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		touch(0, move_c + dir * 60.0, true)
		await real_seconds(0.5)
		touch(0, move_c + dir * 60.0, false)
		await real_seconds(0.3)
	check(await _wait_step(&"dash", 8.0), "passo 1: as quatro direções avançam para o dash")

	# --- 2) Dash ---
	await real_seconds(1.2)
	await _check_blink(MobileLayout.DASH, "passo 2")
	await _check_icon(&"m_dash", "passo 2")
	await snap("42_tutorial_2_dash")
	await tap(5, mc.control_center(MobileLayout.WEAPON))  # outro botão: não conta
	await real_seconds(0.5)
	check(tut.step == &"dash", "passo 2: tocar em outro botão não avança")
	await tap(1, mc.control_center(MobileLayout.DASH), 4)
	check(await _wait_step(&"droid_entry", 8.0), "passo 2: tocar no dash avança")

	# --- 3) Tiro ---
	check(await _wait_step(&"shoot", 40.0), "o droide entra e o passo de tiro começa")
	check(mc.weapon_ranged, "passo 3: o joystick direito está no tiro")
	await real_seconds(0.8)
	await _check_blink(MobileLayout.AIM, "passo 3")
	await _check_icon(&"m_shoot", "passo 3")
	await snap("43_tutorial_3_tiro")
	var aim_c: Vector2 = mc.control_center(MobileLayout.AIM)
	var attempts: int = 0
	while tut.step == &"shoot" and attempts < 14:
		attempts += 1
		var to_droid: Vector2 = (tut.droid.global_position - p.global_position).normalized() if is_instance_valid(tut.droid) else Vector2.DOWN
		touch(1, aim_c + to_droid * 60.0, true)
		await real_seconds(0.55)
		touch(1, aim_c + to_droid * 60.0, false)
		await real_seconds(0.9)
	check(tut.step != &"shoot", "passo 3: acertar um tiro no droide avança (tentativas: %d)" % attempts)
	check(tut._ranged_hits > 0, "passo 3: o avanço veio de um tiro que acertou")

	# --- 4) Trocar arma ---
	check(await _wait_step(&"weapon", 10.0), "passo 4: o tutorial pede para trocar a arma")
	await real_seconds(1.0)
	await _check_blink(MobileLayout.WEAPON, "passo 4")
	await _check_icon(&"m_weapon", "passo 4")
	await snap("44_tutorial_4_trocar_arma")
	await tap(2, mc.control_center(MobileLayout.DASH), 3)  # outro botão: não conta
	await real_seconds(0.6)
	check(tut.step == &"weapon" and mc.weapon_ranged, "passo 4: tocar em outro botão não avança")
	await tap(2, mc.control_center(MobileLayout.WEAPON))
	check(not mc.weapon_ranged, "passo 4: o botão trocou para a espada")
	check(await _wait_step(&"sword", 10.0), "passo 4: trocar a arma avança")

	# --- 5) Espada ---
	await real_seconds(1.0)
	await _check_blink(MobileLayout.AIM, "passo 5")
	check(not mc.weapon_ranged, "passo 5: a espada continua escolhida no joystick direito")
	await _check_icon(&"m_sword", "passo 5")
	await snap("45_tutorial_5_espada")
	attempts = 0
	while tut.step == &"sword" and attempts < 30:
		attempts += 1
		if not is_instance_valid(tut.droid):
			break
		var to: Vector2 = tut.droid.global_position - p.global_position
		if to.length() > 70.0:  # chega perto com o joystick de movimento
			touch(0, move_c + to.normalized() * 60.0, true)
			await real_seconds(0.4)
			touch(0, move_c + to.normalized() * 60.0, false)
		else:  # golpe = arrastar o joystick direito na direção do droide e soltar (espada escolhida)
			var alvo: Vector2 = mc.control_center(MobileLayout.AIM) + to.normalized() * 60.0
			touch(3, alvo, true)
			await frames(6)
			touch(3, alvo, false)
			await real_seconds(0.5)
	check(tut._melee_hits > 0, "passo 5: o joystick direito com a espada acertou o droide (tentativas: %d)" % attempts)
	check(tut.step != &"sword", "passo 5: acertar a espada avança")

	# Destruir o droide (passo 'finish') com a espada.
	attempts = 0
	while tut.step == &"finish" and attempts < 40 and is_instance_valid(tut.droid):
		attempts += 1
		var to2: Vector2 = tut.droid.global_position - p.global_position
		if to2.length() > 70.0:
			touch(0, move_c + to2.normalized() * 60.0, true)
			await real_seconds(0.35)
			touch(0, move_c + to2.normalized() * 60.0, false)
		else:
			var alvo2: Vector2 = mc.control_center(MobileLayout.AIM) + to2.normalized() * 60.0
			touch(3, alvo2, true)
			await frames(6)
			touch(3, alvo2, false)
			await real_seconds(0.45)

	# --- 6) Modo comando + inclinar o celular ---
	check(await _wait_step(&"command", 30.0), "passo 6: o tutorial chega ao modo comando")
	await real_seconds(1.0)
	await _check_blink(MobileLayout.COMMAND, "passo 6a")
	await _check_icon(&"m_command", "passo 6a")
	await snap("46_tutorial_6a_modo_comando")
	var abilities: AbilityComponent = p.get_node("AbilityComponent") as AbilityComponent
	await tap(2, mc.control_center(MobileLayout.WEAPON), 3)  # outro botão: não conta
	await real_seconds(0.5)
	check(tut.step == &"command" and not abilities.command_active, "passo 6a: outro botão não abre o modo comando")
	await tap(2, mc.control_center(MobileLayout.COMMAND), 3)
	check(abilities.command_active, "passo 6a: o botão de modo comando abre o modo (treino, sem habilidades)")
	check(await _wait_step(&"tilt", 8.0), "passo 6b: depois de abrir, pede para inclinar o celular")
	await real_seconds(1.0)
	var board: CommandBoard = (p.get_node("AbilitiesUI") as Node).get_node("CommandBoard") as CommandBoard
	check(board.visible, "passo 6b: o quadro de comandos está aberto")
	await _check_blink(MobileLayout.BOARD, "passo 6b")
	await _check_icon(&"m_tilt", "passo 6b")
	await snap("47_tutorial_6b_inclinar")
	await real_seconds(0.8)  # calibra no neutro
	# Sem inclinar nada, nada avança.
	await real_seconds(1.0)
	check(tut.step == &"tilt", "passo 6b: sem inclinar o passo continua")
	# Cada direção recebe um check; só com as quatro o passo termina.
	var dirs: Array[int] = [AbilityData.Dir.UP, AbilityData.Dir.DOWN, AbilityData.Dir.LEFT, AbilityData.Dir.RIGHT]
	for i: int in dirs.size():
		Input.set_accelerometer(tilt_vector(dirs[i]))
		await real_seconds(0.7)
		Input.set_accelerometer(gravity())
		await real_seconds(0.7)
		if i < dirs.size() - 1:
			check(tut.step == &"tilt", "passo 6b: com %d de 4 direções o passo continua" % (i + 1))
	await real_seconds(1.5)
	check(tut.step != &"tilt" and tut._tilt_seen.size() == 4, "passo 6b: as 4 inclinações avançam o tutorial")
	check(not abilities.practice, "o modo treino é desligado depois do passo")
	await real_seconds(0.5)

	# --- Melhorias e despedida: toque na carta "Saída" ---
	check(await _wait_step(&"upgrades", 20.0), "o tutorial chega à aba de melhorias")
	await real_seconds(1.2)
	var menu: TutorialUpgradeMenu = tut.menu
	var exit_card: Control = menu._cards[1]
	await snap("48_tutorial_melhorias")
	await tap(4, exit_card.get_global_rect().get_center(), 3)
	check(await _wait_step(&"farewell", 10.0) or tut.step == &"done" or tut.step == &"exit_selected", "tocar na carta 'Saída' avança")
	check(await _wait_step(&"done", 20.0) and tut._leaving, "o tutorial termina (despedida e troca para a Fase 1)")
	check(changes == ["res://Scenes/Fase1/fase_1.tscn"], "o tutorial pede a Fase 1 ao terminar (%s)" % [changes])
	# Ordem dos passos vistos.
	var expected: Array[StringName] = [&"move", &"dash", &"droid_entry", &"shoot", &"weapon", &"sword", &"finish", &"command", &"tilt", &"upgrades"]
	var idx: int = 0
	for s: StringName in _transitions:
		if idx < expected.size() and s == expected[idx]:
			idx += 1
	check(idx == expected.size(), "passos na ordem certa: %s (vistos: %s)" % [expected, _transitions])
