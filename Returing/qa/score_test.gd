extends SceneTree
## Testes exatos do cálculo de pontuação (exemplo resolvido, bordas, determinismo e simulação).
## Rodar: godot --headless --path . --script qa/score_test.gd

var _falhas: int = 0  # Verificações que falharam.
var _total: int = 0  # Total de verificações.


## Roda todos os grupos de teste da pontuação e mostra o resultado.
func _initialize() -> void:
	_testar_exemplo_resolvido()  # Exemplo resolvido à mão.
	_testar_bordas_de_tempo()  # Bordas do tempo.
	_testar_combo()  # Combo.
	_testar_penalidade()  # Penalidade.
	_testar_run_sem_abates()  # Run sem abates.
	_testar_determinismo()  # Determinismo e ranks.
	_testar_pesos_reais()  # Pesos reais do jogo.
	_testar_simulacao_de_ranks()  # Simulação de runs de referência.
	print("score_test: %d verificações, %d falhas" % [_total, _falhas])  # Resultado.
	quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.


## Confere uma condição e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		printerr("FALHOU: ", nome)


## Compara o valor obtido com o esperado e mostra os dois se forem diferentes.
func _igual(obtido: Variant, esperado: Variant, nome: String) -> void:
	_total += 1
	if obtido != esperado:
		_falhas += 1
		printerr("FALHOU: %s (obtido %s, esperado %s)" % [nome, obtido, esperado])


## Configuração do exemplo resolvido: 5 fases, pesos 100/200/400, chefe 2000 e vida do mais fraco igual a 2.
## Configuração do exemplo do prompt: 5 fases, pesos 100/200/400, chefe 2000, vida do mais fraco = 2.
func _config_exemplo() -> ScoreConfig:  # Configuração nova.
	var c := ScoreConfig.new()
	c.numero_de_fases = 5  # Cinco fases.
	c.vida_max_por_tipo = {&"a": 2, &"b": 5, &"c": 10, &"boss": 99}  # Vida de cada tipo.
	c.tipos_chefe = [&"boss"]  # O chefe.
	return c


## Run do exemplo resolvido (tempo, abates, combo, dano e vida inicial).
func _run_exemplo() -> RunSnapshot:
	var s := RunSnapshot.new()  # Run nova.
	s.tempo_s = 1020.0  # Tempo de jogo.
	s.abates_por_tipo = {&"a": 30, &"b": 12, &"c": 5, &"boss": 1}  # Abates por tipo.
	s.maior_sequencia_abates = 9  # Maior combo.
	s.dano_causado = 210.0  # Dano causado.
	s.dano_tomado = 30.0  # Dano tomado.
	s.vida_max_inicial_jogador = 10.0  # Vida inicial.
	return s


## Confere o exemplo resolvido ponto a ponto: pesos, cada componente, bruto, penalidade, total e rank.
func _testar_exemplo_resolvido() -> void:
	var cfg: ScoreConfig = _config_exemplo()  # Configuração do exemplo.
	_igual(ScoreCalculator.peso_do_tipo(&"a", cfg), 100, "peso a")  # Pesos por tipo.
	_igual(ScoreCalculator.peso_do_tipo(&"b", cfg), 200, "peso b")
	_igual(ScoreCalculator.peso_do_tipo(&"c", cfg), 400, "peso c")
	_igual(ScoreCalculator.peso_do_tipo(&"boss", cfg), 2000, "peso chefe")
	var r: ScoreResult = ScoreCalculator.calcular(_run_exemplo(), cfg)  # Calcula o resultado.
	_igual(r.pontos_tempo, 3833, "exemplo: tempo")  # Cada componente.
	_igual(r.pontos_abates, 9400, "exemplo: abates")
	_igual(r.pontos_variedade, 1200, "exemplo: variedade")
	_igual(r.pontos_combo, 350, "exemplo: combo")
	_igual(r.pontos_dano, 1050, "exemplo: dano causado")
	_igual(r.bruto, 15833, "exemplo: bruto")  # Bruto.
	_igual(r.penalidade, 4500, "exemplo: penalidade")  # Penalidade.
	_igual(r.total, 11333, "exemplo: total")  # Total.
	_igual(r.rank, &"B", "exemplo: rank")  # Rank.
	_igual(r.pontos_quiz, 0, "exemplo: quiz")  # Quiz desligado.
	_igual(r.linhas_inimigos.size(), 4, "exemplo: linhas de inimigo")  # Linhas de inimigo.
	# Ordenadas por pontos.
	_igual(r.linhas_inimigos[0].pontos, 3000, "exemplo: linhas ordenadas por pontos")


## Testa as bordas do tempo: no tempo par, abaixo, no meio, no limite, acima e com limite igual ao par (sem dividir por zero).
func _testar_bordas_de_tempo() -> void:
	var cfg: ScoreConfig = _config_exemplo()  # Configuração do exemplo.
	_igual(ScoreCalculator.pontos_de_tempo(600.0, cfg), 5000, "tempo 600 (par)")  # No tempo par.
	_igual(ScoreCalculator.pontos_de_tempo(300.0, cfg), 5000, "tempo 300 (abaixo do par)")  # Abaixo do par.
	_igual(ScoreCalculator.pontos_de_tempo(1500.0, cfg), 2500, "tempo 1500")  # No meio da rampa.
	_igual(ScoreCalculator.pontos_de_tempo(2400.0, cfg), 0, "tempo 2400 (limite)")  # No limite.
	# Acima do limite.
	_igual(ScoreCalculator.pontos_de_tempo(3000.0, cfg), 0, "tempo 3000 (acima do limite)")
	# Proteção da divisão: limite <= par não pode dividir por zero.
	var ruim := ScoreConfig.new()  # Configuração ruim.
	ruim.multiplicador_limite = 1.0  # Limite igual ao par.
	_igual(ScoreCalculator.pontos_de_tempo(100.0, ruim), 5000, "limite == par, rápido")  # Rápido.
	_igual(ScoreCalculator.pontos_de_tempo(10000.0, ruim), 0, "limite == par, lento")  # Lento.


## Testa o combo: sem bônus abaixo do mínimo, bônus crescente e teto.
func _testar_combo() -> void:
	var cfg: ScoreConfig = _config_exemplo()  # Configuração do exemplo.
	_igual(ScoreCalculator.pontos_de_combo(2, cfg), 0, "combo 2")  # Combo de 2.
	_igual(ScoreCalculator.pontos_de_combo(3, cfg), 50, "combo 3")  # Combo de 3.
	_igual(ScoreCalculator.pontos_de_combo(30, cfg), 1000, "combo 30 (teto)")  # Teto.
	_igual(ScoreCalculator.pontos_de_combo(0, cfg), 0, "combo 0")  # Zero.


## Testa a penalidade: teto de 50% do bruto, total nunca negativo, sem dano sem penalidade e vida inicial zero.
func _testar_penalidade() -> void:
	var cfg: ScoreConfig = _config_exemplo()  # Configuração do exemplo.
	# Teto de 50% do bruto vale: 100 barras perdidas.
	var run: RunSnapshot = _run_exemplo()  # Run do exemplo.
	run.dano_tomado = 1000.0  # Muito dano tomado.
	var r: ScoreResult = ScoreCalculator.calcular(run, cfg)  # Calcula.
	_igual(r.penalidade, roundi(0.5 * float(r.bruto)), "penalidade limitada em 50%")  # Penalidade limitada.
	_igual(r.total, r.bruto - r.penalidade, "total com teto da penalidade")  # Total com o teto.
	# Total nunca negativo, mesmo com configuração absurda.
	cfg.teto_penalidade_pct = 5.0  # Teto absurdo.
	cfg.penalidade_por_barra = 1000000  # Penalidade absurda.
	r = ScoreCalculator.calcular(run, cfg)  # Calcula.
	_igual(r.total, 0, "total nunca negativo")  # Total zero.
	# Sem dano tomado, sem penalidade.
	run.dano_tomado = 0.0  # Sem dano.
	_igual(ScoreCalculator.calcular(run, _config_exemplo()).penalidade, 0, "sem dano, sem penalidade")
	# Vida inicial zero não divide por zero.
	run.vida_max_inicial_jogador = 0.0  # Vida zero.
	run.dano_tomado = 5.0  # Dano pequeno.
	# Não quebra.
	_confere(ScoreCalculator.calcular(run, _config_exemplo()).total >= 0, "vida inicial 0 não quebra")


## Testa uma run sem nenhum abate: todos os componentes zerados e rank D.
func _testar_run_sem_abates() -> void:
	var cfg: ScoreConfig = _config_exemplo()  # Configuração do exemplo.
	var s := RunSnapshot.new()  # Run vazia.
	s.tempo_s = 2400.0  # Tempo no limite.
	s.vida_max_inicial_jogador = 10.0  # Vida inicial.
	var r: ScoreResult = ScoreCalculator.calcular(s, cfg)  # Calcula.
	_igual(r.pontos_abates, 0, "sem abates: abates")  # Sem abates.
	_igual(r.pontos_variedade, 0, "sem abates: variedade")
	_igual(r.pontos_combo, 0, "sem abates: combo")
	_igual(r.pontos_dano, 0, "sem abates: dano")
	_igual(r.total, 0, "sem abates: total")
	_igual(r.rank, &"D", "sem abates: rank")
	_igual(r.linhas_inimigos.size(), 0, "sem abates: sem linhas de inimigo")  # Sem linhas de inimigo.


## Testa o determinismo (mesma entrada, mesmo resultado), os limites dos ranks e que o cálculo não altera a configuração.
func _testar_determinismo() -> void:
	var cfg: ScoreConfig = _config_exemplo()  # Configuração do exemplo.
	var a: ScoreResult = ScoreCalculator.calcular(_run_exemplo(), cfg)  # Primeiro cálculo.
	var b: ScoreResult = ScoreCalculator.calcular(_run_exemplo(), cfg)  # Segundo cálculo.
	# Iguais.
	_confere(a.total == b.total and a.rank == b.rank and a.bruto == b.bruto and a.penalidade == b.penalidade,
			"mesma entrada, mesmo resultado")
	# Limite S exato.
	_igual(ScoreCalculator.rank_do_total(18000, ScoreConfig.new()), &"S", "limite S exato")
	# Logo abaixo de S.
	_igual(ScoreCalculator.rank_do_total(17999, ScoreConfig.new()), &"A", "logo abaixo de S")
	# Limite C exato.
	_igual(ScoreCalculator.rank_do_total(6500, ScoreConfig.new()), &"C", "limite C exato")
	# Logo abaixo de C.
	_igual(ScoreCalculator.rank_do_total(6499, ScoreConfig.new()), &"D", "logo abaixo de C")
	# Nomes e cores de todos os ranks.
	_confere(not ScoreResult.RANK_NOMES.is_empty() and ScoreResult.RANK_NOMES.size() == ScoreResult.RANK_CORES.size(),
			"nomes e cores de todos os ranks")
	_igual(ScoreResult.RANK_NOMES[&"B"], "BOA", "nome do rank B")  # Nome do rank B.
	# O cálculo não pode alterar a configuração.
	var antes: int = cfg.limite_s  # Limite antes.
	ScoreCalculator.calcular(_run_exemplo(), cfg)  # Calcula.
	_igual(cfg.limite_s, antes, "calcular não altera a configuração")  # Limite depois.


## Pesos reais do jogo a partir do score_config.tres.
func _testar_pesos_reais() -> void:
	var cfg: ScoreConfig = load(ScoreConfig.DEFAULT_PATH) as ScoreConfig  # Carrega a configuração real.
	_confere(cfg != null, "score_config.tres carrega")  # Carregou.
	_igual(ScoreCalculator.vida_do_mais_fraco(cfg), 40.0, "mais fraco = drone")  # O mais fraco é o drone.
	_igual(ScoreCalculator.peso_do_tipo(&"drone", cfg), 100, "peso drone")  # Peso do drone.
	_igual(ScoreCalculator.peso_do_tipo(&"robo", cfg), 200, "peso robo")  # Peso do robô.
	_igual(ScoreCalculator.peso_do_tipo(&"tank", cfg), 800, "peso tank")  # Peso do tank.
	_igual(ScoreCalculator.peso_do_tipo(&"guide", cfg), 2000, "peso guide (chefe)")  # Peso do chefe.
	# Nome do tipo.
	_igual(ScoreCalculator.nome_do_tipo(&"drone", cfg), "DRONE", "nome do tipo em maiúsculas")
	cfg.peso_por_tipo = {&"tank": 123}  # Peso fixo por tipo.
	# O peso fixo tem prioridade.
	_igual(ScoreCalculator.peso_do_tipo(&"tank", cfg), 123, "peso_por_tipo tem prioridade")


## 5 runs de referência com os dados reais: precisam cair em S, A, B, C e D, nessa ordem.
## Simula cinco runs de referência com os dados reais: precisam cair em S, A, B, C e D, nessa ordem.
func _testar_simulacao_de_ranks() -> void:
	var cfg: ScoreConfig = load(ScoreConfig.DEFAULT_PATH) as ScoreConfig  # Configuração real.
	# Abates iguais em todas as runs.
	var abates: Dictionary = {&"drone": 8, &"robo": 9, &"tank": 6, &"guide": 1}
	# [nome, tempo, combo, dano_tomado, acertos_quiz, rank esperado, total esperado]
	var casos: Array[Array] = [
		["perfeita", 330.0, 11, 0.0, 5, &"S", 18900],
		["ótima", 480.0, 8, 40.0, 5, &"A", 17594],
		["média", 780.0, 5, 200.0, 3, &"B", 13056],
		["ruim", 1200.0, 3, 450.0, 2, &"C", 6961],
		["péssima", 1600.0, 0, 900.0, 0, &"D", 5975],
	]
	for caso: Array in casos:  # Para cada caso.
		var s := RunSnapshot.new()  # Run do caso.
		s.tempo_s = caso[1]  # Tempo.
		s.abates_por_tipo = abates.duplicate()  # Abates.
		s.maior_sequencia_abates = caso[2]  # Combo.
		s.dano_causado = 5400.0  # Dano causado.
		s.dano_tomado = caso[3]  # Dano tomado.
		s.acertos_quiz = caso[4]  # Acertos do quiz.
		s.vida_max_inicial_jogador = 100.0  # Vida inicial.
		var r: ScoreResult = ScoreCalculator.calcular(s, cfg)  # Calcula.
		print("  simulação %-9s total %5d rank %s" % [caso[0], r.total, r.rank])  # Mostra o resultado.
		_igual(r.total, caso[6], "simulação %s: total" % caso[0])  # Confere o total.
		_igual(r.rank, caso[5], "simulação %s: rank" % caso[0])  # Confere o rank.
