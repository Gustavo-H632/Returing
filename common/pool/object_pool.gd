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

var _idle: Array[PooledArea] = []
var _all: Array[PooledArea] = []
var _warned_limit: bool = false
var _grow_pending: bool = false


func _ready() -> void:
	for _i: int in mini(prewarm_count, max_size):
		var instance: PooledArea = _create_instance()
		if instance != null:
			_idle.append(instance)


## Entrega uma instância ligada (null se o limite do pool foi atingido).
func acquire() -> PooledArea:
	var instance: PooledArea = null
	if _idle.is_empty():
		if grow_deferred:
			_request_growth()
			return null
		instance = _create_instance()
	else:
		instance = _idle.pop_back()
	if instance == null:
		return null
	instance.pool_activate()
	return instance


## Garante pelo menos `count` instâncias criadas (chame fora de callbacks de física).
func ensure_size(count: int) -> void:
	while _all.size() < mini(count, max_size):
		var instance: PooledArea = _create_instance()
		if instance == null:
			return
		_idle.append(instance)


## Recolhe uma instância em uso.
func release(instance: PooledArea) -> void:
	if not CombatUtils.is_valid(instance) or not instance.is_in_use():
		return
	instance.pool_deactivate()
	_idle.append(instance)


## Recolhe todas as instâncias em uso (transição de fase, morte do dono).
func release_all() -> void:
	for instance: PooledArea in _all:
		release(instance)


## Quantas instâncias estão em uso agora.
func get_active_count() -> int:
	return _all.size() - _idle.size()


## Agenda a criação de uma instância para o fim do frame.
func _request_growth() -> void:
	if _grow_pending:
		return
	_grow_pending = true
	_grow_one.call_deferred()


func _grow_one() -> void:
	_grow_pending = false
	var instance: PooledArea = _create_instance()
	if instance != null:
		_idle.append(instance)


## Cria e registra uma instância nova, já desligada.
func _create_instance() -> PooledArea:
	if _all.size() >= max_size:
		if not _warned_limit:
			_warned_limit = true
			push_warning("ObjectPool '%s': limite de %d instâncias atingido." % [name, max_size])
		return null
	var instance := CombatUtils.instantiate_as(scene, PooledArea) as PooledArea
	if instance == null:
		return null
	instance.pool = self
	add_child(instance)
	_all.append(instance)
	instance.pool_deactivate()
	return instance
