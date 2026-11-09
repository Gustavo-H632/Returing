class_name BaseStateMachine
extends Node
## Máquina de estados genérica: registra os filhos `BaseState` e executa o atual.

# Avisa a troca de estado (nome anterior e novo).
signal state_changed(previous_state: StringName, new_state: StringName)

## Máximo de trocas em cadeia.
const MAX_CHAINED_TRANSITIONS: int = 8

@export var initial_state: BaseState  # Estado em que a máquina começa.
## Inicia sozinha quando o ator termina o _ready.
@export var auto_start: bool = true
## Chama update() dos estados em _process.
@export var run_process_update: bool = false

## Dono da máquina; se vazio, usa o nó pai.
@export var actor: Node = null

var current_state: BaseState = null  # Estado ativo agora.
## Quando true, nenhuma transição é aceita.
var locked: bool = false

var _states: Dictionary[StringName, BaseState] = {}  # Nome em minúsculas -> estado
## Chaves já avisadas (ver _warn_once).
var _warned: Dictionary[StringName, bool] = {}
var _started: bool = false  # True depois do start().
var _transitioning: bool = false  # True durante uma troca (enter/exit rodando).
var _pending_state: StringName = &""  # Troca pedida durante outra troca.
## Trocas em cadeia já resolvidas a partir da chamada em curso.
var _chain_depth: int = 0


## Registra os estados filhos e inicia depois do ator.
## Registra todos os filhos que são estados e agenda o início para depois que o ator estiver pronto.
func _ready() -> void:
	set_physics_process(false)  # A máquina só liga depois de iniciar.
	set_process(false)
	if actor == null:  # Se ninguém definiu o dono, usa o pai.
		actor = get_parent()
	if actor == null:  # Sem dono não há o que controlar.
		push_error("%s: a máquina de estados precisa de um nó pai (o ator)." % name)
		return

	for child: Node in get_children():  # Para cada filho que é um estado.
		if child is BaseState:
			var state := child as BaseState  # Guarda no dicionário (nome em minúsculas).
			_states[_key(state.name)] = state  # Dá ao estado a máquina e o ator.
			state.setup(self, actor)  # Escuta os pedidos de troca do estado.
			state.transition_requested.connect(_on_state_transition_requested.bind(state))

	if auto_start:  # Início automático.
		if actor.is_node_ready():  # Ator já pronto: inicia no fim do quadro.
			start.call_deferred()
		else:  # Senão espera o sinal `ready` do ator.
			actor.ready.connect(start, CONNECT_ONE_SHOT)


## Inicia a máquina no estado inicial; chamadas extras são ignoradas.
## Inicia a máquina no estado inicial. Chamadas repetidas são ignoradas.
func start() -> void:
	if _started or actor == null:  # Já iniciada ou sem dono: nada a fazer.
		return
	if initial_state == null:  # Sem estado inicial definido, procura "Idle" ou o primeiro filho.
		initial_state = _find_default_state()
	if initial_state == null:  # Nenhum estado encontrado.
		push_warning("%s: nenhum estado filho encontrado; a state não foi iniciada." % name)
		return
	_started = true  # Marca como iniciada.
	_transitioning = true  # Durante o enter() qualquer troca fica pendente.
	var first := initial_state
	current_state = first  # O estado inicial vira o atual.
	first.enter()  # Entra no estado inicial.
	_transitioning = false
	if not locked:  # Se não está travada, liga os loops.
		set_physics_process(true)
		set_process(run_process_update)
	state_changed.emit(&"", first.name)  # Avisa a primeira troca (de nada para o inicial).
	_flush_pending()  # Executa troca pedida durante o enter().


## Encerra a máquina: chama `exit()` do estado atual e bloqueia novas transições.
## Encerra a máquina: sai do estado atual, trava e desliga os loops.
func stop() -> void:
	if current_state != null:  # Sai do estado atual (fecha hitboxes etc.).
		current_state.exit()
	current_state = null  # Sem estado atual.
	locked = true  # Trava: nenhuma troca nova.
	_pending_state = &""  # Esquece troca pendente.
	set_physics_process(false)
	set_process(false)


## Repassa o frame ao estado atual.
## A cada quadro de física, repassa o tempo ao estado atual.
func _physics_process(delta: float) -> void:
	if current_state != null:  # Só se há estado ativo.
		current_state.physics_update(delta)


## Repassa o frame ao estado atual.
## A cada quadro normal, repassa o tempo ao estado atual (só liga com `run_process_update`).
func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


## Estado pelo nome (sem diferenciar maiúsculas) ou null.
## Procura um estado pelo nome (sem diferenciar maiúsculas). Devolve null se não existir.
func get_state(state_name: StringName) -> BaseState:
	var key := _key(state_name)  # Nome normalizado.
	return _states[key] if _states.has(key) else null


## True se existe um estado com este nome.
## Diz se existe um estado com esse nome.
func has_state(state_name: StringName) -> bool:
	return _states.has(_key(state_name))


## Nomes dos nós de estado registrados (para mensagens de diagnóstico).
## Lista os nomes dos estados registrados (para as mensagens de aviso).
func get_state_names() -> PackedStringArray:
	var names: PackedStringArray = []  # Lista de nomes.
	for state: BaseState in _states.values():  # Passa por todos os estados.
		names.append(state.name)
	return names


## Avisa uma única vez por chave.
## Avisa uma única vez por chave (evita encher o console a cada quadro).
func _warn_once(key: StringName, message: String) -> void:
	if _warned.has(key):  # Já avisou: ignora.
		return
	_warned[key] = true  # Marca como avisado.
	push_warning(message)  # Escreve o aviso no console.


## True se o estado atual tem este nome.
## Diz se o estado atual tem esse nome.
func is_in_state(state_name: StringName) -> bool:
	return current_state != null and _key(current_state.name) == _key(state_name)


## Troca de estado.
## Troca o state do inimigo: sai do estado antigo, entra no novo e emite o sinal state_changed.
## Recusa a troca se a máquina estiver travada, se o estado não existir ou se for o mesmo que já está ativo.
func transition_to(state_name: StringName) -> bool:
	if locked or not _started:  # Travada ou não iniciada: recusa.
		return false
	var next_state := get_state(state_name)  # Procura o próximo estado pelo nome.
	if next_state == null:  # Nome inexistente: avisa uma vez e recusa.
		_warn_once(state_name, "%s: estado '%s' não encontrado. Estados registrados: %s." % [
			name, state_name, ", ".join(get_state_names())])
		return false
	if next_state == current_state:  # Já está nesse estado: recusa.
		return false
	if _transitioning:  # Estamos dentro de outra troca: guarda o pedido para executar depois.
		_pending_state = state_name  # Guarda o nome do estado pedido.
		return true  # Devolve true: o pedido foi aceito (será executado).

	_transitioning = true  # Marca que a troca começou.
	var previous := current_state  # Guarda o estado anterior.
	if previous != null:
		previous.exit()  # Sai do estado antigo.
	current_state = next_state  # O novo vira o atual.
	next_state.enter()  # Entra no novo estado.
	_transitioning = false  # Fim da troca.

	# Usa `next_state` (não `current_state`).
	# Avisa a troca para quem escuta (HUD, estados canônicos).
	state_changed.emit(previous.name if previous != null else &"", next_state.name)
	_flush_pending()  # Executa troca pedida durante enter()/exit().
	return true


## Executa a troca pedida de dentro de um enter() ou exit().
## Executa a troca que ficou pendente (pedida dentro de um enter() ou exit()), com limite contra laços infinitos.
func _flush_pending() -> void:
	if _pending_state == &"":  # Nada pendente: sai.
		return
	var pending := _pending_state  # Pega o pedido e limpa o campo.
	_pending_state = &""
	if _chain_depth >= MAX_CHAINED_TRANSITIONS:  # Muitas trocas seguidas: provável laço, interrompe.
		push_error("%s: trocas de estado em laço (última pedida: '%s'); cadeia interrompida." % [
			name, pending])
		return
	_chain_depth += 1  # Conta a profundidade da cadeia.
	transition_to(pending)  # Executa a troca.
	_chain_depth -= 1  # Volta a contagem.


## Alias de `transition_to`.
## Atalho com outro nome para `transition_to` (compatibilidade).
func change_state(state_name: StringName) -> void:
	transition_to(state_name)


## Pedido vindo do sinal do estado.
## Recebe o pedido de troca vindo do sinal de um estado e só o aceita se esse estado ainda é o atual.
func _on_state_transition_requested(state_name: StringName, requester: BaseState) -> void:
	if requester == current_state:  # Pedido de um estado que já saiu é ignorado.
		transition_to(state_name)

## Estado inicial padrão: `Idle`, ou o primeiro filho.
## Escolhe o estado inicial padrão: "Idle", "IdleState" ou o primeiro filho que for estado.
func _find_default_state() -> BaseState:
	for candidate: StringName in [&"idle", &"idlestate"]:  # Tenta os nomes padrão primeiro.
		if has_state(candidate):
			return get_state(candidate)
	for child: Node in get_children():  # Senão, o primeiro filho que é estado.
		if child is BaseState:
			return child as BaseState
	return null


## Chave normalizada (minúsculas) usada no dicionário de estados.
## Normaliza o nome do estado para minúsculas (chave do dicionário).
static func _key(state_name: StringName) -> StringName:
	return StringName(String(state_name).to_lower())
