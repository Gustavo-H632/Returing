extends Node
## Modo comando (Ctrl, setas, Enter) num fluxo de jogo real, sem atalhos: ondas de verdade, XP de verdade, menu de
## level-up respondido pelo teclado, habilidade aprendida pelo menu e Ctrl em cada fase.
## Rodar: godot --headless --path . res://qa/ctrl_real_test.tscn   (leva ~20 s)

const FASES: Array[String] = [  # As três fases do jogo.
	"res://Scenes/Fase1/fase_1.tscn",
	"res://Scenes/Fase2/Fase2.tscn",
	"res://Scenes/Fase3/fase_3.tscn",
]
## Direção da seta -> tecla (AbilityData.Dir: UP, DOWN, LEFT, RIGHT).
const TECLAS_SETA: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

var _falhas: int = 0  # Verificações que falharam.
var _total: int = 0  # Total de verificações.
var _fase: Node = null  # Fase aberta agora.
var _player: Player = null  # Jogador da fase.
var _hab: AbilityComponent = null  # Componente de habilidades.
var _ativadas: Array[StringName] = []  # Habilidades ativadas durante o teste.


## Agenda o teste para o fim do quadro.
func _ready() -> void:
	_rodar.call_deferred()


## Confere uma condição, mostra o resultado e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	print(("  ok    " if condicao else "  FALHA ") + nome)
	if not condicao:
		_falhas += 1


## Espera `n` quadros.
func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## Espera `s` segundos em tempo real (o timer ignora a câmera lenta e a pausa).
func _segundos(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Simula apertar ou soltar uma tecla (com Ctrl e lado do teclado opcionais).
func _tecla(keycode: Key, apertada: bool, ctrl: bool = false, lado: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = apertada
	ev.ctrl_pressed = ctrl
	ev.location = lado
	Input.parse_input_event(ev)


## Simula apertar e soltar uma ação do Input Map, com dois quadros de cada.
func _acao(nome: StringName) -> void:
	var ev := InputEventAction.new()  # Evento de apertar.
	ev.action = nome
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(2)
	ev = InputEventAction.new()  # Espera.
	ev.action = nome  # Evento de soltar.
	ev.pressed = false
	Input.parse_input_event(ev)
	await _frames(2)  # Espera.


## Abre uma fase real (removendo a anterior) e liga o teste ao jogador e ao componente de habilidades.
func _abrir_fase(caminho: String) -> void:
	if _fase != null:
		_fase.queue_free()
		await _frames(4)
	_fase = (load(caminho) as PackedScene).instantiate()
	get_tree().root.add_child(_fase)
	get_tree().current_scene = _fase
	await _frames(20)
	_player = _fase.find_child("Player", true, false) as Player  # Jogador.
	_hab = _player.get_node("AbilityComponent") as AbilityComponent  # Componente de habilidades.
	_ativadas.clear()  # Esquece as ativações da fase anterior.
	# Guarda cada ativação.
	_hab.ability_activated.connect(func(d: AbilityData) -> void: _ativadas.append(d.id))


## Mata todos os inimigos da cena com dano enorme e devolve quantos morreram.
func _matar_inimigos() -> int:
	var mortos: int = 0  # Contador.
	for inimigo: Node in get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY):  # Cada inimigo.
		if CombatUtils.apply_damage(inimigo, 99999, _player):  # Dano enorme.
			mortos += 1
	return mortos


## Usa o modo comando como o jogador: Ctrl, sequência da habilidade e Enter. `em_recarga` não zera a recarga (a sequência deve ser recusada) e `andando` testa com o jogador em movimento.
## Usa o modo comando como o jogador: aperta Ctrl, digita a sequência da habilidade e confirma com Enter.
## `em_recarga` = não zera a recarga: a sequência deve ser recusada (comportamento do jogo, 20 s).
func _usar_habilidade(rotulo: String, andando: bool, em_recarga: bool = false) -> void:
	var data: AbilityData = _hab.abilities[0]  # Habilidade testada.
	_ativadas.clear()  # Esquece as ativações.
	var recusas: Array[int] = [0]  # Conta as recusas.
	var contar: Callable = func() -> void: recusas[0] += 1  # Cada recusa soma um.
	_hab.input_failed.connect(contar)  # Escuta as recusas.
	if not em_recarga:  # Fora do caso "em recarga".
		_hab._cooldowns.clear()  # cada uso do teste começa com a habilidade pronta
	if andando:  # Com o jogador andando.
		_tecla(KEY_D, true)  # Aperta D.
		await _frames(12)
		_confere(_player.state == Player.State.MOVE, rotulo + ": Player andando (MOVE)")  # Está andando.
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)  # Aperta Ctrl.
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)  # Solta Ctrl.
	await _frames(3)
	_confere(_hab.command_active, rotulo + ": Ctrl abre o modo comando")  # O modo abriu.
	for dir: int in data.sequence:  # Digita cada seta da sequência.
		_tecla(TECLAS_SETA[dir], true)
		await _frames(2)
		_tecla(TECLAS_SETA[dir], false)
		await _frames(2)
	_confere(not _ativadas.has(data.id), rotulo + ": sem Enter não ativa")  # Sem Enter não ativa.
	_tecla(KEY_ENTER, true)  # Enter.
	await _frames(2)
	_tecla(KEY_ENTER, false)  # Solta Enter.
	await _frames(2)
	if em_recarga:  # Em recarga: a sequência é recusada.
		_confere(not _ativadas.has(data.id) and recusas[0] > 0, rotulo + ": em recarga a sequência é recusada")
	else:  # Fora da recarga: ativou.
		_confere(_ativadas.has(data.id), rotulo + ": sequência ativou '%s'" % data.id)
		# A recarga começou.
		_confere(_hab.get_cooldown_left(data.id) > 0.0, rotulo + ": recarga iniciada (%.0f s)" % _hab.get_cooldown_left(data.id))
	_hab.input_failed.disconnect(contar)  # Para de escutar.
	if em_recarga:  # erro mantém o modo aberto: cancela com o Ctrl
		_confere(_hab.command_active, rotulo + ": erro mantém o modo aberto")
		_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)
		await _frames(3)
		_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(5)  # Espera.
	_confere(not _hab.command_active, rotulo + ": modo fechado ao final")  # O modo fechou.
	# O tempo voltou ao normal.
	_confere(is_equal_approx(Engine.time_scale, 1.0), rotulo + ": tempo normal")
	if andando:  # Solta D.
		_tecla(KEY_D, false)
		await _frames(3)


## Roda o fluxo real: sem habilidades, ondas e XP até o nível 1, menu de level-up pelo teclado, uso da habilidade em várias situações e herança da run nas outras fases.
func _rodar() -> void:
	RunState.reset()  # run nova, como ao iniciar o jogo
	await _abrir_fase(FASES[0])  # Abre a Fase 1.
	print("== Fase 1 ==")
	_confere(_hab.abilities.is_empty(), "início da run: sem habilidades")  # Início da run: sem habilidades.
	_player.conceder_invulnerabilidade(9999.0)  # Jogador invulnerável.

	# Sem habilidade o Ctrl só avisa.
	var avisos: Array[StringName] = []  # Avisos emitidos.
	_hab.command_unavailable.connect(func(m: StringName) -> void: avisos.append(m))  # Guarda cada aviso.
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)  # Aperta Ctrl.
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)  # Solta Ctrl.
	await _frames(3)
	# O modo não abriu e houve aviso.
	_confere(not _hab.command_active and avisos.has(&"sem_habilidades"), "sem habilidades: Ctrl só avisa")

	# Joga de verdade: as ondas nascem sozinhas e cada abate dá XP, até o nível 1.
	var mortos: int = 0  # Abates.
	var inicio_ms: int = Time.get_ticks_msec()  # Hora de início.
	# Até o nível 1 (limite de 40 s).
	while RunState.level < 1 and Time.get_ticks_msec() - inicio_ms < 40000:
		mortos += _matar_inimigos()  # Mata os inimigos.
		await _frames(5)  # Espera.
	# Chegou ao nível 1.
	_confere(RunState.level >= 1, "ondas reais deram XP até o nível 1 (%d abates, xp %d)" % [mortos, RunState.xp])

	# Menu de level-up: abre sozinho com o jogo livre, pausa a árvore, escolhe-se com o teclado.
	var menu: LevelUpMenu = null  # Menu.
	inicio_ms = Time.get_ticks_msec()  # Hora de início.
	while Time.get_ticks_msec() - inicio_ms < 5000:  # Espera até 5 s.
		menu = _player.find_child("LevelUpMenu", true, false) as LevelUpMenu  # Procura o menu.
		if menu != null and menu.is_open():  # Abriu.
			break
		await _frames(2)  # Espera.
	_confere(menu != null and menu.is_open(), "menu de level-up abriu sozinho")  # O menu abriu sozinho.
	_confere(get_tree().paused, "menu pausa o jogo")  # Pausou o jogo.
	# Ctrl com o menu aberto não pode abrir o modo comando.
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)  # Aperta Ctrl.
	await _frames(3)
	_confere(not _hab.command_active, "menu aberto: Ctrl não abre o modo comando")  # Não abriu.
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)  # Solta Ctrl.
	await _frames(2)
	await _segundos(menu.input_delay + 0.2)  # Espera o atraso de entrada do menu.
	for tentativa: int in 4:  # Até 4 tentativas.
		if not menu.is_open():  # Menu fechou.
			break  # Sai do laço.
		await _acao(&"ui_accept")  # carta focada; se for lendária, confirma
		await _segundos(0.3)  # Espera.
	# O jogo voltou.
	_confere(not menu.is_open() and not get_tree().paused, "carta escolhida pelo teclado; o jogo volta a rodar")
	# A habilidade foi aprendida.
	_confere(_hab.abilities.size() == 1, "habilidade aprendida pelo menu: %s" % [_hab.abilities.map(func(a: AbilityData) -> StringName: return a.id)])
	if _hab.abilities.is_empty():  # Sem habilidade não há o que testar.
		_fim()  # Termina.
		return  # Sai.
	_player.conceder_invulnerabilidade(9999.0)  # Jogador invulnerável.

	await _usar_habilidade("Fase 1 parado", false)  # Usa a habilidade parado.
	await _usar_habilidade("Fase 1 em recarga", false, true)  # Usa com a habilidade em recarga.
	await _usar_habilidade("Fase 1 andando", true)  # Usa andando.

	# Com inimigos vivos em volta.
	inicio_ms = Time.get_ticks_msec()  # Hora de início.
	# Espera aparecerem inimigos.
	while get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY).is_empty() and Time.get_ticks_msec() - inicio_ms < 8000:
		await _frames(5)
	# Há inimigos vivos.
	_confere(not get_tree().get_nodes_in_group(CombatUtils.GROUP_ENEMY).is_empty(), "há inimigos vivos na fase")
	await _usar_habilidade("Fase 1 com inimigos", false)  # Usa com inimigos.

	# As outras fases herdam a run (habilidades restauradas pelo RunState).
	for i: int in [1, 2]:  # Fases 2 e 3.
		await _abrir_fase(FASES[i])  # Abre a fase.
		print("== Fase %d ==" % (i + 1))  # Avisa.
		_player.conceder_invulnerabilidade(9999.0)  # Jogador invulnerável.
		_confere(_hab.abilities.size() == 1, "habilidade restaurada na fase")  # Habilidade restaurada.
		if not _hab.abilities.is_empty():  # Usa a habilidade.
			await _usar_habilidade("Fase %d" % (i + 1), false)  # Usa.
	_fim()  # Fim.


## Termina o teste: devolve o tempo normal, despausa e mostra o resultado.
func _fim() -> void:
	Engine.time_scale = 1.0  # Tempo normal.
	get_tree().paused = false  # Despausa.
	print("ctrl_real_test: %d verificações, %d falhas" % [_total, _falhas])  # Resultado.
	get_tree().quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.
