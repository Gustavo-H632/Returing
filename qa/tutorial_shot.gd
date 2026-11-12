extends Node
## Captura telas do tutorial em momentos-chave (precisa de janela: não use --headless).
## Rodar: godot --path . res://qa/tutorial_shot.tscn -- <pasta de saída>
## Salva PNGs numerados na pasta indicada (padrão: user://tutorial_shots).

const SCENE_PATH: String = "res://Scenes/Tutorial/tutorial.tscn"

var _tutorial: Tutorial = null  # Cena em teste.
var _out_dir: String = "user://tutorial_shots"  # Pasta das capturas.
var _count: int = 0  # Quantas capturas já saíram.


## Lê a pasta de saída e inicia.
func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	_run.call_deferred()


## Joga o tutorial e tira fotos.
func _run() -> void:
	_tutorial = (load(SCENE_PATH) as PackedScene).instantiate() as Tutorial
	add_child(_tutorial)
	for t: float in [1.4, 1.0, 1.5, 1.5, 1.5]:
		await _sleep(t)
		_snap("cutscene_t%.1f" % _tutorial_time())
	await _wait_step(&"move")
	_snap("move_painel_vazio")
	Input.action_press(&"move_up")
	Input.action_press(&"move_left")
	await _sleep(0.3)
	_snap("move_teclas_apertadas")
	Input.action_release(&"move_up")
	Input.action_release(&"move_left")
	await _tap(&"move_down", 0.15)
	await _tap(&"move_right", 0.15)
	await _wait_step(&"dash")
	await _sleep(0.8)
	_snap("dash_painel")
	await _tap(&"move_right", 0.02)
	Input.action_press(&"move_right")
	await _tap(&"dash", 0.05)
	await _sleep(0.07)
	_snap("dash_rastro")
	Input.action_release(&"move_right")
	await _wait_step(&"shoot")
	await _sleep(1.6)
	_snap("droide_tiro_painel")
	var droid: TutorialDroid = _tutorial.droid
	_place_droid(droid, 150.0)
	Input.action_press(&"charge_shoot")
	await _sleep(0.5)
	_snap("tiro_carregando")
	Input.action_release(&"charge_shoot")
	await _sleep(0.12)
	_snap("tiro_disparo")
	await _wait_step(&"sword")
	await _sleep(1.0)
	_snap("espada_painel")
	_place_droid(droid, 46.0)
	await _sleep(0.1)
	Input.action_press(&"attack_sword")
	await _sleep(0.12)
	_snap("espada_golpe")
	Input.action_release(&"attack_sword")
	await _wait_step(&"finish")
	await _sleep(1.0)
	_place_droid(droid, 46.0)
	await _sleep(0.1)
	Input.action_press(&"attack_sword")
	await _sleep(0.05)
	Input.action_release(&"attack_sword")
	await _sleep(0.25)
	_snap("explosao")
	await _wait_step(&"upgrades")
	await _sleep(1.6)
	_snap("melhorias_menu")
	var event: InputEventAction = InputEventAction.new()
	event.action = &"ui_right"
	event.pressed = true
	Input.parse_input_event(event)
	await _sleep(0.35)
	_snap("melhorias_saida")
	await _wait_step(&"farewell")
	await _sleep(2.2)
	_snap("despedida")
	print("tutorial_shot: %d capturas em %s" % [_count, _out_dir])
	get_tree().quit()


## Tempo desde o início (s, real).
func _tutorial_time() -> float:
	return Time.get_ticks_msec() / 1000.0


## Espera a lição (tempo real).
func _wait_step(step_name: StringName) -> void:
	var waited: float = 0.0
	while _tutorial.step != step_name and waited < 60.0:
		await _sleep(0.05)
		waited += 0.05


## Aperta uma ação por `seconds` segundos.
func _tap(action: StringName, seconds: float) -> void:
	Input.action_press(action)
	await _sleep(seconds)
	Input.action_release(action)
	await _sleep(0.05)


## Espera em tempo real.
func _sleep(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


## Coloca o droide à frente do jogador, na direção do cursor.
func _place_droid(droid: TutorialDroid, distance: float) -> void:
	var player: Player = _tutorial.player
	var direction: Vector2 = (player.get_global_mouse_position() - player.global_position).normalized()
	if direction == Vector2.ZERO:
		direction = Vector2.RIGHT
	droid.move_speed = 0.0
	droid.global_position = player.global_position + direction * distance


## Salva a imagem da tela.
func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	_count += 1
	var path: String = "%s/%02d_%s.png" % [_out_dir, _count, label]
	image.save_png(path)
	print("captura: ", path)
