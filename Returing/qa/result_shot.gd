extends Node
## Captura da tela final com dados de teste.
## godot --path . res://qa/result_shot.tscn -- <png> [largura altura] [cenario] [espera_s] [anim]
## anim: 1 anima (use a espera para escolher o instante), 0 mostra o estado final
## cenario: media (padrão) | perfeita (rank S) | muitos (mais de 6 tipos, vira OUTROS) | vazio


## Agenda a captura para o fim do quadro.
func _ready() -> void:
	_run.call_deferred()


## Monta uma run de teste conforme o cenário, abre a tela final e salva uma captura.
func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()  # Argumentos de linha de comando.
	var saida: String = args[0] if args.size() > 0 else "result.png"  # Arquivo de saída.
	var largura: int = int(args[1]) if args.size() > 2 else 1152  # Largura.
	var altura: int = int(args[2]) if args.size() > 2 else 648  # Altura.
	# Cenário (média, perfeita, muitos ou vazio).
	var cenario: String = args[3] if args.size() > 3 else "media"
	var espera: float = float(args[4]) if args.size() > 4 else 1.0  # Tempo de espera antes de capturar.
	var win: Window = get_tree().root  # Janela.
	win.mode = Window.MODE_WINDOWED  # Modo janela.
	win.size = Vector2i(largura, altura)  # Tamanho pedido.
	await get_tree().process_frame  # Espera um quadro.

	var cfg: ScoreConfig = ScoreConfig.carregar()  # Configuração da pontuação.
	var run := RunSnapshot.new()  # Run de teste.
	run.tempo_s = 780.0
	run.tempos_por_fase = [190.0, 220.0, 370.0]
	run.abates_por_tipo = {&"drone": 8, &"robo": 9, &"tank": 6, &"guide": 1}
	run.maior_sequencia_abates = 5
	run.dano_causado = 5400.0
	run.dano_tomado = 200.0
	run.acertos_quiz = 3
	run.vida_max_inicial_jogador = 100.0
	match cenario:  # Cada cenário muda os números da run.
		"muitos":  # Mais de seis tipos de inimigo (viram "OUTROS").
			cfg.vida_max_por_tipo.merge({&"a": 50, &"b": 60, &"c": 70, &"d": 80})
			for t: StringName in [&"a", &"b", &"c", &"d"]:
				run.abates_por_tipo[t] = 3
		"perfeita":  # Run perfeita (rank S).
			run.tempo_s = 330.0
			run.tempos_por_fase = [90.0, 80.0, 160.0]
			run.maior_sequencia_abates = 11
			run.dano_tomado = 0.0
			run.acertos_quiz = 5
		"vazio":  # Run sem abates.
			run.abates_por_tipo = {}
			run.maior_sequencia_abates = 0
			run.acertos_quiz = 0
	var resultado: ScoreResult = ScoreCalculator.calcular(run, cfg)  # Calcula o resultado.
	# Recorde de teste.
	var recorde: Dictionary = {"novo_recorde": true, "anterior": {"total": 12000, "rank": &"B", "tempo_s": 900.0},
			"atual": {"total": resultado.total, "rank": resultado.rank, "tempo_s": run.tempo_s}}
	var animar: bool = args.size() > 5 and args[5] == "1"  # Com ou sem animação.
	var tela: ResultScreen = ResultScreen.abrir(self, resultado, recorde, animar)  # Abre a tela.
	get_tree().paused = false  # o fotógrafo precisa seguir rodando para esperar
	await get_tree().create_timer(espera, true, false, true).timeout  # Espera o instante pedido.
	await RenderingServer.frame_post_draw  # Espera o quadro ser desenhado.
	get_tree().root.get_texture().get_image().save_png(saida)  # Salva a imagem.
	print("salvo ", saida, " (", largura, "x", altura, ") total=", resultado.total, " rank=", resultado.rank, " tela=", tela != null)
	get_tree().quit()  # Fecha o jogo.
