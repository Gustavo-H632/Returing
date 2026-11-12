class_name MobileSettings
extends RefCounted
## Preferências do modo celular guardadas em `user://mobile_hud.cfg` (ConfigFile): layout dos controles
## (seção "layout") e ajustes do acelerômetro (seção "tilt"). Tudo estático e com cache.
## Os testes trocam `path` para não mexer no arquivo do jogador.

const DEFAULT_PATH: String = "user://mobile_hud.cfg"
const SECTION_TILT: String = "tilt"
const SECTION_LAYOUT: String = "layout"

## Arquivo em uso (os testes apontam para outro).
static var path: String = _initial_path()
static var _cfg: ConfigFile = null


## Caminho inicial: `user://mobile_hud.cfg`, ou o do argumento de usuário `--mobile-config=user://arquivo.cfg`
## (os testes automáticos usam isso para não mexer nas preferências do jogador).
static func _initial_path() -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--mobile-config="):
			return arg.trim_prefix("--mobile-config=")
	return DEFAULT_PATH


## Valor guardado ou `fallback`.
static func get_value(section: String, key: String, fallback: Variant) -> Variant:
	_ensure_loaded()
	if not _cfg.has_section_key(section, key):  # `get_value` com padrão null reclama; checa antes
		return fallback
	return _cfg.get_value(section, key)


## Guarda um valor (em memória; use `save()` para gravar).
static func set_value(section: String, key: String, value: Variant) -> void:
	_ensure_loaded()
	_cfg.set_value(section, key, value)


## Remove uma seção inteira (restaurar padrão).
static func clear_section(section: String) -> void:
	_ensure_loaded()
	if _cfg.has_section(section):
		_cfg.erase_section(section)


## Grava no disco. Devolve true se deu certo.
static func save() -> bool:
	_ensure_loaded()
	return _cfg.save(path) == OK


## Descarta o cache e relê do disco (usado ao trocar `path` e depois de salvar nos testes).
static func reload() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(path):
		_cfg.load(path)


## Apaga o arquivo e o cache (testes).
static func wipe() -> void:
	_cfg = ConfigFile.new()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


static func _ensure_loaded() -> void:
	if _cfg == null:
		reload()
