class_name BaseStateMachine
extends Node
##  State Machine genérica

signal state_changed(previous_state: StringName, new_state: StringName)

@export var initial_state: BaseState
## Inicia sozinha quando o ator termina o _ready.
@export var auto_start: bool = true
## Chama update() dos estados em _process
@export var run_process_update: bool = false

## Dono da state se vazio usa o nó pai.
@export var actor: Node = null

var current_state: BaseState = null
## Quando true, nenhuma transição é aceita
var locked: bool = false

var _states: Dictionary[StringName, BaseState] = {}  #  minúsculas == estado
var _started: bool = false
var _transitioning: bool = false
var _pending_state: StringName = &""


## Registra os estados filhos e inicia depois do ator.
func _ready() -> void:
	set_physics_process(false)
	set_process(false)
	if actor == null:
		actor = get_parent()
	if actor == null:
		push_error("%s: a máquina de estados precisa de um nó pai (o ator)." % name)
		return

	for child in get_children():
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


## starta a state machine chamadas extras são ignoradas.
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


## Encerra a state Chama exit() no estado atual.
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


## Estado pelo nome.
func get_state(state_name: StringName) -> BaseState:
	var key := _key(state_name)
	return _states[key] if _states.has(key) else null


## Existe o estado.
func has_state(state_name: StringName) -> bool:
	return _states.has(_key(state_name))


## Está neste estado.
func is_in_state(state_name: StringName) -> bool:
	return current_state != null and _key(current_state.name) == _key(state_name)


## Troca o state. Retorna true se a troca ocorreu
func transition_to(state_name: StringName) -> bool:
	if locked or not _started:
		return false
	var next_state := get_state(state_name)
	if next_state == null:
		push_warning("%s: estado '%s' não encontrado." % [name, state_name])
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

	# Usa next_state e um enter() pode chamar stop() e zerar current_state.
	state_changed.emit(previous.name if previous != null else &"", next_state.name)
	_flush_pending()
	return true


## Executa a mudança que foi pedida no enter() e exit().
func _flush_pending() -> void:
	if _pending_state == &"":
		return
	var pending := _pending_state
	_pending_state = &""
	transition_to(pending)


## Mesmo que transition_to.
func change_state(state_name: StringName) -> void:
	transition_to(state_name)


## Pedido vindo do sinal do estado.
func _on_state_transition_requested(state_name: StringName, requester: BaseState) -> void:
	if requester == current_state:
		transition_to(state_name)

## Idle ou o primeiro filho.
func _find_default_state() -> BaseState:
	for candidate: StringName in [&"idle", &"idlestate"]:
		if has_state(candidate):
			return get_state(candidate)
	for child in get_children():
		if child is BaseState:
			return child as BaseState
	return null


## Nome em minúsculas.
static func _key(state_name: StringName) -> StringName:
	return StringName(String(state_name).to_lower())
