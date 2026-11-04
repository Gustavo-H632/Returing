class_name BaseStateMachine
extends Node
## Máquina de estados genérica: registra os filhos `BaseState` e executa o atual.

signal state_changed(previous_state: StringName, new_state: StringName)

## Máximo de trocas em cadeia.
const MAX_CHAINED_TRANSITIONS: int = 8

@export var initial_state: BaseState
## Inicia sozinha quando o ator termina o _ready.
@export var auto_start: bool = true
## Chama update() dos estados em _process.
@export var run_process_update: bool = false

## Dono da máquina; se vazio, usa o nó pai.
@export var actor: Node = null

var current_state: BaseState = null
## Quando true, nenhuma transição é aceita.
var locked: bool = false

var _states: Dictionary[StringName, BaseState] = {}  # Nome em minúsculas -> estado
## Chaves já avisadas (ver _warn_once).
var _warned: Dictionary[StringName, bool] = {}
var _started: bool = false
var _transitioning: bool = false
var _pending_state: StringName = &""
## Trocas em cadeia já resolvidas a partir da chamada em curso.
var _chain_depth: int = 0


## Registra os estados filhos e inicia depois do ator.
func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	if actor == null:
		actor = get_parent()
	if actor == null:
		push_error("%s: a máquina de estados precisa de um nó pai (o ator)." % name)
		return

	for child: Node in get_children():
		if child is BaseState:
			var state := child as BaseState
			_states[_key(state.name)] = state
			state.setup(self, actor)
			state.transition_requested.connect(_on_state_transition_requested.bind(state))

	if auto_start:
		if actor.is_node_ready():
			start.call_deferred()
		else:
			actor.ready.connect(start, CONNECT_ONE_SHOT)


## Inicia a máquina no estado inicial; chamadas extras são ignoradas.
func start() -> void:
	if _started or actor == null:
		return
	if initial_state == null:
		initial_state = _find_default_state()
	if initial_state == null:
		push_warning("%s: nenhum estado filho encontrado; a state não foi iniciada." % name)
		return
	_started = true
	_transitioning = true
	var first := initial_state
	current_state = first
	first.enter()
	_transitioning = false
	if not locked:
		set_physics_process(true)
		set_process(run_process_update)
	state_changed.emit(&"", first.name)
	_flush_pending()


## Encerra a máquina: chama `exit()` do estado atual e bloqueia novas transições.
func stop() -> void:
	if current_state != null:
		current_state.exit()
	current_state = null
	locked = true
	_pending_state = &""
	set_physics_process(false)
	set_process(false)


## Repassa o frame ao estado atual.
func _physics_process(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


## Repassa o frame ao estado atual.
func _process(delta: float) -> void:
	if current_state != null:
		current_state.update(delta)


## Estado pelo nome (sem diferenciar maiúsculas) ou null.
func get_state(state_name: StringName) -> BaseState:
	var key := _key(state_name)
	return _states[key] if _states.has(key) else null


## True se existe um estado com este nome.
func has_state(state_name: StringName) -> bool:
	return _states.has(_key(state_name))


## Nomes dos nós de estado registrados (para mensagens de diagnóstico).
func get_state_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for state: BaseState in _states.values():
		names.append(state.name)
	return names


## Avisa uma única vez por chave.
func _warn_once(key: StringName, message: String) -> void:
	if _warned.has(key):
		return
	_warned[key] = true
	push_warning(message)


## True se o estado atual tem este nome.
func is_in_state(state_name: StringName) -> bool:
	return current_state != null and _key(current_state.name) == _key(state_name)


## Troca de estado.
func transition_to(state_name: StringName) -> bool:
	if locked or not _started:
		return false
	var next_state := get_state(state_name)
	if next_state == null:
		_warn_once(state_name, "%s: estado '%s' não encontrado. Estados registrados: %s." % [
			name, state_name, ", ".join(get_state_names())])
		return false
	if next_state == current_state:
		return false
	if _transitioning:
		_pending_state = state_name
		return true

	_transitioning = true
	var previous := current_state
	if previous != null:
		previous.exit()
	current_state = next_state
	next_state.enter()
	_transitioning = false

	# Usa `next_state` (não `current_state`).
	state_changed.emit(previous.name if previous != null else &"", next_state.name)
	_flush_pending()
	return true


## Executa a troca pedida de dentro de um enter() ou exit().
func _flush_pending() -> void:
	if _pending_state == &"":
		return
	var pending := _pending_state
	_pending_state = &""
	if _chain_depth >= MAX_CHAINED_TRANSITIONS:
		push_error("%s: trocas de estado em laço (última pedida: '%s'); cadeia interrompida." % [
			name, pending])
		return
	_chain_depth += 1
	transition_to(pending)
	_chain_depth -= 1


## Alias de `transition_to`.
func change_state(state_name: StringName) -> void:
	transition_to(state_name)


## Pedido vindo do sinal do estado.
func _on_state_transition_requested(state_name: StringName, requester: BaseState) -> void:
	if requester == current_state:
		transition_to(state_name)

## Estado inicial padrão: `Idle`, ou o primeiro filho.
func _find_default_state() -> BaseState:
	for candidate: StringName in [&"idle", &"idlestate"]:
		if has_state(candidate):
			return get_state(candidate)
	for child: Node in get_children():
		if child is BaseState:
			return child as BaseState
	return null


## Chave normalizada (minúsculas) usada no dicionário de estados.
static func _key(state_name: StringName) -> StringName:
	return StringName(String(state_name).to_lower())
