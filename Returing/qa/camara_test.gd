extends Node
## Teste NO MOTOR da Câmara de Provas (Scenes/Fase5/Camara.tscn): cronograma, raio (hitbox + dash), dano mínimo da
## máquina (tiro x espada), portas, contadores e saída.
## Rodar: godot --headless --path . res://qa/camara_test.tscn      (sai com código 1 se algo falhar)

const FASE: String = "res://Scenes/Fase5/Camara.tscn"
const PROXIMA: String = "res://Scenes/Fase3/fase_3.tscn"  # Depois da Câmara vem a Fase 3.
const PROJETIL: PackedScene = preload("res://characters/turing/PlayerProjectile.tscn")
const TIME_SCALE: float = 2.0  # Acelera o jogo: com Engine.time_scale o `delta` da física também cresce.
const ORDEM_SALA3: Array[String] = ["T0", "RL", "B1", "B3", "LL", "T4", "LU", "B5", "T2", "RU"]
const REFORCADAS: Array[String] = ["B3", "LL"]
const HURT_R: float = 12.341887  # Raio da Hurtbox do Player (ela fica 1 px à direita e 2 abaixo do corpo).

var _falhas: int = 0
var _total: int = 0
var _fase: Camara = null
var _player: Player = null
var _relogio: float = 0.0  # Segundos de JOGO (soma dos `delta` da física, já com a escala de tempo).
var _log: Array[Dictionary] = []  # Transições de estado das máquinas: {t, nome, estado}.
var _ultimo: Dictionary[String, int] = {}  # Último estado visto de cada máquina.
var _danos: Array[float] = []  # Instantes (s) em que o Player tomou dano.
var _requisicoes: Array[String] = []  # Pedidos de troca de cena.


## Agenda o teste para depois da criação dos nós.
func _ready() -> void:
	_rodar.call_deferred()


## Instante atual em segundos de jogo.
func _agora() -> float:
	return _relogio


## Confere uma condição e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if condicao:
		print("OK:     ", nome)
	else:
		_falhas += 1
		printerr("FALHOU: ", nome)


## Espera `n` quadros de física.
func _fisica(n: int) -> void:
	for i: int in n:
		await get_tree().physics_frame


## Espera `segundos` de jogo.
func _espera(segundos: float) -> void:
	var alvo: float = _relogio + segundos
	while _relogio < alvo:
		await get_tree().physics_frame


## Soma o tempo de jogo e registra cada mudança de fase das máquinas (um quadro de resolução).
func _physics_process(delta: float) -> void:
	_relogio += delta
	if _fase == null:
		return
	for no: Node in get_tree().get_nodes_in_group(&"camara_maquina"):
		var m := no as CamaraMaquina
		var antes: int = _ultimo.get(String(m.name), -1)
		if int(m.estado) != antes:
			_ultimo[String(m.name)] = int(m.estado)
			_log.append({"t": _agora(), "nome": String(m.name), "estado": int(m.estado)})


## Instante da primeira vez que `nome` entrou em `estado` depois de `desde` (-1 se nunca).
func _quando(nome: String, estado: CamaraMaquina.Estado, desde: float = 0.0) -> float:
	for e: Dictionary in _log:
		if e["nome"] == nome and e["estado"] == int(estado) and float(e["t"]) >= desde - 0.001:
			return float(e["t"])
	return -1.0


## Abre a fase e deixa o Player invulnerável e parado.
func _abrir(com_abertura: bool = false) -> void:
	if _fase != null:
		_fase.queue_free()
		await _fisica(3)
	_log.clear()
	_ultimo.clear()
	_fase = (load(FASE) as PackedScene).instantiate() as Camara
	if not com_abertura:
		_fase.falas_abertura = PackedStringArray()  # os testes de jogo começam direto
	get_tree().root.add_child(_fase)
	get_tree().current_scene = _fase
	_relogio = 0.0
	await _fisica(3)
	_player = _fase.player
	_player.tomou_dano.connect(func(_q: int) -> void: _danos.append(_agora()))


## Para todos os cronogramas e apaga as máquinas.
func _parar_tudo() -> void:
	for s: CamaraSequenciador in [_fase.sala1, _fase.sala2, _fase.sala3]:
		s.parar()


## Põe o Player num ponto, com vida cheia e sem invulnerabilidade.
func _colocar(p: Vector2, invulneravel: bool) -> void:
	_player.remover_invulnerabilidade()
	_player.hp = _player.hp_maximo
	_player.global_position = p
	if invulneravel:
		_player.conceder_invulnerabilidade(1000.0)
	_danos.clear()


## Dispara `m` sozinha e devolve [início da varredura, primeiro dano (-1 se não houve), nº de danos].
func _provar_chegada(m: CamaraMaquina, ponto: Vector2, invulneravel: bool) -> Array:
	_parar_tudo()
	await _fisica(2)
	_colocar(ponto, invulneravel)
	await _fisica(2)
	_danos.clear()
	m.disparar()
	var t_disparo: float = _agora()
	await _espera(m.duracao_do_ciclo() - m.tempo_pausa + 0.1)
	var inicio: float = t_disparo + m.inicio_da_varredura()
	var primeiro: float = (_danos[0] - inicio) if not _danos.is_empty() else -1.0
	var n: int = _danos.size()
	m.parar()
	return [inicio, primeiro, n]


## Dispara um PlayerProjectile de `de` para `para` com `dano` e espera o tempo de voo.
func _atirar(de: Vector2, para: Vector2, dano: int, voo: float = 1.6) -> void:
	var tiro := PoolHub.acquire(PROJETIL, _player, PlayerProjectile) as PlayerProjectile
	tiro.launch(de, (para - de).normalized(), dano, 1.0, _player)
	await _espera(voo)


## Roda todos os testes e sai com código de erro se algo falhou.
func _rodar() -> void:
	Engine.time_scale = TIME_SCALE
	EventBus.scene_change_requested.disconnect(Global.change_scene)
	EventBus.scene_change_requested.connect(func(p: String) -> void: _requisicoes.append(p))
	await _abertura()
	await _abrir()
	await _estrutura()
	await _sala1()
	await _chegadas()
	await _dano_da_maquina()
	await _sala3_sequencia()
	await _sala3_destruicao()
	_fase.queue_free()
	await _fisica(3)
	Engine.time_scale = 1.0
	print("camara_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


# --- 0) Abertura: tela preta + voz do tutorial (texto azul), sem cutscene ---

func _abertura() -> void:
	await _abrir(true)
	_confere(_fase.falas_abertura.size() >= 2, "a abertura tem falas do homem misterioso")
	var dialogo: Dialogue = null
	for filho: Node in _fase.get_children():
		if filho is Dialogue:
			dialogo = filho as Dialogue
	_confere(dialogo != null and dialogo.style == Dialogue.Style.VOICE, "abertura usa o estilo VOICE (voz azul do tutorial)")
	_confere(not _fase.find_children("*", "ColorRect", true, false).is_empty(), "tela preta cobrindo a fase")
	_confere(_fase.sala_atual == 0 and not _player.is_physics_processing(),
			"durante as falas: nada liga e o Player fica parado (sala %d, física %s)" % [_fase.sala_atual, _player.is_physics_processing()])
	_confere(_fase.find_children("*", "Cutscene*", true, false).is_empty() and dialogo.speaker == "" and dialogo.backdrop == null,
			"sem caixa, nome nem ilustração (não é cutscene)")
	await _espera(2.0)
	_confere(_fase.sala1.maquinas()[0].estado == CamaraMaquina.Estado.INATIVA, "nenhuma máquina dispara durante as falas")
	dialogo.stop()
	await _fisica(3)
	_confere(_fase.sala_atual == 1 and _player.is_physics_processing() and _fase.sala1.ativo,
			"depois das falas: a Sala 1 liga e o Player volta a andar")


# --- 1) Estrutura da cena ---

func _estrutura() -> void:
	_confere(_fase is Camara, "a raiz é a Camara")
	_confere(_fase.find_children("*", "TileMapLayer", true, false).is_empty()
			and _fase.find_children("*", "TileMap", true, false).is_empty(), "sem TileMap/TileMapLayer")
	var todas: Array[Node] = get_tree().get_nodes_in_group(&"camara_maquina")
	_confere(todas.size() == 13, "13 máquinas (2 + 1 + 10), achei %d" % todas.size())
	var nomes: Array[String] = []
	for m: CamaraMaquina in _fase.sala3.maquinas():
		nomes.append(String(m.name))
	_confere(nomes == ORDEM_SALA3, "ordem de disparo da Sala 3 = %s" % str(nomes))
	var ref: Array[String] = []
	var destrutiveis: int = 0
	for m: CamaraMaquina in _fase.sala3.maquinas():
		if m.destrutivel:
			destrutiveis += 1
		if m.reforcada:
			ref.append(String(m.name))
	_confere(destrutiveis == 10, "10 máquinas destrutíveis na Sala 3")
	_confere(ref == ["B3", "LL"], "2 reforçadas (%s)" % str(ref))
	for m: CamaraMaquina in _fase.sala1.maquinas():
		_confere(not m.destrutivel and m.hurtbox == null, "%s é decoração indestrutível (sem Hurtbox)" % m.name)
	_confere(_fase.sala2.maquinas().size() == 1, "Sala 2 tem 1 máquina destrutível")
	_confere(is_equal_approx(_fase.sala3.intervalo_disparos, 2.4), "intervalo da Sala 3 = 2,4 s")
	_confere(ResourceLoader.exists(_fase.next_scene) and _fase.next_scene == PROXIMA, "next_scene aponta para a Fase 3")
	# A Hurtbox da máquina só é lida pelo tiro (camada 1); a espada lê só a camada 5.
	var espada := _player.weapon as Sword
	var h: Hurtbox = _fase.sala2.maquinas()[0].hurtbox
	_confere((h.collision_layer & espada.hitbox.collision_mask) == 0, "a espada NÃO enxerga a Hurtbox da máquina")
	_confere((h.collision_layer & PROJETIL.instantiate().collision_mask) != 0, "o tiro enxerga a Hurtbox da máquina")
	_confere(is_equal_approx(_player.dash_speed, 560.0) and is_equal_approx(_player.dash_duration, 0.3)
			and is_equal_approx(_player.dash_cooldown, 1.0) and is_equal_approx(_player.iframes_duration, 0.34),
			"Player: dash 560 x 0,30 s, recarga 1,0 s, iframes 0,34 s")
	_confere(is_equal_approx(_player.charge_time, 1.2) and is_equal_approx(_player.charge_move_multiplier, 0.4),
			"Player: carga 1,2 s a 40 %")
	_confere(_fase.porta1.esta_aberta and not _fase.porta2.esta_aberta and not _fase.porta_final.esta_aberta,
			"porta 1 aberta; porta 2 e final trancadas")
	_confere(_fase.porta_final.contador.text == "10" and _fase.porta2.contador.text == "1", "contadores das portas: 1 e 10")


# --- 2) Sala 1: cronograma fixo (2 máquinas, ciclo de 10 s) ---

func _sala1() -> void:
	_player.conceder_invulnerabilidade(1000.0)
	await _espera(14.0)
	var a: float = _quando("M1A", CamaraMaquina.Estado.AVISO)
	var b: float = _quando("M1B", CamaraMaquina.Estado.AVISO)
	_confere(absf(a - 3.0) < 0.1, "Sala 1: M1A avisa em 3,0 s (achei %.2f)" % a)
	_confere(absf(b - 8.0) < 0.1, "Sala 1: M1B avisa 5,0 s depois (achei %.2f)" % b)
	var v: float = _quando("M1A", CamaraMaquina.Estado.VARREDURA)
	var c: float = _quando("M1A", CamaraMaquina.Estado.CLARAO)
	var p: float = _quando("M1A", CamaraMaquina.Estado.PAUSA)
	_confere(absf(c - a - 1.0) < 0.06 and absf(v - a - 1.4) < 0.06 and absf(p - a - 3.4) < 0.06,
			"Sala 1: aviso 1,0 s, clarão 0,4 s, varredura 2,0 s")
	_confere(absf(_quando("M1A", CamaraMaquina.Estado.AVISO, a + 1.0) - (a + 10.0)) < 0.1,
			"Sala 1: M1A repete a cada 10,0 s")
	_confere(_player.hp == _player.hp_maximo, "Sala 1: Player invulnerável no dash não perdeu vida")


# --- 3) A linha fere no instante previsto (e o dash recusa o dano) ---

func _chegadas() -> void:
	# (máquina, ponto, instante previsto do 1º contato desde o início da varredura, em s)
	# Hurtbox do Player = círculo r 12,34 em (x + 1, y + 2); a linha tem 5 px de meia espessura.
	var casos: Array = [
		["M1A", Vector2(300, 64), (300.0 + 1.0 - 17.34 - 16.0) / 360.0],            # corredor, varre para leste
		["M1B", Vector2(500, 64), (736.0 - (500.0 + 1.0) - 17.34) / 360.0],         # corredor, varre para oeste
		["M2", Vector2(400, 450), (450.0 + 2.0 - 17.34 - 304.0) / 144.0],           # sala 2, varre para baixo
		["T2", Vector2(1346, 400), (400.0 + 2.0 - 17.34 - 212.0) / 236.0],          # sala 3, de cima para baixo
		["B1", Vector2(1174, 500), (684.0 - (500.0 + 2.0) - 17.34) / 236.0],        # sala 3, de baixo para cima
		["LU", Vector2(1200, 330), (1200.0 + 1.0 - 17.34 - 916.0) / 258.0],         # sala 3, da esquerda
		["RL", Vector2(1700, 566), (1948.0 - (1700.0 + 1.0) - 17.34) / 258.0],      # sala 3, da direita
	]
	for caso: Array in casos:
		var m: CamaraMaquina = _achar(String(caso[0]))
		var r: Array = await _provar_chegada(m, caso[1] as Vector2, false)
		var previsto: float = float(caso[2])
		_confere(float(r[1]) >= 0.0 and absf(float(r[1]) - previsto) < 0.08,
				"%s fere em %.2f s depois do início da varredura (previsto %.2f)" % [caso[0], float(r[1]), previsto])
		var r2: Array = await _provar_chegada(m, caso[1] as Vector2, true)
		_confere(int(r2[2]) == 0, "%s: com iframes (dash) nenhum dano" % caso[0])
	_colocar(Vector2(96, 64), true)


# --- 4) Dano mínimo: tiro fraco e espada ignorados, tiro carregado destrói ---

func _dano_da_maquina() -> void:
	_parar_tudo()
	var m: CamaraMaquina = _achar("M2")
	var rebatidos: Array[int] = []
	var mortas: Array[int] = [0]
	m.rebatida.connect(func(_mm: CamaraMaquina, d: int) -> void: rebatidos.append(d))
	m.destruida.connect(func(_mm: CamaraMaquina) -> void: mortas[0] += 1)
	_confere(not m.take_damage(39), "dano 39 é rebatido")
	_confere(m.corpo.frame == CamaraMaquina.QUADRO_BLINDADA, "quadro BLINDADA com faísca")
	_confere(not m.is_dead() and rebatidos == [39], "a máquina segue de pé")
	# tiro de verdade pela física: dano 30 (fraco) vindo de baixo
	var alvo: Vector2 = m.alvo_global()
	_colocar(Vector2(alvo.x, 560.0), true)
	await _atirar(Vector2(alvo.x, 540.0), alvo, 30)
	_confere(not m.is_dead() and rebatidos.size() == 2 and rebatidos[1] == 30,
			"tiro fraco (30) rebatido pela física, sem destruir")
	# espada: ataca encostada na máquina e não faz nada
	_colocar(Vector2(alvo.x, alvo.y + 44.0), true)
	await _fisica(3)
	(_player.weapon as Sword).attack(Vector2.UP)
	await _espera(0.6)
	_confere(not m.is_dead() and rebatidos.size() == 2, "espada (50 de dano) ignorada: nem chega a enxergar a máquina")
	# tiro carregado (>= 40) destrói
	await _atirar(Vector2(alvo.x, 540.0), alvo, 40)
	_confere(m.is_dead() and mortas[0] == 1, "tiro com dano 40 destrói a máquina")
	_confere(m.segmento_global().size == Vector2.ZERO and not m.feixe.is_active(), "máquina destruída para de emitir")
	_confere(m.corpo.frame == CamaraMaquina.QUADRO_DESTRUIDA, "carcaça no quadro DESTRUÍDA")
	await _espera(0.7)
	_confere(not m.explosao.visible, "explosão termina e some")
	_confere(_fase.porta2.esta_aberta and _fase.porta2.contador.text == "0", "porta 2 abriu e o contador chegou a 0")
	await _fisica(2)
	_confere(_fase.porta2.colisao.disabled, "colisão da porta 2 desligada")
	_confere(not m.disparar(), "máquina destruída não dispara mais")


# --- 5) Sala 3: sequência fixa de disparos, uma de cada vez ---

func _sala3_sequencia() -> void:
	var antes: float = _agora()
	_fase.entrada3.body_entered.emit(_player)
	_player.conceder_invulnerabilidade(1000.0)
	await _espera(3.6 + 24.0 * 1.0 + 1.0)
	_confere(_fase.sala_atual == 3 and _fase.sala3.ativo, "entrar na Sala 3 liga o cronograma dela")
	var base: float = antes + 3.5
	var ok_ordem: bool = true
	var ok_um: bool = true
	for i: int in ORDEM_SALA3.size():
		var t: float = _quando(ORDEM_SALA3[i], CamaraMaquina.Estado.AVISO, antes)
		if absf(t - (base + i * 2.4)) > 0.1:
			ok_ordem = false
			printerr("  vaga %d (%s): avisou em %.2f, previsto %.2f" % [i, ORDEM_SALA3[i], t, base + i * 2.4])
	_confere(ok_ordem, "Sala 3: 10 máquinas avisam na ordem fixa, de 2,4 em 2,4 s")
	# uma de cada vez: nunca duas em AVISO ao mesmo tempo (aviso 1,0 s < intervalo 2,4 s)
	var avisos: Array[Dictionary] = []
	for e: Dictionary in _log:
		if e["estado"] == int(CamaraMaquina.Estado.AVISO) and float(e["t"]) >= antes:
			avisos.append(e)
	for i: int in range(1, avisos.size()):
		if float(avisos[i]["t"]) - float(avisos[i - 1]["t"]) < 2.3:
			ok_um = false
	_confere(ok_um, "Sala 3: avisos nunca se sobrepõem (uma de cada vez)")
	var ciclo: float = _quando("T0", CamaraMaquina.Estado.AVISO, base + 1.0)
	_confere(absf(ciclo - (base + 24.0)) < 0.1, "Sala 3: o ciclo repete (T0 de novo em %.2f, previsto %.2f)" % [ciclo, base + 24.0])


# --- 6) Sala 3: destruir tira a máquina da sequência; 2 reforçadas; 10 abrem a porta final ---

func _sala3_destruicao() -> void:
	var ms: Array[CamaraMaquina] = _fase.sala3.maquinas()
	var mortas: Array[int] = [0]
	for m: CamaraMaquina in ms:
		m.destruida.connect(func(_x: CamaraMaquina) -> void: mortas[0] += 1)
	var t0: CamaraMaquina = _achar("T0")
	t0.take_damage(68)
	_confere(t0.is_dead() and _fase.hud.maquinas.text == "Máquinas 1/10", "HUD: Máquinas 1/10")
	_confere(_fase.porta_final.contador.text == "9" and not _fase.porta_final.esta_aberta, "porta final: faltam 9")
	# a vaga de T0 fica vazia e as outras mantêm seus instantes
	var corte: float = _agora()
	await _espera(26.0)
	_confere(_quando("T0", CamaraMaquina.Estado.AVISO, corte) < 0.0, "T0 destruída saiu da sequência")
	var rl: float = _quando("RL", CamaraMaquina.Estado.AVISO, corte)
	var rl_depois: float = _quando("RL", CamaraMaquina.Estado.AVISO, rl + 1.0)
	_confere(absf(rl_depois - rl - 24.0) < 0.1, "as outras mantêm o ciclo de 24 s (RL: %.2f -> %.2f)" % [rl, rl_depois])
	# reforçadas: 1 tiro não basta
	var b3: CamaraMaquina = _achar("B3")
	b3.take_damage(68)
	_confere(not b3.is_dead() and _fase.hud.maquinas.text == "Máquinas 1/10", "reforçada B3 aguenta o 1º tiro")
	b3.take_damage(68)
	_confere(b3.is_dead() and _fase.hud.maquinas.text == "Máquinas 2/10", "reforçada B3 cai no 2º tiro")
	var restantes: Array[CamaraMaquina] = []
	for m: CamaraMaquina in ms:
		if not m.is_dead():
			restantes.append(m)
	# a saída ainda não funciona com a porta final trancada
	_requisicoes.clear()
	_fase.saida.body_entered.emit(_player)
	_confere(_requisicoes.is_empty(), "saída ignorada com a porta final trancada")
	for m: CamaraMaquina in restantes:
		m.take_damage(68)
		if m.reforcada and not m.is_dead():
			m.take_damage(68)
	_confere(mortas[0] == 10, "10 máquinas destruídas (contei %d)" % mortas[0])
	_confere(_fase.porta_final.esta_aberta and _fase.hud.maquinas.text == "Máquinas 10/10", "porta final abriu: Máquinas 10/10")
	_confere(not _fase.sala3.ativo, "cronograma da Sala 3 parou")
	await _fisica(2)
	_confere(_fase.porta_final.colisao.disabled, "colisão da porta final desligada")
	_fase.saida.body_entered.emit(_player)
	await _fisica(2)
	_confere(_requisicoes == [PROXIMA], "saída pede a próxima cena (%s)" % str(_requisicoes))


## Máquina da fase pelo nome.
func _achar(nome: String) -> CamaraMaquina:
	for no: Node in get_tree().get_nodes_in_group(&"camara_maquina"):
		if String(no.name) == nome:
			return no as CamaraMaquina
	return null
