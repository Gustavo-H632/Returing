extends Node
## Autoload Global: único dono da navegação entre cenas.

## Menu principal.
const MENU_SCENE: String = "res://Scenes/Start/menu_start.tscn"
## Acima de qualquer CanvasLayer do jogo (HUD = 10, Pause = 100).
const FADE_LAYER: int = 128
## Tempo máximo esperando o carregamento em thread antes de carregar direto (ms).
const LOAD_TIMEOUT_MSEC: int = 8000

## Duração (s) do fade preto entre cenas.
@export_range(0.05, 2.0, 0.05) var fade_duration: float = 0.35

# True enquanto uma troca de cena está em andamento (impede duas ao mesmo tempo).
var _changing_scene: bool = false
## Troca pedida enquanto outra estava em andamento (ex.: avançar a cutscene durante o fade).
var _queued_path: String = ""
var _fade_rect: ColorRect = null  # Retângulo preto que cobre a tela no fade.
var _fade_tween: Tween = null  # Animação do fade (guardada para poder cancelar).


## Cria a cortina de fade e escuta os pedidos de navegação.
func _ready() -> void:
	# Precisa continuar rodando com o jogo pausado (pause, quiz).
	process_mode = Node.PROCESS_MODE_ALWAYS  # Mesmo pausado, o fade e a troca continuam rodando.
	_build_fade_rect()  # Cria a cortina preta.
	# Pedido de troca de cena vindo de qualquer lugar do jogo.
	EventBus.scene_change_requested.connect(change_scene)
	EventBus.main_menu_requested.connect(go_to_main_menu)  # Pedido de voltar ao menu.
	EventBus.level_restart_requested.connect(reload_scene)  # Pedido de reiniciar a fase.
	EventBus.quit_requested.connect(quit_game)  # Pedido de fechar o jogo.


## Troca de cena com fade. Um pedido feito durante outra troca fica na fila e roda no fim dela.
func change_scene(path: String) -> bool:
	if _changing_scene:  # Já está trocando: guarda o pedido para depois.
		if not path.is_empty():
			_queued_path = path  # Guarda só o último pedido recebido.
		return false
	# Caminho vazio ou arquivo inexistente: avisa o erro e recusa.
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("Global.change_scene: cena '%s' não encontrada." % path)
		return false
	_changing_scene = true  # Marca que a troca começou.
	_run_change(path)  # Executa a troca (assíncrona).
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


## Volta ao menu principal com fade.
func go_to_main_menu() -> bool:
	return change_scene(get_main_menu_path())


## Fecha o jogo.
func quit_game() -> void:
	get_tree().quit()


## Caminho do menu principal.
func get_main_menu_path() -> String:
	return MENU_SCENE


## Fade out -> carrega (thread) -> troca -> fade in.
func _run_change(path: String) -> void:
	# Carrega em segundo plano enquanto a tela escurece.
	# Pede o carregamento em segundo plano.
	var requested: bool = ResourceLoader.load_threaded_request(path) == OK
	await _fade_to(1.0)  # Escurece a tela enquanto carrega.

	var packed: PackedScene = await _wait_for_scene(path, requested)  # Espera a cena ficar pronta.
	if packed == null:  # Falhou o carregamento: reabre a tela e desiste.
		push_error("Global.change_scene: falha ao carregar '%s'." % path)
		await _fade_to(0.0)
		_changing_scene = false
		return

	get_tree().paused = false  # A cena nova nunca começa pausada.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE  # Devolve o cursor do mouse (o jogo pode tê-lo escondido).
	get_tree().change_scene_to_packed(packed)  # Troca de cena de verdade.
	# Espera a cena nova entrar na árvore antes de revelar a tela.
	await get_tree().process_frame
	await get_tree().process_frame
	await _fade_to(0.0)  # Revela a nova cena.
	_changing_scene = false  # Libera para a próxima troca.
	_run_queued_change()  # Se houve pedido enquanto trocava, executa agora.


## Roda a troca que ficou na fila durante a anterior.
func _run_queued_change() -> void:
	if _queued_path.is_empty():  # Nada na fila: não faz nada.
		return
	var path: String = _queued_path  # Pega o caminho da fila.
	_queued_path = ""  # Esvazia a fila.
	change_scene(path)  # Faz a troca guardada.


## Espera o carregamento em thread.
func _wait_for_scene(path: String, requested: bool) -> PackedScene:
	if not requested:  # Sem carregamento em thread: carrega direto.
		return load(path) as PackedScene
	var started: int = Time.get_ticks_msec()  # Marca a hora de início para medir o tempo limite.
	# Enquanto o Godot ainda carrega, espera um quadro por vez.
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		# Passou do tempo limite: carrega direto para não travar.
		if Time.get_ticks_msec() - started > LOAD_TIMEOUT_MSEC:
			# Carregamento em thread travado: nunca deixa a tela preta para sempre.
			push_warning("Global: carregamento de '%s' passou de %d ms; carregando direto." % [path, LOAD_TIMEOUT_MSEC])
			return load(path) as PackedScene
		await get_tree().process_frame
	# Terminou, mas com erro.
	if ResourceLoader.load_threaded_get_status(path) != ResourceLoader.THREAD_LOAD_LOADED:
		return null
	return ResourceLoader.load_threaded_get(path) as PackedScene  # Entrega a cena carregada.


## Cria a cortina de fade: uma camada acima de tudo com um retângulo preto transparente.
func _build_fade_rect() -> void:
	var layer := CanvasLayer.new()  # Camada acima de qualquer UI do jogo.
	layer.layer = FADE_LAYER
	_fade_rect = ColorRect.new()  # Retângulo preto.
	_fade_rect.color = Color.BLACK
	_fade_rect.modulate.a = 0.0  # Começa totalmente transparente.
	_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # só bloqueia cliques durante o fade
	_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)  # Cobre a tela inteira.
	layer.add_child(_fade_rect)
	add_child(layer)  # Entra na árvore.


## Anima a cortina até `alpha` (1 = preto).
func _fade_to(alpha: float) -> void:
	if _fade_tween != null and _fade_tween.is_valid():  # Cancela o fade anterior.
		_fade_tween.kill()
	if alpha > 0.0:  # Escurecendo: bloqueia cliques.
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_fade_tween = create_tween()  # Novo fade.
	# Anima a transparência até o alvo.
	_fade_tween.tween_property(_fade_rect, ^"modulate:a", alpha, fade_duration)
	await _fade_tween.finished  # Espera acabar.
	if alpha <= 0.0:  # Tela revelada: volta a deixar os cliques passarem.
		_fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
