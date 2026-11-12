extends Node
## Capturas da Câmara de Provas (precisa de janela, não roda headless).
## Rodar: godot --path . --windowed --resolution 1152x648 res://qa/camara_shot.tscn -- <pasta de saída>

var _out: String = "user://"  # Pasta de saída (primeiro argumento depois de --).
var _fase: Camara = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0].rstrip("/") + "/"
	_run.call_deferred()


func _shot(file: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out + file)
	print("saved ", file, " ", img.get_size())


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## Espera uma máquina entrar numa fase do ciclo (no máximo 40 s).
func _ate(m: CamaraMaquina, estado: CamaraMaquina.Estado, extra: float = 0.0) -> void:
	var guarda: int = 0
	while m.estado != estado and guarda < 800:
		await _wait(0.05)
		guarda += 1
	await _wait(extra)


func _run() -> void:
	EventBus.scene_change_requested.disconnect(Global.change_scene)
	_fase = (load("res://Scenes/Fase5/Camara.tscn") as PackedScene).instantiate() as Camara
	_fase.falas_abertura = PackedStringArray()  # as capturas começam direto na fase
	add_child(_fase)
	get_tree().current_scene = _fase
	_fase.player.conceder_invulnerabilidade(100000.0)
	await _wait(0.5)
	await _shot("c0_inicio.png")
	var m1a: CamaraMaquina = _fase.sala1.maquinas()[0]
	await _ate(m1a, CamaraMaquina.Estado.AVISO, 0.4)
	await _shot("c1_sala1_aviso.png")
	await _ate(m1a, CamaraMaquina.Estado.VARREDURA, 0.7)
	await _shot("c2_sala1_raio.png")
	# Sala 2
	_fase.player.global_position = Vector2(672, 340)
	_fase._entrar_sala(2)
	var m2: CamaraMaquina = _fase.sala2.maquinas()[0]
	await _ate(m2, CamaraMaquina.Estado.AVISO, 0.5)
	await _shot("c3_sala2_aviso.png")
	await _ate(m2, CamaraMaquina.Estado.VARREDURA, 0.9)
	await _shot("c4_sala2_raio.png")
	# Sala 3 (com o F3 ligado na última captura)
	_fase.player.global_position = Vector2(1000, 448)
	_fase._entrar_sala(3)
	var ms: Array[CamaraMaquina] = _fase.sala3.maquinas()
	await _ate(ms[0], CamaraMaquina.Estado.AVISO, 0.5)
	await _shot("c5_sala3_aviso.png")
	await _ate(ms[1], CamaraMaquina.Estado.VARREDURA, 0.8)
	await _shot("c6_sala3_raios.png")
	var depuracao := _fase.get_node("Depuracao") as CamaraDebug
	depuracao.ligado = true
	depuracao._aplicar()
	await _wait(0.4)
	await _shot("c7_sala3_f3.png")
	depuracao.ligado = false
	depuracao._aplicar()
	# destruir algumas e a porta final
	ms[0].take_damage(68)
	ms[2].take_damage(68)
	await _wait(0.2)
	await _shot("c8_explosao.png")
	await _wait(1.0)
	await _shot("c9_carcaca.png")
	_fase.sala3.parar()
	for m: CamaraMaquina in ms:
		m.take_damage(68)
		m.take_damage(68)
	_fase.player.global_position = Vector2(1900, 448)
	await _wait(1.2)
	await _shot("c10_porta_final.png")
	get_tree().quit()
