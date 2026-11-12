class_name ScoreCalculator
extends RefCounted
## Cálculo da pontuação. Funções estáticas e puras: só leem o RunSnapshot e o ScoreConfig, sem
## aleatoriedade, hora do sistema, UI nem cena. Cada componente é arredondado (roundi) e depois somado.

## Rótulos das linhas (a tela final usa os mesmos).
const ROTULO_TEMPO: String = "TEMPO DE JOGO"
const ROTULO_VARIEDADE: String = "VARIEDADE"
const ROTULO_COMBO: String = "MAIOR COMBO"
const ROTULO_DANO: String = "DANO CAUSADO"
const ROTULO_QUIZ: String = "QUIZ"
## Evita divisão por zero quando nada informa a vida.
const VIDA_MINIMA: float = 1.0


## Calcula tudo a partir dos números brutos da run.
## Calcula todos os componentes da pontuação a partir dos números brutos: tempo, abates, variedade, combo, dano e quiz, menos a penalidade.
static func calcular(run: RunSnapshot, config: ScoreConfig) -> ScoreResult:
	var r := ScoreResult.new()  # Resultado novo.
	var fraco: float = vida_do_mais_fraco(config)  # Vida do inimigo comum mais fraco (base do dano).

	r.pontos_tempo = pontos_de_tempo(run.tempo_s, config)  # Pontos de tempo.
	# Linha da tela final.
	r.linha_tempo = ScoreResult.Linha.new(&"tempo", ROTULO_TEMPO, run.tempo_s, r.pontos_tempo)

	var tipos_distintos: int = 0  # Tipos de inimigo diferentes abatidos.
	for tipo: StringName in run.abates_por_tipo:  # Cada tipo abatido.
		var qtd: int = int(run.abates_por_tipo[tipo])  # Quantidade abatida.
		if qtd <= 0:  # Ninguém desse tipo: pula.
			continue
		tipos_distintos += 1  # Mais um tipo distinto.
		var pontos: int = qtd * peso_do_tipo(tipo, config)  # Pontos: quantidade vezes o peso do tipo.
		r.pontos_abates += pontos  # Soma aos pontos de abates.
		# Linha do tipo.
		r.linhas_inimigos.append(ScoreResult.Linha.new(&"abates", nome_do_tipo(tipo, config), float(qtd), pontos, tipo))
	r.linhas_inimigos.sort_custom(_por_pontos_decrescente)  # Ordena do que mais pontuou ao que menos.

	r.pontos_variedade = config.pontos_por_tipo_distinto * tipos_distintos  # Bônus de variedade.
	# Linha da variedade.
	r.linha_variedade = ScoreResult.Linha.new(&"variedade", ROTULO_VARIEDADE, float(tipos_distintos), r.pontos_variedade)

	r.pontos_combo = pontos_de_combo(run.maior_sequencia_abates, config)  # Bônus do combo.
	# Linha do combo.
	r.linha_combo = ScoreResult.Linha.new(&"combo", ROTULO_COMBO, float(run.maior_sequencia_abates), r.pontos_combo)

	# Pontos de dano causado.
	r.pontos_dano = roundi(float(config.pontos_por_vida_base_causada) * run.dano_causado / fraco)
	# Linha do dano.
	r.linha_dano = ScoreResult.Linha.new(&"dano", ROTULO_DANO, run.dano_causado, r.pontos_dano)

	if config.quiz_ativo:  # Quiz ligado na configuração.
		r.pontos_quiz = config.pontos_por_acerto * run.acertos_quiz  # Pontos do quiz.
		# Linha do quiz.
		r.linha_quiz = ScoreResult.Linha.new(&"quiz", ROTULO_QUIZ, float(run.acertos_quiz), r.pontos_quiz)

	# Soma bruta.
	r.bruto = r.pontos_tempo + r.pontos_abates + r.pontos_variedade + r.pontos_combo + r.pontos_dano + r.pontos_quiz
	# Barras de vida perdidas.
	r.barras_perdidas = run.dano_tomado / maxf(run.vida_max_inicial_jogador, VIDA_MINIMA)
	# Penalidade por dano tomado, limitada a uma fração do bruto.
	r.penalidade = roundi(minf(config.teto_penalidade_pct * float(r.bruto),
			float(config.penalidade_por_barra) * r.barras_perdidas))
	r.total = maxi(0, r.bruto - r.penalidade)  # Total (nunca negativo).
	r.rank = rank_do_total(r.total, config)  # Rank.
	r.tempos_por_fase = run.tempos_por_fase.duplicate()  # Tempos por fase.
	return r  # Devolve o resultado.


## Tempo par da run inteira (s).
## Tempo "par" da run inteira (acima disso os pontos de tempo começam a cair).
static func tempo_par_s(config: ScoreConfig) -> float:
	return config.tempo_par_por_fase_s * float(config.numero_de_fases)


## Tempo a partir do qual os pontos de tempo valem 0 (s).
## Tempo a partir do qual os pontos de tempo valem 0.
static func tempo_limite_s(config: ScoreConfig) -> float:
	return config.multiplicador_limite * tempo_par_s(config)


## Pontos de tempo: máximo até o tempo par, 0 a partir do limite, linear no meio.
## Pontos de tempo: máximo até o tempo par, zero a partir do limite e linear entre os dois.
static func pontos_de_tempo(tempo_s: float, config: ScoreConfig) -> int:
	var par: float = tempo_par_s(config)  # Tempo par.
	var limite: float = tempo_limite_s(config)  # Tempo limite.
	var faixa: float = limite - par  # Largura da rampa.
	if faixa <= 0.0:  # configuração inválida: sem rampa
		return config.pontos_tempo_max if tempo_s <= par else 0
	return roundi(float(config.pontos_tempo_max) * clampf((limite - tempo_s) / faixa, 0.0, 1.0))


## Bônus da maior sequência de abates.
## Bônus da maior sequência de abates (com teto).
static func pontos_de_combo(maior_sequencia: int, config: ScoreConfig) -> int:
	if maior_sequencia < config.combo_minimo:  # Sequência pequena demais: sem bônus.
		return 0
	# Pontos por abate acima do mínimo, com teto.
	return mini(config.pontos_por_abate_acima_de_2 * (maior_sequencia - config.abates_sem_bonus_combo), config.teto_combo)


## Vida do tipo comum mais fraco (chefes não entram).
## Vida do inimigo comum mais fraco (chefes não entram).
static func vida_do_mais_fraco(config: ScoreConfig) -> float:
	var menor: float = INF  # Começa infinito.
	for tipo: StringName in config.vida_max_por_tipo:  # Cada tipo.
		if config.tipos_chefe.has(tipo):  # Chefe: pula.
			continue
		menor = minf(menor, float(config.vida_max_por_tipo[tipo]))  # Guarda a menor vida.
	return VIDA_MINIMA if is_inf(menor) else maxf(menor, VIDA_MINIMA)  # Sem tipos: vida mínima.


## Peso de um abate: `peso_por_tipo`, depois chefe, depois a faixa pela razão de vida.
## Peso de um abate: valor fixo do tipo, depois chefe, depois a faixa pela razão de vida.
static func peso_do_tipo(tipo: StringName, config: ScoreConfig) -> int:
	if config.peso_por_tipo.has(tipo):  # Peso fixo configurado.
		return config.peso_por_tipo[tipo]
	if config.tipos_chefe.has(tipo):  # Chefe.
		return config.peso_chefe
	if not config.vida_max_por_tipo.has(tipo):  # Tipo desconhecido: faixa mais baixa.
		return config.peso_faixa_1  # tipo desconhecido: faixa mais baixa
	# Razão entre a vida do tipo e a do mais fraco.
	var razao: float = float(config.vida_max_por_tipo[tipo]) / vida_do_mais_fraco(config)
	# Pesos de cada faixa.
	var pesos: Array[int] = [config.peso_faixa_1, config.peso_faixa_2, config.peso_faixa_3, config.peso_faixa_4]
	var faixa: int = 0  # Faixa inicial.
	for limite: float in config.limites_razao_vida:  # cada limite alcançado sobe uma faixa
		if razao >= limite:
			faixa += 1
	return pesos[mini(faixa, pesos.size() - 1)]  # Peso da faixa (nunca passa da última).


## Nome exibido do tipo.
## Nome mostrado do tipo (ou o próprio tipo em maiúsculas).
static func nome_do_tipo(tipo: StringName, config: ScoreConfig) -> String:
	return config.nomes_por_tipo.get(tipo, String(tipo).to_upper())


## Rank de um total.
## Rank de um total, comparando com os limites S, A, B e C (abaixo de C é D).
static func rank_do_total(total: int, config: ScoreConfig) -> StringName:
	if total >= config.limite_s:
		return ScoreResult.RANK_S
	if total >= config.limite_a:
		return ScoreResult.RANK_A
	if total >= config.limite_b:
		return ScoreResult.RANK_B
	if total >= config.limite_c:
		return ScoreResult.RANK_C
	return ScoreResult.RANK_D


## Ordem das linhas: mais pontos primeiro; empate pelo nome do tipo (ordem estável).
static func _por_pontos_decrescente(a: ScoreResult.Linha, b: ScoreResult.Linha) -> bool:
	if a.pontos != b.pontos:
		return a.pontos > b.pontos
	return String(a.tipo) < String(b.tipo)  # desempate estável
