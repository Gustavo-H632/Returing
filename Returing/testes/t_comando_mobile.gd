extends TesteBase
## Modo comando no celular, no jogo real: botão de comando, quadro de comandos, setas vindas da inclinação do
## acelerômetro (Input.set_accelerometer), sequência -> habilidade certa, erro de sequência, fallback com D-pad
## quando o sensor é zero e fechamento do modo.

var mc: Node = null
var p: Player = null
var abilities: AbilityComponent = null
var board: CommandBoard = null
var ti: Node = null
var activated: Array[StringName] = []


func _tilt(dir: int, hold: float = 0.7) -> void:
	Input.set_accelerometer(tilt_vector(dir))
	await real_seconds(hold)


func _neutral(hold: float = 0.7) -> void:
	Input.set_accelerometer(gravity())
	await real_seconds(hold)


## Digita uma sequência de setas inclinando o celular (volta ao neutro entre uma e outra).
func _type_sequence(seq: Array[int]) -> void:
	for dir: int in seq:
		await _tilt(dir)
		await _neutral()


func rodar() -> void:
	mc = get_node("/root/MobileControls")
	ti = get_node("/root/TiltInput")
	ti.simulate_with_keys = false
	ti.cooldown = 0.25
	Input.set_accelerometer(gravity())
	await set_window()
	load_level("res://Scenes/Fase1/fase_1.tscn")
	await frames(60)
	p = player()
	p.conceder_invulnerabilidade(9999.0)
	abilities = p.get_node("AbilityComponent") as AbilityComponent
	board = (p.get_node("AbilitiesUI") as Node).get_node("CommandBoard") as CommandBoard
	check(board != null, "o quadro de comandos existe na interface de habilidades")
	check(not board.visible, "quadro de comandos escondido fora do modo comando")
	abilities.ability_activated.connect(func(data: AbilityData) -> void: activated.append(data.id))

	# Sem habilidades: o botão avisa e não abre.
	await tap(0, mc.control_center(MobileLayout.COMMAND))
	check(not abilities.command_active, "sem habilidades o botão de comando não abre o modo")

	# Com habilidades: abre, mostra o quadro e liga o sensor.
	var escudo: AbilityData = load("res://abilities/data/escudo.tres") as AbilityData
	var passo: AbilityData = load("res://abilities/data/passo_agil.tres") as AbilityData
	abilities.learn(escudo)
	abilities.learn(passo)
	await frames(5)
	await tap(0, mc.control_center(MobileLayout.COMMAND))
	await frames(5)
	check(abilities.command_active, "botão de comando abre o modo comando")
	check(board.visible, "o quadro de comandos aparece no modo comando")
	check(ti.is_active(), "o acelerômetro é ligado com o modo aberto")
	var view: Vector2 = mc.view_size()
	var board_rect: Rect2 = Rect2(board.global_position, board.size * board.scale)
	check(board_rect.position.x / view.x >= 0.78 and board_rect.end.y / view.y <= 0.58, "o quadro está na região marcada no print (%s)" % board_rect)
	for id: StringName in [MobileLayout.MOVE, MobileLayout.AIM, MobileLayout.DASH, MobileLayout.WEAPON, MobileLayout.COMMAND]:
		var r: float = mc.control_radius(id)
		var c: Vector2 = mc.control_center(id)
		check(not board_rect.intersects(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)), "o quadro aberto não cobre %s" % id)
	await snap("20_comando_aberto")
	await real_seconds(0.6)  # calibra no neutro

	# Sequência do Escudo (cima, baixo, esquerda, direita) pela inclinação.
	var typed: Array[Array] = []
	abilities.arrow_input.connect(func(dir: int) -> void: typed.append([dir]))
	await _tilt(AbilityData.Dir.UP)
	check(typed.size() == 1 and typed[0][0] == AbilityData.Dir.UP, "inclinar para cima gera a seta cima (%s)" % [typed])
	await snap("21_comando_seta_cima")
	await _neutral()
	await _tilt(AbilityData.Dir.DOWN)
	check(typed.size() == 2 and typed[1][0] == AbilityData.Dir.DOWN, "inclinar para baixo gera a seta baixo")
	await _neutral()
	await _tilt(AbilityData.Dir.LEFT)
	check(typed.size() == 3 and typed[2][0] == AbilityData.Dir.LEFT, "inclinar para a esquerda gera a seta esquerda")
	await _neutral()
	check(activated.is_empty(), "a habilidade só dispara ao completar a sequência")
	await _tilt(AbilityData.Dir.RIGHT)
	check(typed.size() == 4 and typed[3][0] == AbilityData.Dir.RIGHT, "inclinar para a direita gera a seta direita")
	await real_seconds(0.2)
	check(activated == [&"escudo"], "a sequência cima-baixo-esquerda-direita dispara o Escudo (%s)" % [activated])
	check(abilities.get_cooldown_left(&"escudo") > 0.0, "o Escudo entra em recarga")
	await _neutral()

	# Segurar inclinado não repete a seta (histerese).
	typed.clear()
	await _tilt(AbilityData.Dir.LEFT, 1.5)
	check(typed.size() == 1, "segurar a inclinação 1,5 s gera uma única seta (%d)" % typed.size())
	await _neutral()
	await _tilt(AbilityData.Dir.RIGHT)
	await _neutral()
	await _tilt(AbilityData.Dir.LEFT)
	await real_seconds(0.2)
	check(activated == [&"escudo", &"passo_agil"], "esquerda-direita-esquerda dispara o Passo Ágil (%s)" % [activated])
	await _neutral()

	# Sequência errada zera o que foi digitado.
	var failed: Array[bool] = []
	abilities.input_failed.connect(func() -> void: failed.append(true))
	await _tilt(AbilityData.Dir.DOWN)
	await _neutral()
	await _tilt(AbilityData.Dir.DOWN)
	await _neutral()
	check(failed.size() >= 1, "sequência que não combina com nenhuma habilidade conta como erro")
	await _neutral()

	# Sem acelerômetro: aviso no quadro e D-pad por toque.
	Input.set_accelerometer(Vector3.ZERO)
	await real_seconds(1.4)
	check(ti.sensor_missing, "acelerômetro sempre zero = sensor ausente")
	check(mc.dpad_wanted(), "com o sensor ausente o D-pad de fallback aparece")
	await snap("22_comando_sem_sensor")
	var buttons: Array[Dictionary] = mc.dpad_buttons()
	var board_rect2: Rect2 = Rect2(board.global_position, board.size * board.scale)
	var inside: bool = true
	for b: Dictionary in buttons:
		inside = inside and board_rect2.has_point(b["center"] as Vector2)
	check(buttons.size() == 4 and inside, "os 4 botões do D-pad ficam dentro do quadro de comandos")
	activated.clear()
	abilities.learn(load("res://abilities/data/golpe_amplo.tres") as AbilityData)  # o Passo Ágil ainda está em recarga
	await real_seconds(0.5)
	# Digita o Golpe Amplo (esquerda, baixo, direita) tocando no D-pad.
	var by_dir: Dictionary = {}
	for b: Dictionary in buttons:
		by_dir[int(b["dir"])] = b["center"]
	for dir: int in [AbilityData.Dir.LEFT, AbilityData.Dir.DOWN, AbilityData.Dir.RIGHT]:
		await tap(1, by_dir[dir] as Vector2, 2)
		await real_seconds(0.15)
	check(activated == [&"golpe_amplo"], "o D-pad (fallback) também digita a sequência e dispara a habilidade (%s)" % [activated])

	# Mais habilidades do que cabem: o quadro mostra 3 linhas e "+N" (nunca vaza para cima dos botões).
	abilities.learn(load("res://abilities/data/cura.tres") as AbilityData)
	abilities.learn(load("res://abilities/data/pulso_emp.tres") as AbilityData)
	await frames(5)
	check(board._rows.size() == CommandBoard.MAX_ROWS and board._overflow == 2, "com 5 habilidades o quadro mostra %d linhas e +%d" % [board._rows.size(), board._overflow])
	var rows_bottom: float = CommandBoard.ROWS_TOP + CommandBoard.ROW_HEIGHT * float(CommandBoard.MAX_ROWS)
	check(rows_bottom <= CommandBoard.BASE_SIZE.y, "as linhas terminam dentro do quadro")

	# Fechar: tocar no botão de novo.
	await tap(0, mc.control_center(MobileLayout.COMMAND))
	await real_seconds(0.3)
	check(not abilities.command_active and not board.visible, "tocar no botão de comando de novo fecha o modo e o quadro")
	check(not ti.is_active(), "o sensor é desligado ao fechar o modo")
	check(is_equal_approx(Engine.time_scale, 1.0), "o tempo volta ao normal")
