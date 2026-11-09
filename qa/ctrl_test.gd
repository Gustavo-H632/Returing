extends Node
## Modo comando com teclas simuladas numa fase real: Ctrl abre, setas digitam, Enter confirma; o Alan anda livre.
## Rodar: godot --headless --path . res://qa/ctrl_test.tscn

var _falhas: int = 0  # Verificações que falharam.
var _total: int = 0  # Total de verificações.
var _fase: Node = null  # Fase aberta no teste.
var _ativadas: Array[StringName] = []  # Habilidades que foram ativadas durante o teste.


## Agenda o teste para o fim do quadro.
func _ready() -> void:
	_rodar.call_deferred()  # Roda depois da criação dos nós.


## Confere uma condição, mostra o resultado e conta a falha.
func _confere(condicao: bool, nome: String) -> void:
	_total += 1  # Mais uma verificação.
	print(("  ok    " if condicao else "  FALHA ") + nome)  # Mostra "ok" ou "FALHA".
	if not condicao:  # Falhou.
		_falhas += 1  # Soma a falha.


## Espera `n` quadros.
func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


## Simula apertar ou soltar uma tecla (com Ctrl e lado do teclado opcionais).
func _tecla(keycode: Key, apertada: bool, ctrl: bool = false, localizacao: KeyLocation = KEY_LOCATION_UNSPECIFIED) -> void:
	var ev := InputEventKey.new()  # Evento de tecla.
	ev.physical_keycode = keycode  # Código físico.
	ev.keycode = keycode  # Código lógico.
	ev.pressed = apertada  # Apertada ou solta.
	ev.ctrl_pressed = ctrl  # Ctrl pressionado?
	ev.location = localizacao  # Lado do teclado (esquerdo ou direito).
	Input.parse_input_event(ev)  # Envia o evento.


## Aperta e solta cada tecla em sequência.
## Aperta e solta cada tecla em sequência (dois quadros entre cada passo).
func _digitar(teclas: Array[Key]) -> void:
	for tecla: Key in teclas:  # Cada tecla.
		_tecla(tecla, true)  # Aperta.
		await _frames(2)  # Espera.
		_tecla(tecla, false)  # Solta.
		await _frames(2)  # Espera.


## Roda o teste do modo comando numa fase real: sem habilidades, com Escudo, andar com o modo aberto, erro, Backspace, sequência certa, setas que não movem e Ctrl direito.
func _rodar() -> void:
	RunState.reset()  # Run nova.
	_fase = (load("res://Scenes/Fase1/fase_1.tscn") as PackedScene).instantiate()  # Cria a Fase 1.
	get_tree().root.add_child(_fase)  # Entra na árvore.
	get_tree().current_scene = _fase  # É a cena atual.
	await _frames(20)  # Espera 20 quadros.
	var player: Player = _fase.find_child("Player", true, false) as Player  # Jogador.
	# Componente de habilidades.
	var hab: AbilityComponent = player.get_node("AbilityComponent") as AbilityComponent
	_confere(hab._setup_done, "AbilityComponent terminou o setup")  # O componente terminou o setup.
	# Guarda cada habilidade ativada.
	hab.ability_activated.connect(func(d: AbilityData) -> void: _ativadas.append(d.id))
	var avisos: Array[StringName] = []  # Avisos de indisponibilidade.
	hab.command_unavailable.connect(func(m: StringName) -> void: avisos.append(m))  # Guarda cada aviso.

	# 1) Sem habilidades (início da run): Ctrl só avisa.
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)
	await _frames(3)
	_confere(not hab.command_active, "sem habilidades: modo comando não abre")
	_confere(avisos.has(&"sem_habilidades"), "sem habilidades: o aviso é emitido (%s)" % [avisos])
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)
	await _frames(3)

	# 2) Com uma habilidade (Escudo: cima, baixo, esquerda, direita).
	var escudo: AbilityData = load("res://abilities/data/escudo.tres") as AbilityData  # Habilidade Escudo.
	hab.abilities = [escudo]  # O jogador passa a ter só o Escudo.
	var falhas_sinal: Array[int] = [0]  # Conta os erros de digitação.
	hab.input_failed.connect(func() -> void: falhas_sinal[0] += 1)  # Cada erro soma um.
	_confere(player.state == Player.State.IDLE, "Player parado (IDLE)")  # Jogador parado.

	# Apertar e soltar o Ctrl já basta: o modo fica aberto (não precisa segurar).
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_LEFT)  # Aperta o Ctrl.
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_LEFT)  # Solta o Ctrl.
	await _frames(3)
	_confere(hab.command_active, "Ctrl esquerdo (apertar e soltar) abre o modo comando")  # O modo abriu.
	# Câmera lenta em 0,2 com o modo aberto.
	_confere(is_equal_approx(Engine.time_scale, 0.2) and is_equal_approx(hab.command_time_scale, 0.2),
			"câmera lenta em 0.2 com o modo aberto (%.2f)" % Engine.time_scale)

	# O jogador continua livre para andar com o modo aberto.
	var x0: float = player.global_position.x  # Posição antes de andar.
	_tecla(KEY_D, true)  # Aperta D.
	await get_tree().create_timer(0.6, true, false, true).timeout  # tempo real: a câmera lenta atrasa a física
	_confere(player.state == Player.State.MOVE and player.global_position.x > x0 + 1.0,  # O jogador andou.
			"modo aberto: o Alan anda com WASD")
	_tecla(KEY_D, false)  # Solta D.
	await _frames(3)

	# Sequência errada + Enter: erro, o modo continua aberto e o buffer zera.
	await _digitar([KEY_UP, KEY_UP])  # Digita duas setas para cima.
	await _digitar([KEY_ENTER])  # Enter.
	# Houve um erro e o modo continua aberto com a sequência vazia.
	_confere(falhas_sinal[0] == 1 and hab.command_active and hab._sequence.is_empty(),
			"sequência errada + Enter: erro, modo continua aberto")

	# Backspace apaga a última seta.
	await _digitar([KEY_UP, KEY_DOWN, KEY_BACKSPACE])  # Cima, baixo e Backspace.
	_confere(hab._sequence.size() == 1, "Backspace apaga a última seta")  # Sobrou uma seta.
	await _digitar([KEY_BACKSPACE])  # Apaga a que sobrou.

	# Sequência certa: só dispara no Enter, e o Enter fecha o modo.
	await _digitar([KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT])  # Digita a sequência do Escudo.
	# Ainda não ativou (falta o Enter).
	_confere(not _ativadas.has(&"escudo"), "setas completas sem Enter: ainda não ativa")
	await _digitar([KEY_ENTER])  # Enter.
	# Ativou o Escudo.
	_confere(_ativadas.has(&"escudo"), "sequência ↑↓←→ + Enter ativou o Escudo (%s)" % [_ativadas])
	_confere(not hab.command_active, "Enter fecha o modo comando")  # O Enter fechou o modo.
	# O tempo voltou ao normal.
	_confere(is_equal_approx(Engine.time_scale, 1.0), "Enter devolve o tempo normal")

	# 3) As setas não movem o Alan.
	var pos: Vector2 = player.global_position  # Posição antes de apertar a seta.
	_tecla(KEY_UP, true)  # Aperta a seta para cima.
	await _frames(12)  # Espera 12 quadros.
	# O jogador não se moveu.
	_confere(player.state == Player.State.IDLE and player.global_position.distance_to(pos) < 0.5,
			"seta para cima não move o Alan")
	_tecla(KEY_UP, false)  # Solta a seta.
	await _frames(3)

	# 4) Ctrl direito abre e apertar o Ctrl de novo cancela.
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_RIGHT)  # Aperta o Ctrl direito.
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_RIGHT)  # Solta.
	await _frames(3)
	_confere(hab.command_active, "Ctrl direito abre o modo comando")  # O modo abriu.
	_tecla(KEY_CTRL, true, true, KEY_LOCATION_RIGHT)  # Aperta o Ctrl direito de novo.
	await _frames(3)
	_tecla(KEY_CTRL, false, false, KEY_LOCATION_RIGHT)  # Solta.
	await _frames(3)
	_confere(not hab.command_active, "apertar o Ctrl de novo cancela o modo")  # O modo fechou (cancelou).

	_fase.queue_free()  # Remove a fase.
	await _frames(3)
	Engine.time_scale = 1.0  # Devolve o tempo normal.
	print("ctrl_test: %d verificações, %d falhas" % [_total, _falhas])  # Resultado.
	get_tree().quit(1 if _falhas > 0 else 0)  # Sai com código de erro se algo falhou.
