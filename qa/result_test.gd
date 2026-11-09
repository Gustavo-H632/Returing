extends Node
## Testes da tela final: duração da sequência, "pular" (1ª vez acelera, 2ª vai ao fim) e estado final.
## Rodar: godot --headless --path . res://qa/result_test.tscn   (leva ~25 s: mede tempo real)

const DURACAO_MIN_S: float = 15.0  # Duração mínima da sequência completa.
const DURACAO_MAX_S: float = 20.0  # Duração máxima da sequência completa.
const ESPERA_MAXIMA_S: float = 40.0  # Espera máxima antes de desistir.

var _falhas: int = 0  # Verificações que falharam.
var _total: int = 0  # Total de verificações.
var _resultado: ScoreResult = null  # Resultado de teste.
var _recorde: Dictionary = {}  # Recorde de teste.


## Agenda o teste para o fim do quadro.
func _ready() -> void:
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Confere uma condição e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


## Roda os testes da tela final: formatos, duração completa e "pular".
func _rodar() -> void:
	_montar_dados()  # Monta os dados.
	_testar_formatos()  # Formatos de texto.
	await _testar_duracao_completa()  # Duração da sequência completa.
	await _testar_pular()  # Comportamento do "pular".
	print("result_test: %d verificações, %d falhas" % [_total, _falhas])  # Resultado.
	get_tree().quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.


## Monta um resultado e um recorde de teste a partir de uma run média.
func _montar_dados() -> void:
	var cfg: ScoreConfig = ScoreConfig.carregar()  # Configuração.
	var run := RunSnapshot.new()  # Run de teste.
	run.tempo_s = 780.0
	run.tempos_por_fase = [190.0, 220.0, 370.0]
	run.abates_por_tipo = {&"drone": 8, &"robo": 9, &"tank": 6, &"guide": 1}
	run.maior_sequencia_abates = 5
	run.dano_causado = 5400.0
	run.dano_tomado = 200.0
	run.acertos_quiz = 3
	run.vida_max_inicial_jogador = 100.0
	_resultado = ScoreCalculator.calcular(run, cfg)  # Calcula o resultado.
	# Recorde de teste.
	_recorde = {"novo_recorde": true, "anterior": {"total": 12000, "rank": &"B", "tempo_s": 900.0},
			"atual": {"total": _resultado.total, "rank": _resultado.rank, "tempo_s": run.tempo_s}}


## Testa os formatos de tempo, parcial e decimal.
func _testar_formatos() -> void:
	_confere(ResultScreen.formatar_tempo(1020.32) == "17:00.32", "tempo 17:00.32")  # Tempo com centésimos.
	_confere(ResultScreen.formatar_tempo(0.0) == "00:00.00", "tempo zero")  # Tempo zero.
	_confere(ResultScreen.formatar_tempo(61.5) == "01:01.50", "tempo 01:01.50")  # Mais de um minuto.
	_confere(ResultScreen.formatar_parcial(190.0) == "03:10", "parcial 03:10")  # Parcial por fase.
	_confere(ResultScreen.formatar_decimal(3.0) == "3,0", "decimal com vírgula")  # Decimal com vírgula.


## Cria uma tela final com os dados de teste.
func _nova_tela(animar: bool) -> ResultScreen:
	var tela: ResultScreen = ResultScreen.abrir(self, _resultado, _recorde, animar)  # Abre a tela.
	return tela  # Devolve.


## Fecha a tela e espera dois quadros.
func _fechar(tela: ResultScreen) -> void:
	tela.queue_free()  # Remove a tela.
	await get_tree().process_frame  # Espera.
	await get_tree().process_frame  # Espera mais um.


## Simula apertar Enter na tela final.
func _aperta_accept(tela: ResultScreen) -> void:
	var ev := InputEventAction.new()  # Evento de Enter.
	ev.action = &"ui_accept"  # Ação.
	ev.pressed = true  # Apertada.
	tela._input(ev)  # Entrega à tela.


## Confere o estado final da tela: total, penalidade, odômetro, rank, foco e botões.
func _confere_estado_final(tela: ResultScreen, rotulo: String) -> void:
	_confere(tela._estado == ResultScreen.Estado.FIM, rotulo + ": estado FIM")  # Estado FIM.
	# Total final.
	_confere(tela._linha_total.valor.text == str(_resultado.total), rotulo + ": total final exibido")
	# Penalidade.
	_confere(tela._linha_penalidade.valor.text == "-%d" % _resultado.penalidade, rotulo + ": decréscimo exibido")
	# Odômetro no total.
	_confere(tela._odometro.text.contains("%d" % _resultado.total), rotulo + ": odômetro no total")
	_confere(tela._letra_rank.text == String(_resultado.rank), rotulo + ": letra do rank")  # Letra do rank.
	_confere(tela._letra_rank.scale == Vector2.ONE, rotulo + ": letra com escala 1")  # Escala 1.
	# Nome do rank completo.
	_confere(is_equal_approx(tela._nome_rank.visible_ratio, 1.0), rotulo + ": nome do rank completo")
	_confere(tela._botao_jogar.has_focus(), rotulo + ": foco no primeiro botão")  # Foco no primeiro botão.
	_confere(tela._botoes.modulate.a == 1.0, rotulo + ": botões visíveis")  # Botões visíveis.


## Mede a duração da sequência completa (tempo real) e confere o estado final.
func _testar_duracao_completa() -> void:
	Engine.time_scale = 0.3  # a tela precisa devolver para 1.0
	var inicio_ms: int = Time.get_ticks_msec()  # Hora de início.
	var tela: ResultScreen = _nova_tela(true)  # Abre a tela com animação.
	_confere(Engine.time_scale == 1.0, "entra com Engine.time_scale = 1.0")  # Devolveu o tempo normal.
	_confere(get_tree().paused, "pausa a árvore enquanto aberta")  # Pausou a árvore.
	_confere(tela._estado == ResultScreen.Estado.ANIMANDO, "começa animando")  # Começa animando.
	# Botões sem foco durante a animação.
	_confere(tela._botao_jogar.focus_mode == Control.FOCUS_NONE, "botões sem foco durante a animação")

	var terminou: Array[bool] = [false]  # Marca se terminou.
	tela.animacao_terminou.connect(func() -> void: terminou[0] = true)  # Escuta o fim.
	# Espera até terminar ou estourar o limite.
	while not terminou[0] and float(Time.get_ticks_msec() - inicio_ms) / 1000.0 < ESPERA_MAXIMA_S:
		await get_tree().process_frame
	var duracao: float = float(Time.get_ticks_msec() - inicio_ms) / 1000.0  # Duração medida.
	print("  duração da sequência completa: %.2f s" % duracao)  # Mostra.
	_confere(terminou[0], "a animação termina")  # A animação terminou.
	_confere(duracao >= DURACAO_MIN_S and duracao <= DURACAO_MAX_S,  # Duração dentro da faixa.
			"duração %.2f s entre %.0f e %.0f s" % [duracao, DURACAO_MIN_S, DURACAO_MAX_S])
	_confere_estado_final(tela, "fim natural")  # Estado final correto.
	await _fechar(tela)  # Fecha a tela.
	_confere(not get_tree().paused, "fechar a tela despausa a árvore")  # Fechar despausa a árvore.


## Testa o "pular": entradas iniciais ignoradas, 1ª vez acelera, 2ª vai ao fim, restante a ×4 e tela sem animação.
func _testar_pular() -> void:
	# Entradas logo no começo são ignoradas.
	var tela: ResultScreen = _nova_tela(true)  # Abre a tela.
	_aperta_accept(tela)  # Enter.
	# Continua animando.
	_confere(tela._estado == ResultScreen.Estado.ANIMANDO, "entrada nos primeiros instantes é ignorada")
	# Espera o fim do período de proteção.
	await get_tree().create_timer(tela.entrada_ignorada_s + 0.1, true, false, true).timeout

	# 1ª vez: acelera ×4.
	var inicio_ms: int = Time.get_ticks_msec()  # Hora de início.
	_aperta_accept(tela)  # Enter.
	_confere(tela._estado == ResultScreen.Estado.RAPIDO, "1º pular: modo rápido")  # Modo rápido.
	# Velocidade ×4.
	_confere(is_equal_approx(tela._velocidade, tela.velocidade_rapida), "1º pular: velocidade ×4")
	_confere(tela._estado != ResultScreen.Estado.FIM, "1º pular não vai ao fim")  # Não foi ao fim.

	# 2ª vez: vai direto ao estado final.
	_aperta_accept(tela)  # Enter.
	_confere_estado_final(tela, "2º pular")  # Estado final.
	_confere(float(Time.get_ticks_msec() - inicio_ms) < 500.0, "2º pular é imediato")  # Imediato.
	await _fechar(tela)  # Fecha.

	# Só 1 pular e esperar: termina em cerca de 1/4 do tempo.
	tela = _nova_tela(true)  # Nova tela.
	# Espera o período de proteção.
	await get_tree().create_timer(tela.entrada_ignorada_s + 0.1, true, false, true).timeout
	var terminou: Array[bool] = [false]  # Marca se terminou.
	tela.animacao_terminou.connect(func() -> void: terminou[0] = true)  # Escuta o fim.
	inicio_ms = Time.get_ticks_msec()  # Hora de início.
	_aperta_accept(tela)  # Enter.
	# Espera terminar.
	while not terminou[0] and float(Time.get_ticks_msec() - inicio_ms) / 1000.0 < ESPERA_MAXIMA_S:
		await get_tree().process_frame
	var rapida: float = float(Time.get_ticks_msec() - inicio_ms) / 1000.0  # Tempo restante medido.
	print("  restante da sequência a ×4: %.2f s" % rapida)  # Mostra.
	# Termina bem mais rápido.
	_confere(terminou[0] and rapida < DURACAO_MAX_S / 3.0, "a ×4 o restante termina bem mais rápido")
	await _fechar(tela)  # Fecha.

	# Sem animação: já nasce no estado final.
	tela = _nova_tela(false)  # Tela sem animação.
	_confere_estado_final(tela, "sem animação")  # Estado final.
	await _fechar(tela)  # Fecha.
