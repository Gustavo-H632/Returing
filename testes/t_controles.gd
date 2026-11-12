extends TesteBase
## Controles de toque no jogo real (fase 1, modo celular): joystick de movimento e de mira, botões de
## espada, dash, trocar arma e pausa, multitouch e o layout (posições do print). Toques reais:
## InputEventScreenTouch/Drag via Input.parse_input_event.

var mc: Node = null
var p: Player = null
var _spawn: Vector2 = Vector2.ZERO  # posição inicial do jogador na fase


func rodar() -> void:
	mc = get_node("/root/MobileControls")
	await set_window()
	check(Platform.is_mobile() and not Platform.is_desktop(), "Platform: modo celular ligado (--mobile)")
	check(mc.ativo, "MobileControls ativo")
	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(60)
	p = player()
	check(p != null, "jogador da fase 1 existe")
	_spawn = p.global_position
	check(mc._shown, "controles de toque visíveis em jogo")
	_reset()
	await _layout()
	await _movimento()
	await _mira_e_tiro()
	await _multitouch()
	await _botoes()
	await _pausa()


func _reset() -> void:
	p.conceder_invulnerabilidade(9999.0)
	p.hp = p.hp_maximo
	for pr: PlayerProjectile in active_projectiles():
		pr.recycle()
	p.velocity = Vector2.ZERO


## Posições do print (proporção da tela) e áreas sem sobreposição.
func _layout() -> void:
	var view: Vector2 = mc.view_size()
	check(absf(view.x / view.y - 1464.0 / 648.0) < 0.05, "janela 1500x664 -> tela lógica %s" % view)
	var expected: Dictionary = {
		MobileLayout.MOVE: Vector2(0.107, 0.806), MobileLayout.AIM: Vector2(0.90, 0.806),
		MobileLayout.DASH: Vector2(0.763, 0.852), MobileLayout.WEAPON: Vector2(0.69, 0.66), MobileLayout.COMMAND: Vector2(0.725, 0.50),
		MobileLayout.PAUSE: Vector2(0.964, 0.065), MobileLayout.INTERACT: Vector2(0.725, 0.34),
	}
	for id: StringName in expected:
		var c: Vector2 = mc.control_center(id) / view
		check(c.distance_to(expected[id]) < 0.02, "controle %s na posição do print (%s ~ %s)" % [id, c, expected[id]])
	# Nenhum botão se sobrepõe a outro controle.
	var ids: Array[StringName] = [MobileLayout.MOVE, MobileLayout.AIM, MobileLayout.DASH, MobileLayout.WEAPON,
			MobileLayout.COMMAND, MobileLayout.PAUSE, MobileLayout.INTERACT]
	check(is_equal_approx(mc.control_radius(MobileLayout.INTERACT), mc.control_radius(MobileLayout.WEAPON)), "o botão E tem o MESMO tamanho do botão de trocar arma")
	check(mc.control_center(MobileLayout.INTERACT).y < mc.control_center(MobileLayout.COMMAND).y - mc.control_radius(MobileLayout.COMMAND)
			and absf(mc.control_center(MobileLayout.INTERACT).x - mc.control_center(MobileLayout.COMMAND).x) < 2.0, "o botão E fica imediatamente acima do botão de modo comando")
	var overlap: int = 0
	for i: int in ids.size():
		for j: int in range(i + 1, ids.size()):
			var d: float = mc.control_center(ids[i]).distance_to(mc.control_center(ids[j]))
			if d < mc.control_radius(ids[i]) + mc.control_radius(ids[j]):
				overlap += 1
				print("  sobrepõe: ", ids[i], " x ", ids[j])
	check(overlap == 0, "nenhum controle se sobrepõe")
	# O quadro de comandos ocupa a região do print e não cobre joysticks, botões nem a barra de vida.
	var board: Rect2 = mc.control_rect(MobileLayout.BOARD)
	check(board.position.x / view.x >= 0.78 and board.end.x / view.x <= 1.001, "quadro de comandos começa em x >= 0,78 (%.3f)" % [board.position.x / view.x])
	check(board.position.y / view.y <= 0.03 and board.end.y / view.y <= 0.58, "quadro de comandos vai até y <= 0,57 (%.3f)" % [board.end.y / view.y])
	# (A PAUSA fica de propósito por cima do canto do quadro: o pedido a põe dentro da região azul e exige que fique
	# por cima de qualquer painel; o quadro deixa esse canto livre.)
	for id: StringName in [MobileLayout.MOVE, MobileLayout.AIM, MobileLayout.DASH, MobileLayout.WEAPON, MobileLayout.COMMAND]:
		var r: float = mc.control_radius(id)
		var c: Vector2 = mc.control_center(id)
		var hit: bool = board.intersects(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0))
		check(not hit, "o quadro de comandos não cobre %s" % id)
	# Outras proporções de tela (tablet 4:3, celular comprido, 16:9): o quadro continua na região e não cobre os botões.
	for other: Vector2 in [Vector2(1152.0, 864.0), Vector2(1152.0, 648.0), Vector2(1560.0, 648.0), Vector2(1400.0, 648.0)]:
		var rect_other: Rect2 = mc.layout.get_rect(MobileLayout.BOARD, other)
		check(rect_other.position.x / other.x >= 0.775 and rect_other.end.x <= other.x + 0.5 and rect_other.end.y / other.y <= 0.6,
				"proporção %s: o quadro fica na região marcada (x %.3f, y fim %.3f)" % [other, rect_other.position.x / other.x, rect_other.end.y / other.y])
		var overlaps_other: bool = false
		for id: StringName in [MobileLayout.DASH, MobileLayout.WEAPON, MobileLayout.COMMAND, MobileLayout.AIM, MobileLayout.MOVE]:
			var c2: Vector2 = mc.layout.get_center(id, other)
			var r2: float = mc.layout.get_radius(id)
			if rect_other.intersects(Rect2(c2 - Vector2(r2, r2), Vector2(r2, r2) * 2.0)):
				overlaps_other = true
		check(not overlaps_other, "proporção %s: o quadro não cobre joysticks nem botões" % other)
	var status: Rect2 = mc.control_rect(MobileLayout.STATUS)
	check(not board.intersects(status), "o quadro de comandos não cobre as barras de status")
	# As barras de status estão no canto superior esquerdo.
	var hud: GameHUD = level.get_node("HUD") as GameHUD
	var bar: Control = hud.player_health_bar
	check(bar.global_position.x < 80.0 and bar.global_position.y < 40.0, "barra de vida no canto superior esquerdo (%s)" % bar.global_position)


## Joystick esquerdo: cada direção move o jogador no mesmo sentido.
func _movimento() -> void:
	var center: Vector2 = mc.control_center(MobileLayout.MOVE)
	var dirs: Dictionary = {"direita": Vector2.RIGHT, "esquerda": Vector2.LEFT, "baixo": Vector2.DOWN, "cima": Vector2.UP}
	for name: String in dirs:
		_reset()
		await frames(10)
		var start: Vector2 = p.global_position
		touch(0, center + (dirs[name] as Vector2) * 60.0, true)
		await frames(20)
		var moved: Vector2 = p.global_position - start
		check(moved.dot(dirs[name]) > 15.0, "joystick de movimento %s move o jogador (%s)" % [name, moved])
		touch(0, center + (dirs[name] as Vector2) * 60.0, false)
		await frames(15)
		var stop: Vector2 = p.global_position
		await frames(10)
		check(p.global_position.distance_to(stop) < 2.0, "soltar o joystick para o jogador")
	# Zona morta: encostar no centro não anda.
	_reset()
	await frames(10)
	var s0: Vector2 = p.global_position
	touch(0, center + Vector2(3, 0), true)
	await frames(15)
	check(p.global_position.distance_to(s0) < 3.0, "toque na zona morta não move")
	touch(0, center, false)
	await frames(5)


## Joystick direito: arrastar mira e soltar atira naquela direção.
## O disparo é detectado pela saída do estado de tiro carregado (com a direção que o jogador usou), porque em
## campo aberto o projétil pode acertar um inimigo e sumir em um quadro.
func _mira_e_tiro() -> void:
	check(mc.weapon_ranged, "o joystick direito começa no tiro")
	var center: Vector2 = mc.control_center(MobileLayout.AIM)
	var fired: Array[Vector2] = []
	var last_state: Array[int] = [p.state]
	var on_state: Callable = func(new_state: int) -> void:
		if last_state[0] == Player.State.ATTACK_RANGED and new_state != Player.State.DASH:
			fired.append(p.get_shot_direction())
		last_state[0] = new_state
	p.estado_mudou.connect(on_state)
	for angle_deg: float in [0.0, 90.0, 180.0, 270.0]:
		_reset()
		p.global_position = _spawn + Vector2(320.0, 0.0)  # em campo aberto
		await frames(20)
		fired.clear()
		var dir: Vector2 = Vector2.from_angle(deg_to_rad(angle_deg))
		touch(1, center + dir * 60.0, true)
		await frames(14)
		check(mc.is_aiming(), "dedo no joystick de mira = mirando")
		touch(1, center + dir * 60.0, false)
		await frames(20)
		check(fired.size() == 1, "soltar o joystick de mira atira uma vez (ângulo %d, tiros=%d)" % [int(angle_deg), fired.size()])
		if not fired.is_empty():
			check(fired[0].dot(dir) > 0.8, "o tiro vai na direção apontada (%s ~ %s)" % [fired[0], dir])
	p.estado_mudou.disconnect(on_state)


## Multitouch: andar e atirar ao mesmo tempo, com dedos diferentes.
func _multitouch() -> void:
	_reset()
	await frames(20)
	var move_c: Vector2 = mc.control_center(MobileLayout.MOVE)
	var aim_c: Vector2 = mc.control_center(MobileLayout.AIM)
	var start: Vector2 = p.global_position
	touch(0, move_c + Vector2(60, 0), true)
	touch(1, aim_c + Vector2(0, -60), true)
	await frames(18)
	check(mc.is_aiming(), "multitouch: mirando com o dedo 1")
	check(p.global_position.x - start.x > 10.0, "multitouch: andando com o dedo 0 enquanto mira")
	var fired: Array[Vector2] = []
	var last_state: Array[int] = [p.state]
	var on_state: Callable = func(new_state: int) -> void:
		if last_state[0] == Player.State.ATTACK_RANGED and new_state != Player.State.DASH:
			fired.append(p.get_shot_direction())
		last_state[0] = new_state
	p.estado_mudou.connect(on_state)
	touch(1, aim_c + Vector2(0, -60), false)
	await frames(25)
	p.estado_mudou.disconnect(on_state)
	check(fired.size() == 1 and fired[0].y < -0.7, "multitouch: o tiro para cima saiu enquanto o dedo 0 segue andando (%s)" % [fired])
	check(Input.is_action_pressed(&"move_right"), "multitouch: o movimento continua apertado")
	touch(0, move_c + Vector2(60, 0), false)
	await frames(5)
	check(not Input.is_action_pressed(&"move_right"), "soltar o dedo 0 solta o movimento")


## Botões: dash, espada, trocar arma.
func _botoes() -> void:
	_reset()
	await frames(20)
	# Dash.
	var dash_started: bool = false
	touch(2, mc.control_center(MobileLayout.DASH), true)
	for i: int in 8:
		await get_tree().physics_frame
		if p.state == Player.State.DASH:
			dash_started = true
	touch(2, mc.control_center(MobileLayout.DASH), false)
	check(dash_started, "botão de dash faz o jogador dar dash")
	await frames(40)
	# Não existe mais botão só de espada: o golpe vem do joystick direito com a espada escolhida no "trocar arma".
	_reset()
	await frames(20)
	check(not MobileLayout.IDS.has(&"sword") and not MobileLayout.DEFS.has(&"sword"), "o botão de ataque só de espada foi removido do layout")
	check(mc.weapon_ranged, "o joystick direito começa no tiro")
	var antigo: Vector2 = Vector2(0.794, 0.664) * mc.view_size()  # onde o botão de espada ficava
	var golpeou: bool = false
	touch(3, antigo, true)
	for i: int in 12:
		await get_tree().physics_frame
		if p.state == Player.State.ATTACK_MELEE:
			golpeou = true
	touch(3, antigo, false)
	check(not golpeou, "tocar onde ficava o botão de espada não golpeia")
	await frames(20)
	_reset()
	await frames(10)
	# Trocar arma.
	var swapped: Array[bool] = []
	var on_swap: Callable = func(ranged: bool) -> void: swapped.append(ranged)
	mc.weapon_swapped.connect(on_swap)
	await tap(4, mc.control_center(MobileLayout.WEAPON))
	check(not mc.weapon_ranged and swapped == [false], "trocar arma: joystick direito vira espada")
	# Com a espada no joystick: arrastar e soltar golpeia.
	_reset()
	await frames(20)
	var aim_c: Vector2 = mc.control_center(MobileLayout.AIM)
	touch(5, aim_c + Vector2(60, 0), true)
	await frames(6)
	touch(5, aim_c + Vector2(60, 0), false)
	var swung2: bool = false
	for i: int in 14:
		await get_tree().physics_frame
		if p.state == Player.State.ATTACK_MELEE:
			swung2 = true
	check(swung2, "com a espada equipada, soltar o joystick golpeia")
	await frames(40)
	await tap(4, mc.control_center(MobileLayout.WEAPON))
	check(mc.weapon_ranged and swapped == [false, true], "trocar de novo volta ao tiro")
	mc.weapon_swapped.disconnect(on_swap)


## Botão de pausa abre e fecha o menu, e fica por cima do menu.
func _pausa() -> void:
	_reset()
	await frames(10)
	var pause_menu: Node = level.get_node("Pause")
	check(mc.is_control_active(MobileLayout.PAUSE), "botão de pausa visível em jogo")
	await tap(6, mc.control_center(MobileLayout.PAUSE))
	await frames(6)
	check(get_tree().paused and pause_menu.visible, "tocar na pausa abre o menu de pausa")
	check(mc.is_control_active(MobileLayout.PAUSE), "o botão de pausa continua visível com o menu aberto")
	check(mc._pause_layer.layer > pause_menu.layer, "o botão de pausa fica numa camada acima do menu de pausa")
	await tap(7, mc.control_center(MobileLayout.PAUSE))
	await frames(10)
	check(not get_tree().paused, "tocar na pausa de novo fecha o menu")
