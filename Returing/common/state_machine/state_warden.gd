class_name StateWarden
extends BaseStateMachine
## StateWarden: máquina de estados dos inimigos com estados canônicos.
# Estados canônicos: nomes padronizados que traduzem qualquer nome de nó (Idle, AttackRanged, Dead...).
enum State { IDLE, CHASE, ATTACK, DEAD, PATROL, NONE }

## Equivalente de `state_changed`, já traduzido para estados canônicos.
signal warden_state_changed(previous: State, current: State)
## Emitido uma única vez quando die() é chamado.
signal warden_died

# Nomes de nó aceitos para cada estado canônico (em minúsculas).
const CANDIDATES: Dictionary = {
	State.IDLE: [&"idle", &"idlestate"],
	State.CHASE: [&"chase", &"chasestate"],
	State.ATTACK: [&"attack", &"attackstate", &"attackranged", &"attackmelee"],
	State.DEAD: [&"dead", &"deadstate", &"death", &"deathstate"],
	State.PATROL: [&"patrol", &"patrolstate", &"wander"],
}
## Estados canônicos que todo inimigo precisa ter (Patrol é opcional).
const REQUIRED: Array = [State.IDLE, State.CHASE, State.ATTACK]

@export_group("Rede de segurança")
## Segundos máximos num estado canônico ATTACK antes de voltar ao repouso.
@export_range(0.0, 60.0, 0.5, "or_greater") var max_attack_state_time: float = 8.0

var _canonical_names: Dictionary[State, StringName] = {}  # Nome real do nó de cada estado canônico.
var _dead: bool = false  # True depois que o inimigo morre.
var _current_canonical: State = State.NONE  # Estado canônico atual.
var _previous_canonical: State = State.NONE  # Estado canônico anterior.
var _time_in_state: float = 0.0  # Segundos no estado atual.


## Resolve os nomes canônicos.
## Escuta as trocas antes do `super._ready()` e depois descobre quais nós correspondem a cada estado canônico.
func _ready() -> void:
	# Conectado ANTES do super: start() já emite state_changed, e o estado
	# canônico atual precisa estar correto desde a primeira transição.
	state_changed.connect(_on_state_changed)  # Ligado antes do super: o start() já emite a primeira troca.
	super._ready()  # Registra os estados filhos (máquina base).
	_resolve_canonical_states()  # Descobre os nomes canônicos.


## Conta há quanto tempo o inimigo está no estado atual (tempo de jogo).
## Conta o tempo no estado, repassa o quadro ao estado atual e vigia ataques travados.
func _physics_process(delta: float) -> void:
	_time_in_state += delta  # Soma o tempo de jogo no estado.
	super._physics_process(delta)  # Roda o estado atual (máquina base).
	_check_attack_watchdog()  # Rede de segurança.


## Tira o inimigo de um ataque que não termina (ver max_attack_state_time).
## Se o inimigo fica tempo demais em ATTACK, devolve-o ao repouso (Patrol ou Idle) e avisa no console.
func _check_attack_watchdog() -> void:
	if _dead or max_attack_state_time <= 0.0:  # Morto ou sem limite: não vigia.
		return
	# Só age em ATTACK depois do tempo limite.
	if _current_canonical != State.ATTACK or _time_in_state < max_attack_state_time:
		return
	# Nome do estado travado (para a mensagem).
	var travado: StringName = current_state.name if current_state != null else &"?"
	# Zera antes de tentar sair: se a troca for recusada, o aviso não se repete
	# a cada frame — volta a contar do zero.
	_time_in_state = 0.0  # Zera antes de sair, para o aviso não repetir a cada quadro.
	push_warning("%s: preso em '%s' por mais de %.1f s; voltando ao repouso." % [  # Avisa o desenvolvedor.
		name, travado, max_attack_state_time])
	if has_state(&"Patrol"):  # Prefere voltar a patrulhar.
		transition_to(&"Patrol")
	elif _canonical_names.has(State.IDLE):  # Senão volta ao repouso.
		transition_to(_canonical_names[State.IDLE])


## True se existe um nó para o estado canônico.
## Diz se existe um nó de estado para o estado canônico.
func has_canonical(canonical: State) -> bool:
	return _canonical_names.has(canonical)


## Pede a troca para um estado.
## Pede a troca para um estado canônico. DEAD chama die(). Devolve true se a troca foi aceita.
func request(canonical: State) -> bool:
	if _dead:  # Morto: só aceita DEAD (que já aconteceu).
		return false
	if canonical == State.DEAD:  # Morrer tem rotina própria.
		die()
		return true
	if not _canonical_names.has(canonical):  # Sem nó para esse estado: avisa uma vez.
		_warn_once(StringName("canonical_%d" % canonical),
			"%s: sem nó de estado para %s (aceitos: %s). Estados registrados: %s." % [
				name, State.keys()[canonical], CANDIDATES[canonical], ", ".join(get_state_names())])
		return false
	return transition_to(_canonical_names[canonical])  # Traduz o canônico para o nome real do nó e troca.


## Estado canônico atual (NONE se não houver).
## Devolve o estado canônico atual.
func get_canonical() -> State:
	return _current_canonical


## Estado canônico de onde o inimigo veio (NONE no primeiro estado).
## Devolve o estado canônico anterior.
func get_previous_canonical() -> State:
	return _previous_canonical


## Segundos de jogo no estado atual.
## Devolve há quantos segundos o inimigo está no estado atual.
func get_time_in_state() -> float:
	return _time_in_state


## Estados de ataque que se repetem (ex.: atirar enquanto o player está no alcance) avisam o
## progresso aqui; assim a rede de segurança só pega ataques que realmente travaram.
## Zera o cronômetro do estado, mostrando que o ataque ainda progride (evita a rede de segurança).
func report_progress() -> void:
	_time_in_state = 0.0  # Zera o tempo.


## True se o estado atual corresponde ao canônico.
## Diz se o estado atual é o canônico pedido.
func is_canonical(canonical: State) -> bool:
	return _current_canonical == canonical


## True depois de die().
## Diz se a máquina já passou por die().
func is_dead() -> bool:
	return _dead


## Morte: entra no estado Dead e trava a máquina.
## Morte: entra no estado Dead, trava a máquina e emite `warden_died`.
func die() -> void:
	if _dead:  # Já morreu: não repete.
		return
	_dead = true  # Marca como morto.
	# Nome do nó de morte (se existir).
	var dead_name: StringName = _canonical_names[State.DEAD] if _canonical_names.has(State.DEAD) else &""
	if dead_name != &"" and transition_to(dead_name):  # Entra no estado de morte.
		# Se die() veio de um enter()/exit(), a transição fica pendente e o
		# bloqueio é aplicado em _on_state_changed.
		# Se a troca ficou pendente, o bloqueio é aplicado depois, em _on_state_changed.
		if is_in_state(dead_name):
			locked = true  # nada tira o inimigo do estado de morte
	else:
		stop()  # Sem estado Dead: apenas para a máquina.
	warden_died.emit()  # Avisa a morte.


## Depois de die() só o estado Dead é aceito.
## Depois de die() só o estado Dead é aceito. Aceita também nomes que não existem se houver um equivalente canônico.
func transition_to(state_name: StringName) -> bool:
	if _dead and to_canonical(state_name) != State.DEAD:  # Morto só aceita DEAD.
		return false
	if has_state(state_name):  # O nome existe de verdade: usa a máquina base.
		return super.transition_to(state_name)

	var canonical: State = to_canonical(state_name)  # Procura o equivalente canônico do nome.
	if canonical == State.NONE or not _canonical_names.has(canonical):  # Sem equivalente: avisa e recusa.
		_warn_once(state_name, "%s: estado '%s' não existe e não tem equivalente canônico. Registrados: %s." % [
			name, state_name, ", ".join(get_state_names())])
		return false
	var fallback: StringName = _canonical_names[canonical]  # Usa o nó que representa esse estado.
	# Avisa a substituição uma vez.
	_warn_once(state_name, "%s: estado '%s' não existe; usando '%s' (%s) no lugar." % [
		name, state_name, fallback, State.keys()[canonical]])
	return super.transition_to(fallback)  # Faz a troca para o nó equivalente.


## Converte o nome de um nó de estado no estado canônico (por prefixo).
## Traduz o nome do nó de estado para o estado canônico, olhando o começo do nome.
static func to_canonical(state_name: StringName) -> State:
	var key: String = String(state_name).to_lower()  # Nome em minúsculas.
	if key.is_empty():  # Nome vazio: sem estado.
		return State.NONE
	if key.begins_with("idle"):  # "idle..." -> IDLE.
		return State.IDLE
	if key.begins_with("chase"):  # "chase..." -> CHASE.
		return State.CHASE
	if key.begins_with("patrol") or key.begins_with("wander"):  # "patrol..." ou "wander..." -> PATROL.
		return State.PATROL
	if key.begins_with("dead") or key.begins_with("death"):  # "dead..." ou "death..." -> DEAD.
		return State.DEAD
	if key.contains("attack") or key.begins_with("energywave"):  # Qualquer nome com "attack" -> ATTACK.
		return State.ATTACK
	return State.NONE


## Localiza os nós Idle/Chase/Attack/Dead entre os filhos.
## Procura entre os filhos os nós que correspondem a Idle, Chase, Attack, Dead e Patrol.
func _resolve_canonical_states() -> void:
	_canonical_names.clear()  # Recomeça a lista.
	for canonical: State in CANDIDATES:  # Para cada estado canônico.
		for candidate: StringName in CANDIDATES[canonical]:  # Tenta cada nome aceito.
			if has_state(candidate):  # Achou um nó com esse nome.
				_canonical_names[canonical] = get_state(candidate).name  # Guarda o nome real do nó.
				break

	# Fallback: um nó com nome fora da lista (ex.: "SpecialAttack") ainda é
	# classificado por prefixo, para que o canônico não fique vazio à toa.
	# Nomes fora da lista (ex.: "SpecialAttack") são classificados pelo prefixo.
	for state_name: String in get_state_names():
		var canonical: State = to_canonical(StringName(state_name))  # Traduz o nome do nó.
		# Só preenche se ainda estiver vazio.
		if canonical != State.NONE and not _canonical_names.has(canonical):
			_canonical_names[canonical] = StringName(state_name)

	for required: State in REQUIRED:  # Avisa se faltar algum estado obrigatório.
		if not _canonical_names.has(required):
			# Mensagem de erro com os nomes aceitos.
			push_warning("%s: nenhum nó de estado para %s (nomes aceitos: %s). Registrados: %s." % [
				name, State.keys()[required], CANDIDATES[required], ", ".join(get_state_names())])


## Trava a máquina ao entrar em Dead e emite o sinal canônico.
## Atualiza os estados canônicos a cada troca e trava a máquina ao entrar em Dead.
func _on_state_changed(previous: StringName, new_state: StringName) -> void:
	if _dead and to_canonical(new_state) == State.DEAD:  # Entrou em Dead depois de die(): trava.
		locked = true
	_previous_canonical = to_canonical(previous)  # Guarda o canônico anterior.
	_current_canonical = to_canonical(new_state)  # Guarda o canônico atual.
	_time_in_state = 0.0  # Zera o tempo no estado.
	warden_state_changed.emit(_previous_canonical, _current_canonical)  # Avisa a troca canônica.
