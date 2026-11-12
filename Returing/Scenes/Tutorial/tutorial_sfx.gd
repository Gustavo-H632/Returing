class_name TutorialSfx
extends Node
## Sons do tutorial, sintetizados por código (não precisa de arquivo de áudio).
## Uso: `sfx.play(&"success")`. Os sons são gerados uma vez no `_ready`.

## Taxa de amostragem dos sons gerados (baixa de propósito: som "abafado" e leve).
const RATE: int = 22050
## Quantos sons podem tocar ao mesmo tempo.
const VOICES: int = 10

var _streams: Dictionary[StringName, AudioStreamWAV] = {}  # Nome do som -> áudio pronto.
var _players: Array[AudioStreamPlayer] = []  # Reprodutores reaproveitados.
var _next_voice: int = 0  # Próximo reprodutor a usar (rodízio).
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()  # Ruído sempre igual (seed fixa).


## Gera todos os sons e cria os reprodutores no barramento de efeitos.
func _ready() -> void:
	_rng.seed = 1945  # Mesmo ruído em toda execução.
	_build_streams()
	var bus: StringName = &"SFX" if AudioServer.get_bus_index(&"SFX") != -1 else &"Master"
	for i: int in VOICES:  # Um reprodutor por voz.
		var player: AudioStreamPlayer = AudioStreamPlayer.new()
		player.bus = bus
		add_child(player)
		_players.append(player)


## Toca um som pelo nome. `volume_db` e `pitch` ajustam só esta execução.
func play(sound: StringName, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream: AudioStreamWAV = _streams.get(sound)
	if stream == null or _players.is_empty():  # Nome desconhecido: ignora.
		return
	var player: AudioStreamPlayer = _players[_next_voice]
	_next_voice = (_next_voice + 1) % _players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.pitch_scale = pitch
	player.play()


## Lista os nomes de som disponíveis (usado nos testes).
func sound_names() -> Array[StringName]:
	var names: Array[StringName] = []
	for key: StringName in _streams:
		names.append(key)
	return names


# --- Construção dos sons ---

## Cria cada som. Todos são curtos e usam envelopes simples.
func _build_streams() -> void:
	_streams[&"voice"] = _make(_voice_echo())
	_streams[&"tick"] = _make(_tick())
	_streams[&"light_on"] = _make(_light_on())
	_streams[&"power_up"] = _make(_power_up())
	_streams[&"key_ok"] = _make(_key_ok())
	_streams[&"success"] = _make(_success())
	_streams[&"dash"] = _make(_dash())
	_streams[&"spawn"] = _make(_spawn())
	_streams[&"hit"] = _make(_hit())
	_streams[&"explosion"] = _make(_explosion())
	_streams[&"slash"] = _make(_slash())
	_streams[&"menu_open"] = _make(_menu_open())
	_streams[&"select"] = _make(_select())
	_streams[&"hatch"] = _make(_hatch())


## Converte amostras (-1 a 1) em um áudio de 16 bits.
func _make(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data: PackedByteArray = PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav: AudioStreamWAV = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav


## Cria um buffer vazio de `seconds` segundos.
func _buffer(seconds: float) -> PackedFloat32Array:
	var buffer: PackedFloat32Array = PackedFloat32Array()
	buffer.resize(int(seconds * float(RATE)))
	return buffer


## Soma `eco` (atrasado e atenuado) por cima do buffer, `taps` vezes.
func _add_echo(buffer: PackedFloat32Array, delay_s: float, gain: float, taps: int) -> void:
	var delay: int = int(delay_s * float(RATE))
	var source: PackedFloat32Array = buffer.duplicate()
	for tap: int in range(1, taps + 1):  # Cada repetição fica mais fraca.
		var g: float = pow(gain, float(tap))
		var offset: int = delay * tap
		for i: int in range(source.size() - offset):
			buffer[i + offset] += source[i] * g


# --- Receitas ---

## Voz grave e abafada, com eco (cada fala do mentor).
func _voice_echo() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(1.1)
	var low: float = 0.0  # Estado do filtro passa-baixa do ruído.
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var freq: float = 58.0 + 38.0 * exp(-t * 9.0)  # Desce rápido: "thum" grave.
		var tone: float = sin(TAU * freq * t) * exp(-t * 6.5)
		low += (_rng.randf_range(-1.0, 1.0) - low) * 0.05  # Ruído bem filtrado (som de câmara).
		out[i] = tone * 0.7 + low * exp(-t * 5.0) * 0.5
	_add_echo(out, 0.17, 0.45, 3)
	return out


## Tique curto e grave da digitação.
func _tick() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.045)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		out[i] = sin(TAU * 150.0 * t) * exp(-t * 90.0) * 0.35
	return out


## Luz do chão acendendo: clique + notinha subindo.
func _light_on() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.22)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var freq: float = 330.0 + 500.0 * t
		out[i] = (sin(TAU * freq * t) * 0.3 + _rng.randf_range(-1.0, 1.0) * 0.12 * exp(-t * 60.0)) * exp(-t * 14.0)
	return out


## Energia subindo (o jogador aparece no centro).
func _power_up() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.8)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var freq: float = 120.0 + 900.0 * t * t
		var env: float = minf(t * 8.0, 1.0) * exp(-maxf(t - 0.5, 0.0) * 8.0)
		out[i] = (sin(TAU * freq * t) * 0.35 + sin(TAU * freq * 1.5 * t) * 0.15) * env
	return out


## Pingo curto: tecla marcada.
func _key_ok() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.16)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		out[i] = (sin(TAU * 880.0 * t) * 0.5 + sin(TAU * 1320.0 * t) * 0.2) * exp(-t * 22.0)
	return out


## Sucesso: arpejo ascendente (dó, mi, sol, dó).
func _success() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.62)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5]
	for n: int in notes.size():
		var start: int = int(float(n) * 0.085 * float(RATE))
		for i: int in range(start, out.size()):
			var t: float = float(i - start) / float(RATE)
			var tri: float = asin(sin(TAU * notes[n] * t)) * 0.6366  # Onda triangular.
			out[i] += (tri * 0.32 + sin(TAU * notes[n] * 2.0 * t) * 0.08) * exp(-t * 7.0)
	return out


## Impulso do dash: ruído que "varre" do agudo para o grave.
func _dash() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.3)
	var low: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var k: float = lerpf(0.55, 0.08, minf(t / 0.3, 1.0))  # Filtro fecha com o tempo.
		low += (_rng.randf_range(-1.0, 1.0) - low) * k
		out[i] = low * minf(t * 60.0, 1.0) * exp(-t * 9.0) * 0.9
	return out


## Droide chegando: energia subindo com tremolo.
func _spawn() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.55)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var freq: float = 160.0 + 700.0 * t
		var trem: float = 0.6 + 0.4 * sin(TAU * 22.0 * t)
		out[i] = sin(TAU * freq * t) * trem * minf(t * 10.0, 1.0) * exp(-maxf(t - 0.3, 0.0) * 10.0) * 0.4
	return out


## Golpe metálico (clang) ao acertar o droide.
func _hit() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.35)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var ring: float = sin(TAU * 820.0 * t) + 0.7 * sin(TAU * 1337.0 * t) + 0.5 * sin(TAU * 2110.0 * t)
		out[i] = ring * exp(-t * 16.0) * 0.22 + _rng.randf_range(-1.0, 1.0) * exp(-t * 90.0) * 0.5
	return out


## Explosão metálica: estouro de ruído grave e peças caindo.
func _explosion() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(1.0)
	var low: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		low += (_rng.randf_range(-1.0, 1.0) - low) * lerpf(0.5, 0.06, minf(t / 0.6, 1.0))
		var boom: float = sin(TAU * (48.0 - 20.0 * t) * t) * exp(-t * 5.0)
		var clang: float = sin(TAU * 640.0 * t) * exp(-t * 18.0) * 0.25
		out[i] = low * exp(-t * 4.0) * 1.1 + boom * 0.7 + clang
	return out


## Corte da espada: ruído rápido e agudo.
func _slash() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.2)
	var low: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		low += (_rng.randf_range(-1.0, 1.0) - low) * lerpf(0.15, 0.7, minf(t / 0.12, 1.0))
		out[i] = (_rng.randf_range(-1.0, 1.0) - low) * sin(minf(t / 0.2, 1.0) * PI) * 0.5
	return out


## Menu de melhorias deslizando.
func _menu_open() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.4)
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		var freq: float = 220.0 + 440.0 * (t / 0.4)
		out[i] = sin(TAU * freq * t) * sin(minf(t / 0.4, 1.0) * PI) * 0.3
	return out


## Seleção da melhoria dourada: dois acordes brilhantes.
func _select() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.9)
	var notes: Array[float] = [659.25, 987.77, 1318.5]
	for n: int in notes.size():
		var start: int = int(float(n) * 0.07 * float(RATE))
		for i: int in range(start, out.size()):
			var t: float = float(i - start) / float(RATE)
			out[i] += (sin(TAU * notes[n] * t) * 0.3 + sin(TAU * notes[n] * 2.01 * t) * 0.1) * exp(-t * 4.0)
	return out


## Escotilha do teto abrindo: arrastar metálico.
func _hatch() -> PackedFloat32Array:
	var out: PackedFloat32Array = _buffer(0.6)
	var low: float = 0.0
	for i: int in out.size():
		var t: float = float(i) / float(RATE)
		low += (_rng.randf_range(-1.0, 1.0) - low) * 0.12
		out[i] = (low * 0.6 + sin(TAU * 90.0 * t) * 0.25) * sin(minf(t / 0.6, 1.0) * PI)
	return out
