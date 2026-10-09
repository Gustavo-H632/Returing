class_name CombatUtils
extends RefCounted
## Funções de combate

const GROUP_PLAYER: StringName = &"player"
const GROUP_ENEMY: StringName = &"enemy"
const GROUP_HURTBOX: StringName = &"hurtbox"
const GROUP_HITBOX: StringName = &"hitbox"

## Camadas de física 
const LAYER_WORLD: int = 1
const LAYER_PLAYER: int = 2
const LAYER_ENEMY: int = 3
const LAYER_PLAYER_HURTBOX: int = 4
const LAYER_ENEMY_HURTBOX: int = 5

## true se o objeto existe e não foi liberado da memória.
static func is_valid(obj: Variant) -> bool:
	return is_instance_valid(obj)


## true se o nó é válidoe não foi liberado.
static func is_alive(obj: Variant) -> bool:
	if not is_valid(obj):
		return false
	if obj is Node:
		var node: Node = obj
		return node.is_inside_tree() and not node.is_queued_for_deletion()
	return true


## true se é o player vivo na árvore.
static func is_player(obj: Variant) -> bool:
	if not is_alive(obj) or not obj is Node:
		return false
	var node: Node = obj
	return node.is_in_group(GROUP_PLAYER)


## true se o ator reporta estar morto 
static func is_dead_actor(obj: Variant) -> bool:
	if not is_valid(obj):
		return true
	var o: Object = obj
	if o.has_method(&"esta_morto"):
		return o.call(&"esta_morto") == true
	if o.has_method(&"is_dead"):
		return o.call(&"is_dead") == true
	return false


## Alvo válido para perseguir e não está morto.
static func is_targetable(obj: Variant) -> bool:
	return is_alive(obj) and not is_dead_actor(obj)

## Dono do nó: actor do Inspector, owner ou pai.
static func get_actor(node: Node) -> Node:
	if not is_valid(node):
		return null
	var explicit: Variant = node.get(&"actor")
	if is_valid(explicit) and explicit is Node:
		var actor_node: Node = explicit
		return actor_node
	if node.owner != null:
		return node.owner
	return node.get_parent()

## dano
static func can_take_damage(target: Variant) -> bool:
	if not is_alive(target):
		return false
	var obj: Object = target
	return obj.has_method(&"take_damage") or obj.has_method(&"tomar_dano")


## API de dano. Todos os take_damage  aceitam 
## Retorna true SOMENTE se o alvo aceitou o dano. 
static func apply_damage(target: Variant, amount: int, source: Variant = null) -> bool:
	if amount <= 0 or not is_alive(target):
		return false
	var obj: Object = target
	if obj.has_method(&"take_damage"):
		return _accepted(obj.call(&"take_damage", amount, source))
	if obj.has_method(&"tomar_dano"):
		return _accepted(obj.call(&"tomar_dano", amount))
	return false


## Traduz o retorno de take_damage
static func _accepted(result: Variant) -> bool:
	match typeof(result):
		TYPE_NIL:
			return true
		TYPE_BOOL:
			return result == true
		TYPE_INT, TYPE_FLOAT:
			return result > 0
	return true
 
## Nó onde projéteis/efeitos devem ser instanciados.
static func get_spawn_parent(context: Node) -> Node:
	if not is_valid(context) or not context.is_inside_tree():
		return null
	var tree := context.get_tree()
	if tree.current_scene != null:
		return tree.current_scene
	return tree.root


## Instancia `scene` na posição global `at`.

## Instancia a cena na posição e adiciona no fim do frame.
static func spawn(scene: PackedScene, context: Node, at: Vector2, required_type: Variant = null) -> Node:
	if scene == null:
		push_warning("CombatUtils.spawn: PackedScene nula (verifique o Inspector).")
		return null
	var parent := get_spawn_parent(context)
	if parent == null:
		push_warning("CombatUtils.spawn: contexto fora da árvore, spawn cancelado.")
		return null

	var instance := instantiate_as(scene, required_type)
	if instance == null:
		return null
	if instance is Node2D:
		var local_pos := at
		if parent is CanvasItem:
			local_pos = (parent as CanvasItem).get_global_transform().affine_inverse() * at
		(instance as Node2D).position = local_pos
	_add_child_deferred.call_deferred(parent, instance)
	return instance


## Instancia `scene` SEM adicionar à árvore
static func instantiate_as(scene: PackedScene, required_type: Variant = null) -> Node:
	if scene == null:
		push_warning("CombatUtils.instantiate_as: PackedScene nula (verifique o Inspector).")
		return null
	var instance := scene.instantiate()
	if instance == null:
		return null
	if required_type != null and not is_instance_of(instance, required_type):
		push_warning("CombatUtils: a raiz de '%s' não tem o tipo/script esperado." % scene.resource_path)
		instance.free()
		return null
	return instance


## Se o pai sumiu antes do fim do frame                              
static func _add_child_deferred(parent: Variant, instance: Variant) -> void:
	# Parâmetros Variant de propósito: com tipo Node, um argumento já liberado faz o motor
	# rejeitar a chamada ANTES do corpo, e esta checagem nunca executaria.                                                                                                                                                       
	if not is_instance_valid(instance):
		return
	var child: Node = instance
	if is_alive(parent):
		var parent_node: Node = parent
		parent_node.add_child(child)
	else:
		child.free()


# sinais

## timer no game
static func game_timer(context: Node, seconds: float) -> SceneTreeTimer:
	if not is_alive(context):
		return null
	return context.get_tree().create_timer(maxf(seconds, 0.0), false)


## Conecta só se ainda não estiver conectado.
static func connect_once(sig: Signal, callable: Callable, flags: int = 0) -> void:
	if not sig.is_connected(callable):
		sig.connect(callable, flags)


## Círculo próprio do nó com o raio pedido.
static func set_unique_circle_radius(shape_node: CollisionShape2D, radius: float) -> bool:
	if not is_valid(shape_node):
		return false
	var circle := shape_node.shape as CircleShape2D
	circle = CircleShape2D.new() if circle == null else circle.duplicate() as CircleShape2D
	circle.radius = maxf(radius, 0.0)
	shape_node.shape = circle
	return true


## Raio do círculo ou o fallback.
static func get_circle_radius(shape_node: CollisionShape2D, fallback: float) -> float:
	if is_valid(shape_node) and shape_node.shape is CircleShape2D:
		return (shape_node.shape as CircleShape2D).radius
	return fallback
