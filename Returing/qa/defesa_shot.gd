extends Node
## Capturas da fase de defesa e da transição do cristal (precisa de janela, não roda headless).
## Rodar: godot --path . res://qa/defesa_shot.tscn -- <pasta de saída>

var _out: String = "user://"  # Pasta de saída (primeiro argumento depois de --).


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].rstrip("/") + "/"
	_run.call_deferred()


## Os abates dão XP e o menu de melhorias pausa o jogo: as capturas o ignoram.
func _process(_delta: float) -> void:
	if get_tree().paused:
		get_tree().paused = false
	for menu: Node in get_tree().root.find_children("*", "LevelUpMenu", true, false):
		(menu as CanvasLayer).visible = false


func _shot(file: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out + file)
	print("saved ", file, " ", img.get_size())


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _kill_all(level: DefenseLevel) -> void:
	for enemy: EnemyBase in level._enemies.duplicate():
		if is_instance_valid(enemy):
			enemy.take_damage(100000, null)


func _wait_fighting(level: DefenseLevel, number: int) -> void:
	var guard: int = 0
	while (level.wave_number < number or level.wave_phase != DefenseLevel.WavePhase.FIGHTING) and guard < 400:
		await _wait(0.1)
		guard += 1


func _run() -> void:
	EventBus.scene_change_requested.disconnect(Global.change_scene)
	var level: DefenseLevel = (load("res://Scenes/Defesa/Defesa.tscn") as PackedScene).instantiate() as DefenseLevel
	add_child(level)
	await _wait(0.6)
	await _shot("d1_inicio.png")
	await _wait(DefenseLevel.START_DELAY + 0.6)
	await _shot("d2_aviso_wave1.png")
	level.player.hp_maximo = 100000  # O jogador não pode morrer durante as capturas.
	level.player.hp = 100000
	await _wait_fighting(level, 1)
	await _wait(1.0)
	await _shot("d3_wave1_drones.png")
	_kill_all(level)
	await _wait_fighting(level, 2)
	await _wait(1.5)
	await _shot("d4_wave2.png")
	_kill_all(level)
	await _wait_fighting(level, 3)
	await _wait(1.2)
	await _shot("d5_wave3.png")
	level.portal.hp = DefensePortal.MAX_HP  # Ninguém defende nas capturas: devolve a vida para o portal não cair.
	level.portal._charge_tween.custom_step(20.0)
	await _wait(1.0)  # Ninguém está defendendo nas capturas: pouco tempo para o portal não cair.
	await _shot("d6_combate.png")
	_kill_all(level)
	level._stop_waves()
	level.portal.hp = DefensePortal.MAX_HP
	level.portal._charge_tween.custom_step(15.0)
	await _wait(0.8)
	await _shot("d7_pronto.png")
	level.portal.body_entered.emit(level.player)
	await _wait(0.5 + 0.8)
	await _shot("d8_teleporte.png")
	await _wait(2.3)
	await _shot("d9_dialogo.png")
	level.queue_free()
	await _wait(0.3)
	var sala: SalaNova = (load("res://Scenes/Fase2/SalaNova.tscn") as PackedScene).instantiate() as SalaNova
	add_child(sala)
	await _wait(0.5)
	await _shot("c1_sala.png")
	sala.nucleo.body_entered.emit(sala.get_node("Player"))
	await _wait(0.45)
	await _shot("c2_glitch.png")
	await _wait(1.3)
	await _shot("c3_chiado.png")
	await _wait(1.6)
	await _shot("c4_voz.png")
	await _wait(2.8)
	await _shot("c5_chiado2.png")
	await _wait(1.8)
	await _shot("c6_armadilha.png")
	get_tree().quit()
