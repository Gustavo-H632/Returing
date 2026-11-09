class_name PoolHub
extends Node
## Pools por cena: um ObjectPool para cada PackedScene pedida, criado na primeira vez e liberado com a cena.

const HUB_NAME: StringName = &"PoolHub"  # Nome do nó do hub na cena.
## Limite de instâncias de cada pool criado pelo hub.
const DEFAULT_MAX_SIZE: int = 96

var _pools: Dictionary[String, ObjectPool] = {}  # Pools já criados: caminho da cena -> pool.


## Instância pronta (ligada e já na árvore) da cena pedida, ou null (cena nula, tipo errado, pool cheio).
## Pede uma instância pronta (ligada e na árvore) da cena. Devolve null para cena nula, tipo errado ou pool cheio.
static func acquire(scene: PackedScene, context: Node, required_type: Variant = null) -> PooledArea:
	if scene == null:  # Cena nula (esqueceu de arrastar no Inspector).
		push_warning("PoolHub.acquire: PackedScene nula (verifique o Inspector).")
		return null
	var hub: PoolHub = _get_hub(context)  # Hub da cena atual.
	if hub == null:
		return null
	var instance: PooledArea = hub._get_pool(scene).acquire()  # Pega do pool dessa cena.
	if instance == null:
		return null
	# Confere o tipo da raiz, se foi pedido.
	if required_type != null and not is_instance_of(instance, required_type):
		push_warning("PoolHub: a raiz de '%s' não tem o tipo/script esperado." % scene.resource_path)
		instance.recycle()  # Tipo errado: devolve ao pool.
		return null
	return instance


## Cria `count` instâncias da cena com antecedência (no fim do frame), para o primeiro disparo
## dentro de um callback de física não precisar criar nós.
## Agenda a criação antecipada de `count` instâncias.
static func prewarm(scene: PackedScene, context: Node, count: int) -> void:
	_prewarm_now.call_deferred(scene, context, count)  # Adiado para o fim do quadro.


## Faz de fato a criação antecipada (chamada adiada por `prewarm`).
static func _prewarm_now(scene: PackedScene, context: Node, count: int) -> void:
	if scene == null or not CombatUtils.is_alive(context):  # Cena nula ou contexto removido: nada a fazer.
		return
	var hub: PoolHub = _get_hub(context)  # Hub da cena.
	if hub != null:
		hub._get_pool(scene).ensure_size(count)  # Garante o tamanho pedido.


## Hub da cena atual (criado sob demanda).
## Acha (ou cria) o hub que guarda os pools da cena atual.
static func _get_hub(context: Node) -> PoolHub:
	var parent: Node = CombatUtils.get_spawn_parent(context)  # Nó onde o hub fica.
	if parent == null:  # Fora da árvore não há onde criar o hub.
		push_warning("PoolHub: contexto fora da árvore, pedido cancelado.")
		return null
	var hub := parent.get_node_or_null(NodePath(HUB_NAME)) as PoolHub  # Procura um hub existente.
	if hub == null:  # Não existe: cria.
		hub = PoolHub.new()  # Cria o hub.
		hub.name = HUB_NAME  # Dá o nome padrão.
		parent.add_child(hub)  # Entra na cena (some junto com ela).
	return hub


## Pool da cena pedida (criado na primeira vez).
## Devolve o pool da cena, criando-o na primeira vez.
func _get_pool(scene: PackedScene) -> ObjectPool:
	# Chave do pool: caminho da cena (ou id, se a cena não tem arquivo).
	var key: String = scene.resource_path if not scene.resource_path.is_empty() else str(scene.get_instance_id())
	if not _pools.has(key):  # Primeira vez: cria o pool.
		var pool := ObjectPool.new()  # Cria o pool.
		# Nome legível no editor (ex.: "PlayerProjectilePool").
		pool.name = StringName(key.get_file().get_basename() + "Pool")
		pool.scene = scene  # Cena que o pool reaproveita.
		pool.max_size = DEFAULT_MAX_SIZE  # Limite do hub.
		pool.grow_deferred = true  # Cria instâncias no fim do quadro (seguro em callbacks de física).
		add_child(pool)  # Entra na árvore.
		_pools[key] = pool  # Guarda para a próxima vez.
	return _pools[key]
