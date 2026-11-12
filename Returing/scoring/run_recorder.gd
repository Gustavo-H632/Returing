class_name RunRecorder
extends Node
## Filho do Player: conta o tempo de jogo e registra os números brutos da run em `RunStats`.
## Fica pausável (`process_mode` padrão): pause, menus de escolha/build e quiz pausam a árvore
## e, por isso, não contam. Cutscene e tutorial são cenas sem Player, então também não contam.

## Corte de travadas (arrastar a janela): um frame maior que isso é limitado a este valor.
const MAX_DELTA_S: float = 0.25
## Piso do time_scale para a divisão nunca estourar.
const MIN_TIME_SCALE: float = 0.001

## True depois que a fase terminou: o intervalo até a próxima cena não conta.
var _fase_concluida: bool = false
var _config: ScoreConfig = null  # Configuração da pontuação.
## Quiz da fase (só existe na Fase 2).
var _quiz: QuizScreen = null
## True depois que a tela final foi agendada (avisos repetidos de fim não abrem duas telas).
var _final_agendada: bool = false


## Dá um nome estável ao nó (ele é criado por código).
func _init() -> void:
	name = &"RunRecorder"  # nome estável (nó criado por código)


## Carrega a configuração e liga os sinais do EventBus que alimentam as estatísticas.
func _enter_tree() -> void:
	_config = ScoreConfig.carregar()  # Configuração.
	CombatUtils.connect_once(EventBus.level_completed, _on_level_completed)  # Fase concluída.
	CombatUtils.connect_once(EventBus.enemy_died, _on_enemy_died)  # Inimigo morreu.
	CombatUtils.connect_once(EventBus.enemy_damaged, _on_enemy_damaged)  # Inimigo tomou dano.
	CombatUtils.connect_once(EventBus.player_damaged, _on_player_damaged)  # Jogador tomou dano.


## Procura o quiz da fase no fim do quadro (ele só existe na Fase 2).
func _ready() -> void:
	_ligar_quiz.call_deferred()  # Adiado para depois da criação dos nós.


## Ao sair da cena desliga os sinais.
func _exit_tree() -> void:
	CombatUtils.disconnect_if_connected(EventBus.level_completed, _on_level_completed)
	CombatUtils.disconnect_if_connected(EventBus.enemy_died, _on_enemy_died)
	CombatUtils.disconnect_if_connected(EventBus.enemy_damaged, _on_enemy_damaged)
	CombatUtils.disconnect_if_connected(EventBus.player_damaged, _on_player_damaged)
	if CombatUtils.is_valid(_quiz):  # Se ligou ao quiz, desliga também.
		CombatUtils.disconnect_if_connected(_quiz.resposta_registrada, _on_quiz_resposta)


## A cada quadro lê a vida inicial (uma vez) e soma o tempo de jogo.
func _process(delta: float) -> void:
	_ler_vida_inicial()  # Guarda a vida máxima inicial.
	if pode_contar():  # Só conta com o jogador jogando.
		RunStats.somar_tempo(segundos_contados(delta, Engine.time_scale))  # Soma o tempo real do quadro.


## Segundos de tempo REAL de jogo de um frame: o delta já vem multiplicado pelo time_scale
## (câmera lenta do modo comando), então a divisão devolve o tempo real.
## Tempo real de um quadro: o delta vem reduzido pela câmera lenta, então divide pelo time_scale.
static func segundos_contados(delta: float, time_scale: float) -> float:
	# Limita o quadro e divide pelo time_scale.
	return minf(delta, MAX_DELTA_S) / maxf(time_scale, MIN_TIME_SCALE)


## True só com o jogador de fato jogando: run em andamento, fase em curso e Player vivo.
## Diz se o relógio da run pode contar: run em andamento, fase em curso e jogador vivo.
func pode_contar() -> bool:
	if RunStats.finalizada or _fase_concluida:  # Run encerrada ou fase concluída: não conta.
		return false
	return not CombatUtils.is_dead_actor(get_parent())  # Jogador morto: não conta.


## Guarda a vida máxima do Player na primeira vez (antes de qualquer bônus de habilidade).
## Guarda a vida máxima do jogador na primeira vez (antes de qualquer bônus de habilidade).
func _ler_vida_inicial() -> void:
	if RunStats.vida_max_inicial_jogador > 0.0:  # Já guardada.
		return
	var hp_max: Variant = get_parent().get(&"hp_maximo")  # Vida máxima lida do jogador.
	if hp_max != null:  # Só guarda se existe.
		RunStats.vida_max_inicial_jogador = float(hp_max)  # Guarda.


## Fase concluída. Sem próxima cena é a última: fecha a run, calcula e abre a tela final.
## Fase concluída: guarda o tempo da fase e, se for a última, fecha a run e abre a tela final.
func _on_level_completed(next_scene: String) -> void:
	_fase_concluida = true  # Marca a fase como concluída.
	RunStats.registrar_fim_de_fase()  # Guarda o tempo da fase.
	if next_scene.is_empty():  # Sem próxima cena: é a última fase.
		_finalizar_run()  # Calcula e mostra o resultado.


## Só aqui a pontuação é calculada (durante o jogo nada é calculado nem exibido).
## Calcula a pontuação uma única vez, grava o recorde e agenda a tela final (depois da cutscene final, se a fase tiver uma).
func _finalizar_run() -> void:
	if _final_agendada:  # Já agendada: avisos repetidos não abrem outra tela.
		return
	_final_agendada = true
	RunStats.finalizar()  # Encerra a contagem.
	# Calcula os pontos a partir dos números brutos.
	var resultado: ScoreResult = ScoreCalculator.calcular(RunStats.capturar(), _config)
	# Compara com o recorde local.
	var recorde: Dictionary = HighScoreStore.registrar(resultado.total, resultado.rank, RunStats.tempo_s)
	# Fase com cutscene final (grupo "final_cutscene"): a tela de resultado só abre quando ela termina.
	if get_tree().has_group(FinalCutscene.GROUP):
		EventBus.cutscene_finished.connect(_abrir_tela_final.bind(resultado, recorde), CONNECT_ONE_SHOT)
		return
	# Sem cutscene: timer de jogo (respeita a pausa).
	var timer: SceneTreeTimer = CombatUtils.game_timer(self, _config.atraso_tela_final_s)
	if timer != null:  # Só se foi criado.
		timer.timeout.connect(_abrir_tela_final.bind(resultado, recorde))  # Abre a tela final com o resultado.


## Abre a tela final da run.
func _abrir_tela_final(resultado: ScoreResult, recorde: Dictionary) -> void:
	ResultScreen.abrir(self, resultado, recorde)  # Cria a tela.


## Abate: conta o tipo e a sequência (janela em tempo de jogo).
## Um inimigo morreu: conta o abate e a sequência (combo).
func _on_enemy_died(_enemy: Node2D, kind: StringName, _world_position: Vector2) -> void:
	RunStats.registrar_abate(kind, _config.janela_combo_s)  # Registra o abate.


## Dano efetivo causado a um inimigo (o HealthComponent já limita ao que sobrava de vida).
## Dano efetivo causado a um inimigo (o componente de vida já limita ao que sobrava).
func _on_enemy_damaged(_enemy: Node2D, _kind: StringName, amount: int, _current: int, _max: int) -> void:
	RunStats.registrar_dano_causado(float(amount))  # Soma o dano.


## Dano aplicado ao jogador (já depois de i-frames e escudo; inclui o dano do erro no quiz).
## Dano aplicado ao jogador (depois de i-frames e escudo; inclui o erro no quiz).
func _on_player_damaged(amount: int) -> void:
	RunStats.registrar_dano_tomado(float(amount))  # Soma o dano.


## Procura o quiz na cena do Player (Fase 2) e conta os acertos de primeira.
## Procura o quiz na cena do jogador (Fase 2) e passa a contar os acertos.
func _ligar_quiz() -> void:
	var player: Node = get_parent()  # Dono deste nó.
	if player == null:  # Sem jogador: nada a fazer.
		return
	# Raiz da cena do jogador.
	var raiz: Node = player.owner if player.owner != null else get_tree().current_scene
	if raiz == null:  # Sem cena: nada a fazer.
		return
	# Procura o quiz entre os descendentes.
	var achados: Array[Node] = CombatUtils.find_descendants(raiz, func(n: Node) -> bool: return n is QuizScreen)
	if achados.is_empty():  # Fase sem quiz.
		return
	_quiz = achados[0] as QuizScreen  # Guarda o quiz.
	CombatUtils.connect_once(_quiz.resposta_registrada, _on_quiz_resposta)  # Escuta cada resposta.


## Cada pergunta é feita uma vez, então todo acerto é "de primeira".
## Cada pergunta é feita uma vez, então todo acerto é "de primeira".
func _on_quiz_resposta(_indice: int, correta: bool, _motivo: StringName) -> void:
	if correta:  # Só os acertos contam.
		RunStats.registrar_acerto_quiz()  # Soma o acerto.
