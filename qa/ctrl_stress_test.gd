extends Node
## Estresse do modo comando (Ctrl abre, setas digitam, Enter confirma, Alan livre): todas as habilidades,
## erros, recarga, Ctrl repetido, eco de tecla, pausa, menus, dash/golpe, morte, saída de cena e celular.
## Rodar: godot --headless --path . res://qa/ctrl_stress_test.tscn

const TECLAS_SETA: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]  # Tecla de cada direção de seta.
const ESCALA_ESPERADA: float = 0.2  # Escala de tempo esperada com o modo aberto.

var _falhas: int = 0  # Verificações que falharam.
var _total: int = 0  # Total de verificações.
var _fase: Node = null  # Fase aberta.
var _player: Player = null  # Jogador.
var _hab: AbilityComponent = null  # Componente de habilidades.
var _ui: AbilitiesUI = null  # Interface das habilidades.
var _ativadas: Array[StringName] = []  # Habilidades ativadas.
# Contador de erros de digitação (em lista para a função anônima poder alterar).
var _erros: Array[int] = [0]
var _estados: Array[int] = []  # Estados do jogador observados.


## Agenda o teste para o fim do quadro.
func _ready() -> void:
	_rodar.call_deferred()


## Confere uma condição, mostra o resultado e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		print("  FALHA " + nome)
	else:
		print("  ok    " + nome)


## Espera `n` quadros.
func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## Espera em tempo real (ignora a câmera lenta e a pausa).
func _segundos(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


## Simula apertar ou soltar uma tecla (com Ctrl, lado do teclado e eco opcionais).
func _tecla(keycode: Key, apertada: bool, ctrl: bool = false, lado: KeyLocation = KEY_LOCATION_UNSPECIFIED,
		eco: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	ev.keycode = keycode
	ev.pressed = apertada
	ev.echo = eco
	ev.ctrl_pressed = ctrl
	ev.location = lado
	Input.parse_input_event(ev)


## Aperta e solta uma tecla com dois quadros de espera em cada passo.
func _toque(keycode: Key, lado: KeyLocation = KEY_LOCATION_UNSPECIFIED, ctrl: bool = false) -> void:
	_tecla(keycode, true, ctrl, lado)
	await _frames(2)
	_tecla(keycode, false, false, lado)
	await _frames(2)


## Toca no Ctrl (apertar e soltar).
func _ctrl_toque(lado: KeyLocation = KEY_LOCATION_LEFT) -> void:
	await _toque(KEY_CTRL, lado, true)


## Digita cada tecla da lista em sequência.
func _digitar(teclas: Array[Key]) -> void:
	for tecla: Key in teclas:
		await _toque(tecla)


## Converte uma sequência de direções em teclas de seta.
func _sequencia_para_teclas(seq: Array[int]) -> Array[Key]:
	var teclas: Array[Key] = []  # Lista de teclas.
	for dir: int in seq:  # Cada direção.
		teclas.append(TECLAS_SETA[dir])  # Tecla correspondente.
	return teclas


## Simula apertar ou soltar uma ação do Input Map.
func _acao(nome: StringName, apertada: bool) -> void:
	var ev := InputEventAction.new()
	ev.action = nome
	ev.pressed = apertada
	Input.parse_input_event(ev)


## Zera recargas, efeitos, ativações e erros entre um teste e outro.
func _limpar() -> void:
	_hab._cooldowns.clear()
	_hab._cancel_all_effects()
	_ativadas.clear()
	_erros[0] = 0


## Diz se o modo comando está fechado e o tempo voltou ao normal.
func _fechado() -> bool:
	return not _hab.command_active and is_equal_approx(Engine.time_scale, 1.0)


## Diz se o modo comando está aberto e a câmera lenta está ligada.
func _aberto() -> bool:
	return _hab.command_active and is_equal_approx(Engine.time_scale, ESCALA_ESPERADA)


## Espera o Alan voltar a IDLE/MOVE (a câmera lenta estica o dash e o golpe em tempo real).
## Espera o jogador voltar a ficar parado ou andando (a câmera lenta estica o dash e o golpe em tempo real).
func _esperar_livre() -> void:
	var inicio: int = Time.get_ticks_msec()  # Hora de início.
	while Time.get_ticks_msec() - inicio < 8000:  # Espera até 8 s.
		if _player.state == Player.State.IDLE or _player.state == Player.State.MOVE:  # Voltou ao normal.
			break
		await _frames(2)  # Espera um quadro.
	await _segundos(0.1)  # Pequena folga.


## Fecha o modo comando se ele estiver aberto.
func _fechar_se_aberto() -> void:
	if _hab.command_active:  # Está aberto.
		await _ctrl_toque()  # Toca no Ctrl.
	await _frames(2)  # Espera.


## Abre a Fase 1 e liga o teste ao jogador, à interface e aos sinais de habilidade e estado.
func _abrir_fase() -> void:
	RunState.reset()  # Run nova.
	_fase = (load("res://Scenes/Fase1/fase_1.tscn") as PackedScene).instantiate()  # Cria a fase.
	get_tree().root.add_child(_fase)  # Entra na árvore.
	get_tree().current_scene = _fase  # É a cena atual.
	await _frames(20)  # Espera 20 quadros.
	_player = _fase.find_child("Player", true, false) as Player  # Jogador.
	_hab = _player.get_node("AbilityComponent") as AbilityComponent  # Componente de habilidades.
	_ui = _player.find_child("AbilitiesUI", true, false) as AbilitiesUI  # Interface das habilidades.
	_player.conceder_invulnerabilidade(99999.0)  # Jogador invulnerável.
	# Guarda cada ativação.
	_hab.ability_activated.connect(func(d: AbilityData) -> void: _ativadas.append(d.id))
	_hab.input_failed.connect(func() -> void: _erros[0] += 1)  # Conta cada erro.
	# Guarda cada mudança de estado do jogador.
	_player.estado_mudou.connect(func(e: int) -> void: _estados.append(e))


## Roda o estresse: todas as habilidades, erros, recarga, cancelar, fora do modo, digitação rápida, dash e golpe, pausa e menus, toque, HUD, morte e saída de cena.
func _rodar() -> void:
	await _abrir_fase()  # Abre a fase.
	var todas: Array[AbilityData] = _hab.catalog.abilities.duplicate()  # Todas as habilidades do catálogo.
	print("== Input Map ==")  # Seção.
	_testar_input_map()  # Confere o Input Map.

	print("== Todas as habilidades (%d) ==" % todas.size())
	_hab.abilities = todas  # Dá todas as habilidades ao jogador.
	_hab.abilities_changed.emit()  # Avisa a interface.
	await _frames(3)
	for data: AbilityData in todas:  # Cada habilidade.
		_limpar()  # Limpa.
		await _ctrl_toque()  # Abre o modo.
		var abriu: bool = _aberto()  # Abriu?
		await _digitar(_sequencia_para_teclas(data.sequence))  # Digita a sequência.
		var antes_enter: bool = _ativadas.is_empty()  # Ainda não ativou (falta o Enter).
		await _toque(KEY_ENTER)  # Enter.
		_confere(abriu and antes_enter and _ativadas == [data.id] and _fechado()
				and _hab.get_cooldown_left(data.id) > 0.0,
				"%s %s: abre, só dispara no Enter, fecha, recarga" % [data.id, data.sequence])

	print("== Erros ==")
	_limpar()
	await _ctrl_toque()
	await _digitar([KEY_UP, KEY_UP, KEY_UP, KEY_UP, KEY_UP, KEY_UP, KEY_UP])  # passa do tamanho de qualquer uma
	_confere(_erros[0] >= 1 and _hab._sequence.size() < 7 and _hab.command_active, "sequência longa demais: erro e buffer volta")
	_limpar()
	var escudo: AbilityData = _hab.catalog.find_by_id(&"escudo")
	await _digitar(_sequencia_para_teclas(escudo.sequence))
	await _digitar([KEY_UP])  # seta a mais
	await _toque(KEY_ENTER)
	_confere(_ativadas.is_empty() and _erros[0] >= 1 and _hab.command_active, "seta extra depois da sequência + Enter: não ativa")
	_limpar()
	await _digitar(_sequencia_para_teclas(escudo.sequence).slice(0, 2))
	await _toque(KEY_ENTER)
	_confere(_ativadas.is_empty() and _erros[0] == 1 and _hab._sequence.is_empty() and _hab.command_active,
			"sequência incompleta + Enter: erro, modo aberto")
	await _toque(KEY_ENTER)
	_confere(_erros[0] == 1, "Enter com buffer vazio não conta erro")
	_limpar()
	await _digitar([KEY_RIGHT, KEY_RIGHT, KEY_RIGHT])
	await _digitar(_sequencia_para_teclas(escudo.sequence))
	await _toque(KEY_ENTER)
	_confere(_erros[0] >= 1 and _ativadas == [&"escudo"] and _fechado(), "→→→ erra e zera; a sequência certa digitada em seguida ativa (%s, erros %d)" % [_ativadas, _erros[0]])

	print("== Recarga ==")
	_limpar()
	_hab._cooldowns[&"escudo"] = 5.0
	await _ctrl_toque()
	await _digitar(_sequencia_para_teclas(escudo.sequence))
	await _toque(KEY_ENTER)
	_confere(_ativadas.is_empty() and _erros[0] == 1 and _hab.command_active, "em recarga + Enter: erro e modo aberto")
	await _fechar_se_aberto()
	_confere(_fechado(), "Ctrl cancela")

	print("== Cancelar e Backspace ==")
	_limpar()
	await _ctrl_toque()
	await _digitar([KEY_UP, KEY_DOWN, KEY_LEFT])
	await _ctrl_toque()
	_confere(_fechado() and _hab._sequence.is_empty(), "Ctrl no meio da sequência cancela e zera o buffer")
	await _ctrl_toque()
	_confere(_hab._sequence.is_empty() and _aberto(), "reabrir começa com buffer vazio")
	await _digitar([KEY_BACKSPACE, KEY_BACKSPACE])
	_confere(_hab._sequence.is_empty() and _erros[0] == 0, "Backspace com buffer vazio é inofensivo")
	await _digitar([KEY_UP, KEY_DOWN, KEY_BACKSPACE, KEY_BACKSPACE, KEY_BACKSPACE])
	_confere(_hab._sequence.is_empty(), "Backspace apaga uma a uma")
	await _digitar(_sequencia_para_teclas(escudo.sequence))
	await _digitar([KEY_BACKSPACE, KEY_RIGHT])
	await _toque(KEY_ENTER)
	_confere(_ativadas == [&"escudo"] and _fechado(), "apagar a última seta com Backspace, redigitar e confirmar ativa")

	print("== Fora do modo ==")
	_limpar()
	await _fechar_se_aberto()
	await _digitar([KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT])
	await _toque(KEY_ENTER)
	await _toque(KEY_BACKSPACE)
	_confere(_ativadas.is_empty() and _hab._sequence.is_empty() and _erros[0] == 0, "setas/Enter/Backspace fechados não fazem nada")
	var pos: Vector2 = _player.global_position
	for tecla: Key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_tecla(tecla, true)
	await _segundos(0.5)
	for tecla: Key in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]:
		_tecla(tecla, false)
	await _frames(3)
	_confere(_player.global_position.distance_to(pos) < 0.5, "as 4 setas seguradas não movem o Alan")
	for par: Array in [[KEY_W, Vector2.UP], [KEY_S, Vector2.DOWN], [KEY_A, Vector2.LEFT], [KEY_D, Vector2.RIGHT]]:
		pos = _player.global_position
		_tecla(par[0], true)
		await _segundos(0.4)
		_tecla(par[0], false)
		await _frames(3)
		var delta: Vector2 = _player.global_position - pos
		_confere(delta.length() > 5.0 and delta.normalized().dot(par[1] as Vector2) > 0.8, "WASD move: %s" % OS.get_keycode_string(par[0]))

	print("== Ctrl repetido, eco e segurar ==")
	await _fechar_se_aberto()
	var aberto: bool = false
	var consistente: bool = true
	for i: int in 15:
		await _ctrl_toque(KEY_LOCATION_LEFT if i % 2 == 0 else KEY_LOCATION_RIGHT)
		aberto = not aberto
		consistente = consistente and (_hab.command_active == aberto)
	_confere(consistente and _aberto(), "15 toques alternando Ctrl esq./dir.: estado alterna certinho (termina aberto)")
	await _ctrl_toque()
	_confere(_fechado(), "mais um toque: fechado e tempo 1.0")
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)
	await _frames(2)
	for i: int in 5:
		_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT, true)  # eco do sistema com a tecla segurada
		await _frames(1)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(2)
	_confere(_aberto(), "Ctrl segurado com eco abre uma vez só (eco não desliga)")
	_limpar()
	_tecla(KEY_UP, true)
	_tecla(KEY_UP, true, false, KEY_LOCATION_UNSPECIFIED, true)
	_tecla(KEY_UP, true, false, KEY_LOCATION_UNSPECIFIED, true)
	await _frames(2)
	_tecla(KEY_UP, false)
	await _frames(2)
	_confere(_hab._sequence.size() == 1, "seta segurada (eco) conta uma vez só (%d)" % _hab._sequence.size())
	await _fechar_se_aberto()
	_limpar()
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)
	await _frames(2)
	await _digitar(_sequencia_para_teclas(escudo.sequence))
	await _toque(KEY_ENTER)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(2)
	_confere(_ativadas == [&"escudo"] and _fechado(), "jeito antigo (segurar Ctrl + setas + Enter) também funciona")

	print("== Digitação rápida (várias teclas no mesmo quadro) ==")
	_limpar()
	await _ctrl_toque()
	for tecla: Key in _sequencia_para_teclas(escudo.sequence):
		_tecla(tecla, true)
		_tecla(tecla, false)
	await _frames(3)
	_confere(_hab._sequence.size() == 4, "4 teclas no mesmo quadro: %d no buffer" % _hab._sequence.size())
	await _toque(KEY_ENTER)
	_confere(_ativadas == [&"escudo"], "e o Enter ativa")

	print("== Andar, esquivar e golpear com o modo aberto ==")
	_limpar()
	await _ctrl_toque()
	await _digitar([KEY_UP, KEY_DOWN])
	pos = _player.global_position
	_tecla(KEY_D, true)
	await _digitar([KEY_LEFT])  # digita seta andando
	await _segundos(0.4)
	_confere(_player.global_position.x > pos.x + 5.0 and _hab._sequence.size() == 3, "andando para a direita e digitando ao mesmo tempo")
	_estados.clear()
	_acao(&"dash", true)
	await _frames(2)
	_acao(&"dash", false)
	await _segundos(0.2)
	var viu_dash: bool = _estados.has(Player.State.DASH)
	_confere(viu_dash and _hab.command_active and _aberto(), "dash com o modo aberto: modo continua aberto")
	_confere(_hab._sequence.size() == 3, "dash não apaga o buffer")
	_tecla(KEY_D, false)
	await _esperar_livre()
	_estados.clear()
	_acao(&"attack_sword", true)
	await _segundos(0.3)  # câmera lenta: a física roda a 20% da velocidade, segura até ela ler a tecla
	_acao(&"attack_sword", false)
	await _segundos(0.2)
	var viu_golpe: bool = _estados.has(Player.State.ATTACK_MELEE)
	await _esperar_livre()
	_confere(viu_golpe and _hab.command_active, "golpe com o modo aberto: modo continua aberto (estados %s, aberto %s, estado atual %d, bloqueado %s)" % [_estados, _hab.command_active, _player.state, UiFx.is_attack_input_blocked()])
	await _digitar([KEY_RIGHT])
	await _toque(KEY_ENTER)
	_confere(_ativadas == [&"escudo"] and _fechado(), "termina a sequência depois de esquivar e golpear e ativa")
	_limpar()
	await _ctrl_toque()
	_estados.clear()
	_acao(&"charge_shoot", true)
	await _segundos(0.3)
	await _digitar(_sequencia_para_teclas(escudo.sequence))
	_acao(&"charge_shoot", false)
	await _segundos(0.3)
	await _toque(KEY_ENTER)
	_confere(_estados.has(Player.State.ATTACK_RANGED) and _ativadas == [&"escudo"], "digitar e confirmar enquanto carrega o tiro")
	await _segundos(0.3)

	print("== Pausa e menus com o modo aberto ==")
	_limpar()
	await _fechar_se_aberto()
	await _ctrl_toque()
	await _digitar([KEY_UP, KEY_DOWN])
	get_tree().paused = true
	await _frames(3)
	_confere(_fechado() and _hab._sequence.is_empty(), "pausa fecha o modo, zera o buffer e devolve o tempo")
	await _ctrl_toque()
	_confere(not _hab.command_active, "pausado: Ctrl não abre")
	get_tree().paused = false
	await _frames(3)
	await _ctrl_toque()
	_confere(_aberto(), "despausou: Ctrl abre de novo")
	_ui._queue.append(99)
	await _frames(4)
	_confere(_fechado() and _ui._menu_open and get_tree().paused, "level-up chegando fecha o modo, devolve o tempo e abre o menu")
	_ui._on_kept_current()
	await _frames(3)
	_confere(not get_tree().paused and not _ui._menu_open, "menu de level-up resolvido: jogo volta")
	await _ctrl_toque()
	_confere(_aberto(), "reabre depois do level-up")
	var abriu_build: bool = _ui.open_build_menu()
	await _frames(3)
	_confere(abriu_build and _fechado() and get_tree().paused, "menu de build fecha o modo e pausa")
	_ui._close_build_menu()
	await _frames(3)
	_confere(not get_tree().paused, "menu de build fechou e o jogo voltou")

	print("== Celular (toque) ==")
	_limpar()
	await _fechar_se_aberto()
	_hab.toggle_command_mode()
	_confere(_aberto(), "toggle abre o modo por toque")
	for dir: int in escudo.sequence:
		_hab.press_arrow(dir)
	_confere(_ativadas == [&"escudo"] and _hab.command_active, "toque: dispara ao completar a sequência e mantém o modo")
	_hab.toggle_command_mode()
	_confere(_fechado(), "toque: segundo toggle fecha")

	print("== HUD (colinha) ==")
	var hud: CommandHud = _player.find_child("CommandHud", true, false) as CommandHud
	var cheats: int = 0
	var certos: int = 0
	for entry: Dictionary in hud._entries.values():
		var cheat: ArrowSequenceView = entry["cheat"] as ArrowSequenceView
		var data: AbilityData = entry["data"] as AbilityData
		cheats += 1
		if cheat.get_parent() is VBoxContainer and cheat._sequence == data.sequence \
				and cheat.get_minimum_size().y == CommandHud.CHEAT_ARROW_SIZE \
				and cheat.get_parent().get_child(1) == entry["slot"] \
				and (entry["slot"] as Control).size_flags_horizontal == Control.SIZE_SHRINK_CENTER:
			certos += 1
	_confere(cheats == todas.size() and certos == cheats, "colinha acima de cada slot com a sequência certa (%d/%d)" % [certos, cheats])
	_hab.abilities = [escudo]
	_hab.abilities_changed.emit()
	await _frames(3)
	_confere(hud._entries.size() == 1 and hud._compact.get_child_count() >= CommandHud.MAX_SLOTS, "reconstrói: 1 habilidade + slots vazios alinhados")

	print("== Morte e saída de cena ==")
	await _ctrl_toque()
	_confere(_aberto(), "abre antes de morrer")
	_player.tomar_dano(99999, true)
	await _frames(5)
	_confere(_player.esta_morto() and _fechado(), "morrer fecha o modo e devolve o tempo")
	await _ctrl_toque()
	_confere(not _hab.command_active, "morto: Ctrl não abre")

	_fase.queue_free()
	await _frames(4)
	Engine.time_scale = 1.0
	await _abrir_fase()
	_hab.abilities = [_hab.catalog.find_by_id(&"escudo")]
	await _ctrl_toque()
	_confere(_aberto(), "nova fase: abre")
	_fase.queue_free()
	await _frames(4)
	_confere(is_equal_approx(Engine.time_scale, 1.0), "sair da cena com o modo aberto devolve o tempo 1.0")

	Engine.time_scale = 1.0
	get_tree().paused = false
	print("ctrl_stress_test: %d verificações, %d falhas" % [_total, _falhas])
	get_tree().quit(1 if _falhas > 0 else 0)


## Confere se as ações do modo comando existem no Input Map e se o movimento usa só WASD.
func _testar_input_map() -> void:
	var setas: Array[Key] = [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	var wasd: Array[Key] = [KEY_W, KEY_A, KEY_S, KEY_D]
	for acao: StringName in [&"move_up", &"move_down", &"move_left", &"move_right"]:
		var sem_seta: bool = true
		var com_wasd: bool = false
		for ev: InputEvent in InputMap.action_get_events(acao):
			var k: InputEventKey = ev as InputEventKey
			if k == null:
				continue
			if setas.has(k.physical_keycode) or setas.has(k.keycode):
				sem_seta = false
			if wasd.has(k.physical_keycode):
				com_wasd = true
		_confere(sem_seta and com_wasd, "%s: só WASD, sem setas" % acao)
	for acao: StringName in [&"cmd_up", &"cmd_down", &"cmd_left", &"cmd_right"]:
		var so_seta: bool = true
		var tem_seta: bool = false
		for ev: InputEvent in InputMap.action_get_events(acao):
			var k: InputEventKey = ev as InputEventKey
			if k == null:
				continue
			if wasd.has(k.physical_keycode):
				so_seta = false
			if setas.has(k.physical_keycode):
				tem_seta = true
		_confere(so_seta and tem_seta, "%s: só setas" % acao)
	for acao: StringName in [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]:
		var tem: bool = false
		for ev: InputEvent in InputMap.action_get_events(acao):
			var k: InputEventKey = ev as InputEventKey
			if k != null and (setas.has(k.keycode) or setas.has(k.physical_keycode)):
				tem = true
		_confere(tem, "%s continua com as setas (menus)" % acao)
	_confere(InputMap.has_action(&"cmd_confirm") and InputMap.has_action(&"cmd_back"), "cmd_confirm e cmd_back existem")
	var ev_enter := InputEventKey.new()
	ev_enter.physical_keycode = KEY_ENTER
	ev_enter.pressed = true
	_confere(InputMap.event_is_action(ev_enter, &"cmd_confirm"), "Enter casa com cmd_confirm")
	var ev_kp := InputEventKey.new()
	ev_kp.physical_keycode = KEY_KP_ENTER
	ev_kp.pressed = true
	_confere(InputMap.event_is_action(ev_kp, &"cmd_confirm"), "Enter do teclado numérico casa com cmd_confirm")
	for lado: KeyLocation in [KEY_LOCATION_LEFT, KEY_LOCATION_RIGHT, KEY_LOCATION_UNSPECIFIED]:
		var ev_ctrl := InputEventKey.new()
		ev_ctrl.physical_keycode = KEY_CTRL
		ev_ctrl.keycode = KEY_CTRL
		ev_ctrl.ctrl_pressed = true
		ev_ctrl.pressed = true
		ev_ctrl.location = lado
		_confere(InputMap.event_is_action(ev_ctrl, &"command_mode"), "Ctrl (lado %d) casa com command_mode" % lado)
