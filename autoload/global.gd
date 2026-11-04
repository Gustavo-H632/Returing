extends Node
## Autoload Global: único dono da navegação entre cenas.

## Menu principal.
const MENU_SCENE: String = "res://Scenes/Start/menu_start.tscn"
## Acima de qualquer CanvasLayer do jogo (HUD = 10, Pause = 100).
const FADE_LAYER: int = 128
## Tempo máximo esperando o carregamento em thread antes de carregar direto (ms).
const LOAD_TIMEOUT_MSEC: int = 8000

@export_range(0.05, 2.0, 0.05) var fade_duration: float = 0.35

var _changing_scene: bool = false
## Troca pedida enquanto outra estava em andamento (ex.: avançar a cutscene durante o fade).
var _queued_path: String = ""
var _fade_rect: ColorRect = null
var _fade_tween: Tween = null


## Cria a cortina de fade e escuta os pedidos de navegação.
func _ready() -> void:
	# Precisa continuar rodando com o jogo pausado (pause, quiz).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_fade_rect()
	EventBus.scene_change_requested.connect(change_scene)
	EventBus.main_menu_requested.connect(go_to_main_menu)
	EventBus.level_restart_requested.connect(reload_scene)
	EventBus.quit_requested.connect(quit_game)


## Troca de cena com fade. Um pedido feito durante outra troca fica na fila e roda no fim dela.
func change_scene(path: String) -> bool:
	if _changing_scene:
		if not path.is_empty():
			_queued_path = path
		return false
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Global.change_scene: cena '%s' não encontrada." % path)
		return false
	_changing_scene = true
	_run_change(path)
	return true


## Recarrega a cena atual com fade (reiniciar fase).
func reload_scene() -> bool:
	if _changing_scene:
		return false
	var current: Node = get_tree().current_scene
	if current == null or current.scene_file_path.is_empty():
		push_error("Global.reload_scene: não há cena atual para recarregar.")
		return false
	return change_scene(current.scene_file_path)


func go_to_main_menu() -> bool:
	return change_scene(get_main_menu_path())


func quit_game() -> void:
	get_tree().quit()


## Caminho do menu principal.
func get_main_menu_path() -> String:
	return MENU_SCENE


## Fade out -> carrega (thread) -> troca -> fade in.
func _run_change(path: String) -> void:
	# Carrega em segundo plano enquanto a tela escurece.
	var requested: bool = ResourceLoader.load_threaded_request(path) == OK
	await _fade_to(1.0)

	var packed: PackedScene = await _wait_for_scene(path, requested)
	if packed == null:
		push_error("Global.change_scene: falha ao carregar '%s'." % path)
		await _fade_to(0.0)
		_changing_scene = false
		return

	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().change_scene_to_packed(packed)
	# Espera a cena nova entrar na árvore antes de revelar a tela.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)
	_changing_scene = false
	_run_queued_change()


## Roda a troca que ficou na fila durante a anterior.
func _run_queued_change() -> void:
	if _queued_path.is_empty():
		return
	var path: String = _queued_path
	_queued_path = ""
	change_scene(path)


## Espera o carregamento em thread.
func _wait_for_scene(path: String, requested: bool) -> PackedScene:
	if not requested:
		return load(path) as PackedScene
	var started: int = Time.get_ticks_msec()
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		if Time.get_ticks_msec() - started > LOAD_TIMEOUT_MSEC:
			# Carregamento em thread travado: nunca deixa a tela preta para sempre.
			push_warning("Global: carregamento de '%s' passou de %d ms; carregando direto." % [path, LOAD_TIMEOUT_MSEC])
			return load(path) as PackedScene
		await get_tree().process_frame
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(path) as PackedScene


func _build_fade_rect() -> void:
	var layer := CanvasLayer.new()
	layer.layer = FADE_LAYER
	_fade_rect = ColorRect.new()
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # só bloqueia cliques durante o fade
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade_rect)
	add_child(layer)


## Anima a cortina até `alpha` (1 = preto).
func _fade_to(alpha: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if alpha > 0.0:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()
	_fade_tween.tween_property(_fade_rect, ^"modulate:a", alpha, fade_duration)
	await _fade_tween.finished
	if alpha <= 0.0:
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
