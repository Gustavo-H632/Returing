extends TesteBase
## Testa o autoload TiltInput de ponta a ponta com `Input.set_accelerometer`: as 4 direções, as 2 paisagens e as 2
## plataformas (sistema bruto), zona morta, histerese (volta ao neutro), cooldown, sensor ausente e calibração.

const G: float = 9.8
const DT: float = 1.0 / 60.0
const TILT_DEG: float = 26.0

var _got: Array[int] = []
var _ti: Node = null


func _gravity(roll: float, pitch: float) -> Vector3:
	var p: float = deg_to_rad(-50.0 + pitch)
	var r: float = deg_to_rad(roll)
	return Vector3(sin(r), cos(r) * sin(p), -cos(r) * cos(p)) * G


func _raw_for(screen: Vector3, platform: String, orientation: int) -> Vector3:
	var natural: Vector3 = Vector3(screen.y, -screen.x, screen.z) if orientation == TiltLogic.Orientation.LANDSCAPE \
			else Vector3(-screen.y, screen.x, screen.z)
	return -natural if platform == "android" else natural


## Avança `time` segundos mantendo o acelerômetro em `vec` (passo fixo, determinístico).
func _hold(vec: Vector3, time: float) -> void:
	Input.set_accelerometer(vec)
	var steps: int = int(round(time / DT))
	for i: int in steps:
		_ti.step(DT)


func _on_arrow(dir: int) -> void:
	_got.append(dir)


func _fresh(platform: String = "android", orientation: int = TiltLogic.Orientation.LANDSCAPE, frame: int = TiltLogic.Frame.SCREEN) -> void:
	if _ti.is_active():
		_ti.release(self)
	_ti.sensitivity = 1.0
	_ti.deadzone = 1.0
	_ti.cooldown = 0.30
	_ti.smoothing_rate = 14.0
	_ti.platform_override = platform
	_ti.orientation_override = orientation
	_ti.frame = frame
	_ti.simulate_with_keys = false
	_ti.sensor_missing = false
	_ti.sensor_available = false
	_got.clear()


func rodar() -> void:
	_ti = get_node("/root/TiltInput")
	_ti.arrow.connect(_on_arrow)
	_ti.set_process(false)  # os passos são manuais
	var neutral: Vector3 = _gravity(0.0, 0.0)

	# 1) Quatro direções, duas plataformas, duas paisagens, nos dois sistemas de eixos.
	var cases: Dictionary = {
		"direita": [TiltLogic.DIR_RIGHT, TILT_DEG, 0.0], "esquerda": [TiltLogic.DIR_LEFT, -TILT_DEG, 0.0],
		"cima": [TiltLogic.DIR_UP, 0.0, TILT_DEG], "baixo": [TiltLogic.DIR_DOWN, 0.0, -TILT_DEG],
	}
	for frame: int in [TiltLogic.Frame.SCREEN, TiltLogic.Frame.RAW]:
		for platform: String in ["android", "ios"]:
			for orientation: int in [TiltLogic.Orientation.LANDSCAPE, TiltLogic.Orientation.LANDSCAPE_REVERSE]:
				for name: String in cases:
					_fresh(platform, orientation, frame)
					var spec: Array = cases[name]
					var rest: Vector3 = neutral if frame == TiltLogic.Frame.SCREEN else _raw_for(neutral, platform, orientation)
					var tilted: Vector3 = _gravity(float(spec[1]), float(spec[2]))
					if frame == TiltLogic.Frame.RAW:
						tilted = _raw_for(tilted, platform, orientation)
					Input.set_accelerometer(rest)
					_ti.acquire(self)
					_hold(rest, 0.4)  # calibra no neutro
					_hold(tilted, 0.6)
					check(_got == [int(spec[0])], "frame %d %s/%d: %s gera uma única seta (%s)" % [frame, platform, orientation, name, _got])
					_ti.release(self)

	# 2) Zona morta: inclinação pequena não dispara.
	_fresh()
	Input.set_accelerometer(neutral)
	_ti.acquire(self)
	_hold(neutral, 0.4)
	_hold(_gravity(6.0, 0.0), 0.6)
	check(_got.is_empty(), "6 graus fica na zona morta")
	_ti.release(self)

	# 3) Histerese: segurar inclinado não repete; só depois de voltar ao neutro a próxima seta sai.
	_fresh()
	Input.set_accelerometer(neutral)
	_ti.acquire(self)
	_hold(neutral, 0.4)
	_hold(_gravity(TILT_DEG, 0.0), 2.0)
	check(_got == [TiltLogic.DIR_RIGHT], "segurar inclinado por 2 s gera só 1 seta (histerese)")
	_hold(_gravity(-TILT_DEG, 0.0), 1.0)  # vai direto para o outro lado sem passar pelo neutro de forma estável
	# passa pelo neutro rapidamente ao inverter (o filtro atravessa a zona morta), então pode ter rearmado:
	var after_flip: int = _got.size()
	check(after_flip <= 2, "inverter o lado dispara no máximo mais uma seta")
	_hold(neutral, 0.8)
	var before: int = _got.size()
	_hold(_gravity(0.0, TILT_DEG), 0.8)
	check(_got.size() == before + 1 and _got[_got.size() - 1] == TiltLogic.DIR_UP, "depois de voltar ao neutro a seta seguinte sai")
	_ti.release(self)

	# 4) Cooldown: ir e voltar muito rápido não gera seta antes do intervalo.
	_fresh()
	_ti.cooldown = 0.6
	_ti.smoothing_rate = 40.0
	Input.set_accelerometer(neutral)
	_ti.acquire(self)
	_hold(neutral, 0.4)
	_hold(_gravity(TILT_DEG, 0.0), 0.15)
	_hold(neutral, 0.15)
	_hold(_gravity(-TILT_DEG, 0.0), 0.15)
	check(_got.size() == 1, "cooldown de 0,6 s segura a segunda seta (%s)" % [_got])
	_hold(neutral, 0.2)
	_hold(_gravity(-TILT_DEG, 0.0), 0.5)
	check(_got.size() == 2 and _got[1] == TiltLogic.DIR_LEFT, "passado o cooldown a seta sai (%s)" % [_got])
	_ti.release(self)

	# 5) Calibração: a posição neutra é a de quando o modo abre (celular segurado em outro ângulo).
	_fresh()
	var other_hold: Vector3 = Vector3(0.0, -0.2, -0.98).normalized() * G  # quase deitado
	Input.set_accelerometer(other_hold)
	_ti.acquire(self)
	_hold(other_hold, 0.4)
	check(_got.is_empty(), "no neutro calibrado não sai seta")
	var rolled: Vector3 = Vector3(sin(deg_to_rad(TILT_DEG)), -0.2, -0.98).normalized() * G
	_hold(rolled, 0.6)
	check(_got == [TiltLogic.DIR_RIGHT], "inclinar a partir de outra pose neutra também funciona")
	# Calibrar de novo na pose inclinada: ela vira o neutro.
	_hold(rolled, 0.6)
	_ti.calibrate_now()
	_hold(rolled, 0.3)
	check(_ti.current_tilt.length() < 0.05, "depois de calibrar, a pose atual é o neutro (%s)" % _ti.current_tilt)
	_ti.release(self)

	# 6) Sensor ausente: acelerômetro sempre zero -> aviso e fallback.
	_fresh()
	var missing_signals: Array[bool] = []
	var on_state: Callable = func(available: bool) -> void: missing_signals.append(available)
	_ti.sensor_state_changed.connect(on_state)
	Input.set_accelerometer(Vector3.ZERO)
	_ti.acquire(self)
	_hold(Vector3.ZERO, 0.5)
	check(not _ti.sensor_missing, "antes de 1 s ainda não dá o sensor como ausente")
	_hold(Vector3.ZERO, 0.8)
	check(_ti.sensor_missing and not _ti.sensor_available, "depois de 1 s de zeros o sensor é dado como ausente")
	check(missing_signals == [false], "sinal sensor_state_changed(false) emitido uma vez")
	_hold(_gravity(0.0, 0.0), 0.2)
	check(_ti.sensor_available and not _ti.sensor_missing, "se o sensor aparecer, volta a valer")
	_ti.sensor_state_changed.disconnect(on_state)
	_ti.release(self)
	check(not _ti.is_active(), "sem ninguém pedindo, o TiltInput fica parado")

	# 6b) Zona morta no máximo (250%): a histerese continua valendo (segurar não repete a seta).
	_fresh()
	_ti.deadzone = 2.5
	_ti.sensitivity = 1.0
	Input.set_accelerometer(neutral)
	_ti.acquire(self)
	_hold(neutral, 0.4)
	_hold(_gravity(TILT_DEG, 0.0), 3.0)
	check(_got == [TiltLogic.DIR_RIGHT], "com zona morta de 250%%, segurar a inclinação 3 s ainda gera uma única seta (%s)" % [_got])
	_ti.release(self)

	# 6c) Calibração guardada: com `auto_calibrate` desligado, a pose do botão "Calibrar" é o neutro ao abrir o modo.
	_fresh()
	_ti.auto_calibrate = true
	Input.set_accelerometer(neutral)
	_ti.acquire(self)
	_hold(neutral, 0.4)
	var posed: Vector3 = _gravity(0.0, 14.0)
	_hold(posed, 0.3)
	_ti.calibrate_now()
	_hold(posed, 0.3)
	check(_ti.saved_neutral != Vector3.ZERO, "Calibrar guarda a pose neutra")
	_ti.release(self)
	_ti.auto_calibrate = false
	_got.clear()
	Input.set_accelerometer(posed)
	_ti.acquire(self)
	_hold(posed, 0.4)
	check(_ti.current_tilt.length() < 0.05, "com auto_calibrate desligado, a pose guardada é o neutro ao abrir (%s)" % _ti.current_tilt)
	_hold(_gravity(TILT_DEG, 14.0), 0.6)
	check(_got == [TiltLogic.DIR_RIGHT], "e a inclinação parte dela (%s)" % [_got])
	_ti.release(self)
	_ti.auto_calibrate = true
	_ti.saved_neutral = Vector3.ZERO

	# 6d) Sistema bruto: a paisagem invertida é detectada pelo próprio vetor (sem depender do DisplayServer).
	_fresh("android", -1, TiltLogic.Frame.RAW)
	_ti.orientation_override = -1
	var rev_neutral: Vector3 = _raw_for(neutral, "android", TiltLogic.Orientation.LANDSCAPE_REVERSE)
	Input.set_accelerometer(rev_neutral)
	_ti.acquire(self)
	_hold(rev_neutral, 0.4)
	_hold(_raw_for(_gravity(TILT_DEG, 0.0), "android", TiltLogic.Orientation.LANDSCAPE_REVERSE), 0.6)
	check(_got == [TiltLogic.DIR_RIGHT], "bruto/invertida detectada pelo vetor: inclinar para a direita = direita (%s)" % [_got])
	_ti.release(self)
	_ti.orientation_override = TiltLogic.Orientation.LANDSCAPE

	# 7) Simulação por teclas (PC com --mobile): sem acelerômetro e com `simulate_with_keys` o vetor sintético existe.
	_fresh()
	_ti.simulate_with_keys = true
	Input.set_accelerometer(Vector3.ZERO)
	check(_ti.read_raw().length() > 1.0, "simulação por teclas devolve um vetor de gravidade")
	check(TiltLogic.detect_frame(_ti.read_raw()) == TiltLogic.Frame.SCREEN, "vetor simulado está no sistema de tela")
	var rest: Vector3 = _ti.read_raw()
	var cal: Vector3 = TiltLogic.screen_unit(rest, "android", TiltLogic.Orientation.LANDSCAPE)
	var keys: Dictionary = {KEY_L: TiltLogic.DIR_RIGHT, KEY_J: TiltLogic.DIR_LEFT, KEY_I: TiltLogic.DIR_UP, KEY_K: TiltLogic.DIR_DOWN}
	for key: int in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key as Key
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		var dir: int = TiltLogic.detect(_ti.read_raw(), cal, "android", TiltLogic.Orientation.LANDSCAPE)
		check(dir == int(keys[key]), "tecla %s inclina o celular simulado para a direção %d (%d)" % [OS.get_keycode_string(key as Key), keys[key], dir])
		var release_event: InputEventKey = event.duplicate() as InputEventKey
		release_event.pressed = false
		Input.parse_input_event(release_event)
		Input.flush_buffered_events()
	Input.set_accelerometer(Vector3.ZERO)
