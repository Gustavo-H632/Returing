extends Node
## Testes do relógio de jogo e dos contadores (RunStats / RunRecorder).
## Rodar: godot --headless --path . res://qa/clock_test.tscn  (cena: precisa dos autoloads)

# Jogador falso (só tem esta_morto e hp_maximo).
const _DEAD_STUB: GDScript = preload("res://qa/dead_player_stub.gd")

var _falhas: int = 0  # Verificações que falharam.
var _total: int = 0  # Total de verificações.


## Agenda o teste para o fim do quadro.
func _ready() -> void:
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Roda todos os testes do relógio e dos contadores e mostra o resultado.
func _rodar() -> void:
	_testar_formula()  # Fórmula do tempo contado.
	await _testar_relogio()  # Relógio com jogador real/falso.
	_testar_sequencia()  # Sequência de abates (combo).
	await _testar_ganchos()  # Ganchos do EventBus.
	_testar_sem_sinais_de_pontuacao()  # Garante que a pontuação não emite sinais.
	print("clock_test: %d verificações, %d falhas" % [_total, _falhas])  # Resultado.
	get_tree().quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.


## Confere uma condição e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1  # Mais uma verificação.
	if not condicao:  # Falhou.
		_falhas += 1  # Soma a falha.
		printerr("FALHOU: ", nome)  # Mostra o nome.


## Compara dois números com uma pequena margem.
func _perto(a: float, b: float, margem: float = 0.0001) -> bool:
	return absf(a - b) <= margem


## Testa a fórmula do tempo contado (quadro normal, travada cortada, câmera lenta e time_scale zero).
func _testar_formula() -> void:
	_confere(_perto(RunRecorder.segundos_contados(0.016, 1.0), 0.016), "delta normal")  # Quadro normal.
	# Travada cortada em 0,25 s.
	_confere(_perto(RunRecorder.segundos_contados(1.0, 1.0), 0.25), "travada cortada em 0,25 s")
	# Com câmera lenta conta tempo real.
	_confere(_perto(RunRecorder.segundos_contados(0.3 * 0.1, 0.3), 0.1), "time_scale 0,3 conta tempo real")
	# Time_scale zero não estoura.
	_confere(RunRecorder.segundos_contados(0.01, 0.0) > 0.0, "time_scale zero não estoura")


## Cria um "Player" falso (só precisa de esta_morto e hp_maximo) com o recorder como filho.
func _novo_jogador() -> Node:  # Jogador falso com script de teste.
	var jogador := Node.new()  # Cria o nó.
	jogador.set_script(_DEAD_STUB)  # Aplica o script.
	var recorder := RunRecorder.new()  # Cria o gravador de tempo.
	recorder.name = "RunRecorder"  # Nome fixo.
	jogador.add_child(recorder)  # Entra no jogador.
	get_tree().root.add_child(jogador)  # Entra na árvore.
	return jogador  # Devolve o jogador.


## Devolve o gravador de tempo do jogador falso.
func _recorder(jogador: Node) -> RunRecorder:
	return jogador.get_node("RunRecorder") as RunRecorder


## Roda `n` quadros e devolve quanto o tempo da run avançou.
## Roda `n` frames e devolve quanto o tempo avançou.
func _avancar_frames(n: int) -> float:
	var antes: float = RunStats.tempo_s  # Tempo antes.
	for i: int in n:  # Cada quadro.
		await get_tree().process_frame  # Espera um quadro.
	return RunStats.tempo_s - antes  # Quanto avançou.


## Testa o relógio: avança jogando, para pausado, morto, entre fases, após a run e conta em tempo real na câmera lenta.
func _testar_relogio() -> void:
	RunStats.reset()  # Run nova.
	var jogador: Node = _novo_jogador()  # Jogador falso.
	await get_tree().process_frame  # Espera um quadro.

	_confere(await _avancar_frames(5) > 0.0, "tempo avança jogando")  # Avança jogando.
	# Vida inicial lida.
	_confere(RunStats.vida_max_inicial_jogador == 100.0, "vida inicial lida do Player")

	get_tree().paused = true  # Pausa.
	_confere(_perto(await _avancar_frames(5), 0.0), "árvore pausada não conta")  # Pausado não conta.
	get_tree().paused = false  # Despausa.

	jogador.set(&"morto", true)  # Jogador morto.
	_confere(_perto(await _avancar_frames(5), 0.0), "Player em DEAD não conta")  # Morto não conta.
	jogador.set(&"morto", false)  # Vivo de novo.
	_confere(await _avancar_frames(5) > 0.0, "volta a contar com o Player vivo")  # Volta a contar.

	var antes_fase: float = RunStats.tempo_s  # Tempo antes de concluir a fase.
	EventBus.level_completed.emit("res://x.tscn")  # Conclui a fase.
	_confere(RunStats.tempos_por_fase.size() == 1, "tempo da fase registrado")  # Tempo da fase registrado.
	# Igual ao acumulado.
	_confere(_perto(RunStats.tempos_por_fase[0], antes_fase), "tempo da fase = tempo acumulado")
	# A transição entre fases não conta.
	_confere(_perto(await _avancar_frames(5), 0.0), "transição entre fases não conta")

	jogador.queue_free()  # Remove o jogador.
	await get_tree().process_frame  # Espera um quadro.

	# Recorder novo (próxima fase) e run finalizada.
	var jogador2: Node = _novo_jogador()  # Segundo jogador.
	await get_tree().process_frame  # Espera um quadro.
	_confere(await _avancar_frames(5) > 0.0, "nova fase volta a contar")  # Nova fase volta a contar.
	RunStats.finalizar()  # Finaliza a run.
	_confere(_perto(await _avancar_frames(5), 0.0), "run finalizada não conta")  # Run finalizada não conta.
	jogador2.queue_free()  # Remove o jogador.
	await get_tree().process_frame  # Espera um quadro.
	RunStats.reset()  # Zera.

	# Câmera lenta: 1 s real de jogo com time_scale 0,3 conta ~1 s.
	var jogador3: Node = _novo_jogador()  # Terceiro jogador.
	await get_tree().process_frame  # Espera um quadro.
	Engine.time_scale = 0.3  # Liga a câmera lenta.
	var inicio_ms: int = Time.get_ticks_msec()  # Hora de início.
	var antes: float = RunStats.tempo_s  # Tempo antes.
	while Time.get_ticks_msec() - inicio_ms < 1000:  # Espera 1 s real.
		await get_tree().process_frame  # Espera um quadro.
	var real_s: float = float(Time.get_ticks_msec() - inicio_ms) / 1000.0  # Tempo real medido.
	var contado: float = RunStats.tempo_s - antes  # Tempo contado.
	Engine.time_scale = 1.0  # Desliga a câmera lenta.
	# Compara contado e real.
	_confere(absf(contado - real_s) < 0.15, "time_scale 0,3: contado %.2f s vs real %.2f s" % [contado, real_s])
	jogador3.queue_free()  # Remove o jogador.
	await get_tree().process_frame  # Espera um quadro.


## Testa a sequência de abates (combo): continua dentro da janela e recomeça fora dela.
func _testar_sequencia() -> void:
	RunStats.reset()  # Run nova.
	RunStats.registrar_abate(&"a", 3.0)  # Primeiro abate.
	RunStats.tempo_s = 2.0  # Avança o relógio.
	RunStats.registrar_abate(&"a", 3.0)  # Segundo abate.
	RunStats.tempo_s = 5.0  # Avança o relógio.
	RunStats.registrar_abate(&"b", 3.0)  # exatamente 3,0 s depois: continua
	_confere(RunStats.maior_sequencia_abates == 3, "sequência continua dentro da janela")  # Sequência de 3.
	RunStats.tempo_s = 8.5  # Avança o relógio.
	RunStats.registrar_abate(&"b", 3.0)  # 3,5 s depois: recomeça
	# A maior continua 3.
	_confere(RunStats.maior_sequencia_abates == 3, "sequência recomeça fora da janela")
	_confere(int(RunStats.abates_por_tipo[&"b"]) == 2, "abates por tipo")  # Contagem por tipo.
	RunStats.reset()  # Zera.


## Eventos reais do EventBus chegam em RunStats (e o quiz da cena é encontrado).
## Testa que os eventos reais do EventBus chegam às estatísticas (e que o quiz da cena é encontrado).
func _testar_ganchos() -> void:
	RunStats.reset()  # Run nova.
	var conexoes_antes: int = EventBus.enemy_died.get_connections().size()  # Conexões antes do teste.
	# Quiz real.
	var quiz := (load("res://levels/Quiz/Quiz.tscn") as PackedScene).instantiate() as QuizScreen
	add_child(quiz)  # a cena de teste vira a "fase" onde o recorder procura o quiz
	var jogador: Node = _novo_jogador()  # Jogador falso.
	await get_tree().process_frame  # Espera um quadro.
	await get_tree().process_frame  # Espera mais um.
	var inimigo := Node2D.new()  # Inimigo falso.
	EventBus.enemy_died.emit(inimigo, &"drone", Vector2.ZERO)  # Dois drones morrem.
	EventBus.enemy_died.emit(inimigo, &"drone", Vector2.ZERO)
	EventBus.enemy_died.emit(inimigo, &"tank", Vector2.ZERO)  # Um tank morre.
	_confere(int(RunStats.abates_por_tipo[&"drone"]) == 2 and int(RunStats.abates_por_tipo[&"tank"]) == 1, "abates por tipo via EventBus")
	# Sequência de 3 abates.
	_confere(RunStats.maior_sequencia_abates == 3, "sequência via EventBus (mesmo frame)")
	EventBus.enemy_damaged.emit(inimigo, &"drone", 25, 15, 40)  # Dano causado em um drone.
	EventBus.enemy_damaged.emit(inimigo, &"drone", 15, 0, 40)
	_confere(_perto(RunStats.dano_causado, 40.0), "dano causado via EventBus")  # Soma do dano causado.
	EventBus.player_damaged.emit(7)  # Dano tomado pelo jogador.
	EventBus.player_damaged.emit(3)
	_confere(_perto(RunStats.dano_tomado, 10.0), "dano tomado via EventBus")  # Soma do dano tomado.
	quiz.resposta_registrada.emit(0, true, &"acerto")  # Quiz: acerta.
	quiz.resposta_registrada.emit(1, false, &"erro")  # Quiz: erra.
	quiz.resposta_registrada.emit(2, true, &"acerto")  # Quiz: acerta.
	_confere(RunStats.acertos_quiz == 2, "só acertos contam no quiz")  # Só os acertos contam.
	RunStats.finalizar()  # Finaliza a run.
	EventBus.enemy_died.emit(inimigo, &"drone", Vector2.ZERO)  # Depois de finalizar, nada mais conta.
	EventBus.player_damaged.emit(50)  # Mais dano.
	_confere(int(RunStats.abates_por_tipo[&"drone"]) == 2 and _perto(RunStats.dano_tomado, 10.0), "run finalizada não registra mais")
	inimigo.free()  # Libera o inimigo falso.
	jogador.queue_free()  # Remove o jogador.
	quiz.queue_free()  # Remove o quiz.
	await get_tree().process_frame  # Espera um quadro.
	# Os sinais foram desconectados.
	_confere(EventBus.enemy_died.get_connections().size() == conexoes_antes, "sinais desconectados na saída")
	RunStats.reset()  # Zera.


## Garante que as estatísticas da run não emitem sinais próprios (a pontuação só existe no fim).
func _testar_sem_sinais_de_pontuacao() -> void:
	var sinais: Array[Dictionary] = RunStats.new().get_signal_list()  # Sinais do objeto.
	var proprios: int = 0  # Contador de sinais próprios.
	for s: Dictionary in sinais:  # Cada sinal.
		if not ClassDB.class_has_signal("RefCounted", s["name"]):  # Só conta os que não vêm da classe base.
			proprios += 1  # Mais um próprio.
	_confere(proprios == 0, "RunStats não tem sinais próprios")  # Nenhum.
