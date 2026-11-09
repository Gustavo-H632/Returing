extends Node
## Regressões da auditoria de QA. R1, R5 e R6 reproduziam defeitos reais antes da correção (R2 a R4 são proteções).
## Rodar: godot --headless --path . res://qa/regressao_test.tscn

const FASE_2: String = "res://Scenes/Fase2/Fase2.tscn"  # Fase 2.
const FASE_3: String = "res://Scenes/Fase3/fase_3.tscn"  # Fase 3.
# Arquivo temporário de recorde.
const ARQUIVO_TESTE: String = "user://returing_recordes_regressao_teste.cfg"

var _falhas: int = 0  # Falhas.
var _total: int = 0  # Total de verificações.
var _fase: Node = null  # Fase aberta agora.
var _emissoes: Array[String] = []  # Anota o que o EventBus emitiu durante o teste.


## Troca o arquivo de recorde para um temporário e agenda os testes.
func _ready() -> void:
	HighScoreStore.caminho = ARQUIVO_TESTE  # Não mexe no recorde real.
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Confere uma condição e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


## Espera `n` quadros.
func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## Abre uma fase real (removendo a anterior) e espera ela ficar pronta.
func _abrir_fase(caminho: String) -> void:
	if _fase != null:
		_fase.queue_free()
		await _frames(3)
	_fase = (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child(_fase)
	get_tree().current_scene = _fase
	await _frames(15)


## Devolve o gravador de tempo do jogador da fase atual.
func _recorder() -> RunRecorder:
	var player: Node = _fase.find_child("Player", true, false)
	return player.get_node_or_null("RunRecorder") as RunRecorder if player != null else null


## Devolve as telas finais abertas na fase atual.
func _telas() -> Array[ResultScreen]:
	var achadas: Array[ResultScreen] = []
	for filho: Node in _fase.get_children():
		if filho is ResultScreen:
			achadas.append(filho)
	return achadas


## Roda todas as regressões (R1 a R6) em ordem, limpa e mostra o resultado.
func _rodar() -> void:
	_regressao_config_incompleta()  # R1: configuração incompleta.
	await _regressao_quiz_da_fase_2()  # R2: quiz da Fase 2.
	await _regressao_fim_duplicado_e_entrada_no_hud()  # R3 e R4: fim duplicado e entrada no HUD.
	await _regressao_run_sem_inimigos()  # R5: run sem inimigos.
	await _regressao_valor_zero()  # R6: valor zero.
	if _fase != null:  # Limpeza: remove a fase.
		_fase.queue_free()
		await _frames(3)
	if FileAccess.file_exists(ARQUIVO_TESTE):  # Apaga o arquivo temporário.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO_TESTE))
	print("regressao_test: %d verificações, %d falhas" % [_total, _falhas])  # Resultado.
	get_tree().quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.


## R1: `limites_razao_vida` com menos de 3 valores (edição no Inspector) derrubava o cálculo.
## R1: `limites_razao_vida` com menos de 3 valores (edição no Inspector) derrubava o cálculo.
func _regressao_config_incompleta() -> void:
	var cfg := ScoreConfig.new()  # Configuração com um limite só.
	cfg.limites_razao_vida = [2.0]
	var run := RunSnapshot.new()  # Run com um tank abatido.
	run.abates_por_tipo = {&"tank": 1}
	run.vida_max_inicial_jogador = 100.0
	var resultado: ScoreResult = ScoreCalculator.calcular(run, cfg)  # Calcula.
	# Não pode derrubar o cálculo.
	_confere(resultado != null and resultado.pontos_abates > 0, "R1: limites incompletos não derrubam o cálculo")


## R2: o quiz real da Fase 2 é encontrado e os acertos são contados.
## R2: o quiz real da Fase 2 é encontrado e os acertos são contados.
func _regressao_quiz_da_fase_2() -> void:
	RunStats.reset()  # Run nova.
	await _abrir_fase(FASE_2)  # Abre a Fase 2.
	var recorder: RunRecorder = _recorder()
	_confere(recorder != null, "R2: Player da Fase 2 tem o RunRecorder")
	if recorder == null:
		return
	await _frames(3)  # Espera o gravador achar o quiz.
	var quiz: QuizScreen = _fase.find_child("Quiz", true, false) as QuizScreen  # Quiz da fase.
	_confere(quiz != null, "R2: Fase 2 tem o QuizScreen")
	_confere(recorder._quiz == quiz and quiz != null, "R2: o recorder encontrou o quiz da fase")
	if quiz != null:
		quiz.resposta_registrada.emit(0, true, &"acerto")  # Um acerto.
		quiz.resposta_registrada.emit(1, false, &"erro")  # Um erro.
		_confere(RunStats.acertos_quiz == 1, "R2: só o acerto do quiz real conta")  # Só o acerto conta.


## Anota que o menu principal foi pedido.
func _anota_menu() -> void:
	_emissoes.append("menu")


## Anota que uma troca de cena foi pedida.
func _anota_cena(_caminho: String) -> void:
	_emissoes.append("cena")


## R3 e R4 foram hipóteses de defeito que a auditoria NÃO reproduziu; ficam como proteção contra regressão:
## R3: `level_completed("")` repetido não pode abrir duas telas; R4: Enter logo na abertura não pode acionar o HUD.
## R3: dois avisos de fim não abrem duas telas. R4: Enter logo na abertura não aciona botões do HUD.
func _regressao_fim_duplicado_e_entrada_no_hud() -> void:
	RunStats.reset()
	await _abrir_fase(FASE_3)  # Run nova.
	var recorder: RunRecorder = _recorder()  # Abre a Fase 3.
	recorder._config.atraso_tela_final_s = 0.1  # Atraso curto da tela final.
	EventBus.main_menu_requested.connect(_anota_menu)  # Anota pedidos de menu.
	EventBus.scene_change_requested.connect(_anota_cena)  # Anota pedidos de troca de cena.
	EventBus.level_completed.emit("")  # Fim avisado.
	EventBus.level_completed.emit("")  # Fim avisado de novo.
	await get_tree().create_timer(0.35, true, false, true).timeout  # Espera a tela abrir.
	await _frames(3)
	# Só uma tela.
	_confere(_telas().size() == 1, "R3: duas notificações de fim abrem uma tela só (abriu %d)" % _telas().size())
	# Tempo da fase registrado uma vez.
	_confere(RunStats.tempos_por_fase.size() == 1, "R3: tempo da fase registrado uma vez (%d)" % RunStats.tempos_por_fase.size())

	for i: int in 6:  # Enter martelado nos primeiros instantes (HUD com o botão Menu focado)
		var ev := InputEventAction.new()  # Evento de Enter.
		ev.action = &"ui_accept"
		ev.pressed = true
		Input.parse_input_event(ev)
		await get_tree().process_frame
	# Nenhum pedido foi gerado.
	_confere(_emissoes.is_empty(), "R4: Enter na abertura não aciona botões do HUD (%s)" % [_emissoes])
	EventBus.main_menu_requested.disconnect(_anota_menu)
	EventBus.scene_change_requested.disconnect(_anota_cena)
	for tela: ResultScreen in _telas():  # Remove as telas.
		tela.queue_free()
	await _frames(2)
	get_tree().paused = false  # Despausa.


## R5: sem inimigos abatidos o título "INIMIGOS ABATIDOS" ficava invisível no fim natural da animação
## (e aparecia depois de "pular").
## R5: sem inimigos abatidos o título "INIMIGOS ABATIDOS" ficava invisível no fim natural da animação.
func _regressao_run_sem_inimigos() -> void:
	var run := RunSnapshot.new()  # Run sem abates.
	run.tempo_s = 400.0
	run.tempos_por_fase = [100.0, 100.0, 200.0]
	run.vida_max_inicial_jogador = 100.0
	var resultado: ScoreResult = ScoreCalculator.calcular(run, ScoreConfig.carregar())
	var tela: ResultScreen = ResultScreen.abrir(self, resultado, {}, true)  # Abre a tela com animação.
	tela.entrada_ignorada_s = 0.0  # Sem tempo de proteção.
	var terminou: Array[bool] = [false]  # Marca se a animação terminou.
	tela.animacao_terminou.connect(func() -> void: terminou[0] = true)  # Escuta o fim.
	var ev := InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = true
	tela._input(ev)  # 1º pular: acelera, mas o fim ainda é natural
	var inicio_ms: int = Time.get_ticks_msec()  # Hora de início.
	# Espera até terminar (limite de 15 s).
	while not terminou[0] and Time.get_ticks_msec() - inicio_ms < 15000:
		await get_tree().process_frame
	_confere(terminou[0], "R5: animação sem inimigos termina")  # A animação terminou.
	# O cabeçalho está visível.
	_confere(tela._cabecalho_inimigos.modulate.a == 1.0, "R5: cabeçalho de inimigos visível no fim natural")
	tela.queue_free()  # Remove a tela.
	await _frames(2)
	get_tree().paused = false  # Despausa.


## R6: sem dano tomado a tela mostrava "-0" (e "+0" nos bônus vazios); zero é só "0".
## R6: sem dano tomado a tela mostrava "-0" (e "+0" nos bônus vazios); zero é só "0".
func _regressao_valor_zero() -> void:
	var run := RunSnapshot.new()  # Run sem dano.
	run.tempo_s = 400.0
	run.vida_max_inicial_jogador = 100.0
	var resultado: ScoreResult = ScoreCalculator.calcular(run, ScoreConfig.carregar())
	var tela: ResultScreen = ResultScreen.abrir(self, resultado, {}, false)  # Abre a tela sem animar.
	# Dano tomado zero aparece como 0.
	_confere(tela._linha_penalidade.valor.text == "0", "R6: dano tomado zero aparece como 0 (apareceu '%s')" % tela._linha_penalidade.valor.text)
	# Bônus zerado aparece como 0.
	_confere(tela._linhas_extras_ui[1].valor.text == "0", "R6: bônus zerado aparece como 0 (apareceu '%s')" % tela._linhas_extras_ui[1].valor.text)
	tela.queue_free()  # Remove a tela.
	await _frames(2)
	get_tree().paused = false  # Despausa.
