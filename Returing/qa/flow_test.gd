extends Node
## Teste de integração com as fases reais: o Player nasce com o RunRecorder, o tempo corre,
## a run reseta no início, a troca de fase não zera e a última fase abre a tela final.
## Rodar: godot --headless --path . res://qa/flow_test.tscn

const FASE_1: String = "res://Scenes/Fase1/fase_1.tscn"  # Fase 1.
const FASE_3: String = "res://Scenes/Fase3/fase_3.tscn"  # Fase 3 (última).
# Arquivo temporário de recorde (para não mexer no do jogador).
const ARQUIVO_TESTE: String = "user://returing_recordes_fluxo_teste.cfg"

var _falhas: int = 0  # Verificações que falharam.
var _total: int = 0  # Total de verificações.
var _fase: Node = null  # Fase aberta agora.


## Troca o arquivo de recorde para um temporário e agenda o teste.
func _ready() -> void:
	HighScoreStore.caminho = ARQUIVO_TESTE  # Não mexe no recorde real.
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Confere uma condição e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1  # Mais uma verificação.
	if not condicao:  # Falhou.
		_falhas += 1  # Soma a falha.
		printerr("FALHOU: ", nome)  # Mostra o nome.


## Espera `n` quadros.
func _frames(n: int) -> void:
	for i: int in n:  # Cada quadro.
		await get_tree().process_frame  # Espera um quadro.


## Abre uma fase real (removendo a anterior) e espera ela ficar pronta.
func _abrir_fase(caminho: String) -> void:
	if _fase != null:  # Já havia uma fase.
		_fase.queue_free()  # Remove a antiga.
		await _frames(3)  # Espera a remoção.
	_fase = (load(caminho) as PackedScene).instantiate()  # Cria a fase.
	get_tree().root.add_child(_fase)  # Entra na árvore.
	get_tree().current_scene = _fase  # É a cena atual.
	await _frames(15)  # Espera 15 quadros.


## Devolve o gravador de tempo do jogador da fase atual.
func _recorder() -> RunRecorder:
	var player: Node = _fase.find_child("Player", true, false)  # Procura o jogador.
	# Gravador (ou null).
	return player.get_node_or_null("RunRecorder") as RunRecorder if player != null else null


## Devolve a tela final da fase atual (ou null).
func _tela() -> ResultScreen:
	for filho: Node in _fase.get_children():  # Procura entre os filhos.
		if filho is ResultScreen:  # É a tela final.
			return filho  # Devolve.
	return null  # Não há.


## Roda o fluxo: início de run na Fase 1, troca de fase sem zerar e fim de run na Fase 3 com a tela final.
func _rodar() -> void:
	# --- Fase 1: início de run ---
	RunStats.tempo_s = 123.0  # Valores antigos para provar que a run zera.
	RunStats.abates_por_tipo = {&"lixo": 9}  # Abates antigos.
	await _abrir_fase(FASE_1)  # Abre a Fase 1.
	# O jogador nasce com o gravador.
	_confere(_recorder() != null, "Fase 1: o Player nasce com o RunRecorder")
	# A run começa zerada.
	_confere(RunStats.tempo_s < 5.0 and RunStats.abates_por_tipo.is_empty(), "Fase 1: a run começa zerada (RunState.reset)")
	await _frames(30)  # Espera 30 quadros.
	_confere(RunStats.tempo_s > 0.0, "Fase 1: o relógio corre jogando")  # O relógio corre.
	# Vida inicial lida.
	_confere(RunStats.vida_max_inicial_jogador == 100.0, "Fase 1: vida inicial lida do Player real")

	# Abate real pelo EventBus enquanto joga.
	EventBus.enemy_died.emit(_fase, &"drone", Vector2.ZERO)  # Um drone morre.
	_confere(int(RunStats.abates_por_tipo.get(&"drone", 0)) == 1, "Fase 1: abate registrado")  # Registrado.

	# --- Fase 1 concluída: a troca de fase NÃO zera a run ---
	var tempo_antes: float = RunStats.tempo_s  # Tempo antes.
	EventBus.level_completed.emit("res://Scenes/Fase2/Fase2.tscn")  # Conclui a fase.
	# Tempo da fase registrado.
	_confere(RunStats.tempos_por_fase.size() == 1, "Fase 1 concluída: tempo da fase registrado")
	# Ainda não finaliza nem abre a tela.
	_confere(not RunStats.finalizada and _tela() == null, "Fase 1 concluída: ainda não finaliza nem abre a tela")
	await _frames(20)  # Espera 20 quadros.
	# O intervalo até a próxima fase não conta.
	_confere(is_equal_approx(RunStats.tempo_s, tempo_antes), "Fase 1 concluída: o intervalo até a próxima fase não conta")

	# --- Fase 3 (última): mesma run, sem reset, e a tela final abre ---
	await _abrir_fase(FASE_3)  # Abre a Fase 3.
	# A run continua.
	_confere(RunStats.tempos_por_fase.size() == 1 and int(RunStats.abates_por_tipo.get(&"drone", 0)) == 1,
			"Fase 3: a run continua (sem reset na troca de fase)")
	await _frames(20)  # Espera 20 quadros.
	# O relógio continua somando.
	_confere(RunStats.tempo_s > tempo_antes, "Fase 3: o relógio continua somando")
	var recorder: RunRecorder = _recorder()  # Gravador.
	# O jogador nasce com o gravador.
	_confere(recorder != null, "Fase 3: o Player nasce com o RunRecorder")
	recorder._config.atraso_tela_final_s = 0.2  # Atraso curto da tela final.
	EventBus.level_completed.emit("")  # Conclui a última fase.
	_confere(RunStats.finalizada, "Fase 3: a run foi finalizada")  # Run finalizada.
	# Tempo da fase registrado.
	_confere(RunStats.tempos_por_fase.size() == 2, "Fase 3: tempo da fase registrado")
	await get_tree().create_timer(0.6, true, false, true).timeout  # Passou o atraso antigo da tela final.
	# A Fase 3 tem cutscene final: a tela de resultado só abre quando ela termina.
	_confere(_tela() == null, "Fase 3: a tela final espera a cutscene final")
	EventBus.cutscene_finished.emit()  # Simula o fim da cutscene final.
	await _frames(3)  # Espera 3 quadros.
	var tela: ResultScreen = _tela()  # Tela final.
	_confere(tela != null, "Fase 3: a tela final abriu")  # A tela abriu.
	_confere(get_tree().paused, "Tela final: árvore pausada")  # A árvore está pausada.
	_confere(not HighScoreStore.carregar().is_empty(), "Tela final: recorde salvo")  # O recorde foi salvo.
	if tela != null:  # Há tela.
		# O total bate com o cálculo da run.
		_confere(tela.resultado.total == ScoreCalculator.calcular(RunStats.capturar(), recorder._config).total,
				"Tela final: total bate com o cálculo da run")

	# Nada mais é contado depois de finalizar.
	var tempo_final: float = RunStats.tempo_s  # Tempo final.
	await _frames(10)  # Espera 10 quadros.
	# O tempo não anda.
	_confere(is_equal_approx(RunStats.tempo_s, tempo_final), "Depois da run finalizada o tempo não anda")

	# Run nova: o reset volta ao estado inicial.
	RunState.reset()  # Reseta.
	# Tudo zerado.
	_confere(not RunStats.finalizada and RunStats.tempo_s == 0.0 and RunStats.tempos_por_fase.is_empty(),
			"RunState.reset zera a run (nova run)")

	if tela != null:  # Limpeza.
		tela.queue_free()  # Remove a tela final.
		await _frames(2)  # Espera.
	if FileAccess.file_exists(ARQUIVO_TESTE):  # Apaga o arquivo temporário.
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ARQUIVO_TESTE))  # Apaga.
	_fase.queue_free()  # Remove a fase.
	await _frames(3)  # Espera.
	print("flow_test: %d verificações, %d falhas" % [_total, _falhas])  # Resultado.
	get_tree().quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.
