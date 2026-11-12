extends Node
## Autoload AudioSettings: volumes dos buses "Music" e "SFX".
## Garante que os buses existam, carrega os volumes de user://settings.cfg ao iniciar o jogo,
## aplica ao AudioServer (linear -> dB; 0 = mudo) e salva depois de cada mudança.

## O volume de um bus mudou (0.0 a 1.0).
signal volume_changed(bus: StringName, linear: float)

# Onde o arquivo de configurações fica gravado (pasta do usuário).
const SETTINGS_PATH: String = "user://settings.cfg"
const SECTION: String = "audio"  # Seção do arquivo onde ficam os volumes.
const BUS_MASTER: StringName = &"Master"  # Nome dos buses do AudioServer.
const BUS_MUSIC: StringName = &"Music"
const BUS_SFX: StringName = &"SFX"
## Volume inicial (linear). 1.0 = 0 dB, ou seja, o jogo soa como antes de existir o ajuste.
const DEFAULT_VOLUME: float = 1.0
## Espera (s) depois da última mudança antes de gravar o arquivo (evita gravar a cada passo do slider).
const SAVE_DELAY: float = 0.5
## Volume (dB) usado para silenciar.
const MUTE_DB: float = -80.0

# Volume de cada bus (0.0 a 1.0).
var _volumes: Dictionary[StringName, float] = {
	BUS_MUSIC: DEFAULT_VOLUME,
	BUS_SFX: DEFAULT_VOLUME,
}
var _save_timer: Timer = null  # Timer que adia o salvamento.
var _dirty: bool = false  # True se há mudança ainda não gravada.


## Prepara os buses, o timer de salvamento e aplica os volumes gravados.
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # o menu de pause muda o volume com o jogo pausado
	_ensure_bus(BUS_MUSIC)  # Cria o bus Music se não existir.
	_ensure_bus(BUS_SFX)  # Cria o bus SFX se não existir.
	_save_timer = Timer.new()  # Timer que espera um pouco antes de gravar.
	_save_timer.one_shot = true
	_save_timer.wait_time = SAVE_DELAY
	# O tempo do timer não é afetado pela câmera lenta do modo comando.
	_save_timer.ignore_time_scale = true
	add_child(_save_timer)
	_save_timer.timeout.connect(save_settings)  # Ao terminar a espera, grava o arquivo.
	load_settings()  # Lê o que estava salvo.
	apply_all()  # Aplica os volumes ao AudioServer.


## Grava o que ainda não foi salvo (o jogo pode fechar antes do tempo de espera acabar).
func _exit_tree() -> void:
	if _dirty:  # Salva se o jogo fechar antes do timer acabar.
		save_settings()


## Volume atual do bus (0.0 a 1.0).
func get_volume(bus: StringName) -> float:
	return _volumes.get(bus, DEFAULT_VOLUME)  # Bus desconhecido devolve o volume padrão.


## Muda o volume do bus (0.0 a 1.0), aplica na hora e agenda o salvamento.
func set_volume(bus: StringName, linear: float) -> void:
	if not _volumes.has(bus):  # Bus que não é Music nem SFX: avisa e ignora.
		push_warning("AudioSettings: bus '%s' desconhecido." % bus)
		return
	_volumes[bus] = clampf(linear, 0.0, 1.0)  # Guarda o volume limitado entre 0 e 1.
	_apply(bus)  # Aplica ao AudioServer na hora.
	_dirty = true  # Marca que há algo para gravar.
	_save_timer.start()  # (Re)inicia a espera para gravar.
	volume_changed.emit(bus, _volumes[bus])  # Avisa a UI do novo volume.


## Aplica todos os volumes guardados ao AudioServer.
func apply_all() -> void:
	for bus: StringName in _volumes:  # Aplica cada bus conhecido.
		_apply(bus)


## Lê user://settings.cfg. Sem arquivo (primeira execução) ficam os valores padrão.
func load_settings() -> void:
	var config: ConfigFile = ConfigFile.new()  # Objeto que lê arquivos .cfg.
	if config.load(SETTINGS_PATH) != OK:  # Sem arquivo (primeira vez): mantém os padrões.
		return
	for bus: StringName in _volumes.keys():  # Para cada bus lê o volume salvo.
		# Se não existir, usa o padrão.
		var stored: Variant = config.get_value(SECTION, _config_key(bus), DEFAULT_VOLUME)
		_volumes[bus] = clampf(float(stored), 0.0, 1.0)  # Garante o intervalo de 0 a 1.


## Grava os volumes em user://settings.cfg, preservando outras seções do arquivo.
func save_settings() -> void:
	var config: ConfigFile = ConfigFile.new()  # Abre o arquivo existente para preservar outras seções.
	config.load(SETTINGS_PATH)  # se não existir, começa vazio
	for bus: StringName in _volumes:  # Escreve o volume de cada bus.
		config.set_value(SECTION, _config_key(bus), _volumes[bus])
	var error: Error = config.save(SETTINGS_PATH)  # Grava o arquivo.
	if error != OK:  # Falhou: avisa no console e mantém "sujo" para tentar de novo.
		push_warning("AudioSettings: não foi possível salvar %s (erro %d)." % [SETTINGS_PATH, error])
		return
	_dirty = false  # Gravou: não há mais nada pendente.


## Converte volume linear (0 a 1) em dB; 0 vira o valor de mudo.
static func linear_to_bus_db(linear: float) -> float:
	return MUTE_DB if linear <= 0.0 else linear_to_db(linear)


## Aplica o volume de um bus: liga o mudo se o volume é zero e ajusta os decibéis.
func _apply(bus: StringName) -> void:
	var index: int = AudioServer.get_bus_index(bus)  # Índice do bus no AudioServer.
	if index == -1:  # Bus inexistente: nada a fazer.
		return
	var linear: float = _volumes[bus]  # Volume guardado.
	AudioServer.set_bus_mute(index, linear <= 0.0)  # Volume zero = mudo.
	AudioServer.set_bus_volume_db(index, linear_to_bus_db(linear))  # Converte e aplica.


## Cria o bus (enviando para o Master) se o default_bus_layout.tres não o tiver.
func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) != -1:  # O bus já existe: nada a fazer.
		return
	AudioServer.add_bus()  # Cria um bus novo no fim da lista.
	var index: int = AudioServer.bus_count - 1  # Índice do bus recém-criado.
	AudioServer.set_bus_name(index, bus)  # Dá o nome ao bus.
	AudioServer.set_bus_send(index, BUS_MASTER)  # Manda o som do bus para o Master.


## Monta o nome da chave no arquivo (ex.: "music_volume").
func _config_key(bus: StringName) -> String:
	return "%s_volume" % String(bus).to_lower()
