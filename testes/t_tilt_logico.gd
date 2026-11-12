extends TesteBase
## Testa a função PURA do acelerômetro (`TiltLogic`): vetor + calibração + plataforma + orientação -> direção.
## Cobre as 4 direções, as 2 plataformas (Android e iOS), as 2 paisagens e os dois sistemas de eixos
## (já girado pelo Godot e bruto), além de zona morta, sensibilidade e diagonais.

const G: float = 9.8
const HOLD_BACK_DEG: float = 40.0  # Celular segurado inclinado para trás, como na mão.
const TILT_DEG: float = 24.0  # Inclinação que deve disparar uma seta.

var _failed_combos: Array[String] = []


## Gravidade em tela (x direita, y cima, z fora) com o celular segurado a 40 graus e inclinado `roll` (borda direita
## desce, em graus) e `pitch` (borda de cima desce, em graus).
func _screen_gravity(roll: float, pitch: float) -> Vector3:
	# pitch0 = -(90 - 40) = -50 graus (celular a 40 graus de inclinação para trás); `pitch` positivo = borda de cima desce.
	var p: float = deg_to_rad(-(90.0 - HOLD_BACK_DEG) + pitch)
	var r: float = deg_to_rad(roll)
	return Vector3(sin(r), cos(r) * sin(p), -cos(r) * cos(p)) * G


## O que o sensor entrega no sistema BRUTO (natural, retrato) da plataforma para uma gravidade em tela.
func _raw_for(screen: Vector3, platform: String, orientation: int) -> Vector3:
	var natural: Vector3
	if orientation == TiltLogic.Orientation.LANDSCAPE:
		natural = Vector3(screen.y, -screen.x, screen.z)  # inverso de (sx, sy) = (-vy, vx)
	else:
		natural = Vector3(-screen.y, screen.x, screen.z)  # inverso de (sx, sy) = (vy, -vx)
	return -natural if platform == "android" else natural  # Android: reação do apoio; iOS: gravidade


func rodar() -> void:
	var directions: Dictionary = {
		"direita": [TiltLogic.DIR_RIGHT, TILT_DEG, 0.0],
		"esquerda": [TiltLogic.DIR_LEFT, -TILT_DEG, 0.0],
		"cima": [TiltLogic.DIR_UP, 0.0, TILT_DEG],
		"baixo": [TiltLogic.DIR_DOWN, 0.0, -TILT_DEG],
	}
	var neutral: Vector3 = _screen_gravity(0.0, 0.0)
	# 1) Sistema já girado (o que o Godot 4.x entrega no Android e no iOS): vale para as duas plataformas e paisagens.
	for platform: String in ["android", "ios"]:
		for orientation: int in [TiltLogic.Orientation.LANDSCAPE, TiltLogic.Orientation.LANDSCAPE_REVERSE]:
			var calibration: Vector3 = TiltLogic.screen_unit(neutral, platform, orientation, TiltLogic.Frame.SCREEN)
			for dir_name: String in directions:
				var spec: Array = directions[dir_name]
				var accel: Vector3 = _screen_gravity(float(spec[1]), float(spec[2]))
				var got: int = TiltLogic.detect(accel, calibration, platform, orientation, 1.0, TiltLogic.Frame.SCREEN)
				check(got == int(spec[0]), "SCREEN %s/%d: inclinar para %s -> seta %s" % [platform, orientation, dir_name, got])
	# 2) Sistema bruto: o mapeamento por plataforma e orientação gira e troca o sinal certo.
	for platform: String in ["android", "ios"]:
		for orientation: int in [TiltLogic.Orientation.LANDSCAPE, TiltLogic.Orientation.LANDSCAPE_REVERSE]:
			var raw_neutral: Vector3 = _raw_for(neutral, platform, orientation)
			var calibration: Vector3 = TiltLogic.screen_unit(raw_neutral, platform, orientation, TiltLogic.Frame.RAW)
			for dir_name: String in directions:
				var spec: Array = directions[dir_name]
				var raw: Vector3 = _raw_for(_screen_gravity(float(spec[1]), float(spec[2])), platform, orientation)
				var got: int = TiltLogic.detect(raw, calibration, platform, orientation, 1.0, TiltLogic.Frame.RAW)
				check(got == int(spec[0]), "RAW %s/%d: inclinar para %s -> seta %s" % [platform, orientation, dir_name, got])
	# 3) Exemplos escritos à mão (independentes das fórmulas acima).
	# Android, paisagem com o topo natural à esquerda (ROTATION_90): em pé o sensor lê (+g, 0, 0); inclinar para a direita
	# da tela (borda inferior natural desce) faz o eixo y do sensor ficar positivo.
	var a_neutral: Vector3 = Vector3(G, 0.0, 0.0)
	var a_cal: Vector3 = TiltLogic.screen_unit(a_neutral, "android", TiltLogic.Orientation.LANDSCAPE, TiltLogic.Frame.RAW)
	var a_right: Vector3 = Vector3(G * cos(deg_to_rad(25.0)), G * sin(deg_to_rad(25.0)), 0.0)
	check(TiltLogic.detect(a_right, a_cal, "android", TiltLogic.Orientation.LANDSCAPE, 1.0, TiltLogic.Frame.RAW) == TiltLogic.DIR_RIGHT,
			"Android ROTATION_90 bruto: y positivo = direita")
	# iOS, mesma posição física: CoreMotion entrega a gravidade (sinal oposto).
	var i_cal: Vector3 = TiltLogic.screen_unit(Vector3(-G, 0.0, 0.0), "ios", TiltLogic.Orientation.LANDSCAPE, TiltLogic.Frame.RAW)
	var i_right: Vector3 = Vector3(-G * cos(deg_to_rad(25.0)), -G * sin(deg_to_rad(25.0)), 0.0)
	check(TiltLogic.detect(i_right, i_cal, "ios", TiltLogic.Orientation.LANDSCAPE, 1.0, TiltLogic.Frame.RAW) == TiltLogic.DIR_RIGHT,
			"iOS LandscapeRight bruto: y negativo = direita")
	# Paisagem INVERTIDA, escrita à mão (Android ROTATION_270 / iOS LandscapeLeft): o topo natural aponta para a direita
	# da tela; em pé o sensor Android lê (-g, 0, 0); inclinar para a direita da tela faz o eixo y do sensor ficar NEGATIVO.
	var rev: int = TiltLogic.Orientation.LANDSCAPE_REVERSE
	var ar_cal: Vector3 = TiltLogic.screen_unit(Vector3(-G, 0.0, 0.0), "android", rev, TiltLogic.Frame.RAW)
	check(TiltLogic.detect(Vector3(-G * cos(deg_to_rad(25.0)), -G * sin(deg_to_rad(25.0)), 0.0), ar_cal, "android", rev, 1.0, TiltLogic.Frame.RAW) == TiltLogic.DIR_RIGHT,
			"Android ROTATION_270 bruto: y negativo = direita")
	check(TiltLogic.detect(Vector3(-G * cos(deg_to_rad(25.0)), G * sin(deg_to_rad(25.0)), 0.0), ar_cal, "android", rev, 1.0, TiltLogic.Frame.RAW) == TiltLogic.DIR_LEFT,
			"Android ROTATION_270 bruto: y positivo = esquerda")
	var ir_cal: Vector3 = TiltLogic.screen_unit(Vector3(G, 0.0, 0.0), "ios", rev, TiltLogic.Frame.RAW)
	check(TiltLogic.detect(Vector3(G * cos(deg_to_rad(25.0)), G * sin(deg_to_rad(25.0)), 0.0), ir_cal, "ios", rev, 1.0, TiltLogic.Frame.RAW) == TiltLogic.DIR_RIGHT,
			"iOS LandscapeLeft bruto: y positivo = direita")
	# A paisagem (normal ou invertida) é detectada pelo sinal da gravidade natural em x.
	check(TiltLogic.detect_orientation(Vector3(G, 0.0, 0.0), "android") == TiltLogic.Orientation.LANDSCAPE, "Android: sensor +x em pé = paisagem normal")
	check(TiltLogic.detect_orientation(Vector3(-G, 0.0, 0.0), "android") == TiltLogic.Orientation.LANDSCAPE_REVERSE, "Android: sensor -x em pé = paisagem invertida")
	check(TiltLogic.detect_orientation(Vector3(-G, 0.0, 0.0), "ios") == TiltLogic.Orientation.LANDSCAPE, "iOS: gravidade -x em pé = paisagem normal")
	check(TiltLogic.detect_orientation(Vector3(G, 0.0, 0.0), "ios") == TiltLogic.Orientation.LANDSCAPE_REVERSE, "iOS: gravidade +x em pé = paisagem invertida")
	# 4) Zona morta, sensibilidade, diagonal e sensor ausente.
	var cal: Vector3 = TiltLogic.screen_unit(neutral, "android", TiltLogic.Orientation.LANDSCAPE)
	check(TiltLogic.detect(_screen_gravity(5.0, 0.0), cal, "android", TiltLogic.Orientation.LANDSCAPE) == TiltLogic.DIR_NONE,
			"5 graus fica na zona morta")
	check(TiltLogic.detect(_screen_gravity(0.0, 0.0), cal, "android", TiltLogic.Orientation.LANDSCAPE) == TiltLogic.DIR_NONE,
			"neutro não dispara")
	check(TiltLogic.detect(_screen_gravity(10.0, 0.0), cal, "android", TiltLogic.Orientation.LANDSCAPE, 1.0) == TiltLogic.DIR_NONE,
			"10 graus não dispara com sensibilidade 1")
	check(TiltLogic.detect(_screen_gravity(10.0, 0.0), cal, "android", TiltLogic.Orientation.LANDSCAPE, 2.0) == TiltLogic.DIR_RIGHT,
			"10 graus dispara com sensibilidade 2")
	check(TiltLogic.detect(_screen_gravity(20.0, 20.0), cal, "android", TiltLogic.Orientation.LANDSCAPE) == TiltLogic.DIR_NONE,
			"diagonal ambígua não dispara")
	check(TiltLogic.detect(_screen_gravity(30.0, 10.0), cal, "android", TiltLogic.Orientation.LANDSCAPE) == TiltLogic.DIR_RIGHT,
			"eixo dominante vence na quase-diagonal")
	check(TiltLogic.is_missing(Vector3.ZERO), "vetor zero = sem sensor")
	check(not TiltLogic.is_missing(Vector3(0.0, -G, 0.0)), "vetor com gravidade = sensor presente")
	check(TiltLogic.detect(Vector3.ZERO, cal, "android", TiltLogic.Orientation.LANDSCAPE) == TiltLogic.DIR_NONE,
			"sensor zero devolve nenhuma direção")
	# Unidades: m/s² (Android) ou g dão o mesmo resultado.
	var in_g: Vector3 = _screen_gravity(TILT_DEG, 0.0) / G
	check(TiltLogic.detect(in_g, cal, "ios", TiltLogic.Orientation.LANDSCAPE) == TiltLogic.DIR_RIGHT, "independe da unidade (g ou m/s²)")
	# Detecção do sistema de eixos na calibração.
	check(TiltLogic.detect_frame(_screen_gravity(0.0, 0.0)) == TiltLogic.Frame.SCREEN, "pose normal = já girado para a tela")
	check(TiltLogic.detect_frame(Vector3(G, 0.0, 0.0)) == TiltLogic.Frame.RAW, "gravidade toda em x = eixos brutos (retrato natural)")
