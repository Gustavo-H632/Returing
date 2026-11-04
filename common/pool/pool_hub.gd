class_name PoolHub
extends Node
## Pools por cena: um ObjectPool para cada PackedScene pedida, criado na primeira vez e liberado com a cena.

const HUB_NAME: StringName = &"PoolHub"
## Limite de instâncias de cada pool criado pelo hub.
const DEFAULT_MAX_SIZE: int = 96

var _pools: Dictionary[String, ObjectPool] = {}


## Instância pronta (ligada e já na árvore) da cena pedida, ou null (cena nula, tipo errado, pool cheio).
static func acquire(scene: PackedScene, context: Node, required_type: Variant = null) -> PooledArea:
	if scene == null:
		push_warning("PoolHub.acquire: PackedScene nula (verifique o Inspector).")
		return null
	var hub: PoolHub = _get_hub(context)
	if hub == null:
		return null
	var instance: PooledArea = hub._get_pool(scene).acquire()
	if instance == null:
		return null
	if required_type != null and not is_instance_of(instance, required_type):
		push_warning("PoolHub: a raiz de '%s' não tem o tipo/script esperado." % scene.resource_path)
		instance.recycle()
		return null
	return instance


## Cria `count` instâncias da cena com antecedência (no fim do frame), para o primeiro disparo
## dentro de um callback de física não precisar criar nós.
static func prewarm(scene: PackedScene, context: Node, count: int) -> void:
	_prewarm_now.call_deferred(scene, context, count)


static func _prewarm_now(scene: PackedScene, context: Node, count: int) -> void:
	if scene == null or not CombatUtils.is_alive(context):
		return
	var hub: PoolHub = _get_hub(context)
	if hub != null:
		hub._get_pool(scene).ensure_size(count)


## Hub da cena atual (criado sob demanda).
static func _get_hub(context: Node) -> PoolHub:
	var parent: Node = CombatUtils.get_spawn_parent(context)
	if parent == null:
		push_warning("PoolHub: contexto fora da árvore, pedido cancelado.")
		return null
	var hub := parent.get_node_or_null(NodePath(HUB_NAME)) as PoolHub
	if hub == null:
		hub = PoolHub.new()
		hub.name = HUB_NAME
		parent.add_child(hub)
	return hub


## Pool da cena pedida (criado na primeira vez).
func _get_pool(scene: PackedScene) -> ObjectPool:
	var key: String = scene.resource_path if not scene.resource_path.is_empty() else str(scene.get_instance_id())
	if not _pools.has(key):
		var pool := ObjectPool.new()
		pool.name = StringName(key.get_file().get_basename() + "Pool")
		pool.scene = scene
		pool.max_size = DEFAULT_MAX_SIZE
		pool.grow_deferred = true
		add_child(pool)
		_pools[key] = pool
	return _pools[key]
