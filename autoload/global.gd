extends Node
## Autoload Global o único dono de sinais 
const SETTING_MAIN_SCENE: String = "application/run/main_scene"
const FALLBACK_MENU: String = "res://Scenes/Start/menu_start.tscn"

var _changing_scene: bool = false


## Escuta os pedidos de navegação.
func _ready() -> void:
	# O jogo pode ser pausado por um menu no futuro
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.scene_change_requested.connect(change_scene)
	EventBus.main_menu_requested.connect(_on_main_menu_requested)
	EventBus.level_restart_requested.connect(_on_level_restart_requested)
	EventBus.quit_requested.connect(quit_game)


## Troca de cena e trava os pedidos
func change_scene(path: String) -> bool:
	if _changing_scene:
		return false
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Global.change_scene: cena '%s' não encontrada." % path)
		return false
	_changing_scene = true
	_perform_change.call_deferred(path)
	return true


## Troca de cena de fato (fim do frame).
func _perform_change(path: String) -> void:
	get_tree().paused = false
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("Global.change_scene: falha ao carregar '%s' (erro %d)." % [path, err])
		_changing_scene = false
		return
	_release_scene_lock.call_deferred()


## Fecha o jogo.
func quit_game() -> void:
	get_tree().quit()


## Cena do menu = Main Scene do projeto.
func get_main_menu_path() -> String:
	var main_scene := str(ProjectSettings.get_setting(SETTING_MAIN_SCENE, ""))
	return main_scene if not main_scene.is_empty() else FALLBACK_MENU


## Volta ao menu.
func _on_main_menu_requested() -> void:
	change_scene(get_main_menu_path())


## Recarrega a fase (trava pedidos repetidos).
func _on_level_restart_requested() -> void:
	if _changing_scene:
		return
	_changing_scene = true
	_perform_reload.call_deferred()


## Recarga de fato (fim do frame).
func _perform_reload() -> void:
	get_tree().paused = false
	var err := get_tree().reload_current_scene()
	if err != OK:
		push_error("Global: falha ao recarregar a cena atual (erro %d)." % err)
		_changing_scene = false
		return
	_release_scene_lock.call_deferred()


## Libera novos pedidos 2 frames depois da troca de cenas
func _release_scene_lock() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_changing_scene = false
