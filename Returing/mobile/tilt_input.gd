extends Node
## Autoload TiltInput: lê o acelerômetro (Android/iOS) e transforma a inclinação do celular em setas do
## modo comando. Só trabalha enquanto alguém pede (`acquire`): no resto do tempo não gasta nada.
##
## Fluxo: amostra bruta -> vetor unitário em tela (`TiltLogic`) -> suavização (low-pass) -> inclinação
## em relação à posição neutra calibrada -> direção -> histerese (precisa voltar ao neutro antes da
## próxima seta) + cooldown curto -> sinal `arrow(dir)`.
##
## No PC com `--mobile` (sem sensor) as teclas I/J/K/L simulam a inclinação (cima/esquerda/baixo/direita).

## Uma seta foi detectada (valor de `AbilityData.Dir`).
signal arrow(dir: int)
## Inclinação suavizada mudou (a cada quadro enquanto ativo): UI x direita, y para baixo.
signal tilt_changed(tilt: Vector2)
## O sensor apareceu (true) ou foi dado como ausente (false).
signal sensor_state_changed(available: bool)

@export_group("Sensibilidade")
## Multiplica a inclinação: 2 = metade do ângulo para disparar uma seta.
@export_range(0.5, 2.5, 0.05) var sensitivity: float = 1.0
## Inclinação (em múltiplos de `TiltLogic.BASE_DEADZONE`) abaixo da qual o aparelho conta como "no neutro".
@export_range(0.5, 2.5, 0.05) var deadzone: float = 1.0
## Tempo mínimo (s) entre duas setas.
@export_range(0.05, 1.0, 0.01) var cooldown: float = 0.30
## Velocidade do filtro passa-baixa (maior = responde mais rápido, mais tremido).
@export_range(2.0, 40.0, 0.5) var smoothing_rate: float = 14.0

@export_group("Sensor")
## Segundos de leituras exatamente zero até dar o sensor como ausente.
@export_range(0.2, 5.0, 0.1) var missing_after: float = 1.0
## Sistema de eixos do vetor (veja `TiltLogic.Frame`). AUTO decide na calibração.
@export var frame: TiltLogic.Frame = TiltLogic.Frame.AUTO

## No PC com `--mobile`, I/J/K/L simulam a inclinação quando não há acelerômetro.
var simulate_with_keys: bool = false
## Plataforma/orientação usadas no mapeamento (a `Platform` informa; os testes sobrescrevem).
var platform_override: String = ""
var orientation_override: int = -1

## Calibrar ao abrir o modo comando (padrão). Desligado, vale a pose guardada pelo botão "Calibrar".
var auto_calibrate: bool = true
## Pose neutra guardada pelo botão "Calibrar" (vetor unitário em tela; ZERO = nunca calibrado).
var saved_neutral: Vector3 = Vector3.ZERO

var sensor_available: bool = false  # Já veio alguma leitura diferente de zero.
var sensor_missing: bool = false  # Ficou `missing_after` segundos só com zero.
var current_tilt: Vector2 = Vector2.ZERO  # Inclinação suavizada e calibrada (para os indicadores).
var last_direction: int = TiltLogic.DIR_NONE  # Direção da última seta (fica até voltar ao neutro).
var raw: Vector3 = Vector3.ZERO  # Última leitura bruta (para a depuração).
var calibration: Vector3 = Vector3.ZERO  # Posição neutra (vetor unitário em tela).
var resolved_frame: int = TiltLogic.Frame.SCREEN  # Sistema de eixos em uso.

var _holders: Dictionary = {}  # Quem pediu a leitura (id -> true).
var _smooth: Vector3 = Vector3.ZERO  # Vetor unitário em tela suavizado.
var _has_smooth: bool = false
var _calibrate_pending: bool = false
var _store_neutral: bool = false  # guardar a próxima calibração em `saved_neutral`
var _use_saved: bool = false  # usar `saved_neutral` em vez de calibrar ao abrir
var _latched: bool = false  # Já disparou e ainda não voltou ao neutro.
var _cooldown_left: float = 0.0
var _zero_time: float = 0.0
var _debug_overlay: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # Continua lendo com o jogo pausado (tela de configurações).
	process_priority = -50
	simulate_with_keys = Platform.simulated
	_load_settings()
	set_process(false)
	if Platform.debug_tilt:
		var overlay: Node = load("res://mobile/tilt_debug_overlay.gd").new()
		add_child(overlay)
		_debug_overlay = overlay


## Pede a leitura do sensor. Ao primeiro pedido a posição neutra é calibrada no próximo quadro.
func acquire(holder: Object) -> void:
	var id: int = holder.get_instance_id()
	var was_idle: bool = _holders.is_empty()
	_holders[id] = true
	if was_idle:
		_start()


## Devolve o pedido. Sem pedidos o sensor deixa de ser lido.
func release(holder: Object) -> void:
	_holders.erase(holder.get_instance_id())
	if _holders.is_empty():
		_stop()


## True enquanto alguém usa o sensor.
func is_active() -> bool:
	return not _holders.is_empty()


## True se o aparelho tem acelerômetro utilizável AGORA. Um sensor real sempre mede a gravidade, então qualquer
## leitura diferente de zero prova que ele existe; a simulação por teclas (PC com `--mobile`) conta como sensor.
## É o que decide se "Calibrar", sensibilidade, zona morta e intervalo aparecem nas configurações.
func has_sensor() -> bool:
	if simulate_with_keys:
		return true
	if sensor_missing:
		return false
	return sensor_available or Input.get_accelerometer() != Vector3.ZERO


## Calibra a posição neutra com a pose atual do aparelho (botão "Calibrar").
func calibrate_now() -> void:
	_calibrate_pending = true
	_store_neutral = true  # a pose calibrada também fica guardada (vale quando `auto_calibrate` está desligado)


## Atualiza a posição neutra imediatamente com o vetor suavizado atual (para os testes, sem esperar quadro).
func calibrate_immediately() -> void:
	if _has_smooth:
		calibration = _smooth
		_latched = false
		_calibrate_pending = false


## Tira uma foto do estado e salva os ajustes (sensibilidade, zona morta, cooldown).
func save_settings() -> void:
	MobileSettings.set_value(MobileSettings.SECTION_TILT, "sensitivity", sensitivity)
	MobileSettings.set_value(MobileSettings.SECTION_TILT, "deadzone", deadzone)
	MobileSettings.set_value(MobileSettings.SECTION_TILT, "cooldown", cooldown)
	MobileSettings.set_value(MobileSettings.SECTION_TILT, "auto_calibrate", auto_calibrate)
	MobileSettings.set_value(MobileSettings.SECTION_TILT, "neutral", saved_neutral)
	MobileSettings.save()


## Lê os ajustes salvos.
func _load_settings() -> void:
	sensitivity = clampf(float(MobileSettings.get_value(MobileSettings.SECTION_TILT, "sensitivity", sensitivity)), 0.5, 2.5)
	deadzone = clampf(float(MobileSettings.get_value(MobileSettings.SECTION_TILT, "deadzone", deadzone)), 0.5, 2.5)
	cooldown = clampf(float(MobileSettings.get_value(MobileSettings.SECTION_TILT, "cooldown", cooldown)), 0.05, 1.0)
	auto_calibrate = bool(MobileSettings.get_value(MobileSettings.SECTION_TILT, "auto_calibrate", true))
	var neutral: Variant = MobileSettings.get_value(MobileSettings.SECTION_TILT, "neutral", Vector3.ZERO)
	saved_neutral = neutral as Vector3 if neutral is Vector3 else Vector3.ZERO


## Zera o estado e liga o processamento.
func _start() -> void:
	_has_smooth = false
	_calibrate_pending = true
	_use_saved = not auto_calibrate and saved_neutral != Vector3.ZERO
	_latched = false
	_cooldown_left = 0.0
	_zero_time = 0.0
	current_tilt = Vector2.ZERO
	last_direction = TiltLogic.DIR_NONE
	set_process(true)


func _stop() -> void:
	set_process(false)
	current_tilt = Vector2.ZERO
	last_direction = TiltLogic.DIR_NONE
	_latched = false


## Plataforma usada no mapeamento.
func _platform() -> String:
	return platform_override if platform_override != "" else Platform.platform_name()


## Orientação de paisagem usada no mapeamento.
func _orientation() -> int:
	if orientation_override >= 0:
		return orientation_override
	if resolved_frame == TiltLogic.Frame.RAW and not raw.is_zero_approx():
		# Sistema bruto: a paisagem (normal ou invertida) sai do sinal da gravidade no eixo x natural.
		return TiltLogic.detect_orientation(raw, _platform())
	return Platform.landscape_orientation()


## Leitura bruta: o acelerômetro real ou, no PC com `--mobile`, o vetor sintético das teclas I/J/K/L.
func read_raw() -> Vector3:
	var value: Vector3 = Input.get_accelerometer()
	if value == Vector3.ZERO and simulate_with_keys:
		return _simulated_vector()
	return value


## Gravidade sintética: celular a 40 graus (como na mão) + 28 graus de inclinação enquanto a tecla estiver apertada.
func _simulated_vector() -> Vector3:
	var roll: float = 0.0
	var pitch: float = 0.0
	if Input.is_physical_key_pressed(KEY_L):
		roll += 1.0
	if Input.is_physical_key_pressed(KEY_J):
		roll -= 1.0
	if Input.is_physical_key_pressed(KEY_I):
		pitch += 1.0  # borda de cima desce = seta para cima
	if Input.is_physical_key_pressed(KEY_K):
		pitch -= 1.0
	var pitch_angle: float = deg_to_rad(-(90.0 - 40.0) + 28.0 * pitch)  # segurado a 40 graus + 28 graus nas teclas
	var roll_angle: float = deg_to_rad(28.0 * roll)
	return Vector3(sin(roll_angle), cos(roll_angle) * sin(pitch_angle), -cos(roll_angle) * cos(pitch_angle)) * 9.8


func _process(delta: float) -> void:
	step(delta / maxf(Engine.time_scale, 0.05))  # tempo real, mesmo com a câmera lenta do modo comando


## Um passo da leitura (público para os testes poderem avançar o tempo sem esperar quadros).
func step(dt: float) -> void:
	raw = read_raw()
	if TiltLogic.is_missing(raw):
		_zero_time += dt
		if _zero_time >= missing_after and not sensor_missing:
			sensor_missing = true
			sensor_available = false
			sensor_state_changed.emit(false)
		current_tilt = Vector2.ZERO
		tilt_changed.emit(current_tilt)
		return
	_zero_time = 0.0
	if not sensor_available or sensor_missing:
		sensor_available = true
		sensor_missing = false
		sensor_state_changed.emit(true)
	if frame != TiltLogic.Frame.AUTO:
		resolved_frame = frame  # sistema fixo: a orientação detectada também depende dele
	var frame_now: int = resolved_frame
	var sample: Vector3 = TiltLogic.screen_unit(raw, _platform(), _orientation(), frame_now)
	if not _has_smooth:
		_smooth = sample
		_has_smooth = true
	else:
		_smooth = _smooth.lerp(sample, 1.0 - exp(-smoothing_rate * dt)).normalized()
	if _calibrate_pending:
		if frame == TiltLogic.Frame.AUTO:
			resolved_frame = TiltLogic.detect_frame(raw)
			sample = TiltLogic.screen_unit(raw, _platform(), _orientation(), resolved_frame)
			_smooth = sample
		else:
			resolved_frame = frame
		calibration = saved_neutral if _use_saved else _smooth
		if _store_neutral:
			saved_neutral = calibration
			_store_neutral = false
			save_settings()
		_use_saved = false
		_calibrate_pending = false
		_latched = false
	_cooldown_left = maxf(_cooldown_left - dt, 0.0)
	# Inclinação suavizada em relação ao neutro.
	current_tilt = TiltLogic.tilt_from_unit(_smooth, calibration)
	tilt_changed.emit(current_tilt)
	var dir: int = TiltLogic.direction(current_tilt, sensitivity)
	if _latched:
		# Histerese: só rearma quando volta para dentro da zona morta.
		var back: float = maxf(absf(current_tilt.x), absf(current_tilt.y)) * sensitivity
		# O limite de rearme nunca passa de 80% do limiar de disparo (senão a histerese some com zona morta alta).
		if back < minf(TiltLogic.BASE_DEADZONE * deadzone, TiltLogic.BASE_THRESHOLD * 0.8):
			_latched = false
			last_direction = TiltLogic.DIR_NONE
		return
	if dir != TiltLogic.DIR_NONE and _cooldown_left <= 0.0:
		_latched = true
		_cooldown_left = cooldown
		last_direction = dir
		arrow.emit(dir)
