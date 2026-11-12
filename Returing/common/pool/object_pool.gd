class_name ObjectPool
extends Node
## Pool de cenas: instancia cada ataque uma vez e o reaproveita, sem queue_free() a cada disparo.

## Cena reaproveitada (a raiz precisa herdar de PooledArea).
@export var scene: PackedScene
## Instâncias criadas no _ready (evita instanciar nós no meio da luta).
@export_range(0, 256, 1) var prewarm_count: int = 0
## Limite de instâncias (em uso + livres); acima disso acquire() devolve null.
@export_range(1, 512, 1) var max_size: int = 64
## Ligado, o pool só cria instâncias novas no fim do frame (acquire() devolve null naquela vez).
## Necessário para pools usados dentro de callbacks de física, onde nascer um Area2D gera erro.
@export var grow_deferred: bool = false

var _idle: Array[PooledArea] = []  # Instâncias livres, prontas para serem entregues.
var _all: Array[PooledArea] = []  # Todas as instâncias criadas (livres e em uso).
# True depois de avisar que o limite foi atingido (o aviso sai uma vez só).
var _warned_limit: bool = false
var _grow_pending: bool = false  # True se já há uma criação agendada para o fim do quadro.


## Cria antecipadamente as instâncias pedidas em `prewarm_count` (respeitando o limite).
func _ready() -> void:
	for _i: int in mini(prewarm_count, max_size):  # Cria cada instância já desligada.
		var instance: PooledArea = _create_instance()
		if instance != null:  # Instância válida entra na lista de livres.
			_idle.append(instance)


## Entrega uma instância ligada (null se o limite do pool foi atingido).
## Entrega uma instância ligada: reaproveita uma livre ou cria uma nova. Devolve null se o limite foi atingido.
func acquire() -> PooledArea:
	var instance: PooledArea = null
	if _idle.is_empty():  # Não há livre: precisa criar.
		if grow_deferred:  # Modo adiado: agenda a criação e devolve null desta vez.
			_request_growth()
			return null
		instance = _create_instance()  # Criação imediata.
	else:
		instance = _idle.pop_back()  # Reaproveita a última livre.
	if instance == null:
		return null
	instance.pool_activate()  # Liga a instância (visível e com física).
	return instance


## Garante pelo menos `count` instâncias criadas (chame fora de callbacks de física).
## Cria instâncias até o pool ter `count` (ou o limite). Não use dentro de callbacks de física.
func ensure_size(count: int) -> void:
	while _all.size() < mini(count, max_size):  # Cria enquanto faltar instância e houver espaço.
		var instance: PooledArea = _create_instance()
		if instance == null:
			return
		_idle.append(instance)


## Recolhe uma instância em uso.
## Recolhe uma instância em uso e a coloca na lista de livres.
func release(instance: PooledArea) -> void:
	# Ignora instância liberada ou que já estava livre.
	if not CombatUtils.is_valid(instance) or not instance.is_in_use():
		return
	instance.pool_deactivate()  # Desliga a instância.
	_idle.append(instance)  # Volta para a lista de livres.


## Recolhe todas as instâncias em uso (transição de fase, morte do dono).
## Recolhe todas as instâncias em uso (troca de fase, morte do dono).
func release_all() -> void:
	for instance: PooledArea in _all:
		release(instance)


## Quantas instâncias estão em uso agora.
## Calcula quantas instâncias estão em uso (todas menos as livres).
func get_active_count() -> int:
	return _all.size() - _idle.size()


## Agenda a criação de uma instância para o fim do frame.
## Agenda a criação de uma instância para o fim do quadro (criar Area2D no meio da física causa erro).
func _request_growth() -> void:
	if _grow_pending:  # Já há uma criação agendada.
		return  # Evita agendar duas vezes.
	_grow_pending = true
	_grow_one.call_deferred()  # Roda depois da física.


## Cria uma instância agendada por `_request_growth`.
func _grow_one() -> void:
	_grow_pending = false  # Libera novo agendamento.
	var instance: PooledArea = _create_instance()  # Cria e registra.
	if instance != null:
		_idle.append(instance)


## Cria uma instância nova, registra e deixa desligada. Devolve null se passou do limite ou se a cena é inválida.
## Cria e registra uma instância nova, já desligada.
func _create_instance() -> PooledArea:
	if _all.size() >= max_size:  # Atingiu o limite de instâncias.
		if not _warned_limit:  # Avisa só uma vez.
			_warned_limit = true
			# Aviso no console para o desenvolvedor aumentar o limite.
			push_warning("ObjectPool '%s': limite de %d instâncias atingido." % [name, max_size])
		return null
	# Instancia a cena garantindo que a raiz é um PooledArea.
	var instance := CombatUtils.instantiate_as(scene, PooledArea) as PooledArea
	if instance == null:
		return null
	instance.pool = self  # A instância conhece o pool para devolver-se.
	add_child(instance)  # Entra na árvore como filha do pool.
	_all.append(instance)  # Registra na lista geral.
	instance.pool_deactivate()  # Começa desligada.
	return instance
